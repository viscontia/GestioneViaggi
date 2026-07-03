-- Task 1.16 — web_pagamenti_regole: regole di pagamento per-azienda (PREDISPOSIZIONE)
CREATE TABLE web_pagamenti_regole (
    web_pagamenti_regole_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    modalita                VARCHAR(20)  NOT NULL,       -- soluzione_unica/acconto_saldo
    acconto_previsto        BOOLEAN      NOT NULL DEFAULT false,
    acconto_percentuale     NUMERIC(5,2),                -- 0–100
    acconto_scadenza_tipo   VARCHAR(24),
    acconto_giorni          INTEGER,
    saldo_scadenza_tipo     VARCHAR(28),
    saldo_giorni            INTEGER,
    unica_scadenza_tipo     VARCHAR(24),
    unica_giorni            INTEGER,
    valuta                  CHAR(3)      NOT NULL DEFAULT 'EUR',
    attivo                  BOOLEAN      NOT NULL DEFAULT false,
    azienda_id  INTEGER      NOT NULL UNIQUE REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_pagamenti_regole_modalita     CHECK (modalita IN ('soluzione_unica','acconto_saldo')),
    CONSTRAINT chk_web_pagamenti_regole_acconto_scad CHECK (acconto_scadenza_tipo IN ('alla_prenotazione','giorni_da_prenotazione')),
    CONSTRAINT chk_web_pagamenti_regole_saldo_scad   CHECK (saldo_scadenza_tipo IN ('giorni_prima_partenza','alla_prenotazione','giorni_da_prenotazione')),
    CONSTRAINT chk_web_pagamenti_regole_unica_scad   CHECK (unica_scadenza_tipo IN ('alla_prenotazione','giorni_prima_partenza'))
);
CREATE TRIGGER trg_web_pagamenti_regole_audit BEFORE INSERT OR UPDATE ON web_pagamenti_regole
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_pagamenti_regole ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_pagamenti_regole
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
