-- ============================================================
-- 240: Aggiunte schema per esportazione XML FatturaPA SDI
-- - Aggiunge colonne SDI a ana_regimi_fiscali e ana_tipi_causali
-- - Crea tabella e funzione per progressivo invio FatturaPA
-- Data: 2026-03-07
-- ============================================================

BEGIN;

-- ============================================================
-- 1. ana_regimi_fiscali: codice regime SDI + tipo cassa SDI
-- ============================================================

ALTER TABLE ana_regimi_fiscali
ADD COLUMN IF NOT EXISTS regime_codice_sdi VARCHAR(4);

ALTER TABLE ana_regimi_fiscali
ADD COLUMN IF NOT EXISTS tipo_cassa_sdi VARCHAR(4);

COMMENT ON COLUMN ana_regimi_fiscali.regime_codice_sdi
    IS 'Codice Regime Fiscale per FatturaPA: RF01=Ordinario, RF19=Forfettario, RF02=Semplificato';
COMMENT ON COLUMN ana_regimi_fiscali.tipo_cassa_sdi
    IS 'Codice Tipo Cassa Previdenziale per FatturaPA: TC22=INPS Gestione Separata';

UPDATE ana_regimi_fiscali
SET regime_codice_sdi = 'RF01'
WHERE regime_codice = 'ORDINARIO';

UPDATE ana_regimi_fiscali
SET regime_codice_sdi = 'RF19',
    tipo_cassa_sdi = 'TC22'
WHERE regime_codice = 'FORFETTARIO';

UPDATE ana_regimi_fiscali
SET regime_codice_sdi = 'RF02'
WHERE regime_codice = 'SEMPLIFICATO';

-- ============================================================
-- 2. ana_tipi_causali: tipo documento SDI
-- ============================================================

ALTER TABLE ana_tipi_causali
ADD COLUMN IF NOT EXISTS tipo_documento_sdi VARCHAR(4);

COMMENT ON COLUMN ana_tipi_causali.tipo_documento_sdi
    IS 'Tipo Documento per FatturaPA: TD01=Fattura, TD04=Nota Credito, TD05=Nota Debito';

-- Fatture attive (TD01)
UPDATE ana_tipi_causali
SET tipo_documento_sdi = 'TD01'
WHERE causale_ciclo = 'ATTIVO'
  AND causale_codice IN ('FTA', 'FV')
  AND tipo_documento_sdi IS NULL;

-- Note di credito attive (TD04)
UPDATE ana_tipi_causali
SET tipo_documento_sdi = 'TD04'
WHERE causale_ciclo = 'ATTIVO'
  AND causale_codice = 'NCA'
  AND tipo_documento_sdi IS NULL;

-- Note di debito attive (TD05)
UPDATE ana_tipi_causali
SET tipo_documento_sdi = 'TD05'
WHERE causale_ciclo = 'ATTIVO'
  AND causale_codice IN ('NDA', 'ND')
  AND tipo_documento_sdi IS NULL;

-- ============================================================
-- 3. Tabella progressivi invio FatturaPA
-- Un contatore per azienda, incrementato atomicamente
-- ============================================================

CREATE TABLE IF NOT EXISTS ana_fatturapa_progressivi (
    progressivo_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL REFERENCES ana_aziende(azienda_id),
    ultimo_progressivo INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT uk_fatturapa_progressivo_azienda UNIQUE (azienda_fk)
);

COMMENT ON TABLE ana_fatturapa_progressivi
    IS 'Contatore progressivo invio FatturaPA per azienda. Usato per la nomenclatura file XML.';

-- ============================================================
-- 4. Funzione: Ottieni prossimo progressivo invio (UPSERT atomico)
-- Pattern identico a sp_assegna_protocollo_iva
-- ============================================================

CREATE OR REPLACE FUNCTION fn_fatturapa_get_next_progressivo(p_azienda_id INTEGER)
RETURNS VARCHAR(5)
LANGUAGE plpgsql
AS $$
DECLARE
    v_next INTEGER;
BEGIN
    INSERT INTO ana_fatturapa_progressivi (azienda_fk, ultimo_progressivo, updated_at)
    VALUES (p_azienda_id, 1, NOW())
    ON CONFLICT (azienda_fk)
    DO UPDATE SET
        ultimo_progressivo = ana_fatturapa_progressivi.ultimo_progressivo + 1,
        updated_at = NOW()
    RETURNING ultimo_progressivo INTO v_next;

    RETURN LPAD(v_next::TEXT, 5, '0');
END;
$$;

COMMENT ON FUNCTION fn_fatturapa_get_next_progressivo(INTEGER)
    IS 'Restituisce il prossimo progressivo invio FatturaPA per l''azienda (formato 5 cifre). UPSERT atomico.';

COMMIT;
