-- =====================================================
-- Migration: Gestione Fornitori Italia/Estero
-- Data: 2026-01-28
-- Autore: Claude Code Assistant
-- Descrizione: Aggiunge distinzione fornitori italiani/esteri
--              con validazioni fiscali corrette e constraint ottimizzati
-- =====================================================

BEGIN;

-- STEP 1: Aggiungi nuova colonna per distinguere IT/Estero
ALTER TABLE ana_fornitori
    ADD COLUMN IF NOT EXISTS fornitore_estero BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN ana_fornitori.fornitore_estero IS
    'FALSE = Fornitore Italiano (P.IVA/CF italiani), TRUE = Fornitore Estero (VAT Number)';

-- STEP 2: Estendi lunghezza P.IVA per supportare VAT Number esteri (max 20 char)
ALTER TABLE ana_fornitori
    ALTER COLUMN partita_iva TYPE VARCHAR(20);

COMMENT ON COLUMN ana_fornitori.partita_iva IS
    'P.IVA italiana (11 cifre) per fornitori IT, VAT Number (es: FR12345678901) per fornitori esteri';

-- STEP 3: Imposta dati esistenti come fornitori italiani (backward compatibility)
UPDATE ana_fornitori
SET fornitore_estero = FALSE
WHERE fornitore_estero IS NULL;

-- STEP 4: Normalizza SDI esistenti (imposta default se NULL per fornitori italiani)
UPDATE ana_fornitori
SET codice_destinatario_sdi = '0000000'
WHERE codice_destinatario_sdi IS NULL
  AND fornitore_estero = FALSE;

COMMENT ON COLUMN ana_fornitori.codice_destinatario_sdi IS
    'Codice SDI: "0000000" default per IT, "XXXXXXX" fisso per esteri';

-- STEP 5: Rimuovi constraint debole esistente (permetteva duplicati parziali)
ALTER TABLE ana_fornitori
    DROP CONSTRAINT IF EXISTS uk_fornitori_piva_cf;

-- STEP 6: Aggiungi constraint forti con filtri condizionali

-- Constraint 1: P.IVA unica per fornitori ITALIANI (stesso azienda)
CREATE UNIQUE INDEX IF NOT EXISTS idx_uniq_fornitori_piva_it
    ON ana_fornitori (azienda_fk, partita_iva)
    WHERE partita_iva IS NOT NULL AND fornitore_estero = FALSE;

COMMENT ON INDEX idx_uniq_fornitori_piva_it IS
    'Constraint: P.IVA italiana unica per azienda';

-- Constraint 2: CF unico per fornitori ITALIANI (stesso azienda)
CREATE UNIQUE INDEX IF NOT EXISTS idx_uniq_fornitori_cf_it
    ON ana_fornitori (azienda_fk, codice_fiscale)
    WHERE codice_fiscale IS NOT NULL AND fornitore_estero = FALSE;

COMMENT ON INDEX idx_uniq_fornitori_cf_it IS
    'Constraint: Codice Fiscale italiano unico per azienda';

-- Constraint 3: VAT Number unico per fornitori ESTERI (stesso azienda)
CREATE UNIQUE INDEX IF NOT EXISTS idx_uniq_fornitori_vat_estero
    ON ana_fornitori (azienda_fk, partita_iva)
    WHERE partita_iva IS NOT NULL AND fornitore_estero = TRUE;

COMMENT ON INDEX idx_uniq_fornitori_vat_estero IS
    'Constraint: VAT Number estero unico per azienda';

-- STEP 7: Indici per performance su ricerche

-- Indice parziale: solo fornitori esteri (minority case, ottimizzazione)
CREATE INDEX IF NOT EXISTS idx_fornitori_estero
    ON ana_fornitori (fornitore_estero)
    WHERE fornitore_estero = TRUE;

COMMENT ON INDEX idx_fornitori_estero IS
    'Performance: ricerca fornitori esteri (partial index)';

-- Indice parziale: P.IVA non NULL (per ricerche rapide)
CREATE INDEX IF NOT EXISTS idx_fornitori_piva
    ON ana_fornitori (partita_iva)
    WHERE partita_iva IS NOT NULL;

COMMENT ON INDEX idx_fornitori_piva IS
    'Performance: ricerca per P.IVA/VAT Number';

-- Indice parziale: CF non NULL (per ricerche rapide)
CREATE INDEX IF NOT EXISTS idx_fornitori_cf
    ON ana_fornitori (codice_fiscale)
    WHERE codice_fiscale IS NOT NULL;

COMMENT ON INDEX idx_fornitori_cf IS
    'Performance: ricerca per Codice Fiscale';

COMMIT;

-- =====================================================
-- REPORT POST-MIGRATION
-- =====================================================

-- Verifica struttura tabella
\d ana_fornitori

-- Conta fornitori per tipo
SELECT
    CASE WHEN fornitore_estero THEN 'ESTERI' ELSE 'ITALIANI' END AS tipo,
    COUNT(*) as totale
FROM ana_fornitori
GROUP BY fornitore_estero
ORDER BY fornitore_estero;

-- Identifica fornitori legacy (senza P.IVA e CF)
SELECT
    fornitore_id,
    ragione_sociale,
    partita_iva,
    codice_fiscale,
    codice_destinatario_sdi
FROM ana_fornitori
WHERE fornitore_estero = FALSE
  AND partita_iva IS NULL
  AND codice_fiscale IS NULL
ORDER BY ragione_sociale;

-- Verifica indici creati
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'ana_fornitori'
  AND indexname LIKE 'idx_%fornitori%'
ORDER BY indexname;

-- =====================================================
-- SCRIPT ROLLBACK (CONSERVARE IN CASO DI EMERGENZA)
-- =====================================================
/*
-- ⚠️ ATTENZIONE: Questo rollback TRONCA i VAT Number > 11 caratteri!
-- ESEGUIRE BACKUP COMPLETO prima della migration originale!

BEGIN;
    -- Rimuove indici UNIQUE condizionali
    DROP INDEX IF EXISTS idx_uniq_fornitori_piva_it;
    DROP INDEX IF EXISTS idx_uniq_fornitori_cf_it;
    DROP INDEX IF EXISTS idx_uniq_fornitori_vat_estero;

    -- Rimuove indici performance
    DROP INDEX IF EXISTS idx_fornitori_estero;
    DROP INDEX IF EXISTS idx_fornitori_piva;
    DROP INDEX IF EXISTS idx_fornitori_cf;

    -- Restringe P.IVA a VARCHAR(11) - ⚠️ TRONCA dati > 11 char
    ALTER TABLE ana_fornitori ALTER COLUMN partita_iva TYPE VARCHAR(11);

    -- Rimuove campo fornitore_estero
    ALTER TABLE ana_fornitori DROP COLUMN IF EXISTS fornitore_estero;

    -- Ripristina constraint originale (debole)
    ALTER TABLE ana_fornitori
        ADD CONSTRAINT uk_fornitori_piva_cf
        UNIQUE (azienda_fk, partita_iva, codice_fiscale);
COMMIT;

-- Verifica rollback
\d ana_fornitori
*/
