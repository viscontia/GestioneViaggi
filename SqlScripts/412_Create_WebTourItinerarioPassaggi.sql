-- Task 1.5 — web_tour_itinerario_passaggi: passaggi di ogni giornata (N per giornata)
CREATE TABLE web_tour_itinerario_passaggi (
    web_tour_itinerario_passaggi_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    itinerario_id_fk         BIGINT       NOT NULL REFERENCES web_tour_itinerario(web_tour_itinerario_id) ON DELETE CASCADE,
    testo_html               TEXT         NOT NULL,          -- RichText
    immagine_url             TEXT,                           -- Supabase Storage
    immagine_storage_path    VARCHAR(500),
    immagine_didascalia      VARCHAR(255),
    ordine                   INTEGER      NOT NULL DEFAULT 0, -- drag&drop
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ
);
CREATE INDEX idx_web_tour_itinerario_passaggi_itinerario
    ON web_tour_itinerario_passaggi (itinerario_id_fk);
CREATE INDEX idx_web_tour_itinerario_passaggi_azienda
    ON web_tour_itinerario_passaggi (azienda_id);
CREATE TRIGGER trg_web_tour_itinerario_passaggi_audit BEFORE INSERT OR UPDATE ON web_tour_itinerario_passaggi
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_tour_itinerario_passaggi ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_tour_itinerario_passaggi
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
