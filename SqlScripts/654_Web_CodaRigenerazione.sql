-- ============================================================================
-- La coda di rigenerazione: il sito non resta indietro, nemmeno se nessuno ascolta
--
-- IL PROBLEMA. Il sito e' fatto di pagine statiche rigenerate su richiesta: una
-- pagina resta com'era finche' qualcuno non dice «rifalla». Il trigger
-- `trg_mov_clienti_viaggi_posti` lo diceva gia', con
-- `pg_notify('web_tour_revalidate', ...)`, a ogni variazione di iscrizione.
--
-- ⛔️ MA `pg_notify` E' EFFIMERO. Se nessuno e' in ascolto nell'istante in cui il
-- messaggio parte, **il messaggio e' perso per sempre**. Basta un riavvio
-- dell'ascoltatore nel momento sbagliato e una pagina resta ferma su «3 posti»
-- quando sono zero: nessun errore, nessuna traccia, e se ne accorge un cliente.
--
-- LA SCELTA (Adriano, 2026-09-22): **tutte e due le reti**.
--   1. questa CODA a tabella, che sopravvive ai riavvii, si puo' guardare per
--      sapere cosa e' in attesa, e si puo' ripetere se qualcosa va storto;
--   2. la rigenerazione **a tempo** lato sito (ogni N minuti comunque), cosi' un
--      messaggio perso costa al massimo N minuti di ritardo invece che l'eternita'.
-- Il `pg_notify` resta: serve a svegliare l'ascoltatore subito. La coda e' la
-- verita', la notifica e' solo la sveglia.
--
-- ⭐️ COSA REGISTRA LA CODA: **cosa e' cambiato**, non quale indirizzo rigenerare.
-- Gli indirizzi li conosce il sito, e cambiano con lui; il database sa quale
-- contenuto e' stato toccato. Se la coda scrivesse URL, ogni ristrutturazione
-- del sito richiederebbe di cambiare i trigger.
--
-- ⚠️ IL CASO CHE CI SI DIMENTICA SEMPRE: quando l'ultimo tour di una sezione
-- sparisce, non basta rigenerare quella pagina — va rifatto **il menu**, che sta
-- in ogni pagina del sito. Per questo esiste l'oggetto 'menu'.
--
-- Riferimento: Sito Web SFT/Progettazione/2026-09-22-Disegno_Tappa1_Funzioni_Database.md §3
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) La coda
-- ============================================================================
CREATE TABLE IF NOT EXISTS web_revalidate_coda (
    coda_id       BIGSERIAL PRIMARY KEY,
    azienda_id    INTEGER     NOT NULL,
    -- 'tour' = la pagina di una scheda; 'menu' = il menu e le sezioni (tutto il sito)
    oggetto       VARCHAR(10) NOT NULL,
    -- Per 'tour' e' il web_tour_contenuti_id. Per 'menu' resta NULL.
    riferimento   BIGINT,
    -- Da dove arriva la richiesta: serve a capire, mesi dopo, perche' una pagina
    -- e' stata rifatta. Es. 'web_tour_contenuti/UPDATE'.
    origine       VARCHAR(80) NOT NULL,
    creata        TIMESTAMPTZ NOT NULL DEFAULT now(),
    presa_il      TIMESTAMPTZ,
    completata_il TIMESTAMPTZ,
    tentativi     INTEGER     NOT NULL DEFAULT 0,
    errore        TEXT,
    CONSTRAINT ck_coda_oggetto CHECK (oggetto IN ('tour', 'menu'))
);

-- ⚠️ Deduplica: se la stessa pagina e' gia' in attesa, non serve una seconda riga.
-- Dieci iscrizioni in un minuto sullo stesso tour = una rigenerazione, non dieci.
-- COALESCE perche' un indice unico ignora le righe con NULL, e 'menu' ha
-- riferimento NULL: senza, il menu verrebbe accodato all'infinito.
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_revalidate_in_attesa
    ON web_revalidate_coda (azienda_id, oggetto, COALESCE(riferimento, 0))
    WHERE completata_il IS NULL;

CREATE INDEX IF NOT EXISTS idx_web_revalidate_da_fare
    ON web_revalidate_coda (creata)
    WHERE completata_il IS NULL;

COMMENT ON TABLE web_revalidate_coda IS
    'Pagine del sito da rigenerare. Sopravvive ai riavvii, al contrario di pg_notify che se nessuno ascolta perde il messaggio. Registra COSA e'' cambiato, non quale URL rifare: gli URL li conosce il sito (script 654).';

