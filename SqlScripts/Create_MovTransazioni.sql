-- =============================================
-- Tabella Movimenti Transazioni
-- Data Creazione: 2026-01-29
-- Autore: Antigravity
-- =============================================

CREATE TABLE IF NOT EXISTS mov_transazioni (
    transazione_id SERIAL PRIMARY KEY,
    
    -- FK Azienda (per multi-tenancy)
    transazione_azienda_id INTEGER NOT NULL 
        CONSTRAINT fk_transazioni_azienda 
        REFERENCES ana_aziende(azienda_id),
    
    -- FK Viaggio (OPZIONALE: se NULL = transazione aziendale generale)
    transazione_viaggio_id INTEGER 
        CONSTRAINT fk_transazioni_viaggio 
        REFERENCES ana_viaggi(viaggio_id),
    
    -- FK Data Viaggio (OPZIONALE: se NULL = transazione aziendale generale)
    transazione_data_viaggio_id INTEGER 
        CONSTRAINT fk_transazioni_data_viaggio 
        REFERENCES ana_date_viaggi(data_viaggio_id),
    
    -- FK Fornitore (SEMPRE obbligatorio)
    transazione_fornitore_id INTEGER NOT NULL
        CONSTRAINT fk_transazioni_fornitore 
        REFERENCES ana_fornitori(fornitore_id),
    
    -- Tipo movimento
    transazione_tipo_movimento VARCHAR(10) NOT NULL 
        CHECK (transazione_tipo_movimento IN ('ENTRATA', 'USCITA')),
    
    -- Importo e valuta
    transazione_importo NUMERIC(10,2) NOT NULL,
    
    -- Valuta (FK a ana_valute)
    transazione_valuta_id INTEGER NOT NULL
        CONSTRAINT fk_transazioni_valuta
        REFERENCES ana_valute(valuta_id),
        
    -- Importo in EUR (Calcolato automaticamente da trigger)
    transazione_importo_eur NUMERIC(10,2),
    
    -- Date transazione
    transazione_data DATE NOT NULL,
    transazione_data_scadenza DATE,
    transazione_data_pagamento DATE,
    
    -- Stato pagamento
    transazione_stato VARCHAR(20) NOT NULL DEFAULT 'DA_PAGARE'
        CHECK (transazione_stato IN ('DA_PAGARE', 'PAGATO', 'PARZIALMENTE_PAGATO', 'ANNULLATO')),
    
    -- Descrizioni
    transazione_causale TEXT NOT NULL,
    transazione_note TEXT,
    
    -- Riferimenti documenti
    transazione_numero_documento VARCHAR(50), -- Numero fattura/ricevuta fornitore
    
    -- Collegamento futuro fattura elettronica
    transazione_fattura_fk INTEGER,
    
    -- Campi AUDIT STANDARD
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    
    -- =============================================
    -- CONSTRAINT CRITICO: Coerenza viaggio
    -- =============================================
    -- O ENTRAMBI NULL (transazione generale) 
    -- O ENTRAMBI NOT NULL (transazione specifica viaggio)
    CONSTRAINT chk_viaggio_coerenza 
        CHECK (
            (transazione_viaggio_id IS NULL AND transazione_data_viaggio_id IS NULL) OR
            (transazione_viaggio_id IS NOT NULL AND transazione_data_viaggio_id IS NOT NULL)
        )
);

-- =============================================
-- Trigger per updated_at automatico
-- =============================================
DROP TRIGGER IF EXISTS trg_touch_updated_at_transazioni ON mov_transazioni;

CREATE TRIGGER trg_touch_updated_at_transazioni
BEFORE UPDATE ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_simple();

-- =============================================
-- Trigger per calcolo automatico importo_eur
-- =============================================
CREATE OR REPLACE FUNCTION fn_calcola_importo_eur() 
RETURNS TRIGGER AS $$
DECLARE
    v_valuta_base_id INTEGER;
    v_tasso NUMERIC(15,6);
BEGIN
    -- Ottieni ID valuta base (EUR)
    SELECT valuta_id INTO v_valuta_base_id
    FROM ana_valute
    WHERE valuta_is_base = TRUE
    LIMIT 1;
    
    -- Se la valuta è già quella base, copia l'importo
    IF NEW.transazione_valuta_id = v_valuta_base_id THEN
        NEW.transazione_importo_eur := NEW.transazione_importo;
    ELSE
        -- Calcola conversione usando la fn_get_tasso_cambio (Logica Avanzata)
        v_tasso := fn_get_tasso_cambio(
            NEW.transazione_valuta_id, 
            v_valuta_base_id, 
            NEW.transazione_data
        );
        
        -- Se tasso non trovato (NULL), l'importo EUR rimane NULL (triggering user attention potentially)
        IF v_tasso IS NOT NULL THEN
            NEW.transazione_importo_eur := ROUND((NEW.transazione_importo * v_tasso), 2);
        ELSE
            -- Optional: Log or RAISE NOTICE? Per ora NULL.
            NEW.transazione_importo_eur := NULL; 
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calcola_importo_eur ON mov_transazioni;

CREATE TRIGGER trg_calcola_importo_eur
BEFORE INSERT OR UPDATE OF transazione_importo, transazione_valuta_id, transazione_data
ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_calcola_importo_eur();


-- =============================================
-- Indici per performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_transazioni_azienda 
    ON mov_transazioni(transazione_azienda_id);

CREATE INDEX IF NOT EXISTS idx_transazioni_viaggio 
    ON mov_transazioni(transazione_viaggio_id) 
    WHERE transazione_viaggio_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transazioni_data_viaggio 
    ON mov_transazioni(transazione_data_viaggio_id) 
    WHERE transazione_data_viaggio_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transazioni_fornitore 
    ON mov_transazioni(transazione_fornitore_id);

CREATE INDEX IF NOT EXISTS idx_transazioni_data 
    ON mov_transazioni(transazione_data);

CREATE INDEX IF NOT EXISTS idx_transazioni_stato 
    ON mov_transazioni(transazione_stato) 
    WHERE transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO');

CREATE INDEX IF NOT EXISTS idx_transazioni_tipo 
    ON mov_transazioni(transazione_tipo_movimento);

-- Indice per transazioni generali (non legate a viaggi)
CREATE INDEX IF NOT EXISTS idx_transazioni_generali 
    ON mov_transazioni(transazione_azienda_id, transazione_data) 
    WHERE transazione_viaggio_id IS NULL;

-- Indice composto per report per viaggio
CREATE INDEX IF NOT EXISTS idx_transazioni_viaggio_data 
    ON mov_transazioni(transazione_viaggio_id, transazione_data) 
    WHERE transazione_viaggio_id IS NOT NULL;

-- Indice per scadenze
CREATE INDEX IF NOT EXISTS idx_transazioni_scadenze 
    ON mov_transazioni(transazione_data_scadenza) 
    WHERE transazione_stato = 'DA_PAGARE' AND transazione_data_scadenza IS NOT NULL;

-- =============================================
-- Commenti
-- =============================================
COMMENT ON TABLE mov_transazioni IS 'Tabella movimenti finanziari (entrate/uscite). Gestisce sia spese generali che spese specifiche di viaggio.';
COMMENT ON COLUMN mov_transazioni.transazione_importo_eur IS 'Importo convertito automaticamente in Valuta Base (EUR) dal trigger trg_calcola_importo_eur.';
