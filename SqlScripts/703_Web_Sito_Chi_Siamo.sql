-- ============================================================================
-- 703 — La pagina «Chi siamo» del sito (Tappa 4C, Task 1)
--
-- Decisioni del 2026-10-27 (disegno della Tappa 4, §10): testo scritto nel gestionale
-- (scheda «Sito web» → «Chi siamo», editor Quill) e tradotto come gli altri testi del
-- sito; 2 foto caricate dalla scheda come la foto della home (698: WebP 2000 px nella
-- libreria dello Storage, una copia sola). Una pagina senza testo non esiste (le foto
-- da sole non bastano): lo decide il database.
--   - web_sito_contenuti + chi_siamo (HTML), chi_siamo_aggiornato, e per ogni foto
--     indirizzo, percorso, larghezza, altezza;
--   - fn_web_sito_chi_siamo_save: salva il testo (l'HTML vuoto di Quill → NULL; la data
--     cambia solo se il testo cambia). Solo il gestionale (postgres);
--   - fn_web_sito_foto_chi_siamo_save(azienda, posizione 1|2, …): registra la foto (tutto
--     NULL = la toglie) e RESTITUISCE il percorso della vecchia, che il gestionale
--     cancella dallo Storage. Solo il gestionale;
--   - fn_web_sito_pagina: in più 'chi_siamo', con la chiave 'foto' (indirizzo e misure,
--     mai il percorso interno; in ordine, solo quelle presenti). Le pagine legali restano
--     com'erano;
--   - fn_web_sito_pagine: 'chi_siamo' in testa, quando c'è il testo.
-- ⚠️ In PROD insieme al sito del 4C (Task 5), non prima: il sito del 4B rifiuta come
-- «sconosciuta» una pagina nuova nell'elenco.
-- La coda di rigenerazione la avvisa il trigger della 692. Rigiocabile.
-- Test: Test_703_Web_Sito_Chi_Siamo.sql
-- ============================================================================
BEGIN;

ALTER TABLE web_sito_contenuti
    ADD COLUMN IF NOT EXISTS chi_siamo                 text,
    ADD COLUMN IF NOT EXISTS chi_siamo_aggiornato      timestamptz,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto1_url       text,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto1_path      text,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto1_larghezza integer,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto1_altezza   integer,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto2_url       text,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto2_path      text,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto2_larghezza integer,
    ADD COLUMN IF NOT EXISTS chi_siamo_foto2_altezza   integer;