-- ============================================================================
-- 2) Accodare
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_web_revalidate_accoda(
    p_azienda_id  INTEGER,
    p_oggetto     VARCHAR,
    p_riferimento BIGINT,
    p_origine     VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_azienda_id IS NULL THEN
        RETURN;   -- senza azienda non si sa quale sito rigenerare
    END IF;

    INSERT INTO web_revalidate_coda (azienda_id, oggetto, riferimento, origine)
    VALUES (p_azienda_id, p_oggetto, p_riferimento, p_origine)
    ON CONFLICT DO NOTHING;   -- gia' in attesa: va bene cosi'

    -- La sveglia per chi ascolta. ⚠️ Se non c'e' nessuno si perde, ed e' previsto:
    -- la verita' e' nella riga appena scritta, non in questo messaggio.
    PERFORM pg_notify('web_tour_revalidate',
        json_build_object('azienda_id', p_azienda_id,
                          'oggetto', p_oggetto,
                          'riferimento', p_riferimento)::text);
END;
$$;

-- ============================================================================
-- 3) Il trigger, uno solo per tutte le tabelle
--
-- ⚠️ Deve restare LEGGERISSIMO: gira dentro ogni salvataggio del gestionale.
-- Niente calcoli, niente join complicate — solo capire chi e' l'azienda e quale
-- contenuto, e scrivere una riga.
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_web_revalidate_func()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec        RECORD;
    v_azienda    INTEGER;
    v_contenuto  BIGINT;
    v_tocca_menu BOOLEAN := FALSE;
BEGIN
    v_rec := COALESCE(NEW, OLD);

    CASE TG_TABLE_NAME
        WHEN 'web_tour_contenuti' THEN
            v_azienda   := v_rec.azienda_id;
            v_contenuto := v_rec.web_tour_contenuti_id;
            -- ⚠️ Pubblicare o ritirare una scheda puo' far comparire o sparire
            -- un'intera SEZIONE: il menu va rifatto.
            v_tocca_menu := TRUE;

        WHEN 'web_tour_immagini', 'web_tour_itinerario', 'web_tour_mappa' THEN
            v_azienda   := v_rec.azienda_id;
            v_contenuto := v_rec.web_tour_contenuti_id_fk;

        WHEN 'ana_date_viaggi' THEN
            -- Una data che cambia puo' togliere l'ultimo tour da una sezione.
            v_azienda   := v_rec.azienda_id;
            v_tocca_menu := TRUE;
            SELECT c.web_tour_contenuti_id INTO v_contenuto
              FROM web_tour_contenuti c
             WHERE c.data_viaggio_id_fk = v_rec.data_viaggio_id
             LIMIT 1;

        WHEN 'ana_viaggi' THEN
            -- Capienza, soglia, incluso/escluso, difficolta': si vedono sulla scheda.
            v_azienda := v_rec.azienda_id;
            FOR v_contenuto IN
                SELECT c.web_tour_contenuti_id FROM web_tour_contenuti c
                 WHERE c.viaggio_id_fk = v_rec.viaggio_id
            LOOP
                PERFORM fn_web_revalidate_accoda(v_azienda, 'tour', v_contenuto,
                                                 TG_TABLE_NAME || '/' || TG_OP);
            END LOOP;
            RETURN NULL;

        ELSE
            RETURN NULL;
    END CASE;

    IF v_contenuto IS NOT NULL THEN
        PERFORM fn_web_revalidate_accoda(v_azienda, 'tour', v_contenuto,
                                         TG_TABLE_NAME || '/' || TG_OP);
    END IF;

    IF v_tocca_menu THEN
        PERFORM fn_web_revalidate_accoda(v_azienda, 'menu', NULL,
                                         TG_TABLE_NAME || '/' || TG_OP);
    END IF;

    RETURN NULL;   -- AFTER trigger
END;
$$;

DROP TRIGGER IF EXISTS trg_web_revalidate ON web_tour_contenuti;
CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON web_tour_contenuti
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

DROP TRIGGER IF EXISTS trg_web_revalidate ON web_tour_immagini;
CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON web_tour_immagini
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

DROP TRIGGER IF EXISTS trg_web_revalidate ON web_tour_itinerario;
CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON web_tour_itinerario
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

DROP TRIGGER IF EXISTS trg_web_revalidate ON web_tour_mappa;
CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON web_tour_mappa
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

DROP TRIGGER IF EXISTS trg_web_revalidate ON ana_date_viaggi;
CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON ana_date_viaggi
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

