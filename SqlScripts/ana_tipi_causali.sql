-- ============================================================================
-- Creazione Tabella ana_tipi_causali
-- ============================================================================

CREATE TABLE IF NOT EXISTS ana_tipi_causali (
    causale_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL REFERENCES ana_aziende(azienda_id),
    causale_codice VARCHAR(10) NOT NULL,
    causale_descrizione VARCHAR(100) NOT NULL,
    causale_segno INTEGER NOT NULL DEFAULT 1, -- +1 (Debito/Aumento), -1 (Credito/Diminuzione)
    causale_is_documento BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),

    -- Vincoli
    CONSTRAINT uk_causale_azienda_codice UNIQUE (azienda_fk, causale_codice),
    CONSTRAINT chk_causale_segno CHECK (causale_segno IN (1, -1))
);

-- Indici
CREATE INDEX IF NOT EXISTS idx_causale_azienda ON ana_tipi_causali(azienda_fk);
CREATE INDEX IF NOT EXISTS idx_causale_attive ON ana_tipi_causali(azienda_fk) WHERE is_active = TRUE;

-- Commenti
COMMENT ON TABLE ana_tipi_causali IS 'Tabella magister per le causali contabili (Fatture, NC, Pagamenti).';
COMMENT ON COLUMN ana_tipi_causali.causale_segno IS 'Segno algebrico: +1 aumenta il debito verso fornitore, -1 lo diminuisce.';

-- Trigger per updated_at
CREATE TRIGGER trg_touch_updated_at_causali 
    BEFORE UPDATE ON ana_tipi_causali 
    FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at_simple();

-- Inserimento dati base per le aziende esistenti (Se opportuno)
-- Nota: In un sistema reale questo andrebbe fatto per ogni azienda.
-- Per ora inseriamo i tipi standard per l'azienda di test (Id=6)
INSERT INTO ana_tipi_causali (azienda_fk, causale_codice, causale_descrizione, causale_segno, causale_is_documento, created_by)
VALUES 
(6, 'FT', 'Fattura passiva', 1, TRUE, 'system'),
(6, 'NC', 'Nota di Credito', -1, TRUE, 'system'),
(6, 'PG', 'Pagamento / Acconto', -1, FALSE, 'system'),
(6, 'ND', 'Nota di Debito / Penale', 1, TRUE, 'system')
ON CONFLICT DO NOTHING;
