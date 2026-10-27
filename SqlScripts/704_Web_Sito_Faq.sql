-- ============================================================================
-- 704 — Le FAQ del sito, divise in gruppi (Tappa 4C, Task 2)
--
-- Decisioni del 2026-10-27 (disegno della Tappa 4, §10): Antonio crea i gruppi con
-- l'ordine e ci mette le domande, in ordine, ciascuna «attiva» o no; domanda in testo
-- semplice, risposta HTML (Quill, come i testi legali); tutto tradotto. La pagina FAQ
-- esiste se c'è almeno una domanda da mostrare: lo decide il database.
--   - web_sito_faq_gruppi (azienda, ordine, nome) e web_sito_faq (gruppo, azienda,
--     ordine, domanda, risposta, attiva); la domanda sta nella stessa azienda del gruppo
--     (chiave doppia). RLS accese, tabelle chiuse al pubblico;
--   - fn_web_sito_faq_save(azienda, gruppi jsonb, utente): l'elenco intero in un colpo
--     solo (lo fa «Aggiorna»): ordine = posizione nell'elenco; con «id» si aggiorna (anche
--     spostando una domanda di gruppo), senza si crea; ciò che non è nell'elenco si
--     cancella con le sue traduzioni. Un testo italiano cambiato rende obsolete le sue
--     traduzioni. Identificativi di un'altra azienda, nome o domanda vuoti → errore.
--     Solo il gestionale;
--   - fn_web_sito_faq_list(azienda): per il gestionale, tutto, con gli identificativi;
--   - fn_web_sito_faq(azienda, lingua): per il sito, i gruppi in ordine con le domande
--     attive e con risposta; gruppo senza domande escluso. Una domanda è tradotta solo se
--     domanda e risposta lo sono tutte e due (mai due lingue nella stessa domanda);
--     'lingua' dice quale;
--   - fn_web_sito_pagine: 'faq' dopo 'chi_siamo', se fn_web_sito_faq non è vuota (una
--     sola definizione di «c'è qualcosa da mostrare»);
--   - la coda di rigenerazione: le due tabelle e le loro traduzioni → tutto il sito.
-- ⚠️ In PROD insieme al sito del 4C (Task 5), non prima: il sito del 4B rifiuta come
-- «sconosciuta» una pagina nuova nell'elenco.
-- Rigiocabile. Test: Test_704_Web_Sito_Faq.sql
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS web_sito_faq_gruppi (
    web_sito_faq_gruppi_id bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id             integer      NOT NULL REFERENCES ana_aziende(azienda_id),
    ordine                 integer      NOT NULL,
    nome                   varchar(150) NOT NULL CHECK (btrim(nome) <> ''),
    updated_by             varchar(100),
    updated                timestamptz  NOT NULL DEFAULT now(),
    UNIQUE (web_sito_faq_gruppi_id, azienda_id)
);

CREATE TABLE IF NOT EXISTS web_sito_faq (
    web_sito_faq_id bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gruppo_fk       bigint       NOT NULL,
    azienda_id      integer      NOT NULL REFERENCES ana_aziende(azienda_id),
    ordine          integer      NOT NULL,
    domanda         varchar(300) NOT NULL CHECK (btrim(domanda) <> ''),
    risposta        text,
    attiva          boolean      NOT NULL DEFAULT true,
    updated_by      varchar(100),
    updated         timestamptz  NOT NULL DEFAULT now(),
    -- la domanda sta nella stessa azienda del suo gruppo
    FOREIGN KEY (gruppo_fk, azienda_id) REFERENCES web_sito_faq_gruppi (web_sito_faq_gruppi_id, azienda_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_web_sito_faq_gruppo ON web_sito_faq (gruppo_fk);
CREATE INDEX IF NOT EXISTS ix_web_sito_faq_gruppi_azienda ON web_sito_faq_gruppi (azienda_id);

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['web_sito_faq_gruppi', 'web_sito_faq'] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('REVOKE ALL ON TABLE %I FROM PUBLIC', t);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE ALL ON TABLE %I FROM anon, authenticated', t);
        END IF;
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION fn_web_sito_faq_save(p_azienda_id integer, p_gruppi jsonb, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    g        jsonb;
    q        jsonb;
    gi       bigint;
    qi       bigint;
    v_gid    bigint;
    v_qid    bigint;
    v_nome   text;
    v_dom    text;
    v_risp   text;
    v_att    boolean;
    v_vecchio_nome text;
    v_vecchia_dom  text;
    v_vecchia_risp text;
    v_tenuti_g bigint[] := '{}';
    v_tenuti_q bigint[] := '{}';
BEGIN
    IF jsonb_typeof(coalesce(p_gruppi, '[]'::jsonb)) <> 'array' THEN
        RAISE EXCEPTION 'Elenco dei gruppi non valido.';
    END IF;

    FOR g, gi IN SELECT e.value, e.ordinality FROM jsonb_array_elements(coalesce(p_gruppi, '[]'::jsonb)) WITH ORDINALITY e LOOP
        v_nome := nullif(btrim(g->>'nome'), '');
        IF v_nome IS NULL THEN
            RAISE EXCEPTION 'Il gruppo n. % non ha un nome.', gi;
        END IF;
        IF g->>'id' IS NOT NULL THEN
            v_gid := (g->>'id')::bigint;
            SELECT x.nome INTO v_vecchio_nome FROM web_sito_faq_gruppi x
             WHERE x.web_sito_faq_gruppi_id = v_gid AND x.azienda_id = p_azienda_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Il gruppo % non è dell''azienda %.', v_gid, p_azienda_id;
            END IF;
            IF v_vecchio_nome IS DISTINCT FROM v_nome THEN
                PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_sito_faq_gruppi', v_gid, 'nome');
            END IF;
            UPDATE web_sito_faq_gruppi
               SET nome = v_nome, ordine = gi, updated_by = p_utente, updated = now()
             WHERE web_sito_faq_gruppi_id = v_gid AND (nome IS DISTINCT FROM v_nome OR ordine IS DISTINCT FROM gi);
        ELSE
            INSERT INTO web_sito_faq_gruppi (azienda_id, ordine, nome, updated_by)
            VALUES (p_azienda_id, gi, v_nome, p_utente)
            RETURNING web_sito_faq_gruppi_id INTO v_gid;
        END IF;
        v_tenuti_g := v_tenuti_g || v_gid;

        FOR q, qi IN SELECT e.value, e.ordinality FROM jsonb_array_elements(coalesce(g->'domande', '[]'::jsonb)) WITH ORDINALITY e LOOP
            v_dom  := nullif(btrim(q->>'domanda'), '');
            v_risp := fn_web_sito_html_pieno(q->>'risposta');
            v_att  := coalesce((q->>'attiva')::boolean, true);
            IF v_dom IS NULL THEN
                RAISE EXCEPTION 'La domanda n. % del gruppo «%» è vuota.', qi, v_nome;
            END IF;
            IF q->>'id' IS NOT NULL THEN
                v_qid := (q->>'id')::bigint;
                SELECT x.domanda, x.risposta INTO v_vecchia_dom, v_vecchia_risp FROM web_sito_faq x
                 WHERE x.web_sito_faq_id = v_qid AND x.azienda_id = p_azienda_id;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'La domanda % non è dell''azienda %.', v_qid, p_azienda_id;
                END IF;
                IF v_vecchia_dom IS DISTINCT FROM v_dom THEN
                    PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_sito_faq', v_qid, 'domanda');
                END IF;
                IF v_vecchia_risp IS DISTINCT FROM v_risp THEN
                    PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_sito_faq', v_qid, 'risposta');
                END IF;
                UPDATE web_sito_faq
                   SET gruppo_fk = v_gid, ordine = qi, domanda = v_dom, risposta = v_risp, attiva = v_att,
                       updated_by = p_utente, updated = now()
                 WHERE web_sito_faq_id = v_qid
                   AND (gruppo_fk, ordine, domanda, risposta, attiva) IS DISTINCT FROM (v_gid, qi, v_dom, v_risp, v_att);
            ELSE
                INSERT INTO web_sito_faq (gruppo_fk, azienda_id, ordine, domanda, risposta, attiva, updated_by)
                VALUES (v_gid, p_azienda_id, qi, v_dom, v_risp, v_att, p_utente)
                RETURNING web_sito_faq_id INTO v_qid;
            END IF;
            v_tenuti_q := v_tenuti_q || v_qid;
        END LOOP;
    END LOOP;

    -- ciò che non è più nell'elenco si cancella, con le sue traduzioni (nessuna traduzione orfana)
    DELETE FROM web_traduzioni t
     WHERE t.azienda_id = p_azienda_id AND t.entita = 'web_sito_faq'
       AND t.entita_id IN (SELECT x.web_sito_faq_id FROM web_sito_faq x
                            WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_id = ANY (v_tenuti_q));
    DELETE FROM web_sito_faq x WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_id = ANY (v_tenuti_q);
    DELETE FROM web_traduzioni t
     WHERE t.azienda_id = p_azienda_id AND t.entita = 'web_sito_faq_gruppi'
       AND t.entita_id IN (SELECT x.web_sito_faq_gruppi_id FROM web_sito_faq_gruppi x
                            WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_gruppi_id = ANY (v_tenuti_g));
    DELETE FROM web_sito_faq_gruppi x WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_gruppi_id = ANY (v_tenuti_g);
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_faq_list(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id', g.web_sito_faq_gruppi_id, 'nome', g.nome,
               'domande', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                        'id', q.web_sito_faq_id, 'domanda', q.domanda,
                                        'risposta', q.risposta, 'attiva', q.attiva)
                                        ORDER BY q.ordine, q.web_sito_faq_id)
                                      FROM web_sito_faq q WHERE q.gruppo_fk = g.web_sito_faq_gruppi_id), '[]'::jsonb))
           ORDER BY g.ordine, g.web_sito_faq_gruppi_id), '[]'::jsonb)
      FROM web_sito_faq_gruppi g
     WHERE g.azienda_id = p_azienda_id;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_faq(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'nome', fn_web_sito_testo('web_sito_faq_gruppi', g.web_sito_faq_gruppi_id, 'nome', p_lingua, g.nome),
               'domande', d.domande)
           ORDER BY g.ordine, g.web_sito_faq_gruppi_id), '[]'::jsonb)
      INTO v
      FROM web_sito_faq_gruppi g
      CROSS JOIN LATERAL (
          SELECT jsonb_agg(jsonb_build_object(
                     -- tutta la domanda in una lingua: tradotta solo se domanda E risposta lo sono
                     'domanda', CASE WHEN tr.dom IS NOT NULL AND tr.risp IS NOT NULL THEN tr.dom ELSE q.domanda END,
                     'risposta', CASE WHEN tr.dom IS NOT NULL AND tr.risp IS NOT NULL THEN tr.risp ELSE q.risposta END,
                     'lingua', CASE WHEN tr.dom IS NOT NULL AND tr.risp IS NOT NULL THEN p_lingua ELSE 'IT' END)
                     ORDER BY q.ordine, q.web_sito_faq_id) AS domande
            FROM web_sito_faq q
            CROSS JOIN LATERAL (
                SELECT (SELECT nullif(btrim(t.testo), '') FROM web_traduzioni t
                         WHERE p_lingua <> 'IT' AND t.entita = 'web_sito_faq' AND t.entita_id = q.web_sito_faq_id
                           AND t.campo = 'domanda' AND t.lingua = p_lingua AND NOT t.obsoleto) AS dom,
                       (SELECT fn_web_sito_html_pieno(t.testo) FROM web_traduzioni t
                         WHERE p_lingua <> 'IT' AND t.entita = 'web_sito_faq' AND t.entita_id = q.web_sito_faq_id
                           AND t.campo = 'risposta' AND t.lingua = p_lingua AND NOT t.obsoleto) AS risp) tr
           WHERE q.gruppo_fk = g.web_sito_faq_gruppi_id AND q.attiva
             AND fn_web_sito_html_pieno(q.risposta) IS NOT NULL) d
     WHERE g.azienda_id = p_azienda_id AND d.domande IS NOT NULL;
    RETURN v;
