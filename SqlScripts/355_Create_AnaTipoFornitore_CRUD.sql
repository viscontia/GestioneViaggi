-- =====================================================
-- Stored Procedures CRUD: ana_tipo_fornitore
-- Description: Create, Update, Delete per Tipi Fornitore
-- Author: Sistema DB-First
-- Created: 2026-03-16
-- =====================================================

-- =====================================================
-- sp_ana_tipo_fornitore_create
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_tipo_fornitore_create(
    p_azienda_fk INTEGER,
    p_descrizione VARCHAR(50),
    p_categoria VARCHAR(20) DEFAULT NULL,
    p_conto_contabile_default VARCHAR(20) DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    -- Validazioni
    IF p_azienda_fk IS NULL OR p_azienda_fk <= 0 THEN
        RAISE EXCEPTION 'INVALID_AZIENDA: Azienda obbligatoria';
    END IF;

    IF p_descrizione IS NULL OR TRIM(p_descrizione) = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: Descrizione obbligatoria';
    END IF;

    -- Normalizzazione UPPER CASE
    p_descrizione := UPPER(TRIM(p_descrizione));
    p_categoria := UPPER(TRIM(p_categoria));

    -- Validazione categoria (se fornita)
    IF p_categoria IS NOT NULL AND p_categoria NOT IN ('COSTO', 'RICAVO', 'MISTO') THEN
        RAISE EXCEPTION 'INVALID_DATA: Categoria deve essere COSTO, RICAVO o MISTO';
    END IF;

    -- Insert
    INSERT INTO ana_tipo_fornitore (
        azienda_fk,
        descrizione,
        categoria,
        conto_contabile_default
    )
    VALUES (
        p_azienda_fk,
        p_descrizione,
        p_categoria,
        p_conto_contabile_default
    )
    RETURNING tipo_fornitore_id INTO v_new_id;

    RETURN v_new_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_DESCRIZIONE: Tipo fornitore già esistente per questa azienda';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_AZIENDA: Azienda non valida';
END;
$$;

COMMENT ON FUNCTION sp_ana_tipo_fornitore_create(INTEGER, VARCHAR, VARCHAR, VARCHAR) IS
'Crea nuovo tipo fornitore con normalizzazione UPPER CASE e validazioni business logic';

-- =====================================================
-- sp_ana_tipo_fornitore_update
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_tipo_fornitore_update(
    p_tipo_fornitore_id INTEGER,
    p_descrizione VARCHAR(50),
    p_categoria VARCHAR(20) DEFAULT NULL,
    p_conto_contabile_default VARCHAR(20) DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validazioni
    IF p_descrizione IS NULL OR TRIM(p_descrizione) = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: Descrizione obbligatoria';
    END IF;

    -- Normalizzazione UPPER CASE
    p_descrizione := UPPER(TRIM(p_descrizione));
    p_categoria := UPPER(TRIM(p_categoria));

    -- Validazione categoria (se fornita)
    IF p_categoria IS NOT NULL AND p_categoria NOT IN ('COSTO', 'RICAVO', 'MISTO') THEN
        RAISE EXCEPTION 'INVALID_DATA: Categoria deve essere COSTO, RICAVO o MISTO';
    END IF;

    -- Update
    UPDATE ana_tipo_fornitore
    SET
        descrizione = p_descrizione,
        categoria = p_categoria,
        conto_contabile_default = p_conto_contabile_default,
        updated_at = NOW()
    WHERE tipo_fornitore_id = p_tipo_fornitore_id;

    -- Verifica se il record esiste
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Tipo fornitore con ID % non trovato', p_tipo_fornitore_id;
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_DESCRIZIONE: Tipo fornitore già esistente per questa azienda';
END;
$$;

COMMENT ON FUNCTION sp_ana_tipo_fornitore_update(INTEGER, VARCHAR, VARCHAR, VARCHAR) IS
'Aggiorna tipo fornitore esistente con normalizzazione UPPER CASE e validazioni';

-- =====================================================
-- sp_ana_tipo_fornitore_delete
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_tipo_fornitore_delete(
    p_tipo_fornitore_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Elimina il record
    DELETE FROM ana_tipo_fornitore
    WHERE tipo_fornitore_id = p_tipo_fornitore_id;

    -- Verifica se il record esisteva
    IF NOT FOUND THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Tipo fornitore con ID % non trovato', p_tipo_fornitore_id;
    END IF;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'RECORD_IN_USE: Impossibile eliminare, tipo fornitore in uso da controparti';
END;
$$;

COMMENT ON FUNCTION sp_ana_tipo_fornitore_delete(INTEGER) IS
'Elimina tipo fornitore. Blocca eliminazione se in uso da controparti (FK violation)';
