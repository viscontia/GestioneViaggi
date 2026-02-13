-- =============================================
-- Migration: Add Check Constraint for Data Documento
-- Date: 2026-02-12
-- Description: Prevents future-dated documents by ensuring
--              data_documento <= transazione_data (registration date)
-- =============================================

-- Add constraint: Document date cannot be later than registration date
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_data_documento_non_futura
CHECK (
    transazione_data_documento IS NULL OR
    transazione_data_documento <= transazione_data
);

-- Add comment for documentation
COMMENT ON CONSTRAINT chk_data_documento_non_futura ON mov_transazioni IS
    'Impedisce che la data documento sia successiva alla data di registrazione contabile. '
    'Best practice contabile: la data del documento (emissione fattura) non può essere nel futuro rispetto alla registrazione.';
