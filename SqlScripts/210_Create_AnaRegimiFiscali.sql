-- ============================================================
-- 210: Creazione tabella ana_regimi_fiscali
-- Tabella SYSTEM-LEVEL (NON multi-tenant)
-- I regimi fiscali sono definiti dalla legge italiana
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.ana_regimi_fiscali (
    regime_id SERIAL PRIMARY KEY,
    regime_codice VARCHAR(20) UNIQUE NOT NULL,
    regime_descrizione VARCHAR(100) NOT NULL,

    -- UI Behavior
    show_helper_calcolo BOOLEAN NOT NULL DEFAULT FALSE,

    -- Default IVA Configuration
    default_aliquota_iva_codice VARCHAR(10),
    is_iva_detraibile BOOLEAN NOT NULL DEFAULT TRUE,

    -- Cassa Previdenziale (es. INPS)
    cassa_prev_percentuale NUMERIC(5,2),
    cassa_prev_descrizione VARCHAR(50),
    cassa_prev_aliquota_codice VARCHAR(10),

    -- Imposta di Bollo
    bollo_soglia NUMERIC(10,2),
    bollo_importo NUMERIC(10,2),
    bollo_aliquota_codice VARCHAR(10),

    -- Metadata
    attivo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50),

    -- Constraints
    CONSTRAINT chk_regime_codice_upper CHECK (regime_codice = UPPER(regime_codice))
);

COMMENT ON TABLE ana_regimi_fiscali IS 'Regimi fiscali italiani. Tabella system-level (non multi-tenant).';
COMMENT ON COLUMN ana_regimi_fiscali.show_helper_calcolo IS 'Mostra il bottone helper di calcolo nella UI transazioni';
COMMENT ON COLUMN ana_regimi_fiscali.default_aliquota_iva_codice IS 'Codice aliquota IVA default per questo regime (es. N2.2, 22)';
COMMENT ON COLUMN ana_regimi_fiscali.is_iva_detraibile IS 'Se FALSE (forfettario), IVA non recuperabile. Impatta calcolo margine.';
COMMENT ON COLUMN ana_regimi_fiscali.cassa_prev_percentuale IS 'Percentuale cassa previdenziale (es. 4% INPS per forfettario)';
COMMENT ON COLUMN ana_regimi_fiscali.bollo_soglia IS 'Soglia importo sopra la quale si applica il bollo (es. 77.47)';
COMMENT ON COLUMN ana_regimi_fiscali.bollo_importo IS 'Importo fisso del bollo (es. 2.00)';

-- Trigger updated_at
CREATE OR REPLACE FUNCTION fn_touch_updated_at_regimi_fiscali()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_updated_at_regimi_fiscali ON ana_regimi_fiscali;
CREATE TRIGGER trg_touch_updated_at_regimi_fiscali
    BEFORE UPDATE ON ana_regimi_fiscali
    FOR EACH ROW
    EXECUTE FUNCTION fn_touch_updated_at_regimi_fiscali();

-- ============================================================
-- SEED DATA: 3 regimi fiscali italiani
-- ============================================================

INSERT INTO ana_regimi_fiscali (
    regime_codice, regime_descrizione,
    show_helper_calcolo, default_aliquota_iva_codice, is_iva_detraibile,
    cassa_prev_percentuale, cassa_prev_descrizione, cassa_prev_aliquota_codice,
    bollo_soglia, bollo_importo, bollo_aliquota_codice,
    attivo, created_by
) VALUES
(
    'ORDINARIO', 'Regime Ordinario',
    FALSE, '22', TRUE,
    NULL, NULL, NULL,
    NULL, NULL, NULL,
    TRUE, 'SYSTEM'
),
(
    'FORFETTARIO', 'Regime Forfettario (L. 190/2014)',
    TRUE, 'N2.2', FALSE,
    4.00, 'RIVALSA INPS 4%', 'N2.2',
    77.47, 2.00, 'N1',
    TRUE, 'SYSTEM'
),
(
    'SEMPLIFICATO', 'Regime Semplificato',
    FALSE, '22', TRUE,
    NULL, NULL, NULL,
    NULL, NULL, NULL,
    TRUE, 'SYSTEM'
);

COMMIT;
