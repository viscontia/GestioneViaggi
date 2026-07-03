CREATE TABLE web_categorie_sport (
    web_categorie_sport_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codice      VARCHAR(20)  NOT NULL,   -- FUORISTRADA, QUAD, MOTO_ENDURO, MOTO_STRADALE
    etichetta   VARCHAR(50)  NOT NULL,
    slug        VARCHAR(50)  NOT NULL,
    ordine      INTEGER      NOT NULL DEFAULT 0,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_categorie_sport_codice UNIQUE (azienda_id, codice),
    CONSTRAINT uq_web_categorie_sport_slug   UNIQUE (azienda_id, slug)
);
CREATE INDEX idx_web_categorie_sport_azienda ON web_categorie_sport(azienda_id);
CREATE TRIGGER trg_web_categorie_sport_audit BEFORE INSERT OR UPDATE ON web_categorie_sport
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_categorie_sport ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_categorie_sport
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
