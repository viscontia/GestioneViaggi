-- =====================================================
-- Script: 03_aggiungi_causale_ciclo.sql
-- Descrizione: Aggiunta colonna causale_ciclo a ana_tipi_causali
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Verifica stato iniziale
SELECT 'Causali esistenti: ' || COUNT(*)::text as info FROM ana_tipi_causali;

-- Step 2: Aggiungi colonna causale_ciclo (nullable per ora)
ALTER TABLE public.ana_tipi_causali
ADD COLUMN IF NOT EXISTS causale_ciclo VARCHAR(10);

-- Step 3: Imposta tutte le causali esistenti come PASSIVO
-- Tutte le causali attuali sono per il ciclo fornitori (passivo)
UPDATE public.ana_tipi_causali
SET causale_ciclo = 'PASSIVO'
WHERE causale_ciclo IS NULL;

-- Step 4: Rendi la colonna NOT NULL e aggiungi constraint
ALTER TABLE public.ana_tipi_causali
ALTER COLUMN causale_ciclo SET NOT NULL;

ALTER TABLE public.ana_tipi_causali
ADD CONSTRAINT chk_causale_ciclo
CHECK (causale_ciclo IN ('ATTIVO', 'PASSIVO'));

-- Step 5: Crea indice per performance
CREATE INDEX IF NOT EXISTS idx_causali_ciclo ON ana_tipi_causali(causale_ciclo);

-- Step 6: Aggiungi commento per documentazione
COMMENT ON COLUMN ana_tipi_causali.causale_ciclo IS 'Ciclo contabile: ATTIVO (clienti - fatture emesse/incassi) o PASSIVO (fornitori - fatture ricevute/pagamenti)';

-- Step 7: Verifica risultato
SELECT
    causale_ciclo,
    COUNT(*) as numero_causali,
    STRING_AGG(causale_codice, ', ' ORDER BY causale_codice) as causali
FROM ana_tipi_causali
GROUP BY causale_ciclo
ORDER BY causale_ciclo;

SELECT 'Colonna causale_ciclo aggiunta con successo!' as risultato;
