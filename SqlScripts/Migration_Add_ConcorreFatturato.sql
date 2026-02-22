-- ============================================================================
-- Migration: Aggiunta colonna causale_concorre_fatturato
-- Data: 2026-02-22
-- Descrizione: Aggiunge il flag booleano per indicare se una causale
--              concorre al calcolo del fatturato aziendale.
-- ============================================================================

ALTER TABLE ana_tipi_causali
ADD COLUMN IF NOT EXISTS causale_concorre_fatturato BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN ana_tipi_causali.causale_concorre_fatturato IS
  'Se TRUE, le transazioni con questa causale concorrono al calcolo del fatturato aziendale.';

-- Popolare i valori di default per le causali ATTIVO che generano fatturato:
-- FV (Fattura Attiva/Vendita) segno +1 → aumenta fatturato
-- NCA (Nota di Credito Emessa) segno -1 → riduce fatturato
-- NDA (Nota di Debito Emessa) segno +1 → aumenta fatturato
-- IN (Incasso/Acconto) → NON concorre (movimento di cassa)
UPDATE ana_tipi_causali
SET causale_concorre_fatturato = TRUE
WHERE causale_ciclo = 'ATTIVO'
  AND causale_codice IN ('FV', 'NCA', 'NDA');
