-- =====================================================
-- Fix ana_aziende: Aggiunge NOT NULL e DEFAULT ai campi obbligatori
-- =====================================================
-- Data: 2025-12-26
-- Descrizione: Corregge i campi socio_unico, in_liquidazione e codice_destinatario_sdi
--              che dovevano essere NOT NULL ma erano nullable
-- =====================================================

BEGIN;

-- 1. Imposta i valori di default per i record esistenti con valori NULL
UPDATE ana_aziende
SET socio_unico = FALSE
WHERE socio_unico IS NULL;

UPDATE ana_aziende
SET in_liquidazione = FALSE
WHERE in_liquidazione IS NULL;

UPDATE ana_aziende
SET codice_destinatario_sdi = '0000000'
WHERE codice_destinatario_sdi IS NULL;

-- 2. Aggiungi i constraint NOT NULL
ALTER TABLE ana_aziende
ALTER COLUMN socio_unico SET NOT NULL,
ALTER COLUMN socio_unico SET DEFAULT FALSE;

ALTER TABLE ana_aziende
ALTER COLUMN in_liquidazione SET NOT NULL,
ALTER COLUMN in_liquidazione SET DEFAULT FALSE;

ALTER TABLE ana_aziende
ALTER COLUMN codice_destinatario_sdi SET NOT NULL,
ALTER COLUMN codice_destinatario_sdi SET DEFAULT '0000000';

-- 3. Verifica finale
SELECT
    column_name,
    is_nullable,
    column_default,
    data_type
FROM information_schema.columns
WHERE table_name = 'ana_aziende'
  AND column_name IN ('socio_unico', 'in_liquidazione', 'codice_destinatario_sdi')
ORDER BY column_name;

COMMIT;

-- =====================================================
-- Output atteso:
--       column_name       | is_nullable | column_default | data_type
-- ------------------------+-------------+----------------+-----------
--  codice_destinatario_sdi| NO          | '0000000'      | varchar
--  in_liquidazione        | NO          | false          | boolean
--  socio_unico            | NO          | false          | boolean
-- =====================================================
