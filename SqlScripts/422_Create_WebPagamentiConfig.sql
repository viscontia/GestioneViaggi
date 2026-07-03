-- Task 1.15 — web_pagamenti_config: credenziali Stripe per-azienda (PREDISPOSIZIONE, non cablata nel 1° rilascio)
CREATE TABLE web_pagamenti_config (
    web_pagamenti_config_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stripe_publishable_key      VARCHAR(255),            -- pubblica (no cifratura)
    stripe_secret_key_enc       JSONB,                   -- CIFRATA, solo server-side
    stripe_webhook_secret_enc   JSONB,                   -- CIFRATA
    modo                        VARCHAR(8)  NOT NULL DEFAULT 'test',
    attivo                      BOOLEAN     NOT NULL DEFAULT false,
    azienda_id  INTEGER      NOT NULL UNIQUE REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_pagamenti_config_modo CHECK (modo IN ('test','live'))
);
CREATE TRIGGER trg_web_pagamenti_config_audit BEFORE INSERT OR UPDATE ON web_pagamenti_config
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_pagamenti_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_pagamenti_config
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
