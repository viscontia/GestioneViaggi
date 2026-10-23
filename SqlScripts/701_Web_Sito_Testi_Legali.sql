-- ============================================================================
-- 701 — I testi legali del sito: note legali, privacy, cookie (Tappa 4B, Task 1)
--
-- Decisioni del 2026-10-23 (disegno della Tappa 4, §9): i tre testi si scrivono nel
-- gestionale (scheda «Sito web» → «Testi legali», editor Quill) e si traducono come
-- gli altri testi del sito; una pagina vuota non esiste (il sito risponde 404 e non
-- mette il link): lo decide il database.
--   - web_sito_contenuti + note_legali, privacy, cookie (HTML) e, per ciascuno, la data
--     dell'ultimo cambiamento (la pagina la mostra: «Ultimo aggiornamento»);
--   - fn_web_sito_testi_legali_save: salva i tre testi (a parte dalla scheda Home, come
--     foto e video del 698); l'HTML vuoto di Quill (<p><br></p>) diventa NULL; la data
--     cambia solo per il testo che cambia. Solo il gestionale (postgres);
--   - fn_web_sito_pagina(azienda, lingua, pagina) → {html, lingua, aggiornato}: il testo
--     nella lingua chiesta, altrimenti l'italiano — e 'lingua' dice quale (la pagina in
--     tedesco sa se sta mostrando l'italiano); null se il testo non c'è;
--   - fn_web_sito_pagine(azienda) → l'elenco delle pagine con testo, in ordine fisso:
--     proxy, piede e sitemap lo leggono (Chi siamo e FAQ si aggiungeranno col 4C).
-- Le letture al pubblico (anon, authenticated), SECURITY DEFINER, search_path fissato.
-- La coda di rigenerazione la avvisa il trigger della 692. Rigiocabile.
-- Test: Test_701_Web_Sito_Testi_Legali.sql
-- ============================================================================
BEGIN;

ALTER TABLE web_sito_contenuti
    ADD COLUMN IF NOT EXISTS note_legali            text,
    ADD COLUMN IF NOT EXISTS privacy                text,
    ADD COLUMN IF NOT EXISTS cookie                 text,
    ADD COLUMN IF NOT EXISTS note_legali_aggiornato timestamptz,
    ADD COLUMN IF NOT EXISTS privacy_aggiornato     timestamptz,
    ADD COLUMN IF NOT EXISTS cookie_aggiornato      timestamptz;

-- Un testo «vuoto» per il sito: NULL, spazi, o l'HTML che Quill lascia quando si cancella tutto.
CREATE OR REPLACE FUNCTION fn_web_sito_html_pieno(p_html text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_html IS NULL
                  OR btrim(regexp_replace(p_html, '<p>(\s|<br\s*/?>|&nbsp;)*</p>', '', 'gi')) = '' THEN NULL
                ELSE p_html END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_testi_legali_save(
    p_azienda_id integer, p_note_legali text, p_privacy text, p_cookie text, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    n text := fn_web_sito_html_pieno(p_note_legali);
    p text := fn_web_sito_html_pieno(p_privacy);
    c text := fn_web_sito_html_pieno(p_cookie);
BEGIN
    INSERT INTO web_sito_contenuti AS w
           (azienda_id, note_legali, privacy, cookie,
            note_legali_aggiornato, privacy_aggiornato, cookie_aggiornato, updated_by, updated)
    VALUES (p_azienda_id, n, p, c,
            CASE WHEN n IS NOT NULL THEN now() END, CASE WHEN p IS NOT NULL THEN now() END,
            CASE WHEN c IS NOT NULL THEN now() END, p_utente, now())
    ON CONFLICT (azienda_id) DO UPDATE
       SET note_legali = EXCLUDED.note_legali,
           privacy     = EXCLUDED.privacy,
           cookie      = EXCLUDED.cookie,
           -- la data dell'ultimo aggiornamento cambia solo per il testo che cambia
           note_legali_aggiornato = CASE WHEN w.note_legali IS DISTINCT FROM EXCLUDED.note_legali THEN now() ELSE w.note_legali_aggiornato END,
           privacy_aggiornato     = CASE WHEN w.privacy     IS DISTINCT FROM EXCLUDED.privacy     THEN now() ELSE w.privacy_aggiornato END,
           cookie_aggiornato      = CASE WHEN w.cookie      IS DISTINCT FROM EXCLUDED.cookie      THEN now() ELSE w.cookie_aggiornato END,
           updated_by = EXCLUDED.updated_by,
           updated    = now();
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_pagina(p_azienda_id integer, p_lingua varchar, p_pagina varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_it    text;
    v_quando timestamptz;
    v_tr    text;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    IF p_pagina NOT IN ('note_legali', 'privacy', 'cookie') THEN
        RAISE EXCEPTION 'Pagina sconosciuta: %', p_pagina;
    END IF;
    SELECT CASE p_pagina WHEN 'note_legali' THEN c.note_legali WHEN 'privacy' THEN c.privacy ELSE c.cookie END,
           CASE p_pagina WHEN 'note_legali' THEN c.note_legali_aggiornato WHEN 'privacy' THEN c.privacy_aggiornato ELSE c.cookie_aggiornato END
      INTO v_it, v_quando
      FROM web_sito_contenuti c WHERE c.azienda_id = p_azienda_id;
    v_it := fn_web_sito_html_pieno(v_it);
    IF v_it IS NULL THEN RETURN NULL; END IF;
    IF p_lingua <> 'IT' THEN
        SELECT fn_web_sito_html_pieno(t.testo) INTO v_tr FROM web_traduzioni t
         WHERE t.entita = 'web_sito_contenuti' AND t.entita_id = p_azienda_id AND t.campo = p_pagina
           AND t.lingua = p_lingua AND NOT t.obsoleto;
    END IF;
    RETURN jsonb_build_object('html', coalesce(v_tr, v_it),
                              'lingua', CASE WHEN v_tr IS NOT NULL THEN p_lingua ELSE 'IT' END,
                              'aggiornato', v_quando);
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_pagine(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_agg(p ORDER BY o), '[]'::jsonb)
      FROM web_sito_contenuti c,
           LATERAL (VALUES (1, 'note_legali', c.note_legali), (2, 'privacy', c.privacy), (3, 'cookie', c.cookie)) v(o, p, testo)
     WHERE c.azienda_id = p_azienda_id AND fn_web_sito_html_pieno(v.testo) IS NOT NULL;
$$;

-- Permessi: le due letture al pubblico (esplicitamente); salvataggio e aiuto no.
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_web_sito_testi_legali_save(integer, text, text, text, varchar)',
                             'fn_web_sito_html_pieno(text)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
    FOREACH f IN ARRAY ARRAY['fn_web_sito_pagina(integer, varchar, varchar)', 'fn_web_sito_pagine(integer)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated', f);
        END IF;
    END LOOP;
END $$;

COMMIT;
