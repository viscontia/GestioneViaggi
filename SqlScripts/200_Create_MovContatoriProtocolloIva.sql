-- ============================================================================
-- mov_contatori_protocollo_iva
-- Tabella contatori per numerazione protocollo IVA.
-- Separati per azienda, anno solare e ciclo (ATTIVO/PASSIVO).
-- La numerazione riparte da 1 ogni anno per ogni combinazione azienda+ciclo.
-- ============================================================================

CREATE TABLE IF NOT EXISTS mov_contatori_protocollo_iva (
    contatore_id         SERIAL PRIMARY KEY,
    contatore_azienda_id INTEGER NOT NULL REFERENCES ana_aziende(azienda_id),
    contatore_anno       INTEGER NOT NULL,
    contatore_ciclo      VARCHAR(10) NOT NULL CHECK (contatore_ciclo IN ('PASSIVO', 'ATTIVO')),
    contatore_ultimo_numero INTEGER NOT NULL DEFAULT 0,
    updated_at           TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT uk_contatore_azienda_anno_ciclo
        UNIQUE (contatore_azienda_id, contatore_anno, contatore_ciclo)
);

COMMENT ON TABLE mov_contatori_protocollo_iva IS
    'Contatori per numerazione protocollo IVA - separati per azienda, anno solare e ciclo (ATTIVO=Vendite, PASSIVO=Acquisti)';
COMMENT ON COLUMN mov_contatori_protocollo_iva.contatore_ultimo_numero IS
    'Ultimo numero di protocollo assegnato per questa combinazione azienda/anno/ciclo';
