-- ============================================================================
-- 636 — La stessa persona non puo' esistere due volte nella stessa azienda
--
-- Nasce dai due doppioni veri trovati in produzione il 2026-09-07 e risolti lo
-- stesso giorno: MAIORCA MARIA (3324/3327) e TACCA ALESSANDRO (4381/4377).
--
-- ⚠️ La premessa da cui si partiva era sbagliata: un indice unico c'era gia',
-- `ana_clienti_idx06_scoped` su (azienda, cognome, nome, data di nascita, CF).
-- Non protegge perche' in un btree UNIQUE il NULL non collide con niente —
-- nemmeno con un altro NULL. Su 777 clienti 324 hanno il codice fiscale NULL:
-- per loro quell'indice semplicemente non esiste. E' esattamente il caso
-- MAIORCA (nessuna delle due schede aveva il CF); nel caso TACCA una lo aveva e
-- l'altra no, quindi le due chiavi differivano e convivevano lo stesso.
--
-- Il lavoro non e' aggiungere un vincolo, e' sostituirne uno che dava una
-- falsa sicurezza.
--
-- COSA DEVE RESTARE POSSIBILE (misurato su PROD, in sola lettura):
--   - due coniugi con la STESSA email — 3 coppie vere in produzione: per questo
--     l'unicita' NON tocca l'indirizzo, che oltretutto non avrebbe fermato
--     nessuno dei due doppioni (MAIORCA non aveva email, TACCA ne aveva due);
--   - un cliente SENZA codice fiscale — 327 righe, quasi tutti stranieri e
--     storici;
--   - gli omonimi veri: GALLI ANDREA esiste due volte, nato nel 1964 e nel 1968.
--
-- IL CODICE FISCALE E' GIA' COPERTO dallo script 592
-- (`ana_clienti_cf_unico_per_azienda`, parziale sui CF non vuoti). Qui non si
-- rifa': manca l'altra meta', l'identita' anagrafica di chi il CF non ce l'ha.
--
-- ⚠️ QUESTO NON E' UN RILEVATORE DI DOPPIONI, e' la rete sotto. Il controllo
-- che parla resta `fn_ana_clienti_verifica_duplicato`, che confronta con piu'
-- tolleranza e dice a chi lavora chi e' l'omonimo e cosa fare. Restano fuori da
-- questo indice due casi reali:
--   - i 34 clienti senza data di nascita (32 in azienda 6, in SFT sono due:
--     GENDUSO FRANCESCA e FORNO RAFFAELLA);
--   - le date sbagliate: COLOMBO ROBERTA esiste due volte in SFT, «1964-05-20»
--     (3027) e «1964-05-25» (3889), stesso comune di nascita, stesso indirizzo
--     di residenza. Il CF `CLMRRT64E65A794E` dice che la data vera e' il 25
--     (`E65` = giorno 25 per una donna): la 3027 ha un refuso. Le due date
--     differiscono davvero, quindi questo indice NON l'avrebbe fermata. Le due schede
--     sono state fuse a mano su PROD il 2026-09-08 (documentato in
--     Documents/PROD/2026-09-08-Doppione_COLOMBO_3027.md): il caso e' chiuso, il
--     limite dell'indice no.
--
-- Violazioni oggi: zero, in locale e su PROD, su tutte le aziende.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Il codice fiscale «non lo so» si scrive in un modo solo
-- ---------------------------------------------------------------------------
-- Tre schede in produzione (MIRONOVA, SULLI, GRASSO) hanno la stringa vuota
-- invece di NULL. L'indice del 592 le esclude entrambe, quindi non e' un
-- problema di vincoli — e' un problema di dato: due scritture diverse per lo
-- stesso significato, che prima o poi divergono nel confronto.
UPDATE ana_clienti
   SET cliente_codicefiscale = NULL
 WHERE btrim(COALESCE(cliente_codicefiscale, '')) = ''
   AND cliente_codicefiscale IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. La stessa persona, una volta sola
-- ---------------------------------------------------------------------------
-- Parziale sulla data di nascita: senza data non si puo' distinguere un
-- doppione da un omonimo, e un indice che includesse i NULL non fermerebbe
-- comunque nulla (vedi sopra), mentre escluderli lo rende onesto su cosa copre.
CREATE UNIQUE INDEX IF NOT EXISTS ana_clienti_uq_identita
    ON ana_clienti (azienda_fk,
                    upper(btrim(cliente_cognome)),
                    upper(btrim(cliente_nome)),
                    cliente_data_nascita)
    WHERE cliente_data_nascita IS NOT NULL;

COMMENT ON INDEX ana_clienti_uq_identita IS
'Cognome, nome e data di nascita identificano una persona sola dentro la stessa azienda.
Sostituisce ana_clienti_idx06_scoped, che includeva anche il codice fiscale e percio'' non
valeva per le 324 schede che non ce l''hanno (in un btree UNIQUE il NULL non collide).
⚠️ Per azienda e non globale: le aziende sono silos. ⚠️ Non copre chi non ha la data di
nascita ne'' le date scritte male: per quelli vale fn_ana_clienti_verifica_duplicato.';

