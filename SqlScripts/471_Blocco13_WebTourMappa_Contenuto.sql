-- ============================================================================
-- Blocco 13 re-model — RI-ANCORAGGIO web_tour_mappa dal VIAGGIO al CONTENUTO
-- web_tour_mappa: da 1:1 col viaggio a 1:1 col web_tour_contenuti.
-- Tabella figlia VUOTA: DROP/ADD colonna liberamente. Forward migration.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) TABELLA: viaggio_id_fk (INTEGER, UNIQUE, FK ana_viaggi)
--    -> web_tour_contenuti_id_fk (BIGINT NOT NULL UNIQUE, FK web_tour_contenuti
--       ON DELETE CASCADE). Il vincolo UNIQUE si sposta sulla nuova colonna.
--    Il DROP COLUMN elimina in cascata sia il UNIQUE sia la FK su ana_viaggi.
-- ---------------------------------------------------------------------------
-- La policy RLS anon dipende da viaggio_id_fk: la droppo (ricreata per-contenuto in Fase C)
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_mappa;

ALTER TABLE web_tour_mappa DROP COLUMN IF EXISTS viaggio_id_fk;

ALTER TABLE web_tour_mappa
    ADD COLUMN IF NOT EXISTS web_tour_contenuti_id_fk BIGINT NOT NULL
        UNIQUE
        REFERENCES web_tour_contenuti(web_tour_contenuti_id) ON DELETE CASCADE;

-- idx_web_tour_mappa_azienda: invariato (non toccato).

-- ---------------------------------------------------------------------------
-- 2) FUNZIONI: cambia il tipo del parametro che porta l'id -> serve DROP della
--    firma vecchia esatta prima di ricreare (altrimenti si crea un overload).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_web_tour_mappa_insert(
    INTEGER, INTEGER, TEXT, VARCHAR, NUMERIC, NUMERIC, NUMERIC, NUMERIC,
    VARCHAR, VARCHAR, JSONB, TEXT, VARCHAR, TIMESTAMPTZ);

DROP FUNCTION IF EXISTS fn_web_tour_mappa_get_by_viaggio(INTEGER, INTEGER);

DROP FUNCTION IF EXISTS fn_web_tour_mappa_update(
    BIGINT, INTEGER, INTEGER, TEXT, VARCHAR, NUMERIC, NUMERIC, NUMERIC, NUMERIC,
    VARCHAR, VARCHAR, JSONB, TEXT, VARCHAR, TIMESTAMPTZ);

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_insert(
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_gpx_originale TEXT DEFAULT NULL,
    p_gpx_filename VARCHAR DEFAULT NULL,
    p_bbox_min_lat NUMERIC DEFAULT NULL,
    p_bbox_min_lon NUMERIC DEFAULT NULL,
    p_bbox_max_lat NUMERIC DEFAULT NULL,
    p_bbox_max_lon NUMERIC DEFAULT NULL,
    p_provider VARCHAR DEFAULT 'geoapify',
    p_stile VARCHAR DEFAULT 'osm-bright',
    p_parametri_render JSONB DEFAULT NULL,
    p_immagine_url TEXT DEFAULT NULL,
    p_immagine_storage_path VARCHAR DEFAULT NULL,
    p_data_generazione TIMESTAMPTZ DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_mappa(
        web_tour_contenuti_id_fk, gpx_originale, gpx_filename, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
        provider, stile, parametri_render, immagine_url, immagine_storage_path, data_generazione, azienda_id)
    VALUES (
        p_web_tour_contenuti_id_fk, p_gpx_originale, p_gpx_filename, p_bbox_min_lat, p_bbox_min_lon, p_bbox_max_lat, p_bbox_max_lon,
        p_provider, p_stile, p_parametri_render, p_immagine_url, p_immagine_storage_path, p_data_generazione, p_azienda_id)
    RETURNING web_tour_mappa_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_list(p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa WHERE azienda_id = p_azienda_id ORDER BY web_tour_contenuti_id_fk;
$$;

-- GET singolo (scoped per azienda) -> INVARIATA, non toccata.

-- GET per contenuto (1:1): la UI carica la mappa del contenuto
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_get_by_contenuto(p_web_tour_contenuti_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = p_web_tour_contenuti_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_gpx_originale TEXT,
    p_gpx_filename VARCHAR,
    p_bbox_min_lat NUMERIC,
    p_bbox_min_lon NUMERIC,
    p_bbox_max_lat NUMERIC,
    p_bbox_max_lon NUMERIC,
    p_provider VARCHAR,
    p_stile VARCHAR,
    p_parametri_render JSONB,
    p_immagine_url TEXT,
    p_immagine_storage_path VARCHAR,
    p_data_generazione TIMESTAMPTZ)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_mappa
       SET web_tour_contenuti_id_fk=p_web_tour_contenuti_id_fk, gpx_originale=p_gpx_originale, gpx_filename=p_gpx_filename,
           bbox_min_lat=p_bbox_min_lat, bbox_min_lon=p_bbox_min_lon, bbox_max_lat=p_bbox_max_lat, bbox_max_lon=p_bbox_max_lon,
           provider=p_provider, stile=p_stile, parametri_render=p_parametri_render,
           immagine_url=p_immagine_url, immagine_storage_path=p_immagine_storage_path, data_generazione=p_data_generazione
     WHERE web_tour_mappa_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> INVARIATA, non toccata.

COMMIT;
