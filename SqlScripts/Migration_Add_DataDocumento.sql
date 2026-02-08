-- Migration: Add transazione_data_documento field to mov_transazioni
-- Date: 2026-02-07
-- Description: Adds a new field for document date with validation constraints

-- Step 1: Add the new column
ALTER TABLE mov_transazioni ADD COLUMN transazione_data_documento date;

-- Step 2: Update existing records with numero_documento to have data_documento = data_transazione
UPDATE mov_transazioni
SET transazione_data_documento = transazione_data
WHERE transazione_numero_documento IS NOT NULL
AND transazione_data_documento IS NULL;

-- Step 3: Add validation constraints
-- Constraint: se c'è numero documento deve esserci anche data documento e viceversa
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_documento_completo
CHECK (
    (transazione_numero_documento IS NULL AND transazione_data_documento IS NULL) OR
    (transazione_numero_documento IS NOT NULL AND transazione_data_documento IS NOT NULL)
);

-- Constraint: data scadenza >= data documento (se entrambi presenti)
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_scadenza_dopo_documento
CHECK (
    transazione_data_documento IS NULL OR
    transazione_data_scadenza IS NULL OR
    transazione_data_scadenza >= transazione_data_documento
);

-- Constraint: data pagamento >= data documento (se entrambi presenti)
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_pagamento_dopo_documento
CHECK (
    transazione_data_documento IS NULL OR
    transazione_data_pagamento IS NULL OR
    transazione_data_pagamento >= transazione_data_documento
);

-- Constraint: data pagamento >= data scadenza (se entrambi presenti)
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_pagamento_dopo_scadenza
CHECK (
    transazione_data_scadenza IS NULL OR
    transazione_data_pagamento IS NULL OR
    transazione_data_pagamento >= transazione_data_scadenza
);

-- Step 4: Update SQL functions to include the new field
-- Execute Create_Fn_Get_Transazioni.sql after dropping the existing functions:
-- DROP FUNCTION IF EXISTS fn_get_all_transazioni(integer, integer, date, boolean);
-- DROP FUNCTION IF EXISTS fn_get_transazioni_by_azienda(integer, integer, integer, date, boolean);
-- Then execute: Create_Fn_Get_Transazioni.sql
