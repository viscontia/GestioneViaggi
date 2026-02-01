-- =============================================
-- DROP EXISTING OBJECTS (Reverse Order)
-- =============================================
DROP TABLE IF EXISTS ana_fornitori CASCADE;
DROP TABLE IF EXISTS ana_tipo_fornitore CASCADE;

-- =============================================
-- 1. Tabella Lookup: ana_tipo_fornitore
-- =============================================
CREATE TABLE IF NOT EXISTS ana_tipo_fornitore (
    tipo_fornitore_id SERIAL PRIMARY KEY,
    
    -- Multi-tenant: azienda_fk NULL = Sistema (Globale), NOT NULL = Custom Azienda
    azienda_fk INTEGER CONSTRAINT fk_tipo_fornitore_azienda REFERENCES ana_aziende(azienda_id),
    
    descrizione VARCHAR(50) NOT NULL,
    categoria VARCHAR(20) CHECK (categoria IN ('COSTO', 'RICAVO', 'MISTO')), 
    conto_contabile_default VARCHAR(20),
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Indice Unico per Azienda (Filtra i duplicati per azienda, permette duplicati globali se necessario o gestisce scope)
-- Se azienda_fk è NULL, descrizione deve essere unica tra i NULL.
CREATE UNIQUE INDEX idx_uniq_tipo_fornitore_sys ON ana_tipo_fornitore(descrizione) WHERE azienda_fk IS NULL;
CREATE UNIQUE INDEX idx_uniq_tipo_fornitore_az ON ana_tipo_fornitore(azienda_fk, descrizione) WHERE azienda_fk IS NOT NULL;


-- Esempi di tipi fornitore (SYSTEM - Globali)
INSERT INTO ana_tipo_fornitore (descrizione, categoria, azienda_fk) VALUES
('ALBERGO', 'COSTO', NULL),
('RISTORANTE', 'COSTO', NULL),
('MECCANICO/OFFICINA', 'COSTO', NULL),
('CARBURANTE', 'COSTO', NULL),
('GUIDE TURISTICHE', 'COSTO', NULL),
('NOLEGGIO ATTREZZATURA', 'COSTO', NULL),
('ASSICURAZIONI', 'COSTO', NULL),
('CLIENTE VIAGGIO', 'RICAVO', NULL),
('SPONSOR', 'RICAVO', NULL),
('FORNITORE GENERICO', 'MISTO', NULL)
ON CONFLICT DO NOTHING;

-- =============================================
-- 2. Tabella ana_fornitori
-- =============================================
CREATE TABLE IF NOT EXISTS ana_fornitori (
    fornitore_id SERIAL PRIMARY KEY,
    
    -- PK Logica per Partizionamento (Spesso richiesta in Enterprise)
    -- Ma per ora manteniamo Serial PK e usiamo azienda_fk come colonna fondamentale
    azienda_fk INTEGER NOT NULL CONSTRAINT fk_fornitori_azienda 
        REFERENCES ana_aziende(azienda_id),
    
    -- Dati anagrafici
    ragione_sociale VARCHAR(100) NOT NULL,
    nome_breve VARCHAR(50), 
    indirizzo VARCHAR(100),
    
    -- Geografia
    comune_fk INTEGER CONSTRAINT fk_fornitori_comune 
        REFERENCES ana_geo_comuni(comune_id),
    
    -- Contatti
    telefono_prefisso VARCHAR(5),
    telefono_numero VARCHAR(20),
    email VARCHAR(100),
    pec VARCHAR(100),
    sito_web VARCHAR(100),
    
    -- Fiscali
    codice_destinatario_sdi VARCHAR(7),
    partita_iva VARCHAR(11),
    codice_fiscale VARCHAR(16),
    
    -- TIPO FORNITORE
    tipo_fornitore_fk INTEGER NOT NULL 
        CONSTRAINT fk_fornitori_tipo 
        REFERENCES ana_tipo_fornitore(tipo_fornitore_id),
    
    -- Campi operativi
    attivo BOOLEAN DEFAULT TRUE, 
    priorita SMALLINT DEFAULT 5 CHECK (priorita BETWEEN 1 AND 10), 
    note TEXT,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    
    -- Indice per performance e Unicità Fiscale per Azienda
    CONSTRAINT uk_fornitori_piva_cf UNIQUE (azienda_fk, partita_iva, codice_fiscale)
);

-- =============================================
-- 3. Trigger per updated_at
-- =============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger 
                   WHERE tgname = 'trg_touch_updated_at_fornitori') THEN
        CREATE TRIGGER trg_touch_updated_at_fornitori
        BEFORE UPDATE ON ana_fornitori
        FOR EACH ROW
        EXECUTE FUNCTION fn_touch_updated_at();
    END IF;
END $$;

-- =============================================
-- 4. Indici per performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_fornitori_tipo 
    ON ana_fornitori(tipo_fornitore_fk);
CREATE INDEX IF NOT EXISTS idx_fornitori_azienda 
    ON ana_fornitori(azienda_fk);
CREATE INDEX IF NOT EXISTS idx_fornitori_comune 
    ON ana_fornitori(comune_fk);
CREATE INDEX IF NOT EXISTS idx_fornitori_attivo 
    ON ana_fornitori(attivo) WHERE attivo = TRUE;
