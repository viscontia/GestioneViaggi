-- =============================================
-- Tabella Tassi di Cambio (Storicizzati)
-- Data Creazione: 2026-01-29
-- Autore: Antigravity
-- =============================================

CREATE TABLE IF NOT EXISTS ana_tassi_cambio (
    tasso_id SERIAL PRIMARY KEY,
    
    -- Valuta di origine (es. ZAR)
    tasso_valuta_da_fk INTEGER NOT NULL,
    
    -- Valuta di destinazione (es. EUR)
    tasso_valuta_a_fk INTEGER NOT NULL,
    
    -- Data di validità del tasso (es. data fattura)
    tasso_data_validita DATE NOT NULL,
    
    -- Tasso di cambio (quanto vale 1 unità di valuta_da in valuta_a)
    -- Es: 1 ZAR = 0.050 EUR → tasso = 0.050
    tasso_valore NUMERIC(15,6) NOT NULL CHECK (tasso_valore > 0),
    
    -- Fonte del tasso (manuale, BCE, API, ecc.)
    tasso_fonte VARCHAR(50) DEFAULT 'MANUALE',
    
    -- Note opzionali
    tasso_note TEXT,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    
    -- Foreign Keys
    CONSTRAINT fk_tasso_valuta_da FOREIGN KEY (tasso_valuta_da_fk) 
        REFERENCES ana_valute(valuta_id) ON DELETE RESTRICT,
        
    CONSTRAINT fk_tasso_valuta_a FOREIGN KEY (tasso_valuta_a_fk) 
        REFERENCES ana_valute(valuta_id) ON DELETE RESTRICT,
    
    -- Constraints
    -- Un solo tasso per coppia valute per data
    CONSTRAINT uk_tasso_coppia_data UNIQUE (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita),
    
    -- Non ha senso convertire una valuta in se stessa
    CONSTRAINT chk_valute_diverse CHECK (tasso_valuta_da_fk != tasso_valuta_a_fk)
);

-- Index sulle FK per performance nelle join
CREATE INDEX IF NOT EXISTS idx_tasso_valuta_da ON ana_tassi_cambio(tasso_valuta_da_fk);
CREATE INDEX IF NOT EXISTS idx_tasso_valuta_a ON ana_tassi_cambio(tasso_valuta_a_fk);
CREATE INDEX IF NOT EXISTS idx_tasso_data ON ana_tassi_cambio(tasso_data_validita);

-- =============================================
-- Trigger per aggiornamento automatico updated_at
-- =============================================
DROP TRIGGER IF EXISTS trg_update_ana_tassi_cambio_modtime ON ana_tassi_cambio;

CREATE TRIGGER trg_update_ana_tassi_cambio_modtime
BEFORE UPDATE ON ana_tassi_cambio
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_simple();

-- =============================================
-- Commenti e Documentazione
-- =============================================
COMMENT ON TABLE ana_tassi_cambio IS 'Tabella storica dei tassi di cambio. Ogni record rappresenta il valore di conversione tra due valute in una specifica data.';
COMMENT ON COLUMN ana_tassi_cambio.tasso_id IS 'Identificativo univoco auto-incrementale';
COMMENT ON COLUMN ana_tassi_cambio.tasso_valuta_da_fk IS 'FK alla valuta di origine (cosa sto convertendo)';
COMMENT ON COLUMN ana_tassi_cambio.tasso_valuta_a_fk IS 'FK alla valuta di destinazione (in cosa lo sto convertendo)';
COMMENT ON COLUMN ana_tassi_cambio.tasso_data_validita IS 'Data di validità del tasso (senza orario)';
COMMENT ON COLUMN ana_tassi_cambio.tasso_valore IS 'Fattore di conversione: 1 Unità DA = X Unità A';
COMMENT ON COLUMN ana_tassi_cambio.tasso_fonte IS 'Origine del dato (Manuale, Import, BCE, ecc)';
COMMENT ON COLUMN ana_tassi_cambio.tasso_note IS 'Note libere';

-- =============================================
-- Function: fn_get_tasso_cambio (Core - Integers)
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_tasso_cambio(
    p_valuta_da INTEGER,
    p_valuta_a INTEGER,
    p_data DATE
) RETURNS NUMERIC(15,6) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_tasso NUMERIC(15,6);
BEGIN
    -- Se stessa valuta, ritorna 1
    IF p_valuta_da = p_valuta_a THEN
        RETURN 1.0;
    END IF;
    
    -- Cerca il tasso più recente disponibile <= data richiesta
    SELECT tasso_valore INTO v_tasso
    FROM ana_tassi_cambio
    WHERE tasso_valuta_da_fk = p_valuta_da
      AND tasso_valuta_a_fk = p_valuta_a
      AND tasso_data_validita <= p_data
    ORDER BY tasso_data_validita DESC
    LIMIT 1;
    
    -- Se non trovato, prova il tasso inverso
    IF v_tasso IS NULL THEN
        SELECT (1.0 / tasso_valore) INTO v_tasso
        FROM ana_tassi_cambio
        WHERE tasso_valuta_da_fk = p_valuta_a -- Invertito da/a
          AND tasso_valuta_a_fk = p_valuta_da -- Invertito da/a
          AND tasso_data_validita <= p_data
        ORDER BY tasso_data_validita DESC
        LIMIT 1;
    END IF;
    
    -- Se ancora NULL, ritorniamo NULL (lasciamo gestire l'errore al chiamante o logica superiore)
    -- L'utente suggeriva RAISE EXCEPTION, ma per query massive è meglio NULL.
    -- Possiamo discutere se reintrodurre RAISE EXCEPTION.
    
    RETURN v_tasso;
END;
$$;

-- =============================================
-- Function: fn_get_tasso_cambio (Wrapper - ISO Codes)
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_tasso_cambio(
    p_iso_da VARCHAR(3), 
    p_iso_a VARCHAR(3), 
    p_data DATE
)
RETURNS NUMERIC(15,6)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_da INTEGER;
    v_id_a INTEGER;
BEGIN
    -- Recupera ID valuta DA
    SELECT valuta_id INTO v_id_da FROM ana_valute WHERE valuta_codice_iso = UPPER(p_iso_da);
    
    -- Recupera ID valuta A
    SELECT valuta_id INTO v_id_a FROM ana_valute WHERE valuta_codice_iso = UPPER(p_iso_a);
    
    -- Se una delle valute non esiste, ritorna NULL
    IF v_id_da IS NULL OR v_id_a IS NULL THEN
        RETURN NULL;
    END IF;

    -- Chiama la funzione core
    RETURN fn_get_tasso_cambio(v_id_da, v_id_a, p_data);
END;
$$;

COMMENT ON FUNCTION fn_get_tasso_cambio(INTEGER, INTEGER, DATE) IS 'Restituisce il tasso di cambio più recente (<= data) calcolando anche l''inverso. Core function.';
COMMENT ON FUNCTION fn_get_tasso_cambio(VARCHAR, VARCHAR, DATE) IS 'Wrapper che accetta codici ISO e invoca la core function.';
