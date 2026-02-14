-- =====================================================
-- MIGRAZIONE: Metadati IVA su ana_tipi_causali
-- Scopo: Estendere sistema metadata-driven con logica IVA
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- Implementazione: STEP 3 - Implementazione_IVA.md
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Aggiungi colonne metadati IVA
-- =====================================================

ALTER TABLE public.ana_tipi_causali
ADD COLUMN causale_genera_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_richiede_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_aliquota_iva_default_fk INTEGER REFERENCES ana_aliquote_iva(iva_id) ON DELETE SET NULL;

-- =====================================================
-- STEP 2: Commenti colonne
-- =====================================================

COMMENT ON COLUMN ana_tipi_causali.causale_genera_iva IS
'TRUE se la causale può avere IVA (FT, FV, ND, NDA). FALSE per pagamenti/incassi (PG, IN) e note credito (NC, NCA) che stornano IVA già registrata.';

COMMENT ON COLUMN ana_tipi_causali.causale_richiede_iva IS
'TRUE se IVA è obbligatoria per questa causale (trigger validerà presenza aliquota). Usare solo per FT/FV dove IVA è sempre presente.';

COMMENT ON COLUMN ana_tipi_causali.causale_aliquota_iva_default_fk IS
'FK a aliquota IVA preselezionata in UI per questa causale (es. 22% per FT/FV italiane). NULL = utente sceglie manualmente.';

-- =====================================================
-- STEP 3: Aggiorna causali esistenti (Azienda 6)
-- =====================================================

-- Ciclo PASSIVO (Fornitori)
UPDATE ana_tipi_causali
SET causale_genera_iva = TRUE,
    causale_richiede_iva = TRUE,
    causale_aliquota_iva_default_fk = (SELECT iva_id FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = '22')
WHERE causale_codice IN ('FT', 'ND') AND azienda_fk = 6;
-- FT (Fattura Passiva) e ND (Nota Debito) hanno sempre IVA

UPDATE ana_tipi_causali
SET causale_genera_iva = FALSE,
    causale_richiede_iva = FALSE
WHERE causale_codice IN ('PG', 'NC') AND azienda_fk = 6;
-- PG (Pagamento) non ha IVA (è un movimento su fattura già registrata)
-- NC (Nota Credito) storna IVA già registrata nella FT originale, non genera nuova IVA

-- Ciclo ATTIVO (Clienti)
UPDATE ana_tipi_causali
SET causale_genera_iva = TRUE,
    causale_richiede_iva = TRUE,
    causale_aliquota_iva_default_fk = (SELECT iva_id FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = '22')
WHERE causale_codice IN ('FV', 'NDA') AND azienda_fk = 6;
-- FV (Fattura Vendita) e NDA (Nota Debito Attiva) hanno sempre IVA

UPDATE ana_tipi_causali
SET causale_genera_iva = FALSE,
    causale_richiede_iva = FALSE
WHERE causale_codice IN ('IN', 'NCA') AND azienda_fk = 6;
-- IN (Incasso) non ha IVA
-- NCA (Nota Credito Attiva) storna IVA già registrata

-- =====================================================
-- STEP 4: Constraint logico (richiede_iva implica genera_iva)
-- =====================================================

ALTER TABLE ana_tipi_causali
ADD CONSTRAINT chk_iva_richiede_implica_genera CHECK (
    (causale_richiede_iva = FALSE) OR (causale_genera_iva = TRUE)
);
-- Se richiede IVA obbligatoria, deve anche generare IVA

-- =====================================================
-- COMMIT
-- =====================================================

COMMIT;

-- =====================================================
-- QUERY DI VERIFICA POST-MIGRAZIONE
-- =====================================================

-- Verifica configurazione causali azienda 6
SELECT
    causale_codice,
    causale_descrizione,
    causale_ciclo,
    causale_genera_iva,
    causale_richiede_iva,
    aiva.iva_codice AS aliquota_default
FROM ana_tipi_causali tc
LEFT JOIN ana_aliquote_iva aiva ON tc.causale_aliquota_iva_default_fk = aiva.iva_id
WHERE tc.azienda_fk = 6
ORDER BY causale_ciclo, causale_codice;

-- Atteso:
-- PASSIVO:
--   FT:  genera=T, richiede=T, default=22
--   ND:  genera=T, richiede=T, default=22
--   PG:  genera=F, richiede=F, default=NULL
--   NC:  genera=F, richiede=F, default=NULL
-- ATTIVO:
--   FV:  genera=T, richiede=T, default=22
--   NDA: genera=T, richiede=T, default=22
--   IN:  genera=F, richiede=F, default=NULL
--   NCA: genera=F, richiede=F, default=NULL
