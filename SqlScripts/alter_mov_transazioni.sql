-- ============================================================================
-- Migrazione mov_transazioni verso ana_tipi_causali
-- ============================================================================

-- 1. Aggiunta colonna FK (inizialmente nullable per permettere la migrazione)
ALTER TABLE mov_transazioni ADD COLUMN transazione_causale_tipo_id INTEGER;

-- 2. Migrazione Dati (Logica Basata su tipo_movimento e prefisso NC)
-- Nota: Usiamo i codici inseriti precedentemente per l'azienda 6.
-- Se ci sono altre aziende, lo script andrebbe esteso.

-- 2a. Pagamenti (USCITA) -> PG
UPDATE mov_transazioni t
SET transazione_causale_tipo_id = c.causale_id
FROM ana_tipi_causali c
WHERE t.transazione_azienda_id = c.azienda_fk
AND c.causale_codice = 'PG'
AND t.transazione_tipo_movimento = 'USCITA';

-- 2b. Note di Credito (ENTRATA e prefisso NC/) -> NC
UPDATE mov_transazioni t
SET transazione_causale_tipo_id = c.causale_id
FROM ana_tipi_causali c
WHERE t.transazione_azienda_id = c.azienda_fk
AND c.causale_codice = 'NC'
AND t.transazione_tipo_movimento = 'ENTRATA'
AND t.transazione_numero_documento ILIKE 'NC%';

-- 2c. Fatture (ENTRATA e NO prefisso NC/) -> FT
UPDATE mov_transazioni t
SET transazione_causale_tipo_id = c.causale_id
FROM ana_tipi_causali c
WHERE t.transazione_azienda_id = c.azienda_fk
AND c.causale_codice = 'FT'
AND t.transazione_tipo_movimento = 'ENTRATA'
AND transazione_causale_tipo_id IS NULL; -- Copre il rimanente (Fatture e Note di Debito)

-- 3. Vincoli e Pulizia
-- Impostiamo NOT NULL dopo la migrazione
ALTER TABLE mov_transazioni ALTER COLUMN transazione_causale_tipo_id SET NOT NULL;

-- Aggiunta FK
ALTER TABLE mov_transazioni 
    ADD CONSTRAINT fk_transazione_causale_tipo 
    FOREIGN KEY (transazione_causale_tipo_id) 
    REFERENCES ana_tipi_causali(causale_id);

-- Indice per performance
CREATE INDEX IF NOT EXISTS idx_transazioni_causale_tipo ON mov_transazioni(transazione_causale_tipo_id);

-- 4. Rimozione vecchio campo (Commentata: La faremo DOPO aver aggiornato le function)
-- ALTER TABLE mov_transazioni DROP COLUMN transazione_tipo_movimento;

-- Commento
COMMENT ON COLUMN mov_transazioni.transazione_causale_tipo_id IS 'FK verso ana_tipi_causali (Fattura, Pagamento, NC, ecc.)';
