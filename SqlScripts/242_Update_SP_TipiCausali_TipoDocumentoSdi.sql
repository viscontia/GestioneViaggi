-- ============================================================================
-- Migration: Aggiornamento SP CRUD causali per tipo_documento_sdi
-- Data: 2026-03-07
-- Descrizione: Aggiunge il parametro p_tipo_documento_sdi alle
--              stored procedures di create e update.
-- ============================================================================

-- =============================================
-- SP CREATE - Aggiunge parametro tipo_documento_sdi
-- =============================================
CREATE OR REPLACE FUNCTION sp_ana_tipi_causali_create(
    p_azienda_fk INTEGER,
    p_causale_codice VARCHAR(10),
    p_causale_descrizione VARCHAR(100),
    p_causale_segno INTEGER,
    p_causale_is_documento BOOLEAN,
    p_causale_ciclo VARCHAR(10),
    p_causale_richiede_scadenza BOOLEAN DEFAULT FALSE,
    p_causale_giorni_scadenza_default INTEGER DEFAULT NULL,
    p_causale_genera_scadenza_auto BOOLEAN DEFAULT FALSE,
    p_causale_genera_iva BOOLEAN DEFAULT FALSE,
    p_causale_richiede_iva BOOLEAN DEFAULT FALSE,
    p_causale_aliquota_iva_default_fk INTEGER DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE,
    p_created_by VARCHAR DEFAULT NULL,
    p_updated_by VARCHAR DEFAULT NULL,
    p_causale_concorre_fatturato BOOLEAN DEFAULT FALSE,
    p_tipo_documento_sdi VARCHAR(4) DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    -- Normalizzazione UPPER CASE
    p_causale_codice := UPPER(TRIM(p_causale_codice));
    p_causale_descrizione := UPPER(TRIM(p_causale_descrizione));
    p_causale_ciclo := UPPER(TRIM(p_causale_ciclo));
    p_tipo_documento_sdi := UPPER(TRIM(p_tipo_documento_sdi));

    -- Validazioni base
    IF p_azienda_fk IS NULL THEN
        RAISE EXCEPTION 'INVALID_AZIENDA: L''azienda è obbligatoria';
    END IF;

    IF p_causale_codice = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: Il codice causale è obbligatorio';
    END IF;

    IF p_causale_descrizione = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: La descrizione è obbligatoria';
    END IF;

    IF p_causale_ciclo NOT IN ('ATTIVO', 'PASSIVO') THEN
        RAISE EXCEPTION 'INVALID_DATA: Il ciclo deve essere ATTIVO o PASSIVO';
    END IF;

    IF p_causale_segno NOT IN (-1, 1) THEN
        RAISE EXCEPTION 'INVALID_DATA: Il segno deve essere +1 o -1';
    END IF;

    -- Insert
    INSERT INTO ana_tipi_causali (
        azienda_fk, causale_codice, causale_descrizione,
        causale_segno, causale_is_documento, causale_ciclo,
        causale_richiede_scadenza, causale_giorni_scadenza_default,
        causale_genera_scadenza_auto, causale_genera_iva,
        causale_richiede_iva, causale_aliquota_iva_default_fk,
        causale_concorre_fatturato, tipo_documento_sdi,
        is_active, created_at, created_by, updated_at, updated_by
    ) VALUES (
        p_azienda_fk, p_causale_codice, p_causale_descrizione,
        p_causale_segno, p_causale_is_documento, p_causale_ciclo,
        p_causale_richiede_scadenza, p_causale_giorni_scadenza_default,
        p_causale_genera_scadenza_auto, p_causale_genera_iva,
        p_causale_richiede_iva, p_causale_aliquota_iva_default_fk,
        p_causale_concorre_fatturato, p_tipo_documento_sdi,
        p_is_active, CURRENT_TIMESTAMP, p_created_by, CURRENT_TIMESTAMP, p_updated_by
    )
    RETURNING causale_id INTO v_new_id;

    RETURN v_new_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE: Causale con codice % già esistente per questa azienda', p_causale_codice;
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_AZIENDA: Azienda non valida';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA: Violazione constraint di validazione';
END;
$$;

-- =============================================
-- SP UPDATE - Aggiunge parametro tipo_documento_sdi
-- =============================================
CREATE OR REPLACE FUNCTION sp_ana_tipi_causali_update(
    p_causale_id INTEGER,
    p_causale_codice VARCHAR(10),
    p_causale_descrizione VARCHAR(100),
    p_causale_segno INTEGER,
    p_causale_is_documento BOOLEAN,
    p_causale_ciclo VARCHAR(10),
    p_causale_richiede_scadenza BOOLEAN DEFAULT FALSE,
    p_causale_giorni_scadenza_default INTEGER DEFAULT NULL,
    p_causale_genera_scadenza_auto BOOLEAN DEFAULT FALSE,
    p_causale_genera_iva BOOLEAN DEFAULT FALSE,
    p_causale_richiede_iva BOOLEAN DEFAULT FALSE,
    p_causale_aliquota_iva_default_fk INTEGER DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE,
    p_updated_by VARCHAR DEFAULT NULL,
    p_causale_concorre_fatturato BOOLEAN DEFAULT FALSE,
    p_tipo_documento_sdi VARCHAR(4) DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Normalizzazione UPPER CASE
    p_causale_codice := UPPER(TRIM(p_causale_codice));
    p_causale_descrizione := UPPER(TRIM(p_causale_descrizione));
    p_causale_ciclo := UPPER(TRIM(p_causale_ciclo));
    p_tipo_documento_sdi := UPPER(TRIM(p_tipo_documento_sdi));

    -- Validazioni base
    IF p_causale_codice = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: Il codice causale è obbligatorio';
    END IF;

    IF p_causale_descrizione = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: La descrizione è obbligatoria';
    END IF;

    IF p_causale_ciclo NOT IN ('ATTIVO', 'PASSIVO') THEN
        RAISE EXCEPTION 'INVALID_DATA: Il ciclo deve essere ATTIVO o PASSIVO';
    END IF;

    IF p_causale_segno NOT IN (-1, 1) THEN
        RAISE EXCEPTION 'INVALID_DATA: Il segno deve essere +1 o -1';
    END IF;

    UPDATE ana_tipi_causali SET
        causale_codice = p_causale_codice,
        causale_descrizione = p_causale_descrizione,
        causale_segno = p_causale_segno,
        causale_is_documento = p_causale_is_documento,
        causale_ciclo = p_causale_ciclo,
        causale_richiede_scadenza = p_causale_richiede_scadenza,
        causale_giorni_scadenza_default = p_causale_giorni_scadenza_default,
        causale_genera_scadenza_auto = p_causale_genera_scadenza_auto,
        causale_genera_iva = p_causale_genera_iva,
        causale_richiede_iva = p_causale_richiede_iva,
        causale_aliquota_iva_default_fk = p_causale_aliquota_iva_default_fk,
        causale_concorre_fatturato = p_causale_concorre_fatturato,
        tipo_documento_sdi = p_tipo_documento_sdi,
        is_active = p_is_active,
        updated_by = p_updated_by
    WHERE causale_id = p_causale_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Causale con ID % non trovata', p_causale_id;
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE: Causale con codice % già esistente per questa azienda', p_causale_codice;
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA: Violazione constraint di validazione';
END;
$$;
