-- CRUD di web_tour_mappa adeguata alle mappe multiple (segue lo script 493).
-- Design: "Estensione Progetto WEB/Documenti/2026-07-25-Mappe_Multiple_GPX_design.md"
--
-- Convenzione invariata: scoping per p_azienda_id, SECURITY INVOKER, audit da trg_web_audit(),
-- insert ritorna il nuovo id, update/delete ritornano le righe toccate (0/1), le violazioni di
-- vincolo propagano e vengono tradotte da DatabaseExceptionHelper.
--
-- Le firme di insert/update cambiano (tre parametri nuovi in coda): DROP esplicito della firma
-- precedente, come da convenzione Blocco 13, per non lasciare overload ambigui (errore 42883).

DROP FUNCTION IF EXISTS fn_web_tour_mappa_insert(
    INTEGER, BIGINT, TEXT, VARCHAR, NUMERIC, NUMERIC, NUMERIC, NUMERIC,
    VARCHAR, VARCHAR, JSONB, TEXT, VARCHAR, TIMESTAMPTZ);

DROP FUNCTION IF EXISTS fn_web_tour_mappa_update(
    BIGINT, INTEGER, BIGINT, TEXT, VARCHAR, NUMERIC, NUMERIC, NUMERIC, NUMERIC,
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
    p_data_generazione TIMESTAMPTZ DEFAULT NULL,
    p_web_tour_itinerario_id_fk BIGINT DEFAULT NULL,
    p_descrizione VARCHAR DEFAULT NULL,
    p_gpx_bytes INTEGER DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_mappa(
        web_tour_contenuti_id_fk, gpx_originale, gpx_filename,
        bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
        provider, stile, parametri_render, immagine_url, immagine_storage_path, data_generazione,
        azienda_id, web_tour_itinerario_id_fk, descrizione, gpx_bytes)
    VALUES (
        p_web_tour_contenuti_id_fk, p_gpx_originale, p_gpx_filename,
        p_bbox_min_lat, p_bbox_min_lon, p_bbox_max_lat, p_bbox_max_lon,
        p_provider, p_stile, p_parametri_render, p_immagine_url, p_immagine_storage_path, p_data_generazione,
        p_azienda_id, p_web_tour_itinerario_id_fk, p_descrizione, p_gpx_bytes)
    RETURNING web_tour_mappa_id INTO v_id;
    RETURN v_id;
END $$;

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
    p_data_generazione TIMESTAMPTZ,
    p_web_tour_itinerario_id_fk BIGINT DEFAULT NULL,
    p_descrizione VARCHAR DEFAULT NULL,
    p_gpx_bytes INTEGER DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_mappa
       SET web_tour_contenuti_id_fk = p_web_tour_contenuti_id_fk,
           gpx_originale = p_gpx_originale, gpx_filename = p_gpx_filename,
           bbox_min_lat = p_bbox_min_lat, bbox_min_lon = p_bbox_min_lon,
           bbox_max_lat = p_bbox_max_lat, bbox_max_lon = p_bbox_max_lon,
           provider = p_provider, stile = p_stile, parametri_render = p_parametri_render,
           immagine_url = p_immagine_url, immagine_storage_path = p_immagine_storage_path,
           data_generazione = p_data_generazione,
           web_tour_itinerario_id_fk = p_web_tour_itinerario_id_fk,
           descrizione = p_descrizione,
           gpx_bytes = p_gpx_bytes
     WHERE web_tour_mappa_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- LIST per edizione: ordine naturale = prima la mappa d'insieme, poi le giornate per giorno_numero.
-- Non serve un campo "ordine": l'ordinamento discende dall'abbinamento.
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_list_by_contenuto(
    p_web_tour_contenuti_id BIGINT,
    p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT m.*
      FROM web_tour_mappa m
      LEFT JOIN web_tour_itinerario i
             ON i.web_tour_itinerario_id = m.web_tour_itinerario_id_fk
     WHERE m.web_tour_contenuti_id_fk = p_web_tour_contenuti_id
       AND m.azienda_id = p_azienda_id
     ORDER BY (m.web_tour_itinerario_id_fk IS NOT NULL), i.giorno_numero, m.web_tour_mappa_id;
$$;

-- GET per edizione: ora significa "la mappa dell'INTERO VIAGGIO" di quella edizione.
-- Con N mappe la vecchia semantica ("la mappa del contenuto") sarebbe ambigua: per l'elenco
-- completo si usa fn_web_tour_mappa_list_by_contenuto.
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_get_by_contenuto(
    p_web_tour_contenuti_id BIGINT,
    p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa
     WHERE web_tour_contenuti_id_fk = p_web_tour_contenuti_id
       AND azienda_id = p_azienda_id
       AND web_tour_itinerario_id_fk IS NULL;
$$;

-- GET per giornata: la mappa abbinata a una specifica giornata dell'itinerario (0 o 1 riga).
CREATE OR REPLACE FUNCTION fn_web_tour_mappa_get_by_giornata(
    p_web_tour_itinerario_id BIGINT,
    p_azienda_id INTEGER)
RETURNS SETOF web_tour_mappa LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_mappa
     WHERE web_tour_itinerario_id_fk = p_web_tour_itinerario_id
       AND azienda_id = p_azienda_id;
$$;

COMMENT ON FUNCTION fn_web_tour_mappa_list_by_contenuto(BIGINT, INTEGER) IS
'Mappe di una edizione: prima quella dell''intero viaggio, poi le giornate in ordine di giorno_numero.';
COMMENT ON FUNCTION fn_web_tour_mappa_get_by_contenuto(BIGINT, INTEGER) IS
'Mappa dell''INTERO VIAGGIO di una edizione (web_tour_itinerario_id_fk IS NULL). Per l''elenco completo usare fn_web_tour_mappa_list_by_contenuto.';
