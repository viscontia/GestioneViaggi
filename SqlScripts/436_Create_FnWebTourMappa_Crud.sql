-- Funzioni CRUD per web_tour_mappa (Blocco 2 estensione web).
-- 1:1 con il viaggio: la UI carica per viaggio (fn_web_tour_mappa_get_by_viaggio).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default); colonne di audit valorizzate da trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_insert(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
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
        viaggio_id_fk, gpx_originale, gpx_filename, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
        provider, stile, parametri_render, immagine_url, immagine_storage_path, data_generazione, azienda_id)
    VALUES (
        p_viaggio_id_fk, p_gpx_originale, p_gpx_filename, p_bbox_min_lat, p_bbox_min_lon, p_bbox_max_lat, p_bbox_max_lon,
        p_provider, p_stile, p_parametri_render, p_immagine_url, p_immagine_storage_path, p_data_generazione, p_azienda_id)
    RETURNING web_tour_mappa_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_list(p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa WHERE azienda_id = p_azienda_id ORDER BY viaggio_id_fk;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa WHERE web_tour_mappa_id = p_id AND azienda_id = p_azienda_id;
$$;

-- GET per viaggio (1:1): la UI carica la mappa del viaggio
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_get_by_viaggio(p_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa WHERE viaggio_id_fk = p_viaggio_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
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
       SET viaggio_id_fk=p_viaggio_id_fk, gpx_originale=p_gpx_originale, gpx_filename=p_gpx_filename,
           bbox_min_lat=p_bbox_min_lat, bbox_min_lon=p_bbox_min_lon, bbox_max_lat=p_bbox_max_lat, bbox_max_lon=p_bbox_max_lon,
           provider=p_provider, stile=p_stile, parametri_render=p_parametri_render,
           immagine_url=p_immagine_url, immagine_storage_path=p_immagine_storage_path, data_generazione=p_data_generazione
     WHERE web_tour_mappa_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tour_mappa WHERE web_tour_mappa_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
