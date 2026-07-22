-- =====================================================================
-- 491 - CHECK su web_tipi_viaggio_descrizioni (integrità lato DB)
-- Sposta a livello DB le regole finora validate solo lato applicativo:
--   - descrizione_web: almeno 3 caratteri "reali" (dopo trim)
--   - ordine: >= 1
-- Bulletproof, non bypassabili nemmeno via SQL diretto. Idempotente.
-- NB: lo script 490 ha già normalizzato ordine a 1..N (quindi ck ordine passa).
-- =====================================================================

ALTER TABLE web_tipi_viaggio_descrizioni
    DROP CONSTRAINT IF EXISTS ck_web_tipi_viaggio_descrizioni_descrizione_min;
ALTER TABLE web_tipi_viaggio_descrizioni
    ADD CONSTRAINT ck_web_tipi_viaggio_descrizioni_descrizione_min
    CHECK (length(btrim(descrizione_web)) >= 3);

ALTER TABLE web_tipi_viaggio_descrizioni
    DROP CONSTRAINT IF EXISTS ck_web_tipi_viaggio_descrizioni_ordine_min;
ALTER TABLE web_tipi_viaggio_descrizioni
    ADD CONSTRAINT ck_web_tipi_viaggio_descrizioni_ordine_min
    CHECK (ordine >= 1);
