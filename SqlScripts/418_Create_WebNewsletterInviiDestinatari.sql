-- Task 1.11 — web_newsletter_invii_destinatari: log consegna per destinatario
CREATE TABLE web_newsletter_invii_destinatari (
    web_newsletter_invii_destinatari_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invio_id_fk          BIGINT       NOT NULL REFERENCES web_newsletter_invii(web_newsletter_invii_id) ON DELETE CASCADE,
    email                CITEXT       NOT NULL,
    lingua               CHAR(2),
    stato_consegna       VARCHAR(16),                 -- inviata/bounce/aperta/errore
    data                 TIMESTAMPTZ,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ
);
CREATE INDEX idx_web_newsletter_invii_destinatari_invio ON web_newsletter_invii_destinatari (invio_id_fk);
CREATE INDEX idx_web_newsletter_invii_destinatari_azienda ON web_newsletter_invii_destinatari (azienda_id);
CREATE TRIGGER trg_web_newsletter_invii_destinatari_audit BEFORE INSERT OR UPDATE ON web_newsletter_invii_destinatari
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_newsletter_invii_destinatari ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_newsletter_invii_destinatari
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
