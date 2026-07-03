-- Task 1.12 — web_newsletter_soppressioni: lista di soppressione (esclusa da ogni invio)
CREATE TABLE web_newsletter_soppressioni (
    web_newsletter_soppressioni_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email                CITEXT       NOT NULL,
    motivo               VARCHAR(20)  NOT NULL,        -- disiscritto/bounce_permanente/manuale
    data                 TIMESTAMPTZ  NOT NULL DEFAULT now(),
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_newsletter_soppressioni_email UNIQUE (azienda_id, email)
);
CREATE TRIGGER trg_web_newsletter_soppressioni_audit BEFORE INSERT OR UPDATE ON web_newsletter_soppressioni
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_newsletter_soppressioni ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_newsletter_soppressioni
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
