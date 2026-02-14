-- =====================================================
-- CRUD FUNCTIONS: ana_tipi_causali
-- Scopo: DB-First approach per gestione tipi causali
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- =====================================================

-- =====================================================
-- 1. GET ALL - Lista tutte le causali per azienda
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_tipi_causali_get_all(
    p_azienda_id INTEGER
)
RETURNS SETOF ana_tipi_causali
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_tipi_causali
    WHERE azienda_fk = p_azienda_id
    ORDER BY causale_ciclo, causale_descrizione;
END;
$$;

COMMENT ON FUNCTION fn_ana_tipi_causali_get_all IS
'Recupera tutte le causali per azienda, ordinate per ciclo e descrizione. Usato dalla griglia principale.';

-- =====================================================
-- 2. GET ACTIVE - Solo causali attive
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_tipi_causali_get_active(
    p_azienda_id INTEGER
)
RETURNS SETOF ana_tipi_causali
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_tipi_causali
    WHERE azienda_fk = p_azienda_id
      AND is_active = TRUE
    ORDER BY causale_descrizione;
END;
$$;

COMMENT ON FUNCTION fn_ana_tipi_causali_get_active IS
'Recupera solo le causali attive per azienda. Usato nei dropdown/combobox.';

-- =====================================================
-- 3. GET ACTIVE BY CICLO - Causali attive per ciclo
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_tipi_causali_get_active_by_ciclo(
    p_azienda_id INTEGER,
    p_ciclo VARCHAR(10)
)
RETURNS SETOF ana_tipi_causali
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_tipi_causali
    WHERE azienda_fk = p_azienda_id
      AND causale_ciclo = p_ciclo
      AND is_active = TRUE
    ORDER BY causale_descrizione;
END;
$$;

COMMENT ON FUNCTION fn_ana_tipi_causali_get_active_by_ciclo IS
'Recupera causali attive filtrate per ciclo contabile (ATTIVO/PASSIVO). Usato nei filtri transazioni.';

-- =====================================================
-- 4. CREATE - Crea nuova causale
-- =====================================================
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
    p_created_by VARCHAR(50) DEFAULT NULL,
    p_updated_by VARCHAR(50) DEFAULT NULL
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
        is_active, created_at, created_by, updated_at, updated_by
    ) VALUES (
        p_azienda_fk, p_causale_codice, p_causale_descrizione,
        p_causale_segno, p_causale_is_documento, p_causale_ciclo,
        p_causale_richiede_scadenza, p_causale_giorni_scadenza_default,
        p_causale_genera_scadenza_auto, p_causale_genera_iva,
        p_causale_richiede_iva, p_causale_aliquota_iva_default_fk,
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

COMMENT ON FUNCTION sp_ana_tipi_causali_create IS
'Crea nuova causale con validazione completa e normalizzazione automatica UPPER CASE.';

-- =====================================================
-- 5. UPDATE - Aggiorna causale esistente
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_tipi_causali_update(
    p_causale_id INTEGER,
    p_causale_codice VARCHAR(10),
    p_causale_descrizione VARCHAR(100),
    p_causale_segno INTEGER,
    p_causale_is_documento BOOLEAN,
    p_causale_ciclo VARCHAR(10),
    p_causale_richiede_scadenza BOOLEAN,
    p_causale_giorni_scadenza_default INTEGER,
    p_causale_genera_scadenza_auto BOOLEAN,
    p_causale_genera_iva BOOLEAN,
    p_causale_richiede_iva BOOLEAN,
    p_causale_aliquota_iva_default_fk INTEGER,
    p_is_active BOOLEAN,
    p_updated_by VARCHAR(50)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verifica esistenza
    SELECT EXISTS(SELECT 1 FROM ana_tipi_causali WHERE causale_id = p_causale_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Causale % non trovata', p_causale_id;
    END IF;

    -- Normalizzazione UPPER CASE
    p_causale_codice := UPPER(TRIM(p_causale_codice));
    p_causale_descrizione := UPPER(TRIM(p_causale_descrizione));
    p_causale_ciclo := UPPER(TRIM(p_causale_ciclo));

    -- Validazioni
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

    -- Update
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
        is_active = p_is_active,
        updated_at = CURRENT_TIMESTAMP,
        updated_by = p_updated_by
    WHERE causale_id = p_causale_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE: Causale con codice % già esistente per questa azienda', p_causale_codice;
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_REFERENCE: Riferimento non valido (verificare aliquota IVA)';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA: Violazione constraint di validazione';
END;
$$;

COMMENT ON FUNCTION sp_ana_tipi_causali_update IS
'Aggiorna causale esistente con validazione completa e normalizzazione automatica UPPER CASE.';

-- =====================================================
-- 6. DELETE - Elimina causale
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_tipi_causali_delete(
    p_causale_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verifica esistenza
    SELECT EXISTS(SELECT 1 FROM ana_tipi_causali WHERE causale_id = p_causale_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Causale % non trovata', p_causale_id;
    END IF;

    -- Elimina
    DELETE FROM ana_tipi_causali WHERE causale_id = p_causale_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'RECORD_IN_USE: Impossibile eliminare la causale perché è utilizzata in transazioni esistenti';
END;
$$;

COMMENT ON FUNCTION sp_ana_tipi_causali_delete IS
'Elimina causale. Blocca eliminazione se in uso da transazioni.';
