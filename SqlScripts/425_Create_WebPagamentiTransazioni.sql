-- Task 1.18 — web_pagamenti_transazioni: incassi Stripe (PREDISPOSIZIONE)
-- Importi in centesimi. mov_transazione_fk: INTEGER + FK reale a mov_transazioni(transazione_id) (PK legacy INTEGER),
-- UNIQUE per idempotenza 1:1 incasso→contabilità (anti-doppioni sui retry webhook, §2.17).
CREATE TABLE web_pagamenti_transazioni (
    web_pagamenti_transazioni_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_viaggio_id_fk      INTEGER REFERENCES ana_date_viaggi(data_viaggio_id),
    cliente_fk              INTEGER REFERENCES ana_clienti(cliente_id),
    tipo                    VARCHAR(12)  NOT NULL,       -- acconto/saldo/unica
    importo_cent            INTEGER      NOT NULL,       -- centesimi
    valuta                  CHAR(3)      NOT NULL DEFAULT 'EUR',
    scadenza                DATE,
    stato                   VARCHAR(16)  NOT NULL DEFAULT 'creato',
    stripe_payment_intent   VARCHAR(64),
    stripe_checkout_session VARCHAR(80),
    data_pagamento          TIMESTAMPTZ,
    mov_transazione_fk      INTEGER REFERENCES mov_transazioni(transazione_id) ON DELETE SET NULL,
    fattura_numero          VARCHAR(30),
    fattura_pdf_storage_path VARCHAR(500),
    fattura_inviata_data    TIMESTAMPTZ,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_pagamenti_transazioni_tipo  CHECK (tipo IN ('acconto','saldo','unica')),
    CONSTRAINT chk_web_pagamenti_transazioni_stato CHECK (stato IN ('creato','in_attesa','pagato','fallito','rimborsato')),
    CONSTRAINT uq_web_pagamenti_transazioni_mov UNIQUE (mov_transazione_fk)
);
CREATE INDEX idx_web_pagamenti_transazioni_stato    ON web_pagamenti_transazioni (azienda_id, stato);
CREATE INDEX idx_web_pagamenti_transazioni_scadenza ON web_pagamenti_transazioni (scadenza);
CREATE TRIGGER trg_web_pagamenti_transazioni_audit BEFORE INSERT OR UPDATE ON web_pagamenti_transazioni
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_pagamenti_transazioni ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_pagamenti_transazioni
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
