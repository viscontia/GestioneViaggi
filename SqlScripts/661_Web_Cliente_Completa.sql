-- ============================================================================
-- Completare una scheda esistente senza poterla sovrascrivere
--
-- Disegno: Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-09-25-cliente-
-- riconosciuto-otp-design.md (approvato il 2026-09-25). Voce L4 delle due liste.
--
-- Il sito, per un cliente che NON ha superato il codice usa e getta, puo' solo
-- COMPLETARE la scheda: scrivere dove il campo e' vuoto. Riscrivere un dato che
-- c'e' gia' e' MODIFICARE, e senza codice non e' ammesso — altrimenti chi conosce
-- un'email riscrive residenza e documento di un altro (lo faceva /api/cliente/save
-- fino al 2026-09-25).
--
-- ⚠️ Cambia la decisione del 2026-09-05 (script 594), che lasciava sovrascrivere
-- recapiti, indirizzo e documento: da ora quella e' una modifica, e passa dall'OTP.
--
-- ⚠️ SI COMPLETANO SOLO I CAMPI DEL MODULO, elencati uno per uno (una whitelist,
-- non una lista di esclusi). Una lista di esclusi si allarga da sola il giorno in
-- cui ana_clienti prende una colonna nuova, e nessuno se ne accorge; una whitelist
-- no. Fuori restano, apposta:
--   - email e consenso: hanno la loro strada (fn_ana_clienti_aggancia_email,
--     fn_consenso_registra_risposta), e un consenso «completato» sarebbe falso;
--   - cognome e nome: sono l'identita', e in archivio non sono mai vuoti;
--   - note, IBAN, lingua, controparte, foto e file del documento, azienda, audit:
--     il modulo non li manda, quindi dal sito non devono poter arrivare.
-- La stessa lista da' l'etichetta per l'avviso al cliente: una fonte sola.
-- Titolo e comuni sono NOT NULL con chiave esterna, quindi in pratica non si
-- riempiono mai: restano per simmetria con fn_ana_clienti_campi_mancanti.
--
-- Vuoto e assente sono la stessa cosa, come in fn_ana_clienti_campi_mancanti:
-- NULL, stringa di soli spazi e, per le chiavi esterne, lo zero. Vale per il dato
-- in archivio (e' vuoto, si puo' riempire) e per quello ricevuto (e' vuoto, non
-- riempie e non svuota niente). Si accettano solo testi e numeri: un oggetto o
-- una lista al posto di un campo si salta.
--
-- ⚠️ NESSUN COMPLETAMENTO SENZA TESTIMONE. Cio' che rende accettabile scrivere
-- senza codice e' l'avviso che il sito manda al cliente, all'email in archivio,
-- con l'elenco dei campi completati. Senza email non c'e' avviso: la funzione
-- risponde «Cliente non trovato.», lo stesso messaggio del cliente che non
-- esiste, per non rivelare nulla. ⚠️ Per chi l'email non l'ha, il sito la aggancia
-- PRIMA con fn_ana_clienti_aggancia_email, e solo dopo completa.
--
-- ⚠️ CODICE FISCALE E DATI DI NASCITA SI COMPLETANO SOLO SE SI CONFERMANO A
-- VICENDA. Discende dal 594 (data e luogo di nascita identificano la persona, e
-- li conferma il codice fiscale) e dalla decisione di Adriano del 2026-09-25:
--   - il codice fiscale si scrive solo se fn_cf_verifica, sui dati uniti (scheda
--     + modulo), risponde CORRISPONDE o OMOCODIA. FORMA_OK (dati insufficienti,
--     o nato all'estero) non conferma niente: il campo si salta, senza errore;
--   - data e comune di nascita si scrivono solo se il codice fiscale e' GIA' IN
--     ARCHIVIO, arriva anche nella stessa chiamata, e con quei dati risponde
--     CORRISPONDE o OMOCODIA. Altrimenti si saltano;
--   - ⚠️ se in archivio mancano SIA il codice fiscale SIA la data di nascita, non
--     si completa nessuno dei due: si saltano, senza errore, e il sito passa al
--     codice usa e getta. «Si confermano a vicenda» li' non prova niente: il
--     codice fiscale si calcola in modo pubblico da cognome, nome, sesso e comune
--     (gia' in scheda) piu' la data, quindi una data inventata con il suo codice
--     calcolato tornerebbe sempre. Un dato conferma l'altro solo se uno dei due
--     c'era gia'. (Seconda revisione di qualita', 2026-09-25.)
--   - documento, recapiti, indirizzo e intolleranze si completano liberamente.
--
-- ⛔️ I MESSAGGI DI VALIDAZIONE NON ESCONO COSI' COME SONO. Il sito mostra al
-- visitatore il testo di ogni errore, e chi completa senza codice non ha
-- dimostrato di essere il titolare: fn_cf_verifica, per esempio, risponde con il
-- codice fiscale che «risulterebbe» dai dati in archivio, e da quello si leggono
-- data, sesso e comune di nascita di un altro. Per questo la funzione VALIDA
-- PRIMA DI SCRIVERE, con fn_ana_clienti_valida sulla scheda unita, e se qualcosa
-- non va solleva un testo suo, scelto dal codice di esito, senza valori dentro.
-- Solo se la validazione passa chiama fn_ana_clienti_update, che rivaluta gli
-- stessi dati e quindi passa anche lei. Conferme a FALSE: anche gli esiti
-- CONFERMA fermano.
--
-- Un valore malformato (una data «abc», un numero dove serve un comune, un comune
-- che non esiste) si traduce in un messaggio unico: l'errore di Postgres non dice
-- niente al cliente, e il DAO Flask lo inghiottirebbe.
-- ⛔️ Lo stesso per OGNI violazione di vincolo, non solo le chiavi esterne. I
-- vincoli che fn_ana_clienti_valida non guarda prima (rilascio dopo la nascita,
-- scadenza dopo il rilascio, l'indice unico su cognome + nome + data di nascita
-- senza comune) fanno uscire un errore il cui DETAIL e' la RIGA INTERA della
-- scheda: «Failing row contains (3870, SIG., VISCONTI, …, codice fiscale, …)».
-- Si risponde con un testo senza valori, e un'eccezione nuova non ha DETAIL.
--
-- ⚠️ La riga del cliente si legge FOR UPDATE: due completamenti insieme (doppio
-- clic, due schede aperte) non devono vedere tutti e due il campo vuoto e
-- riempirlo due volte con valori diversi. Il secondo aspetta il primo e poi
-- trova il campo pieno. E' una scrittura breve del sito: il lucchetto qui e'
-- quello giusto, a differenza della lettura dello script 660.
--
-- Permessi: nessun GRANT. Nasce chiusa ad anon (script 659); la chiama solo Flask,
-- che si connette come postgres, proprietario. search_path fissato (script 655).
--
-- Test: Test_661_Web_Cliente_Completa.sql (gira in una transazione annullata).
--
-- ✅ Applicato in locale e a PROD il 2026-09-26 (rilascio L4/L13, sito Flask v5.0.0); test OK.
-- ============================================================================

BEGIN;

-- L'esito di fn_cf_verifica su una scheda intera (jsonb con le colonne di
-- ana_clienti). Il sesso si ricava dal titolo, come in fn_ana_clienti_valida:
-- e' quello che il trigger scrivera', non quello che c'era prima.
-- ⚠️ Restituisce solo il codice di esito, mai il messaggio ne' il cf_atteso:
-- sono proprio i due campi che rivelano i dati di nascita della scheda.
CREATE OR REPLACE FUNCTION fn_web_cliente_completa_esito_cf(p_scheda JSONB)
RETURNS VARCHAR
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
    SELECT v.esito
      FROM fn_cf_verifica(
               p_scheda ->> 'cliente_codicefiscale',
               p_scheda ->> 'cliente_cognome',
               p_scheda ->> 'cliente_nome',
               (p_scheda ->> 'cliente_data_nascita')::DATE,
               (SELECT t.titolo_persone_sesso FROM ana_titolo_persone t
                 WHERE t.titolo_persone_cod = (p_scheda ->> 'cliente_titolo_fk')::INTEGER),
               (p_scheda ->> 'cliente_comune_nascita_fk')::INTEGER) v
     LIMIT 1;
$$;

COMMENT ON FUNCTION fn_web_cliente_completa_esito_cf(JSONB) IS
    'Solo l''esito di fn_cf_verifica su una scheda in jsonb, senza messaggio ne'' codice atteso. Serve a fn_web_cliente_completa (script 661).';

CREATE OR REPLACE FUNCTION fn_web_cliente_completa(p_cliente_id INTEGER, p_azienda_id INTEGER, p_dati JSONB)
RETURNS TABLE(campo VARCHAR, etichetta TEXT)
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_attuale   JSONB;
    v_filtrati  JSONB := '{}'::jsonb;
    -- colonna -> [ordine, etichetta], per restituire i campi scritti nell'ordine del modulo
    v_etichette JSONB := '{}'::jsonb;
    v_unito     JSONB;
    v_esito_cf  VARCHAR;
    v_cf_inviato TEXT;
    v_esito     VARCHAR;
    v_vincolo   TEXT;
    r           RECORD;
BEGIN
    SELECT to_jsonb(c) INTO v_attuale
      FROM ana_clienti c
     WHERE c.cliente_id = p_cliente_id AND c.azienda_fk = p_azienda_id
       FOR UPDATE;
    IF v_attuale IS NULL OR btrim(COALESCE(v_attuale ->> 'cliente_email', '')) = '' THEN
        RAISE EXCEPTION 'Cliente non trovato.';
    END IF;

    -- ⚠️ Le colonne della lista si chiamano `colonna` e `testo`, non `campo` ed
    -- `etichetta`: quei due nomi sono gia' le variabili di uscita della funzione,
    -- e in una query sarebbero ambigui.
    FOR r IN
        SELECT w.ordine, w.colonna, w.testo, p_dati -> w.colonna AS nuovo
          FROM (VALUES
                    ( 1, 'cliente_titolo_fk',                     'il titolo'),
                    ( 2, 'cliente_data_nascita',                  'la data di nascita'),
                    ( 3, 'cliente_comune_nascita_fk',             'il comune di nascita'),
                    ( 4, 'cliente_codicefiscale',                 'il codice fiscale'),
                    ( 5, 'cliente_comune_residenza_fk',           'il comune di residenza'),
                    ( 6, 'cliente_indirizzo_residenza',           'l''indirizzo di residenza'),
                    ( 7, 'cliente_preftelint',                    'il prefisso internazionale'),
                    ( 8, 'cliente_telefono',                      'il numero di telefono'),
                    ( 9, 'cliente_intolleranza',                  'le allergie o intolleranze'),
                    (10, 'cliente_tipodoc_identita',              'il tipo di documento'),
                    (11, 'cliente_documento_numero',              'il numero del documento'),
                    (12, 'cliente_documento_rilasciato_da',       'l''ente che ha rilasciato il documento'),
                    (13, 'cliente_documento_rilasciato_data',     'la data di rilascio del documento'),
                    (14, 'cliente_documento_rilasciato_scadenza', 'la data di scadenza del documento')
               ) AS w(ordine, colonna, testo)
         WHERE COALESCE(p_dati, '{}'::jsonb) ? w.colonna
    LOOP
        -- Solo testi e numeri: null, booleani, oggetti e liste non sono un dato del modulo.
        CONTINUE WHEN jsonb_typeof(r.nuovo) NOT IN ('string', 'number');
        -- Il dato ricevuto e' vuoto: non riempie niente (e non svuota niente).
        CONTINUE WHEN btrim(r.nuovo #>> '{}') = ''
                   OR (r.colonna LIKE '%\_fk' AND (r.nuovo #>> '{}') = '0');
        -- Il dato in archivio c'e': cambiarlo e' una modifica, e senza codice no.
        CONTINUE WHEN NOT (btrim(COALESCE(v_attuale ->> r.colonna, '')) = ''
                           OR (r.colonna LIKE '%\_fk' AND (v_attuale ->> r.colonna) = '0'));

        v_filtrati  := v_filtrati  || jsonb_build_object(r.colonna, r.nuovo);
        v_etichette := v_etichette || jsonb_build_object(r.colonna, jsonb_build_array(r.ordine, r.testo));
    END LOOP;

    BEGIN
        -- Codice fiscale e nascita: si tengono solo se si confermano a vicenda.
        IF v_filtrati ?| ARRAY['cliente_data_nascita', 'cliente_comune_nascita_fk',
                               'cliente_codicefiscale'] THEN
            v_cf_inviato := upper(btrim(COALESCE(p_dati ->> 'cliente_codicefiscale', '')));

            -- 1. La nascita: serve il codice fiscale GIA' IN ARCHIVIO, arrivato
            --    anche nel modulo, che con i dati nuovi corrisponda. Quello che si
            --    sta completando non basta: vedi la testata.
            IF v_filtrati ?| ARRAY['cliente_data_nascita', 'cliente_comune_nascita_fk'] THEN
                v_unito := v_attuale || v_filtrati;
                v_esito_cf := fn_web_cliente_completa_esito_cf(v_unito);
                IF v_cf_inviato = ''
                   OR v_cf_inviato <> upper(btrim(COALESCE(v_attuale ->> 'cliente_codicefiscale', '')))
                   OR v_esito_cf NOT IN ('CORRISPONDE', 'OMOCODIA') THEN
                    v_filtrati := v_filtrati - 'cliente_data_nascita' - 'cliente_comune_nascita_fk';
                END IF;
            END IF;

            -- 2. Il codice fiscale: FORMA_OK non conferma niente, e si salta.
            --    Se la data di nascita mancava in archivio, dal punto 1 non e'
            --    arrivata: qui l'esito e' FORMA_OK, e il codice si salta anche lui.
            --    Un esito di errore invece resta, e lo ferma la validazione qui
            --    sotto con un messaggio senza valori.
            IF v_filtrati ? 'cliente_codicefiscale' THEN
                v_esito_cf := fn_web_cliente_completa_esito_cf(v_attuale || v_filtrati);
                IF v_esito_cf IN ('FORMA_OK', 'MANCANTE') THEN
                    v_filtrati := v_filtrati - 'cliente_codicefiscale';
                END IF;
            END IF;
        END IF;

        IF v_filtrati = '{}'::jsonb THEN
            RETURN;
        END IF;

        -- ⛔️ Validare prima di scrivere, e non far uscire il messaggio originale:
        -- vedi la testata. Si guarda il primo esito che ferma, gli altri no:
        -- al visitatore basta sapere che cosa correggere.
        SELECT v.esito INTO v_esito
          FROM fn_ana_clienti_valida(v_attuale || v_filtrati, p_cliente_id) v
         WHERE v.gravita IN ('ERRORE', 'CONFERMA')
         ORDER BY CASE WHEN v.esito IN ('FORMA', 'CARATTERE_CONTROLLO', 'INVERTITI', 'NON_CORRISPONDE')
                       THEN 0 ELSE 1 END
         LIMIT 1;

        IF v_esito IS NOT NULL THEN
            RAISE EXCEPTION '%', CASE
                WHEN v_esito IN ('FORMA', 'CARATTERE_CONTROLLO', 'INVERTITI', 'NON_CORRISPONDE')
                    THEN 'Il codice fiscale non corrisponde ai dati della scheda.'
                WHEN v_esito = 'RILASCIO_FUTURO'
                    THEN 'La data di rilascio del documento è nel futuro.'
                WHEN v_esito = 'PREFISSO_MANCANTE'
                    THEN 'C''è un numero di telefono ma manca il prefisso internazionale.'
                WHEN v_esito LIKE 'MANCA\_%'
                    THEN 'Per completare la scheda servono anche gli altri dati obbligatori: compilali, oppure usa il codice per modificare la scheda.'
                -- Doppioni, nascita senza codice fiscale, e qualunque esito nuovo:
                -- nessun dettaglio, perche' il dettaglio parla di altre schede.
                ELSE 'Alcuni dati non sono validi: controllali, oppure usa il codice per modificare la scheda.'
            END;
        END IF;

        PERFORM fn_ana_clienti_update(p_cliente_id, v_filtrati, FALSE);
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'Questi dati risultano già su un''altra scheda: usa il codice per modificare la scheda.';
        WHEN check_violation THEN
            -- Solo i due vincoli sulle date sono «date incoerenti»; gli altri
            -- (indirizzo troppo corto, caratteri nel telefono) sono un formato.
            GET STACKED DIAGNOSTICS v_vincolo = CONSTRAINT_NAME;
            IF v_vincolo IN ('ana_clienti_rilascio_dopo_nascita_check',
                             'ana_clienti_scadenza_dopo_rilascio_check') THEN
                RAISE EXCEPTION 'Alcune date non sono coerenti tra loro.';
            END IF;
            RAISE EXCEPTION 'Uno dei dati inviati non è nel formato atteso.';
        WHEN data_exception OR integrity_constraint_violation THEN
            RAISE EXCEPTION 'Uno dei dati inviati non è nel formato atteso.';
    END;

    RETURN QUERY
    SELECT f.key::VARCHAR, v_etichette -> f.key ->> 1
      FROM jsonb_each(v_filtrati) f
     ORDER BY (v_etichette -> f.key ->> 0)::INTEGER;
END;
$$;

COMMENT ON FUNCTION fn_web_cliente_completa(INTEGER, INTEGER, JSONB) IS
    'Scrive sulla scheda SOLO i campi del modulo oggi vuoti e restituisce quali, con un''etichetta per l''avviso al cliente. E'' l''unica scrittura che il sito puo'' fare su una scheda esistente senza codice usa e getta (script 661).';

COMMIT;
