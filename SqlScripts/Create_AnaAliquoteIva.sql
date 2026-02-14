-- =====================================================
-- TABELLA: ana_aliquote_iva
-- Scopo: Anagrafica aliquote IVA per azienda
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- Versione: 1.0
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Creazione Tabella
-- =====================================================

CREATE TABLE IF NOT EXISTS public.ana_aliquote_iva (
    -- Identificativi
    iva_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,

    -- Dati aliquota
    iva_codice VARCHAR(10) NOT NULL,           -- '22', '10', '4', 'FC', 'ES', 'NS'
    iva_descrizione VARCHAR(100) NOT NULL,     -- 'IVA Ordinaria 22%', 'Fuori Campo IVA'
    iva_percentuale NUMERIC(5, 2) NOT NULL DEFAULT 0,

    -- Fatturazione Elettronica (FE)
    iva_natura VARCHAR(10),                    -- N1, N2.1, N3.2, N4, N5, N6.x, N7

    -- Configurazione UI
    is_default BOOLEAN DEFAULT FALSE,          -- Aliquota default per azienda
    is_active BOOLEAN DEFAULT TRUE,
    ordinamento SMALLINT DEFAULT 100,          -- Ordinamento dropdown (1=primo)

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50),

    -- Constraint
    CONSTRAINT uk_iva_azienda_codice UNIQUE (azienda_fk, iva_codice),
    CONSTRAINT chk_iva_percentuale CHECK (iva_percentuale >= 0 AND iva_percentuale <= 100),
    CONSTRAINT chk_iva_codice_upper CHECK (iva_codice = UPPER(iva_codice))
);

-- =====================================================
-- STEP 2: Indici per Performance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_aliquote_iva_azienda
ON ana_aliquote_iva(azienda_fk);

CREATE INDEX IF NOT EXISTS idx_aliquote_iva_attive
ON ana_aliquote_iva(azienda_fk, is_active)
WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_aliquote_iva_default
ON ana_aliquote_iva(azienda_fk, is_default)
WHERE is_default = TRUE;

-- =====================================================
-- STEP 3: Commenti per Documentazione
-- =====================================================

COMMENT ON TABLE ana_aliquote_iva IS
'Anagrafica aliquote IVA multi-tenant - supporta fatturazione elettronica e regimi speciali';

COMMENT ON COLUMN ana_aliquote_iva.iva_id IS
'Chiave primaria - ID univoco aliquota IVA';

COMMENT ON COLUMN ana_aliquote_iva.azienda_fk IS
'FK a ana_aziende - Multi-tenant isolation';

COMMENT ON COLUMN ana_aliquote_iva.iva_codice IS
'Codice aliquota (22, 10, 4, FC=Fuori Campo, ES=Esente, NS=Non Soggetto) - sempre UPPER CASE';

COMMENT ON COLUMN ana_aliquote_iva.iva_descrizione IS
'Descrizione aliquota visualizzata in UI (es. "IVA Ordinaria 22%")';

COMMENT ON COLUMN ana_aliquote_iva.iva_percentuale IS
'Percentuale IVA (22.00 per 22%) - 0.00 per FC/ES/NS';

COMMENT ON COLUMN ana_aliquote_iva.iva_natura IS
'Codice natura per Fatturazione Elettronica: N1=escluso art.15, N2=non soggetto, N3=non imponibile, N4=esente, N5=regime margine, N6=reverse charge, N7=altro';

COMMENT ON COLUMN ana_aliquote_iva.is_default IS
'TRUE se aliquota default per azienda (max 1 per azienda) - preselezionata in UI';

COMMENT ON COLUMN ana_aliquote_iva.is_active IS
'TRUE se aliquota attiva e selezionabile in UI';

COMMENT ON COLUMN ana_aliquote_iva.ordinamento IS
'Ordinamento dropdown UI (1=primo, 100=default, 999=ultimo)';

-- =====================================================
-- STEP 4: Trigger - Validazione Single Default
-- =====================================================

CREATE OR REPLACE FUNCTION fn_check_single_default_iva()
RETURNS TRIGGER AS $$
BEGIN
    -- Se si imposta is_default = TRUE, rimuovi il flag da tutte le altre aliquote della stessa azienda
    IF NEW.is_default = TRUE THEN
        UPDATE ana_aliquote_iva
        SET is_default = FALSE,
            updated_at = NOW()
        WHERE azienda_fk = NEW.azienda_fk
          AND iva_id != NEW.iva_id
          AND is_default = TRUE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_single_default_iva ON ana_aliquote_iva;

CREATE TRIGGER trg_check_single_default_iva
BEFORE INSERT OR UPDATE ON ana_aliquote_iva
FOR EACH ROW
WHEN (NEW.is_default = TRUE)
EXECUTE FUNCTION fn_check_single_default_iva();

