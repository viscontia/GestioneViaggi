-- Task 1.6 — web_tour_immagini: galleria del tour
CREATE TABLE web_tour_immagini (
    web_tour_immagini_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    viaggio_id_fk            INTEGER      NOT NULL REFERENCES ana_viaggi(viaggio_id),
    tipo                     VARCHAR(12)  NOT NULL DEFAULT 'galleria',
    url                      TEXT         NOT NULL,          -- Supabase Storage (pubblico)
    storage_path             VARCHAR(500) NOT NULL,
    alt_text                 VARCHAR(255),                   -- SEO/accessibilità
    titolo                   VARCHAR(255),                   -- tooltip
    larghezza                INTEGER,                        -- per layout
    altezza                  INTEGER,                        -- per layout
    mime                     VARCHAR(50),                    -- es. image/webp
    ordine                   INTEGER      NOT NULL DEFAULT 0,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_tour_immagini_tipo CHECK (tipo IN ('principale','galleria'))
);
CREATE INDEX idx_web_tour_immagini_viaggio
    ON web_tour_immagini (viaggio_id_fk, tipo, ordine);
CREATE INDEX idx_web_tour_immagini_azienda ON web_tour_immagini (azienda_id);
-- Regola: una sola immagine tipo='principale' per tour
CREATE UNIQUE INDEX uq_web_tour_immagini_principale
    ON web_tour_immagini (viaggio_id_fk) WHERE tipo = 'principale';
CREATE TRIGGER trg_web_tour_immagini_audit BEFORE INSERT OR UPDATE ON web_tour_immagini
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_tour_immagini ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_tour_immagini
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
