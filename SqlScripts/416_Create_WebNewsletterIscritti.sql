-- Task 1.9 — web_newsletter_iscritti
CREATE TABLE web_newsletter_iscritti (
    web_newsletter_iscritti_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email                CITEXT       NOT NULL,
    nome                 VARCHAR(100),
    cognome              VARCHAR(100),
    lingua               CHAR(2)      NOT NULL DEFAULT 'IT',
    data_iscrizione      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    consenso             BOOLEAN      NOT NULL DEFAULT true,
    consenso_data        TIMESTAMPTZ,
    consenso_fonte       VARCHAR(20),                 -- sito/gestionale/import
    stato                VARCHAR(12)  NOT NULL DEFAULT 'attivo',
    token_disiscrizione  VARCHAR(64)  NOT NULL,        -- per link unsubscribe
    cliente_fk           INTEGER REFERENCES ana_clienti(cliente_id),  -- solo per dedup/arricchimento
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_newsletter_iscritti_stato CHECK (stato IN ('attivo','disiscritto')),
    CONSTRAINT uq_web_newsletter_iscritti_email UNIQUE (azienda_id, email)
);
CREATE TRIGGER trg_web_newsletter_iscritti_audit BEFORE INSERT OR UPDATE ON web_newsletter_iscritti
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_newsletter_iscritti ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_newsletter_iscritti
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
