-- =============================================
-- Migration: Add Validation Metadata to ana_tipi_causali
-- Date: 2026-02-12
-- Description: Adds metadata flags for dynamic validation of mov_transazioni
--              based on causale type, eliminating hardcoded causale checks
-- =============================================

-- Step 1: Add new metadata columns
ALTER TABLE ana_tipi_causali
ADD COLUMN IF NOT EXISTS causale_richiede_scadenza BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS causale_giorni_scadenza_default INTEGER DEFAULT NULL,
ADD COLUMN IF NOT EXISTS causale_genera_scadenza_auto BOOLEAN NOT NULL DEFAULT FALSE;

-- Step 2: Update existing causali with business rules

-- FT, ND (Fatture e Note di Debito PASSIVO) richiedono scadenza con 30gg default
UPDATE ana_tipi_causali
SET
    causale_richiede_scadenza = TRUE,
    causale_giorni_scadenza_default = 30,
    causale_genera_scadenza_auto = TRUE
WHERE causale_is_documento = TRUE
  AND causale_ciclo = 'PASSIVO'
  AND causale_codice IN ('FT', 'ND');

-- NC (Note di Credito) non richiedono scadenza
UPDATE ana_tipi_causali
SET
    causale_richiede_scadenza = FALSE,
    causale_giorni_scadenza_default = NULL,
    causale_genera_scadenza_auto = FALSE
WHERE causale_codice = 'NC';

-- FV (Fatture Attive) richiedono scadenza con 30gg default
UPDATE ana_tipi_causali
SET
    causale_richiede_scadenza = TRUE,
    causale_giorni_scadenza_default = 30,
    causale_genera_scadenza_auto = TRUE
WHERE causale_is_documento = TRUE
  AND causale_ciclo = 'ATTIVO'
  AND causale_codice = 'FV';

-- PG, IN (Pagamenti/Incassi) non richiedono scadenza
UPDATE ana_tipi_causali
SET
    causale_richiede_scadenza = FALSE,
    causale_giorni_scadenza_default = NULL,
    causale_genera_scadenza_auto = FALSE
WHERE causale_is_documento = FALSE
  AND causale_codice IN ('PG', 'IN');

-- Documenti generici (SA, SM, CO, AB) non richiedono scadenza
UPDATE ana_tipi_causali
SET
    causale_richiede_scadenza = FALSE,
    causale_giorni_scadenza_default = NULL,
    causale_genera_scadenza_auto = FALSE
WHERE causale_codice IN ('SA', 'SM', 'CO', 'AB');

-- Step 3: Add column comments for documentation
COMMENT ON COLUMN ana_tipi_causali.causale_richiede_scadenza IS
    'Se TRUE, la data scadenza è obbligatoria per transazioni con questa causale. Usato dal trigger di validazione.';

COMMENT ON COLUMN ana_tipi_causali.causale_giorni_scadenza_default IS
    'Numero di giorni da aggiungere alla data documento (o data transazione) per calcolare la scadenza automatica. NULL = nessun default.';

COMMENT ON COLUMN ana_tipi_causali.causale_genera_scadenza_auto IS
    'Se TRUE, genera automaticamente la scadenza se non specificata dall''utente (data_documento + giorni_default). Usato dal trigger.';

-- Step 4: Verify results
SELECT
    causale_codice,
    causale_descrizione,
    causale_ciclo,
    causale_is_documento,
    causale_richiede_scadenza,
    causale_giorni_scadenza_default,
    causale_genera_scadenza_auto
FROM ana_tipi_causali
WHERE is_active = TRUE
ORDER BY causale_ciclo, causale_codice;
