-- =============================================
-- Migration: Add Constraint for Data Documento Required for Non-EUR Transactions
-- Data Creazione: 2026-02-08
-- Autore: Antigravity
-- Descrizione: Aggiunge un trigger che blocca l'inserimento/aggiornamento
--              di transazioni in valuta estera senza data_documento
-- =============================================

-- Funzione di validazione
CREATE OR REPLACE FUNCTION fn_validate_data_documento()
RETURNS TRIGGER AS $$
DECLARE
    v_is_base_currency BOOLEAN;
BEGIN
    -- Verifica se la valuta della transazione è la valuta base (EUR)
    SELECT valuta_is_base INTO v_is_base_currency
    FROM ana_valute
    WHERE valuta_id = NEW.transazione_valuta_id;

    -- Se la valuta NON è quella base (EUR) e data_documento è NULL
    -- blocca l'operazione con un messaggio esplicito
    IF v_is_base_currency = FALSE AND NEW.transazione_data_documento IS NULL THEN
        RAISE EXCEPTION
            'ERRORE: Per transazioni in valuta estera è OBBLIGATORIO inserire la Data Documento. '
            'La Data Documento viene utilizzata per recuperare il tasso di cambio corretto dalla Frankfurter API. '
            'Impossibile procedere senza questo dato.'
            USING ERRCODE = 'check_violation',
                  HINT = 'Inserire la data del documento (fattura/ricevuta) nel campo transazione_data_documento';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop del trigger esistente se presente
DROP TRIGGER IF EXISTS trg_validate_data_documento ON mov_transazioni;

-- Creazione del trigger (eseguito PRIMA di INSERT e UPDATE)
CREATE TRIGGER trg_validate_data_documento
BEFORE INSERT OR UPDATE OF transazione_valuta_id, transazione_data_documento
ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_validate_data_documento();

-- =============================================
-- Commenti
-- =============================================
COMMENT ON FUNCTION fn_validate_data_documento() IS
    'Valida che le transazioni in valuta estera abbiano obbligatoriamente la data_documento per recuperare il tasso di cambio corretto';

COMMENT ON TRIGGER trg_validate_data_documento ON mov_transazioni IS
    'Blocca inserimenti/aggiornamenti di transazioni in valuta estera senza data_documento';

-- =============================================
-- Messaggio di conferma
-- =============================================
DO $$
BEGIN
    RAISE NOTICE 'Migration completata: constraint data_documento obbligatoria per valute estere aggiunto';
END $$;
