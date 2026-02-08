-- =============================================
-- Migration: Add Exchange Rate Tracking Fields to mov_transazioni
-- Data Creazione: 2026-02-08
-- Autore: Antigravity
-- Descrizione: Aggiunge campi per tracciare il tasso di cambio applicato,
--              la fonte e la data di validità per ogni transazione
-- =============================================

-- Aggiungere i nuovi campi per tracciare il tasso di cambio applicato
ALTER TABLE mov_transazioni
ADD COLUMN IF NOT EXISTS transazione_tasso_cambio_applicato NUMERIC(15,6);

ALTER TABLE mov_transazioni
ADD COLUMN IF NOT EXISTS transazione_tasso_fonte VARCHAR(50);

ALTER TABLE mov_transazioni
ADD COLUMN IF NOT EXISTS transazione_tasso_data_validita DATE;

-- =============================================
-- Commenti sui nuovi campi
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_tasso_cambio_applicato IS
    'Tasso di cambio effettivamente applicato per la conversione in EUR (storicizzato al momento della registrazione)';

COMMENT ON COLUMN mov_transazioni.transazione_tasso_fonte IS
    'Fonte del tasso di cambio applicato (es. FRANKFURTER_API, FALLBACK_DB, MANUALE)';

COMMENT ON COLUMN mov_transazioni.transazione_tasso_data_validita IS
    'Data di validità del tasso di cambio applicato (può differire dalla data documento se si usa un fallback)';

-- =============================================
-- Messaggio di conferma
-- =============================================
DO $$
BEGIN
    RAISE NOTICE 'Migration completata: campi tasso_cambio aggiunti a mov_transazioni';
END $$;
