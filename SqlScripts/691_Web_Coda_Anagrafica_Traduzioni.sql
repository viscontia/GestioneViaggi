-- ============================================================================
-- 691 — La coda di rigenerazione si accorge anche di anagrafica, traduzioni e
--       testi delle giornate (Tappa 3 del sito, Task 13)
--
-- Il trigger dello script 654 avvisa la coda solo per schede, foto, giornate,
-- mappe, date e viaggi. Trovato il 2026-10-17 preparando il PDF del programma:
-- NON avvisavano la coda
--   - l'ANAGRAFICA dell'azienda (nome, P.IVA, sede, email: sono nel piede del PDF
--     e, con la Tappa 4, nel piede del sito): «qualsiasi cambiamento sulla
--     anagrafica azienda è importante» (Adriano);
--   - WhatsApp (web_indirizzi) e il Place ID delle recensioni (web_aziende_funzioni);
--   - i nomi delle sezioni (web_tipi_viaggio_descrizioni, tabella comune);
--   - i testi delle giornate (web_tour_itinerario_passaggi);
--   - le traduzioni (web_traduzioni).
-- Le pagine si rinfrescavano comunque entro un'ora (seconda rete); i PDF ora pure,
-- ma con questo script un cambiamento arriva in 1–2 minuti.
--
--   anagrafica, WhatsApp, recensioni, sezioni → 'menu': tutto il sito, tutti i PDF;
--   testo di una giornata                    → 'tour' della sua scheda;
--   traduzione                               → la scheda di ciò che traduce
--                                              (sezione: 'menu'; altro: niente).
--
-- ⚠️ Resta LEGGERISSIMO (gira dentro ogni salvataggio del gestionale): solo
-- letture per chiave e una riga in coda; i doppioni li unisce l'indice unico.
-- I casi dello script 654 sono copiati senza cambiamenti. Rigiocabile.
-- ============================================================================
BEGIN;

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

        -- 691: il testo di una giornata → la sua scheda
        WHEN 'web_tour_itinerario_passaggi' THEN
            v_azienda := v_rec.azienda_id;
            SELECT i.web_tour_contenuti_id_fk INTO v_contenuto
              FROM web_tour_itinerario i
             WHERE i.web_tour_itinerario_id = v_rec.itinerario_id_fk;

        -- 691: anagrafica dell'azienda, WhatsApp, recensioni → tutto il sito (e tutti i PDF)
        WHEN 'ana_aziende', 'web_indirizzi', 'web_aziende_funzioni' THEN
            v_azienda    := v_rec.azienda_id;
            v_tocca_menu := TRUE;

        WHEN 'ana_aziende_sedi', 'ana_aziende_email' THEN
            v_azienda    := v_rec.azienda_fk;
            v_tocca_menu := TRUE;

        -- 691: i nomi delle sezioni sono una tabella comune: il menu di ogni azienda col sito
        WHEN 'web_tipi_viaggio_descrizioni' THEN
            FOR v_azienda IN SELECT DISTINCT c.azienda_id FROM web_tour_contenuti c LOOP
                PERFORM fn_web_revalidate_accoda(v_azienda, 'menu', NULL,
                                                 TG_TABLE_NAME || '/' || TG_OP);
            END LOOP;
            RETURN NULL;

        -- 691: una traduzione → la scheda di cio' che traduce
        WHEN 'web_traduzioni' THEN
            v_azienda := v_rec.azienda_id;
            CASE v_rec.entita
                WHEN 'web_tour_contenuti' THEN
                    v_contenuto := v_rec.entita_id;
                WHEN 'web_tour_itinerario' THEN
                    SELECT i.web_tour_contenuti_id_fk INTO v_contenuto
                      FROM web_tour_itinerario i WHERE i.web_tour_itinerario_id = v_rec.entita_id;
                WHEN 'web_tour_itinerario_passaggi' THEN
                    SELECT i.web_tour_contenuti_id_fk INTO v_contenuto
                      FROM web_tour_itinerario_passaggi p
                      JOIN web_tour_itinerario i ON i.web_tour_itinerario_id = p.itinerario_id_fk
                     WHERE p.web_tour_itinerario_passaggi_id = v_rec.entita_id;
                WHEN 'web_tour_mappa' THEN
                    SELECT m.web_tour_contenuti_id_fk INTO v_contenuto
                      FROM web_tour_mappa m WHERE m.web_tour_mappa_id = v_rec.entita_id;
                WHEN 'ana_viaggi' THEN
                    FOR v_contenuto IN
                        SELECT c.web_tour_contenuti_id FROM web_tour_contenuti c
                         WHERE c.viaggio_id_fk = v_rec.entita_id
                    LOOP
                        PERFORM fn_web_revalidate_accoda(v_azienda, 'tour', v_contenuto,
                                                         TG_TABLE_NAME || '/' || TG_OP);
                    END LOOP;
                    RETURN NULL;
                WHEN 'web_tipi_viaggio_descrizioni' THEN
                    v_tocca_menu := TRUE;
                ELSE
                    RETURN NULL;   -- traduzioni che il sito non usa (newsletter, ...)
            END CASE;

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

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['web_tour_itinerario_passaggi', 'web_traduzioni', 'ana_aziende', 'ana_aziende_sedi',
                             'ana_aziende_email', 'web_indirizzi', 'web_aziende_funzioni', 'web_tipi_viaggio_descrizioni'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_web_revalidate ON %I', t);
        EXECUTE format('CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON %I
                        FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func()', t);
    END LOOP;
END $$;

COMMIT;

-- ============================================================================
-- Verifica: Test_691_Web_Coda_Anagrafica_Traduzioni.sql
-- ============================================================================