END;
$$;

-- Le pagine: come la 703, più 'faq' (con la stessa definizione della lettura). CREATE OR REPLACE conserva i permessi.
CREATE OR REPLACE FUNCTION fn_web_sito_pagine(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_agg(x.p ORDER BY x.o), '[]'::jsonb)
      FROM (SELECT v.o, v.p
              FROM web_sito_contenuti c,
                   LATERAL (VALUES (0, 'chi_siamo', c.chi_siamo), (2, 'note_legali', c.note_legali),
                                   (3, 'privacy', c.privacy), (4, 'cookie', c.cookie)) v(o, p, testo)
             WHERE c.azienda_id = p_azienda_id AND fn_web_sito_html_pieno(v.testo) IS NOT NULL
            UNION ALL
            SELECT 1, 'faq' WHERE fn_web_sito_faq(p_azienda_id, 'IT') <> '[]'::jsonb) x;
$$;

-- ---------------------------------------------------------------------------
-- La coda: trg_web_revalidate_func della 692 con le FAQ (tabelle e traduzioni)
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

        -- 692: la scheda «Sito web» (home, in evidenza) → tutto il sito; 704: le FAQ
        WHEN 'web_sito_contenuti', 'web_sito_evidenza', 'web_sito_faq_gruppi', 'web_sito_faq' THEN
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
                -- 692: motto, frase, titolo in evidenza → tutto il sito; 704: le FAQ
                WHEN 'web_sito_contenuti', 'web_sito_faq_gruppi', 'web_sito_faq' THEN
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
    FOREACH t IN ARRAY ARRAY['web_sito_faq_gruppi', 'web_sito_faq'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_web_revalidate ON %I', t);
        EXECUTE format('CREATE TRIGGER trg_web_revalidate AFTER INSERT OR UPDATE OR DELETE ON %I
                        FOR EACH ROW EXECUTE FUNCTION trg_web_revalidate_func()', t);
    END LOOP;
END $$;

-- Permessi: la lettura al pubblico; salvataggio ed elenco solo al gestionale.
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_web_sito_faq_save(integer, jsonb, varchar)', 'fn_web_sito_faq_list(integer)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
    EXECUTE 'REVOKE EXECUTE ON FUNCTION fn_web_sito_faq(integer, varchar) FROM PUBLIC';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION fn_web_sito_faq(integer, varchar) TO anon, authenticated';
    END IF;
END $$;

COMMIT;