-- ---------------------------------------------------------------------------
-- 3. Via il vecchio indice, ma non l'accesso che serviva
-- ---------------------------------------------------------------------------
-- ⚠️ `ana_clienti_idx06_scoped` in PROD e' usato in lettura (37 scansioni), a
-- differenza del locale dove e' fermo a zero. Toglierlo e basta rischierebbe di
-- rallentare una ricerca; e il nuovo indice, essendo parziale, il planner non lo
-- puo' usare per una query che non garantisce «data di nascita non nulla».
-- Quindi si sostituisce con lo stesso accesso, senza la promessa di unicita'
-- che non manteneva.
DROP INDEX IF EXISTS ana_clienti_idx06_scoped;

CREATE INDEX IF NOT EXISTS ana_clienti_idx06_ricerca
    ON ana_clienti (azienda_fk,
                    upper(cliente_cognome),
                    upper(cliente_nome),
                    cliente_data_nascita,
                    upper(cliente_codicefiscale));

COMMENT ON INDEX ana_clienti_idx06_ricerca IS
'Stesse colonne del vecchio ana_clienti_idx06_scoped, ma NON unico: quell''unicita'' era
apparente (il NULL non collide) e la copre ora ana_clienti_uq_identita. Serve solo
alla ricerca per cognome/nome dentro l''azienda.';

-- ---------------------------------------------------------------------------
-- Verifiche
-- ---------------------------------------------------------------------------
DO $verifica$
DECLARE
    v_n     INTEGER;
    v_id    INTEGER;
    v_cols  TEXT;
    v_sel   TEXT;
    v_stato TEXT;
BEGIN
    -- I due indici ci sono, il vecchio no.
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='ana_clienti_uq_identita') THEN
        RAISE EXCEPTION '636: ana_clienti_uq_identita non e stato creato.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='ana_clienti_cf_unico_per_azienda') THEN
        RAISE EXCEPTION '636: manca ana_clienti_cf_unico_per_azienda (script 592): applicarlo prima.';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='ana_clienti_idx06_scoped') THEN
        RAISE EXCEPTION '636: il vecchio ana_clienti_idx06_scoped e ancora li.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='ana_clienti_idx06_ricerca') THEN
        RAISE EXCEPTION '636: manca l indice di ricerca che sostituisce il 06_scoped.';
    END IF;

    -- Nessun codice fiscale scritto come stringa vuota.
    SELECT count(*) INTO v_n FROM ana_clienti WHERE cliente_codicefiscale = '';
    IF v_n > 0 THEN
        RAISE EXCEPTION '636: restano % codici fiscali vuoti non normalizzati.', v_n;
    END IF;

    -- Il doppione viene rifiutato davvero. Si ricopia per intero una scheda
    -- esistente cambiando SOLO come e scritto il nome (minuscolo) e togliendo il
    -- codice fiscale: cosi si prova esattamente il caso MAIORCA — due schede
    -- della stessa persona, nessuna delle due con il CF — e non l indice del 592.
    SELECT cliente_id INTO v_id
      FROM ana_clienti WHERE cliente_data_nascita IS NOT NULL LIMIT 1;

    SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position),
           string_agg(CASE column_name
                        WHEN 'cliente_cognome'       THEN 'lower(cliente_cognome)'
                        WHEN 'cliente_nome'          THEN 'lower(cliente_nome)'
                        WHEN 'cliente_codicefiscale' THEN 'NULL'
                        ELSE quote_ident(column_name)
                      END, ', ' ORDER BY ordinal_position)
      INTO v_cols, v_sel
      FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'ana_clienti'
       AND column_name <> 'cliente_id';

    BEGIN
        EXECUTE format(
            'INSERT INTO ana_clienti (cliente_id, %s) SELECT (SELECT max(cliente_id)+1 FROM ana_clienti), %s FROM ana_clienti WHERE cliente_id = %s',
            v_cols, v_sel, v_id);
        RAISE EXCEPTION '636: il doppione e stato ACCETTATO, l indice non protegge.';
    EXCEPTION
        WHEN unique_violation THEN
            GET STACKED DIAGNOSTICS v_stato = CONSTRAINT_NAME;
            IF v_stato <> 'ana_clienti_uq_identita' THEN
                RAISE EXCEPTION '636: rifiutato, ma da % invece che da ana_clienti_uq_identita.', v_stato;
            END IF;
            RAISE NOTICE '636: doppione senza codice fiscale rifiutato da %.', v_stato;
    END;

    RAISE NOTICE '636: unicita anagrafica attiva su % clienti.', (SELECT count(*) FROM ana_clienti);
END
$verifica$;

COMMIT;
