-- Task 1.4 — web_tour_itinerario: giornate dell'itinerario (N per tour)
CREATE TABLE web_tour_itinerario (
    web_tour_itinerario_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    viaggio_id_fk           INTEGER      NOT NULL REFERENCES ana_viaggi(viaggio_id),
    giorno_numero           INTEGER      NOT NULL,           -- 1,2,3…
    titolo_giornata         VARCHAR(255) NOT NULL,           -- es. "1 TAPPA – COSTA DEL SINIS"
    ordine                  INTEGER      NOT NULL DEFAULT 0, -- drag&drop
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_tour_itinerario_giorno UNIQUE (viaggio_id_fk, giorno_numero)
);
CREATE INDEX idx_web_tour_itinerario_azienda ON web_tour_itinerario (azienda_id);
CREATE TRIGGER trg_web_tour_itinerario_audit BEFORE INSERT OR UPDATE ON web_tour_itinerario
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_tour_itinerario ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_tour_itinerario
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
