-- Task 1.14 — ana_aziende_esp: credenziali servizio email (ESP) per-azienda (1 per azienda)
-- api_key_enc cifrata lato applicazione (stesso pattern di ana_aziende_smtp.password_enc).
CREATE TABLE ana_aziende_esp (
    ana_aziende_esp_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider             VARCHAR(30)  NOT NULL,        -- brevo/mailchimp/ses/…
    api_key_enc          JSONB        NOT NULL,        -- CIFRATA (pattern password_enc)
    sender_email         CITEXT,
    sender_name          VARCHAR(255),
    sender_domain        VARCHAR(255),                 -- dominio mittente verificato
    attivo               BOOLEAN      NOT NULL DEFAULT false,
    azienda_id  INTEGER      NOT NULL UNIQUE REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ
);
CREATE TRIGGER trg_ana_aziende_esp_audit BEFORE INSERT OR UPDATE ON ana_aziende_esp
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE ana_aziende_esp ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON ana_aziende_esp
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
