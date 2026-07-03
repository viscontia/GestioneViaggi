-- Task 1.10 — web_newsletter_invii (IT; traduzioni in web_traduzioni)
CREATE TABLE web_newsletter_invii (
    web_newsletter_invii_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    oggetto              VARCHAR(255) NOT NULL,
    corpo_html           TEXT         NOT NULL,
    stato                VARCHAR(12)  NOT NULL DEFAULT 'bozza',
    data_invio           TIMESTAMPTZ,
    numero_destinatari   INTEGER,
    canale               VARCHAR(8),                  -- smtp/esp usato
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_newsletter_invii_stato CHECK (stato IN ('bozza','in_invio','inviata'))
);
CREATE INDEX idx_web_newsletter_invii_azienda ON web_newsletter_invii (azienda_id);
CREATE TRIGGER trg_web_newsletter_invii_audit BEFORE INSERT OR UPDATE ON web_newsletter_invii
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_newsletter_invii ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_newsletter_invii
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
