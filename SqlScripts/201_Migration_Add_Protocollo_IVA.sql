-- ============================================================================
-- Migration: Aggiunge colonna protocollo IVA a mov_transazioni
-- Il protocollo e' un numero progressivo annuale per azienda+ciclo,
-- assegnato automaticamente alle transazioni IVA qualificanti.
-- ============================================================================

-- Aggiunge la colonna (nullable: NULL = transazione non IVA o non ancora protocollata)
ALTER TABLE mov_transazioni
ADD COLUMN IF NOT EXISTS transazione_numero_protocollo_iva INTEGER;

COMMENT ON COLUMN mov_transazioni.transazione_numero_protocollo_iva IS
    'Numero protocollo IVA (progressivo annuale per azienda+ciclo). Assegnato solo a transazioni IVA qualificanti (causale_genera_iva=TRUE, EUR, stato!=ANNULLATO). Una volta assegnato, non viene mai riutilizzato.';

-- Indice parziale: solo le transazioni con protocollo assegnato
CREATE INDEX IF NOT EXISTS idx_transazioni_protocollo_iva
    ON mov_transazioni(transazione_azienda_id, transazione_numero_protocollo_iva)
    WHERE transazione_numero_protocollo_iva IS NOT NULL;
