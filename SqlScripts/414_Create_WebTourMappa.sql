-- Task 1.7 — web_tour_mappa: mappa percorso (1:1 con tour)
CREATE TABLE web_tour_mappa (
    web_tour_mappa_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    viaggio_id_fk            INTEGER      NOT NULL UNIQUE REFERENCES ana_viaggi(viaggio_id),
    gpx_originale            TEXT,                           -- solo lato server, mai esposto al sito
    gpx_filename             VARCHAR(255),
    bbox_min_lat             NUMERIC(9,6),                   -- riquadro calcolato
    bbox_min_lon             NUMERIC(9,6),
    bbox_max_lat             NUMERIC(9,6),
    bbox_max_lon             NUMERIC(9,6),
    provider                 VARCHAR(20)  DEFAULT 'geoapify',
    stile                    VARCHAR(40)  DEFAULT 'osm-bright', -- palette outdoor
    parametri_render         JSONB,                          -- tolleranza Douglas-Peucker, zoom, margine, w/h
    immagine_url             TEXT,                           -- URL pubblico Supabase Storage
    immagine_storage_path    VARCHAR(500),
    data_generazione         TIMESTAMPTZ,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ
);
CREATE INDEX idx_web_tour_mappa_azienda ON web_tour_mappa (azienda_id);
CREATE TRIGGER trg_web_tour_mappa_audit BEFORE INSERT OR UPDATE ON web_tour_mappa
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_tour_mappa ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_tour_mappa
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
