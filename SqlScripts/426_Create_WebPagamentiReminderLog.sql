-- Task 1.18 — web_pagamenti_reminder_log: log promemoria inviati (anti-duplicati) (PREDISPOSIZIONE)
CREATE TABLE web_pagamenti_reminder_log (
    web_pagamenti_reminder_log_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transazione_fk          BIGINT       NOT NULL REFERENCES web_pagamenti_transazioni(web_pagamenti_transazioni_id) ON DELETE CASCADE,
    reminder_regola_fk      BIGINT       NOT NULL REFERENCES web_pagamenti_reminder_regole(web_pagamenti_reminder_regole_id),
    destinatario            CITEXT       NOT NULL,       -- cliente
    lingua                  CHAR(2),
    data_invio              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    esito                   VARCHAR(16),                 -- inviato/errore
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_pagamenti_reminder_log UNIQUE (transazione_fk, reminder_regola_fk)  -- non invia due volte lo stesso reminder
);
CREATE INDEX idx_web_pagamenti_reminder_log_azienda ON web_pagamenti_reminder_log (azienda_id);
CREATE TRIGGER trg_web_pagamenti_reminder_log_audit BEFORE INSERT OR UPDATE ON web_pagamenti_reminder_log
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_pagamenti_reminder_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_pagamenti_reminder_log
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