CREATE OR REPLACE FUNCTION fn_web_sito_chi_siamo_save(p_azienda_id integer, p_html text, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v text := fn_web_sito_html_pieno(p_html);
BEGIN
    INSERT INTO web_sito_contenuti AS w (azienda_id, chi_siamo, chi_siamo_aggiornato, updated_by, updated)
    VALUES (p_azienda_id, v, CASE WHEN v IS NOT NULL THEN now() END, p_utente, now())
    ON CONFLICT (azienda_id) DO UPDATE
       SET chi_siamo = EXCLUDED.chi_siamo,
           -- la data dell'ultimo aggiornamento cambia solo se cambia il testo
           chi_siamo_aggiornato = CASE WHEN w.chi_siamo IS DISTINCT FROM EXCLUDED.chi_siamo THEN now() ELSE w.chi_siamo_aggiornato END,
           updated_by = EXCLUDED.updated_by,
           updated    = now();
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_foto_chi_siamo_save(
    p_azienda_id integer, p_posizione integer, p_url text, p_path text, p_larghezza integer, p_altezza integer, p_utente varchar)
RETURNS TABLE(percorso text)
LANGUAGE plpgsql AS $$
DECLARE
    v_vecchio text;
    v_togli   boolean := p_url IS NULL AND p_path IS NULL;
BEGIN
    IF p_posizione NOT IN (1, 2) THEN
        RAISE EXCEPTION 'Posizione della foto: 1 o 2, non %.', p_posizione;
    END IF;
    IF NOT v_togli THEN
        IF p_url IS NULL OR p_path IS NULL OR p_larghezza IS NULL OR p_altezza IS NULL
           OR p_larghezza <= 0 OR p_altezza <= 0 THEN
            RAISE EXCEPTION 'Foto incompleta: servono indirizzo, percorso e misure.';
        END IF;
        IF p_path NOT LIKE 'libreria/' || p_azienda_id || '/%' THEN
            RAISE EXCEPTION 'La foto deve stare nella libreria dell''azienda %.', p_azienda_id;
        END IF;
    END IF;

    SELECT CASE p_posizione WHEN 1 THEN c.chi_siamo_foto1_path ELSE c.chi_siamo_foto2_path END
      INTO v_vecchio FROM web_sito_contenuti c WHERE c.azienda_id = p_azienda_id;

    INSERT INTO web_sito_contenuti (azienda_id, updated_by, updated)
    VALUES (p_azienda_id, p_utente, now())
    ON CONFLICT (azienda_id) DO NOTHING;

    IF p_posizione = 1 THEN
        UPDATE web_sito_contenuti
           SET chi_siamo_foto1_url = p_url, chi_siamo_foto1_path = p_path,
               chi_siamo_foto1_larghezza = p_larghezza, chi_siamo_foto1_altezza = p_altezza,
               updated_by = p_utente, updated = now()
         WHERE azienda_id = p_azienda_id;
    ELSE
        UPDATE web_sito_contenuti
           SET chi_siamo_foto2_url = p_url, chi_siamo_foto2_path = p_path,
               chi_siamo_foto2_larghezza = p_larghezza, chi_siamo_foto2_altezza = p_altezza,
               updated_by = p_utente, updated = now()
         WHERE azienda_id = p_azienda_id;
    END IF;

    RETURN QUERY SELECT v_vecchio WHERE v_vecchio IS NOT NULL AND v_vecchio IS DISTINCT FROM p_path;
END;
$$;

-- La pagina: come la 701, più 'chi_siamo' con le foto. CREATE OR REPLACE conserva i permessi.
CREATE OR REPLACE FUNCTION fn_web_sito_pagina(p_azienda_id integer, p_lingua varchar, p_pagina varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_it     text;
    v_quando timestamptz;
    v_tr     text;
    v_foto   jsonb;
    v        jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    IF p_pagina NOT IN ('chi_siamo', 'note_legali', 'privacy', 'cookie') THEN
        RAISE EXCEPTION 'Pagina sconosciuta: %', p_pagina;
    END IF;
    SELECT CASE p_pagina WHEN 'chi_siamo' THEN c.chi_siamo WHEN 'note_legali' THEN c.note_legali
                         WHEN 'privacy' THEN c.privacy ELSE c.cookie END,
           CASE p_pagina WHEN 'chi_siamo' THEN c.chi_siamo_aggiornato WHEN 'note_legali' THEN c.note_legali_aggiornato
                         WHEN 'privacy' THEN c.privacy_aggiornato ELSE c.cookie_aggiornato END,
           -- ai visitatori indirizzo e misure, mai il percorso interno dello Storage
           (SELECT coalesce(jsonb_agg(jsonb_build_object('url', f.url, 'larghezza', f.l, 'altezza', f.a) ORDER BY f.n), '[]'::jsonb)
              FROM (VALUES (1, c.chi_siamo_foto1_url, c.chi_siamo_foto1_larghezza, c.chi_siamo_foto1_altezza),
                           (2, c.chi_siamo_foto2_url, c.chi_siamo_foto2_larghezza, c.chi_siamo_foto2_altezza)) f(n, url, l, a)
             WHERE f.url IS NOT NULL)
      INTO v_it, v_quando, v_foto
      FROM web_sito_contenuti c WHERE c.azienda_id = p_azienda_id;
    v_it := fn_web_sito_html_pieno(v_it);
    IF v_it IS NULL THEN RETURN NULL; END IF;
    IF p_lingua <> 'IT' THEN
        SELECT fn_web_sito_html_pieno(t.testo) INTO v_tr FROM web_traduzioni t
         WHERE t.entita = 'web_sito_contenuti' AND t.entita_id = p_azienda_id AND t.campo = p_pagina
           AND t.lingua = p_lingua AND NOT t.obsoleto;
    END IF;
    v := jsonb_build_object('html', coalesce(v_tr, v_it),
                            'lingua', CASE WHEN v_tr IS NOT NULL THEN p_lingua ELSE 'IT' END,
                            'aggiornato', v_quando);
    RETURN CASE WHEN p_pagina = 'chi_siamo' THEN v || jsonb_build_object('foto', v_foto) ELSE v END;
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_pagine(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_agg(p ORDER BY o), '[]'::jsonb)
      FROM web_sito_contenuti c,
           LATERAL (VALUES (0, 'chi_siamo', c.chi_siamo), (1, 'note_legali', c.note_legali),
                           (2, 'privacy', c.privacy), (3, 'cookie', c.cookie)) v(o, p, testo)
     WHERE c.azienda_id = p_azienda_id AND fn_web_sito_html_pieno(v.testo) IS NOT NULL;
$$;

-- Permessi: i salvataggi solo al gestionale (le letture li conservano dalla 701).
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_web_sito_chi_siamo_save(integer, text, varchar)',
                             'fn_web_sito_foto_chi_siamo_save(integer, integer, text, text, integer, integer, varchar)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
END $$;

COMMIT;
