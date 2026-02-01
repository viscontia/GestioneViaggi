-- =============================================
-- Tabella Valute
-- Data Creatione: 2026-01-29
-- Autore: Antigravity
-- =============================================

CREATE TABLE IF NOT EXISTS ana_valute (
    valuta_id SERIAL PRIMARY KEY,
    
    -- Codice ISO 4217 (3 caratteri) es. EUR, USD
    valuta_codice_iso VARCHAR(3) NOT NULL,
    
    -- Descrizione estesa della valuta es. Euro, Dollaro USA
    valuta_descrizione VARCHAR(50) NOT NULL,
    
    -- Simbolo per visualizzazione es. €, $
    valuta_simbolo VARCHAR(5),
    
    -- Valuta di base per i report (una sola può essere TRUE)
    valuta_is_base BOOLEAN DEFAULT FALSE,
    
    -- Attiva/disattivata (Soft Delete logico)
    valuta_attiva BOOLEAN DEFAULT TRUE,
    
    -- Decimali (di solito 2, ma alcune valute ne hanno 0 o 3)
    valuta_decimali SMALLINT DEFAULT 2 CHECK (valuta_decimali BETWEEN 0 AND 4),
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    
    -- Constraints
    CONSTRAINT uk_valuta_codice_iso UNIQUE (valuta_codice_iso)
);

-- Index unico parziale per garantire una sola valuta base
CREATE UNIQUE INDEX uk_valuta_is_base 
ON ana_valute (valuta_is_base) 
WHERE valuta_is_base = TRUE;

-- =============================================
-- Trigger per aggiornamento automatico updated_at
-- =============================================
DROP TRIGGER IF EXISTS trg_update_ana_valute_modtime ON ana_valute;

CREATE TRIGGER trg_update_ana_valute_modtime
BEFORE UPDATE ON ana_valute
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_simple();

-- =============================================
-- Commenti e Documentazione
-- =============================================
COMMENT ON TABLE ana_valute IS 'Tabella anagrafica delle valute gestite dal sistema (ISO 4217)';
COMMENT ON COLUMN ana_valute.valuta_id IS 'Identificativo univoco auto-incrementale della valuta';
COMMENT ON COLUMN ana_valute.valuta_codice_iso IS 'Codice ISO 4217 univoco a 3 caratteri (es. EUR, USD)';
COMMENT ON COLUMN ana_valute.valuta_descrizione IS 'Descrizione estesa della valuta';
COMMENT ON COLUMN ana_valute.valuta_simbolo IS 'Simbolo grafico della valuta per visualizzazione UI';
COMMENT ON COLUMN ana_valute.valuta_is_base IS 'Flag che indica se è la valuta di riferimento per il sistema (solo una riga a TRUE)';
COMMENT ON COLUMN ana_valute.valuta_attiva IS 'Flag di stato: TRUE=Attiva, FALSE=Disattivata (non selezionabile)';
COMMENT ON COLUMN ana_valute.valuta_decimali IS 'Numero di decimali da gestire per questa valuta (0-4)';
COMMENT ON COLUMN ana_valute.created_at IS 'Data e ora di creazione del record';
COMMENT ON COLUMN ana_valute.created_by IS 'Utente che ha creato il record';
COMMENT ON COLUMN ana_valute.updated_at IS 'Data e ora di ultima modifica del record';
COMMENT ON COLUMN ana_valute.updated_by IS 'Utente che ha modificato il record';
