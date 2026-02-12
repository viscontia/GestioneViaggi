-- =====================================================
-- Script: 06_rinomina_fornitore_a_controparte.sql
-- Descrizione: Rinomina transazione_fornitore_id → transazione_controparte_id
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Verifica stato iniziale
SELECT 'Transazioni esistenti: ' || COUNT(*)::text as info FROM mov_transazioni;

-- Step 2: Drop constraint FK esistente
ALTER TABLE public.mov_transazioni
DROP CONSTRAINT IF EXISTS fk_transazioni_fornitore;

-- Step 3: Rinomina colonna
ALTER TABLE public.mov_transazioni
RENAME COLUMN transazione_fornitore_id TO transazione_controparte_id;

-- Step 4: Rinomina indice (se esiste)
ALTER INDEX IF EXISTS idx_transazioni_fornitore
RENAME TO idx_transazioni_controparte;

-- Step 5: Crea nuova constraint FK verso ana_controparti
ALTER TABLE public.mov_transazioni
ADD CONSTRAINT fk_transazioni_controparte
FOREIGN KEY (transazione_controparte_id)
REFERENCES ana_controparti(controparte_id);

-- Step 6: Aggiorna commento colonna
COMMENT ON COLUMN mov_transazioni.transazione_controparte_id IS 'FK verso ana_controparti (fornitore o cliente a seconda del causale_ciclo)';

-- Step 7: Verifica integrità referenziale
SELECT 'Transazioni con controparte valida: ' || COUNT(*)::text as info
FROM mov_transazioni t
JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id;

SELECT 'Transazioni orfane (ERRORE se > 0): ' || COUNT(*)::text as info
FROM mov_transazioni t
LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
WHERE c.controparte_id IS NULL;

SELECT 'Rinomina completata con successo!' as risultato;
