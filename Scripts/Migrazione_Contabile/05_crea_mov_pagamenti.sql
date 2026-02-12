-- =====================================================
-- Script: 05_crea_mov_pagamenti.sql
-- Descrizione: Creazione tabella mov_pagamenti e trigger automatico
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Creazione tabella mov_pagamenti
CREATE TABLE IF NOT EXISTS public.mov_pagamenti (
    pagamento_id SERIAL PRIMARY KEY,
    transazione_fk INTEGER NOT NULL REFERENCES mov_transazioni(transazione_id) ON DELETE CASCADE,

    -- Dati pagamento
    pagamento_data DATE NOT NULL,
    pagamento_importo_eur NUMERIC(10,2) NOT NULL CHECK (pagamento_importo_eur > 0),
    pagamento_metodo VARCHAR(50), -- Bonifico, Assegno, Contanti, RiBa, Carta, ecc.
    pagamento_note TEXT,

    -- Riferimenti bancari (opzionali)
    pagamento_conto_bancario_fk INTEGER, -- FK verso eventuale tabella conti bancari (futura)
    pagamento_riferimento VARCHAR(100), -- Numero assegno, CRO, TRN, ecc.

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50)
);

-- Step 2: Creazione indici
CREATE INDEX IF NOT EXISTS idx_pagamenti_transazione ON mov_pagamenti(transazione_fk);
CREATE INDEX IF NOT EXISTS idx_pagamenti_data ON mov_pagamenti(pagamento_data);
CREATE INDEX IF NOT EXISTS idx_pagamenti_metodo ON mov_pagamenti(pagamento_metodo);

-- Step 3: Trigger per updated_at
CREATE TRIGGER trg_touch_updated_at_pagamenti
BEFORE UPDATE ON mov_pagamenti
FOR EACH ROW
EXECUTE FUNCTION fn_touch_updated_at_simple();

-- Step 4: Creazione funzione trigger per aggiornamento automatico stato transazione
CREATE OR REPLACE FUNCTION fn_aggiorna_stato_transazione()
RETURNS TRIGGER AS $$
DECLARE
    v_transazione_id INTEGER;
    v_totale_documento NUMERIC(10,2);
    v_totale_pagato NUMERIC(10,2);
    v_causale_segno INTEGER;
BEGIN
    -- Determina l'ID della transazione (gestisce INSERT, UPDATE, DELETE)
    IF TG_OP = 'DELETE' THEN
        v_transazione_id := OLD.transazione_fk;
    ELSE
        v_transazione_id := NEW.transazione_fk;
    END IF;

    -- Recupera totale documento e causale_segno
    SELECT
        t.transazione_importo_eur,
        ca.causale_segno
    INTO v_totale_documento, v_causale_segno
    FROM mov_transazioni t
    JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
    WHERE t.transazione_id = v_transazione_id;

    -- Calcola totale pagato
    SELECT COALESCE(SUM(pagamento_importo_eur), 0)
    INTO v_totale_pagato
    FROM mov_pagamenti
    WHERE transazione_fk = v_transazione_id;

    -- Aggiorna stato in base a totale pagato
    UPDATE mov_transazioni
    SET
        transazione_stato = CASE
            WHEN v_totale_pagato = 0 THEN 'DA_PAGARE'
            WHEN v_totale_pagato >= ABS(v_totale_documento * v_causale_segno) THEN 'PAGATO'
            ELSE 'PARZIALMENTE_PAGATO'
        END,
        transazione_data_pagamento = CASE
            WHEN v_totale_pagato >= ABS(v_totale_documento * v_causale_segno)
            THEN (SELECT MAX(pagamento_data) FROM mov_pagamenti WHERE transazione_fk = v_transazione_id)
            ELSE NULL
        END
    WHERE transazione_id = v_transazione_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 5: Creazione trigger su mov_pagamenti
DROP TRIGGER IF EXISTS trg_aggiorna_stato_dopo_pagamento ON mov_pagamenti;

CREATE TRIGGER trg_aggiorna_stato_dopo_pagamento
AFTER INSERT OR UPDATE OR DELETE ON mov_pagamenti
FOR EACH ROW
EXECUTE FUNCTION fn_aggiorna_stato_transazione();

-- Step 6: Commenti per documentazione
COMMENT ON TABLE mov_pagamenti IS 'Tracciamento pagamenti parziali/totali per transazioni. Aggiorna automaticamente lo stato della transazione.';
COMMENT ON COLUMN mov_pagamenti.pagamento_importo_eur IS 'Importo del pagamento in EUR (sempre positivo)';
COMMENT ON COLUMN mov_pagamenti.pagamento_metodo IS 'Metodo di pagamento: Bonifico, Assegno, Contanti, RiBa, Carta, ecc.';
COMMENT ON COLUMN mov_pagamenti.pagamento_riferimento IS 'Riferimento bancario: numero assegno, CRO, TRN, codice operazione, ecc.';

-- Step 7: Verifica creazione
SELECT 'Tabella mov_pagamenti e trigger creati con successo!' as risultato;
