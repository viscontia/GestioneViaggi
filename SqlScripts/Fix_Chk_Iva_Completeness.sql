-- Drop the overly restrictive constraint
ALTER TABLE mov_transazioni DROP CONSTRAINT chk_iva_completeness;

-- Add the corrected constraint that checks only VAT-specific fields
ALTER TABLE mov_transazioni ADD CONSTRAINT chk_iva_completeness 
CHECK (
    (transazione_aliquota_iva_fk IS NULL AND transazione_imponibile_eur IS NULL AND transazione_iva_eur IS NULL) 
    OR 
    (transazione_aliquota_iva_fk IS NOT NULL AND transazione_imponibile_eur IS NOT NULL AND transazione_iva_eur IS NOT NULL)
);

COMMENT ON CONSTRAINT chk_iva_completeness ON mov_transazioni IS 'Garantisce che i campi IVA (Aliquota, Imponibile, Imposta) siano tutti valorizzati o tutti NULL. Il Lordo è escluso perché può essere valorizzato anche senza dettaglio IVA (es. Pagamenti o Movimenti Finanziari).';