DROP TRIGGER IF EXISTS trg_web_revalidate ON ana_viaggi;
CREATE TRIGGER trg_web_revalidate AFTER UPDATE ON ana_viaggi
    FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func();

-- ============================================================================
-- 4) Le iscrizioni: l'unico caso che c'era gia'
--
-- `trg_mov_clienti_viaggi_posti_func` faceva solo il pg_notify. Ora accoda anche,
-- cosi' un cambio di «posti rimasti» non si perde piu'.
-- ⚠️ `mov_clienti_viaggi` non ha azienda_id: si risale dal viaggio.
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_mov_clienti_viaggi_posti_func()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec       RECORD;
    v_azienda   INTEGER;
    v_contenuto BIGINT;
BEGIN
    v_rec := COALESCE(NEW, OLD);

    SELECT v.azienda_id INTO v_azienda
      FROM ana_viaggi v WHERE v.viaggio_id = v_rec.viaggio_id_fk;

    SELECT c.web_tour_contenuti_id INTO v_contenuto
      FROM web_tour_contenuti c
     WHERE c.data_viaggio_id_fk = v_rec.data_viaggio_id_fk
     LIMIT 1;

    IF v_contenuto IS NOT NULL THEN
        PERFORM fn_web_revalidate_accoda(v_azienda, 'tour', v_contenuto,
                                         'mov_clienti_viaggi/' || TG_OP);
    END IF;

    RETURN NULL;
END;
$$;

-- ============================================================================
-- 5) Le funzioni per chi ascolta
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_web_revalidate_prossimi(p_limite INTEGER DEFAULT 20)
RETURNS TABLE(coda_id BIGINT, azienda_id INTEGER, oggetto VARCHAR,
              riferimento BIGINT, slug VARCHAR, origine VARCHAR, creata TIMESTAMPTZ)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- ⚠️ SKIP LOCKED: se un domani ci fossero due ascoltatori, non si prendono
    -- la stessa riga e non aspettano l'uno per l'altro.
    WITH prese AS (
        SELECT q.coda_id
          FROM web_revalidate_coda q
         WHERE q.completata_il IS NULL
         ORDER BY q.creata
         LIMIT p_limite
           FOR UPDATE SKIP LOCKED
    ), marcate AS (
        UPDATE web_revalidate_coda q
           SET presa_il = now(), tentativi = q.tentativi + 1
          FROM prese
         WHERE q.coda_id = prese.coda_id
        RETURNING q.*
    )
    SELECT m.coda_id, m.azienda_id, m.oggetto, m.riferimento,
           c.slug,          -- lo slug del tour, per comodita' di chi costruisce l'URL
           m.origine, m.creata
      FROM marcate m
      LEFT JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = m.riferimento
     ORDER BY m.creata;
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_revalidate_completa(p_ids BIGINT[])
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_revalidate_coda
       SET completata_il = now(), errore = NULL
     WHERE coda_id = ANY(p_ids) AND completata_il IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_revalidate_fallita(p_id BIGINT, p_errore TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
    -- Resta in coda: verra' ripresa. `tentativi` dice se si sta impuntando.
    UPDATE web_revalidate_coda
       SET presa_il = NULL, errore = left(p_errore, 2000)
     WHERE coda_id = p_id;
$$;

CREATE OR REPLACE FUNCTION fn_web_revalidate_pulisci(p_giorni INTEGER DEFAULT 7)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_revalidate_coda
     WHERE completata_il IS NOT NULL
       AND completata_il < now() - make_interval(days => p_giorni);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$;

COMMENT ON FUNCTION fn_web_revalidate_prossimi(INTEGER) IS
    'Le prossime pagine da rigenerare, marcandole come prese. SKIP LOCKED: due ascoltatori non si pestano i piedi (script 654).';

COMMIT;

-- ============================================================================
-- Verifica: si tocca qualcosa e si guarda la coda.
--
--   UPDATE web_tour_contenuti SET ordine = ordine WHERE web_tour_contenuti_id = <x>;
--   SELECT oggetto, riferimento, origine, creata FROM web_revalidate_coda
--    WHERE completata_il IS NULL ORDER BY creata;
--   -- attesi: una riga 'tour' e una riga 'menu'
--
--   SELECT * FROM fn_web_revalidate_prossimi(10);   -- le prende
--   SELECT fn_web_revalidate_completa(ARRAY[1,2]);  -- le chiude
-- ============================================================================
