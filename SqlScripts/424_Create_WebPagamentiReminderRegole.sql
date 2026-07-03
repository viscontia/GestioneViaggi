-- Task 1.17 — web_pagamenti_reminder_regole: regole promemoria/solleciti (N per azienda) (PREDISPOSIZIONE)
CREATE TABLE web_pagamenti_reminder_regole (
    web_pagamenti_reminder_regole_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo                    VARCHAR(12)  NOT NULL,       -- promemoria/sollecito
    attivo                  BOOLEAN      NOT NULL DEFAULT true,
    offset_giorni           INTEGER      NOT NULL,       -- <0 = prima scadenza (promemoria), >0 = dopo (sollecito)
    ccn_operatore           BOOLEAN      NOT NULL DEFAULT true,
    ccn_email_fk            INTEGER REFERENCES ana_aziende_email(email_id),
    template_oggetto        VARCHAR(255),                -- IT (traduzioni in web_traduzioni)
    template_corpo          TEXT,                        -- IT
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_pagamenti_reminder_regole_tipo CHECK (tipo IN ('promemoria','sollecito'))
);
CREATE INDEX idx_web_pagamenti_reminder_regole_azienda ON web_pagamenti_reminder_regole (azienda_id);
CREATE TRIGGER trg_web_pagamenti_reminder_regole_audit BEFORE INSERT OR UPDATE ON web_pagamenti_reminder_regole
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_pagamenti_reminder_regole ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_pagamenti_reminder_regole
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