COMMENT ON FUNCTION fn_check_single_default_iva() IS
'Garantisce che solo 1 aliquota per azienda abbia is_default = TRUE. Eseguito BEFORE INSERT/UPDATE quando is_default = TRUE.';

-- =====================================================
-- STEP 5: Trigger - Touch Updated Timestamp
-- =====================================================

CREATE OR REPLACE FUNCTION fn_touch_updated_at_iva()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_updated_at_iva ON ana_aliquote_iva;

CREATE TRIGGER trg_touch_updated_at_iva
BEFORE UPDATE ON ana_aliquote_iva
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_iva();

-- =====================================================
-- STEP 6: Dati Iniziali - Aliquote Standard Italia
-- =====================================================

-- Inserimento per azienda test (ID 6)
-- Se l'azienda con ID 6 non esiste, lo script darà errore FK
-- In questo caso, modificare l'ID azienda o inserire prima l'azienda

INSERT INTO ana_aliquote_iva (
    azienda_fk,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento,
    created_at
) VALUES
-- Aliquote standard Italia
(6, '22', 'IVA Ordinaria 22%', 22.00, NULL, TRUE, TRUE, 1, NOW()),
(6, '10', 'IVA Ridotta 10%', 10.00, NULL, FALSE, TRUE, 2, NOW()),
(6, '5', 'IVA Ridotta 5%', 5.00, NULL, FALSE, TRUE, 3, NOW()),
(6, '4', 'IVA Ridotta 4%', 4.00, NULL, FALSE, TRUE, 4, NOW()),

-- Aliquote speciali (0%)
(6, 'FC', 'Fuori Campo IVA (Art. 7-ter)', 0.00, 'N1', FALSE, TRUE, 10, NOW()),
(6, 'ES', 'Operazione Esente IVA', 0.00, 'N4', FALSE, TRUE, 11, NOW()),
(6, 'NS', 'Non Soggetto IVA (Regime Forfettario)', 0.00, 'N2.1', FALSE, TRUE, 12, NOW())

ON CONFLICT (azienda_fk, iva_codice) DO NOTHING;

-- =====================================================
-- STEP 7: Query di Verifica
-- =====================================================

-- Verifica creazione tabella
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ana_aliquote_iva') THEN
        RAISE NOTICE '✓ Tabella ana_aliquote_iva creata con successo';
    ELSE
        RAISE EXCEPTION '✗ Errore: Tabella ana_aliquote_iva NON creata';
    END IF;
END $$;

-- Verifica dati inseriti
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM ana_aliquote_iva
    WHERE azienda_fk = 6;

    IF v_count >= 7 THEN
        RAISE NOTICE '✓ Dati iniziali inseriti: % aliquote per azienda 6', v_count;
    ELSE
        RAISE WARNING '⚠ Attenzione: Solo % aliquote inserite per azienda 6 (attese: 7)', v_count;
    END IF;
END $$;

-- Verifica constraint single default
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM ana_aliquote_iva
    WHERE azienda_fk = 6 AND is_default = TRUE;

    IF v_count = 1 THEN
        RAISE NOTICE '✓ Constraint single default verificato: 1 aliquota default';
    ELSE
        RAISE EXCEPTION '✗ Errore: % aliquote default per azienda 6 (attesa: 1)', v_count;
    END IF;
END $$;

COMMIT;

-- =====================================================
-- Query di Controllo Post-Creazione
-- =====================================================

-- Visualizza tutte le aliquote create per azienda 6
SELECT
    iva_id,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento
FROM ana_aliquote_iva
WHERE azienda_fk = 6
ORDER BY ordinamento;

-- Statistiche tabella
SELECT
    COUNT(*) AS totale_aliquote,
    COUNT(DISTINCT azienda_fk) AS totale_aziende,
    COUNT(CASE WHEN is_default = TRUE THEN 1 END) AS totale_default,
    COUNT(CASE WHEN is_active = TRUE THEN 1 END) AS totale_attive
FROM ana_aliquote_iva;

-- =====================================================
-- FINE SCRIPT
-- =====================================================

-- Note Implementative:
-- 1. Se l'azienda con ID 6 non esiste, modificare l'ID o inserire prima l'azienda
-- 2. Il trigger fn_check_single_default_iva garantisce che solo 1 aliquota per azienda sia default
-- 3. Il constraint chk_iva_codice_upper forza i codici in UPPER CASE
-- 4. L'ordinamento definisce l'ordine nel dropdown UI (1=primo, 999=ultimo)
-- 5. Per altre aziende, duplicare l'INSERT cambiando azienda_fk

-- Rollback (se necessario):
-- DROP TABLE IF EXISTS ana_aliquote_iva CASCADE;
-- DROP FUNCTION IF EXISTS fn_check_single_default_iva() CASCADE;
-- DROP FUNCTION IF EXISTS fn_touch_updated_at_iva() CASCADE;
