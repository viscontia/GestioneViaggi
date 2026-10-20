-- ============================================================================
-- 692 — La scheda «Sito web» dell'azienda: home e «In evidenza»; garanzie del
--       tour operator (Tappa 4A del sito; voci L24, L26, L28)
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md
--   - web_sito_contenuti: UNA riga per azienda (foto della home dalla libreria,
--     motto, frase d'apertura, email che riceve i messaggi del sito, titolo del
--     blocco «In evidenza»). Chi siamo e testi legali: colonne dei pezzi 4B/4C.
--     Traduzioni in web_traduzioni con entita = 'web_sito_contenuti',
--     entita_id = azienda.
--   - web_sito_evidenza: fino a 3 tour per azienda, in ordine (scelta di
--     Antonio del 2026-10-19).
--   - ana_aziende: polizza RC e fondo di garanzia (Dati generali, decisione di
--     Adriano del 2026-10-19). NON si tocca fn_ana_aziende_update: due funzioni
--     a parte.
--   - Foto, email e tour devono essere DELL'AZIENDA: lo controlla un trigger,
--     quindi vale anche per chi scrive direttamente in tabella.
--   - Ogni modifica avvisa la coda con «menu» (tutto il sito): nuova versione di
--     trg_web_revalidate_func, copiata dal 691 con due casi in più.
--
-- Le funzioni sono del GESTIONALE (che si collega come proprietario): niente
-- SECURITY DEFINER, e niente esecuzione per anon/authenticated. Le letture
-- per il sito sono nello script 693. Rigiocabile.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS web_sito_contenuti (
    azienda_id          integer PRIMARY KEY REFERENCES ana_aziende(azienda_id),
    foto_home_fk        bigint  REFERENCES web_immagini_libreria(web_immagini_libreria_id) ON DELETE SET NULL,
    motto               varchar(120),
    frase_home          varchar(300),
    email_messaggi_fk   integer REFERENCES ana_aziende_email(email_id) ON DELETE SET NULL,
    evidenza_titolo     varchar(120),
    updated_by          varchar(100),
    updated             timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS web_sito_evidenza (
    azienda_id                 integer  NOT NULL REFERENCES ana_aziende(azienda_id),
    web_tour_contenuti_id_fk   bigint   NOT NULL REFERENCES web_tour_contenuti(web_tour_contenuti_id) ON DELETE CASCADE,
    ordine                     smallint NOT NULL CHECK (ordine BETWEEN 1 AND 3),
    updated_by                 varchar(100),
    PRIMARY KEY (azienda_id, ordine),
    UNIQUE (azienda_id, web_tour_contenuti_id_fk)
);

ALTER TABLE ana_aziende
    ADD COLUMN IF NOT EXISTS polizza_rc_compagnia    varchar(150),
    ADD COLUMN IF NOT EXISTS polizza_rc_numero       varchar(80),
    ADD COLUMN IF NOT EXISTS fondo_garanzia_ente     varchar(150),
    ADD COLUMN IF NOT EXISTS fondo_garanzia_estremi  varchar(150);

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['web_sito_contenuti', 'web_sito_evidenza'] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('REVOKE ALL ON TABLE %I FROM PUBLIC', t);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE ALL ON TABLE %I FROM anon, authenticated', t);
        END IF;
    END LOOP;
END $$;

-- Foto, email e tour devono essere della stessa azienda della riga.
CREATE OR REPLACE FUNCTION trg_web_sito_stessa_azienda()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_TABLE_NAME = 'web_sito_contenuti' THEN
        IF NEW.foto_home_fk IS NOT NULL AND NOT EXISTS (
               SELECT 1 FROM web_immagini_libreria
                WHERE web_immagini_libreria_id = NEW.foto_home_fk AND azienda_id = NEW.azienda_id) THEN
            RAISE EXCEPTION 'La foto % non è nella libreria dell''azienda %', NEW.foto_home_fk, NEW.azienda_id;
        END IF;
        IF NEW.email_messaggi_fk IS NOT NULL AND NOT EXISTS (
               SELECT 1 FROM ana_aziende_email
                WHERE email_id = NEW.email_messaggi_fk AND azienda_fk = NEW.azienda_id) THEN
            RAISE EXCEPTION 'L''email % non è dell''azienda %', NEW.email_messaggi_fk, NEW.azienda_id;
        END IF;
    ELSE
        IF NOT EXISTS (SELECT 1 FROM web_tour_contenuti
                        WHERE web_tour_contenuti_id = NEW.web_tour_contenuti_id_fk AND azienda_id = NEW.azienda_id) THEN
            RAISE EXCEPTION 'Il tour % non è dell''azienda %', NEW.web_tour_contenuti_id_fk, NEW.azienda_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_web_sito_stessa_azienda ON web_sito_contenuti;
CREATE TRIGGER trg_web_sito_stessa_azienda BEFORE INSERT OR UPDATE ON web_sito_contenuti
    FOR EACH ROW EXECUTE FUNCTION trg_web_sito_stessa_azienda();
DROP TRIGGER IF EXISTS trg_web_sito_stessa_azienda ON web_sito_evidenza;
CREATE TRIGGER trg_web_sito_stessa_azienda BEFORE INSERT OR UPDATE ON web_sito_evidenza
    FOR EACH ROW EXECUTE FUNCTION trg_web_sito_stessa_azienda();

-- ---------------------------------------------------------------------------
-- Funzioni del gestionale
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_sito_contenuti_get(p_azienda_id integer)
RETURNS SETOF web_sito_contenuti
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_sito_contenuti WHERE azienda_id = p_azienda_id;
$$;

-- Salva la sotto-scheda Home (crea la riga se manca). Testi vuoti → NULL.
CREATE OR REPLACE FUNCTION fn_web_sito_contenuti_save(
    p_azienda_id integer, p_foto_home_fk bigint, p_motto varchar, p_frase_home varchar,
    p_email_messaggi_fk integer, p_evidenza_titolo varchar, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO web_sito_contenuti AS c
           (azienda_id, foto_home_fk, motto, frase_home, email_messaggi_fk, evidenza_titolo, updated_by, updated)
    VALUES (p_azienda_id, p_foto_home_fk, nullif(btrim(p_motto), ''), nullif(btrim(p_frase_home), ''),
            p_email_messaggi_fk, nullif(btrim(p_evidenza_titolo), ''), p_utente, now())
    ON CONFLICT (azienda_id) DO UPDATE
       SET foto_home_fk      = EXCLUDED.foto_home_fk,
           motto             = EXCLUDED.motto,
           frase_home        = EXCLUDED.frase_home,
           email_messaggi_fk = EXCLUDED.email_messaggi_fk,
           evidenza_titolo   = EXCLUDED.evidenza_titolo,
           updated_by        = EXCLUDED.updated_by,
           updated           = now();
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_evidenza_list(p_azienda_id integer)
RETURNS TABLE (ordine smallint, web_tour_contenuti_id bigint)
LANGUAGE sql STABLE AS $$
    SELECT e.ordine, e.web_tour_contenuti_id_fk
      FROM web_sito_evidenza e
     WHERE e.azienda_id = p_azienda_id
     ORDER BY e.ordine;
$$;

-- Sostituisce l'elenco dei tour in evidenza: l'ordine è la posizione nell'array.
-- Vuoto = nessun tour in evidenza (il blocco della home non si mostra).
CREATE OR REPLACE FUNCTION fn_web_sito_evidenza_save(p_azienda_id integer, p_contenuti bigint[], p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF coalesce(array_length(p_contenuti, 1), 0) > 3 THEN
        RAISE EXCEPTION 'Al massimo 3 tour in evidenza (ne sono stati scelti %)', array_length(p_contenuti, 1);
    END IF;
    DELETE FROM web_sito_evidenza WHERE azienda_id = p_azienda_id;
    INSERT INTO web_sito_evidenza (azienda_id, web_tour_contenuti_id_fk, ordine, updated_by)
    SELECT p_azienda_id, c.id, c.pos, p_utente
      FROM unnest(p_contenuti) WITH ORDINALITY AS c(id, pos);
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_aziende_garanzie_get(p_azienda_id integer)
RETURNS TABLE (polizza_rc_compagnia varchar, polizza_rc_numero varchar,
               fondo_garanzia_ente varchar, fondo_garanzia_estremi varchar)
LANGUAGE sql STABLE AS $$
    SELECT a.polizza_rc_compagnia, a.polizza_rc_numero, a.fondo_garanzia_ente, a.fondo_garanzia_estremi
      FROM ana_aziende a WHERE a.azienda_id = p_azienda_id;
$$;

-- Testi vuoti → NULL. Avvisa la coda attraverso il trigger su ana_aziende (691).
CREATE OR REPLACE FUNCTION fn_ana_aziende_garanzie_save(
    p_azienda_id integer, p_polizza_rc_compagnia varchar, p_polizza_rc_numero varchar,
    p_fondo_garanzia_ente varchar, p_fondo_garanzia_estremi varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE ana_aziende
       SET polizza_rc_compagnia   = nullif(btrim(p_polizza_rc_compagnia), ''),
           polizza_rc_numero      = nullif(btrim(p_polizza_rc_numero), ''),
           fondo_garanzia_ente    = nullif(btrim(p_fondo_garanzia_ente), ''),
           fondo_garanzia_estremi = nullif(btrim(p_fondo_garanzia_estremi), '')
     WHERE azienda_id = p_azienda_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Azienda % inesistente', p_azienda_id;
    END IF;
END;
$$;

-- Solo il gestionale: niente esecuzione per il pubblico.
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY[
        'fn_web_sito_contenuti_get(integer)',
        'fn_web_sito_contenuti_save(integer, bigint, varchar, varchar, integer, varchar, varchar)',
        'fn_web_sito_evidenza_list(integer)',
        'fn_web_sito_evidenza_save(integer, bigint[], varchar)',
        'fn_ana_aziende_garanzie_get(integer)',
        'fn_ana_aziende_garanzie_save(integer, varchar, varchar, varchar, varchar)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- La coda: trg_web_revalidate_func del 691 con due casi in più (692)
-- ---------------------------------------------------------------------------
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

        -- 692: la scheda «Sito web» (home, in evidenza) → tutto il sito
        WHEN 'web_sito_contenuti', 'web_sito_evidenza' THEN
            v_azienda    := v_rec.azienda_id;
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
                -- 692: motto, frase, titolo in evidenza → tutto il sito
                WHEN 'web_sito_contenuti' THEN
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
    FOREACH t IN ARRAY ARRAY['web_sito_contenuti', 'web_sito_evidenza'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_web_revalidate ON %I', t);
        EXECUTE format('CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON %I
                        FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func()', t);
    END LOOP;
END $$;

COMMIT;

-- ============================================================================
-- Verifica: Test_692_Web_Sito_Contenuti.sql
-- ============================================================================
