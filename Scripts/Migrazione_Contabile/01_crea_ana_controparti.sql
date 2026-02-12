-- =====================================================
-- Script: 01_crea_ana_controparti.sql
-- Descrizione: Creazione tabella ana_controparti
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Creazione tabella ana_controparti
CREATE TABLE IF NOT EXISTS public.ana_controparti (
    controparte_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL,

    -- Anagrafica base
    ragione_sociale VARCHAR(100) NOT NULL,
    nome_breve VARCHAR(50),

    -- NUOVI FLAG FONDAMENTALI
    is_fornitore BOOLEAN NOT NULL DEFAULT FALSE,
    is_cliente BOOLEAN NOT NULL DEFAULT FALSE,

    -- Dati fiscali
    partita_iva VARCHAR(20),
    codice_fiscale VARCHAR(16),
    codice_destinatario_sdi VARCHAR(7),

    -- Contatti
    indirizzo VARCHAR(100),
    comune_fk INTEGER,
    telefono_prefisso VARCHAR(5),
    telefono_numero VARCHAR(20),
    email VARCHAR(100),
    pec VARCHAR(100),
    sito_web VARCHAR(100),

    -- Classificazione
    tipo_fornitore_fk INTEGER,
    fornitore_estero BOOLEAN DEFAULT FALSE,

    -- Operatività
    attivo BOOLEAN DEFAULT TRUE,
    priorita SMALLINT DEFAULT 5,
    note TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50),

    -- Constraint: almeno un ruolo deve essere attivo
    CONSTRAINT chk_almeno_un_ruolo CHECK (is_fornitore = TRUE OR is_cliente = TRUE),

    -- Foreign keys
    CONSTRAINT fk_controparti_azienda FOREIGN KEY (azienda_fk) REFERENCES ana_aziende(azienda_id),
    CONSTRAINT fk_controparti_comune FOREIGN KEY (comune_fk) REFERENCES ana_geo_comuni(comune_id),
    CONSTRAINT fk_controparti_tipo_fornitore FOREIGN KEY (tipo_fornitore_fk) REFERENCES ana_tipo_fornitore(tipo_fornitore_id)
);

-- Step 2: Creazione indici per performance
CREATE INDEX IF NOT EXISTS idx_controparti_azienda ON ana_controparti(azienda_fk);
CREATE INDEX IF NOT EXISTS idx_controparti_fornitori ON ana_controparti(azienda_fk, is_fornitore)
    WHERE is_fornitore = TRUE;
CREATE INDEX IF NOT EXISTS idx_controparti_clienti ON ana_controparti(azienda_fk, is_cliente)
    WHERE is_cliente = TRUE;
CREATE INDEX IF NOT EXISTS idx_controparti_attivi ON ana_controparti(attivo)
    WHERE attivo = TRUE;
CREATE INDEX IF NOT EXISTS idx_controparti_ragione_sociale ON ana_controparti(ragione_sociale);

-- Step 3: Creazione trigger per updated_at
CREATE TRIGGER trg_touch_updated_at_controparti
BEFORE UPDATE ON ana_controparti
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_simple();

-- Step 4: Commenti per documentazione
COMMENT ON TABLE ana_controparti IS 'Anagrafica controparti (fornitori e clienti). Un record può essere sia fornitore che cliente contemporaneamente.';
COMMENT ON COLUMN ana_controparti.is_fornitore IS 'TRUE se la controparte è un fornitore';
COMMENT ON COLUMN ana_controparti.is_cliente IS 'TRUE se la controparte è un cliente';
COMMENT ON COLUMN ana_controparti.tipo_fornitore_fk IS 'Tipo fornitore (es: Hotel, Trasporto, Guide, ecc.) - valido solo se is_fornitore=TRUE';
COMMENT ON COLUMN ana_controparti.fornitore_estero IS 'TRUE se la controparte è estera (fuori UE)';

-- Verifica creazione
SELECT 'Tabella ana_controparti creata con successo!' as risultato;
