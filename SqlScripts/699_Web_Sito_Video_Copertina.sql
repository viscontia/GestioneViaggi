-- ============================================================================
-- 699 — La copertina del video d'apertura (Tappa 4A, Task V5)
--
-- Prova di Adriano sull'anteprima (2026-10-20): col video, finché non partiva si
-- vedeva il fondo blu. I siti d'esempio mostrano un'immagine PRESA DAL VIDEO (il
-- primo fotogramma) e il video ci parte sopra: il passaggio non si vede. Il
-- gestionale ora estrae il primo fotogramma e lo manda allo Storage insieme al video.
--   - web_sito_contenuti + video_home_copertina_url / _path;
--   - fn_web_sito_video_home_save: due parametri in più (la copertina è obbligatoria:
--     il gestionale la prepara sempre) e restituisce anche la copertina vecchia.
--     La firma a 9 parametri si toglie: la usava solo il codice della 2.4, non rilasciato;
--   - fn_web_sito_home: 'video' ha in più 'copertina' (null per un video registrato
--     prima del 699, come quello d'esempio in PROD).
-- Rigiocabile. Test: Test_699_Web_Sito_Video_Copertina.sql
-- ============================================================================
BEGIN;

ALTER TABLE web_sito_contenuti
    ADD COLUMN IF NOT EXISTS video_home_copertina_url  text,
    ADD COLUMN IF NOT EXISTS video_home_copertina_path text;

DROP FUNCTION IF EXISTS fn_web_sito_video_home_save(integer, text, text, text, text, integer, integer, numeric, varchar);

CREATE OR REPLACE FUNCTION fn_web_sito_video_home_save(
    p_azienda_id integer, p_url text, p_path text, p_telefono_url text, p_telefono_path text,
    p_copertina_url text, p_copertina_path text,
    p_larghezza integer, p_altezza integer, p_durata numeric, p_utente varchar)
RETURNS TABLE(percorso text)
LANGUAGE plpgsql AS $$
DECLARE
    v_vecchi text[];
    v_togli  boolean := p_url IS NULL AND p_path IS NULL AND p_telefono_url IS NULL AND p_telefono_path IS NULL
                         AND p_copertina_url IS NULL AND p_copertina_path IS NULL;
BEGIN
    IF NOT v_togli THEN
        IF p_url IS NULL OR p_path IS NULL OR p_telefono_url IS NULL OR p_telefono_path IS NULL
           OR p_copertina_url IS NULL OR p_copertina_path IS NULL
           OR p_larghezza IS NULL OR p_altezza IS NULL OR p_durata IS NULL THEN
            RAISE EXCEPTION 'Video incompleto: servono le due versioni (computer e telefono), la copertina, le misure e la durata.';
        END IF;
        -- i file stanno nella libreria dell'azienda: mai quelli di un'altra
        IF p_path NOT LIKE 'libreria/' || p_azienda_id || '/%' OR p_telefono_path NOT LIKE 'libreria/' || p_azienda_id || '/%'
           OR p_copertina_path NOT LIKE 'libreria/' || p_azienda_id || '/%' THEN
            RAISE EXCEPTION 'Il video deve stare nella libreria dell''azienda %.', p_azienda_id;
        END IF;
        IF p_durata <= 0 OR p_durata > 20.5 OR p_larghezza <= 0 OR p_altezza <= 0 THEN
            RAISE EXCEPTION 'Video non valido: durata fino a 20 secondi, misure positive.';
        END IF;
    END IF;

    SELECT array_remove(ARRAY[c.video_home_path, c.video_home_telefono_path, c.video_home_copertina_path], NULL) INTO v_vecchi
      FROM web_sito_contenuti c WHERE c.azienda_id = p_azienda_id;

    INSERT INTO web_sito_contenuti AS c
           (azienda_id, video_home_url, video_home_path, video_home_telefono_url, video_home_telefono_path,
            video_home_copertina_url, video_home_copertina_path, video_home_larghezza, video_home_altezza, video_home_durata, video_home_aggiornato, updated_by, updated)
    VALUES (p_azienda_id, p_url, p_path, p_telefono_url, p_telefono_path,
            p_copertina_url, p_copertina_path, p_larghezza, p_altezza, p_durata, CASE WHEN v_togli THEN NULL ELSE clock_timestamp() END, p_utente, now())
    ON CONFLICT (azienda_id) DO UPDATE
       SET video_home_url           = EXCLUDED.video_home_url,
           video_home_path          = EXCLUDED.video_home_path,
           video_home_telefono_url  = EXCLUDED.video_home_telefono_url,
           video_home_telefono_path = EXCLUDED.video_home_telefono_path,
           video_home_copertina_url = EXCLUDED.video_home_copertina_url,
           video_home_copertina_path = EXCLUDED.video_home_copertina_path,
           video_home_larghezza     = EXCLUDED.video_home_larghezza,
           video_home_altezza       = EXCLUDED.video_home_altezza,
           video_home_durata        = EXCLUDED.video_home_durata,
           video_home_aggiornato    = EXCLUDED.video_home_aggiornato,
           updated_by               = EXCLUDED.updated_by,
           updated                  = now();

    -- i vecchi file (se diversi dai nuovi): li cancella il gestionale dallo Storage
    RETURN QUERY SELECT v FROM unnest(COALESCE(v_vecchi, ARRAY[]::text[])) v
                  WHERE v IS DISTINCT FROM p_path AND v IS DISTINCT FROM p_telefono_path AND v IS DISTINCT FROM p_copertina_path;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_sito_video_home_save(integer, text, text, text, text, text, text, integer, integer, numeric, varchar) FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_sito_video_home_save(integer, text, text, text, text, text, text, integer, integer, numeric, varchar)
            FROM anon, authenticated;
    END IF;
END $$;

-- La home per il sito: come la 698, più la copertina del video. CREATE OR REPLACE conserva i permessi. CREATE OR REPLACE conserva i permessi.
CREATE OR REPLACE FUNCTION fn_web_sito_home(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT jsonb_build_object(
               'foto', CASE WHEN c.foto_home_url IS NOT NULL THEN
                            jsonb_build_object('url', c.foto_home_url, 'larghezza', c.foto_home_larghezza,
                                               'altezza', c.foto_home_altezza, 'descrizione', NULL)
                       ELSE (SELECT jsonb_build_object('url', i.url, 'larghezza', i.larghezza,
                                                       'altezza', i.altezza, 'descrizione', i.descrizione)
                               FROM web_immagini_libreria i WHERE i.web_immagini_libreria_id = c.foto_home_fk) END,
               'video', CASE WHEN c.video_home_url IS NOT NULL THEN jsonb_build_object(
                            'computer', c.video_home_url, 'telefono', c.video_home_telefono_url,
                            'copertina', c.video_home_copertina_url,
                            'larghezza', c.video_home_larghezza, 'altezza', c.video_home_altezza,
                            'versione', floor(extract(epoch FROM c.video_home_aggiornato) * 1000)::bigint) END,
               'motto', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'motto', p_lingua, c.motto),
               'titolo', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'titolo_home', p_lingua, c.titolo_home),
               'sottotitolo', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'sottotitolo_home', p_lingua, c.sottotitolo_home))
      INTO v
      FROM web_sito_contenuti c
     WHERE c.azienda_id = p_azienda_id;
    RETURN v;
END;
$$;

COMMIT;
