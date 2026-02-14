-- =====================================================
-- STORED FUNCTIONS E PROCEDURES: ana_aliquote_iva
-- Scopo: Operazioni CRUD DB-First per aliquote IVA
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- Versione: 1.0
-- =====================================================

-- =====================================================
-- FUNCTION 1: Get All Aliquote per Azienda
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_aliquote_iva_get_all(
    p_azienda_id INTEGER
)
RETURNS SETOF ana_aliquote_iva
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
    ORDER BY ordinamento, iva_descrizione;
END;
$$;

COMMENT ON FUNCTION fn_ana_aliquote_iva_get_all(INTEGER) IS
'Recupera tutte le aliquote IVA per azienda, ordinate per ordinamento e descrizione';

-- =====================================================
-- FUNCTION 2: Get Active Aliquote per Azienda
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_aliquote_iva_get_active(
    p_azienda_id INTEGER
)
RETURNS SETOF ana_aliquote_iva
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
      AND is_active = TRUE
    ORDER BY ordinamento, iva_descrizione;
END;
$$;

COMMENT ON FUNCTION fn_ana_aliquote_iva_get_active(INTEGER) IS
'Recupera solo le aliquote IVA attive per azienda (per dropdown UI)';

-- =====================================================
-- FUNCTION 3: Get Default Aliquota per Azienda
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_aliquote_iva_get_default(
    p_azienda_id INTEGER
)
RETURNS ana_aliquote_iva
LANGUAGE plpgsql
AS $$
DECLARE
    v_result ana_aliquote_iva;
BEGIN
    SELECT *
    INTO v_result
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
      AND is_default = TRUE
    LIMIT 1;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION fn_ana_aliquote_iva_get_default(INTEGER) IS
'Recupera l''aliquota IVA default per azienda (preselezionata in UI)';

-- =====================================================
-- PROCEDURE 4: Create Aliquota IVA
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_aliquote_iva_create(
    p_azienda_fk INTEGER,
    p_iva_codice VARCHAR(10),
    p_iva_descrizione VARCHAR(100),
    p_iva_percentuale NUMERIC(5, 2),
    p_iva_natura VARCHAR(10),
    p_is_default BOOLEAN,
    p_is_active BOOLEAN,
    p_ordinamento SMALLINT,
    p_created_by VARCHAR(50),
    p_updated_by VARCHAR(50)
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_iva_id INTEGER;
BEGIN
    -- Validazione parametri obbligatori
    IF p_azienda_fk IS NULL OR p_azienda_fk = 0 THEN
        RAISE EXCEPTION 'AZIENDA_REQUIRED';
    END IF;

    IF p_iva_codice IS NULL OR LENGTH(TRIM(p_iva_codice)) = 0 THEN
        RAISE EXCEPTION 'CODICE_REQUIRED';
    END IF;

    IF p_iva_descrizione IS NULL OR LENGTH(TRIM(p_iva_descrizione)) = 0 THEN
        RAISE EXCEPTION 'DESCRIZIONE_REQUIRED';
    END IF;

    -- Normalizzazione UPPER CASE (il constraint la verifica, ma la forziamo)
    p_iva_codice := UPPER(TRIM(p_iva_codice));
    p_iva_descrizione := UPPER(TRIM(p_iva_descrizione));
    IF p_iva_natura IS NOT NULL THEN
        p_iva_natura := UPPER(TRIM(p_iva_natura));
    END IF;

    -- Insert
    INSERT INTO ana_aliquote_iva (
        azienda_fk,
        iva_codice,
        iva_descrizione,
        iva_percentuale,
        iva_natura,
        is_default,
        is_active,
        ordinamento,
        created_at,
        created_by,
        updated_at,
        updated_by
    ) VALUES (
        p_azienda_fk,
        p_iva_codice,
        p_iva_descrizione,
        COALESCE(p_iva_percentuale, 0),
        p_iva_natura,
        COALESCE(p_is_default, FALSE),
        COALESCE(p_is_active, TRUE),
        COALESCE(p_ordinamento, 100),
        NOW(),
        p_created_by,
        NOW(),
        p_updated_by
    )
    RETURNING iva_id INTO v_iva_id;

    RETURN v_iva_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_AZIENDA';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA';
END;
$$;

COMMENT ON FUNCTION sp_ana_aliquote_iva_create IS
'Crea nuova aliquota IVA con validazione e normalizzazione UPPER CASE. Ritorna iva_id.';

-- =====================================================
-- PROCEDURE 5: Update Aliquota IVA
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_aliquote_iva_update(
    p_iva_id INTEGER,
    p_iva_codice VARCHAR(10),
    p_iva_descrizione VARCHAR(100),
    p_iva_percentuale NUMERIC(5, 2),
    p_iva_natura VARCHAR(10),
    p_is_default BOOLEAN,
    p_is_active BOOLEAN,
    p_ordinamento SMALLINT,
    p_updated_by VARCHAR(50)
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (SELECT 1 FROM ana_aliquote_iva WHERE iva_id = p_iva_id) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Validazione parametri obbligatori
    IF p_iva_codice IS NULL OR LENGTH(TRIM(p_iva_codice)) = 0 THEN
        RAISE EXCEPTION 'CODICE_REQUIRED';
    END IF;

    IF p_iva_descrizione IS NULL OR LENGTH(TRIM(p_iva_descrizione)) = 0 THEN
        RAISE EXCEPTION 'DESCRIZIONE_REQUIRED';
    END IF;

    -- Normalizzazione UPPER CASE
    p_iva_codice := UPPER(TRIM(p_iva_codice));
    p_iva_descrizione := UPPER(TRIM(p_iva_descrizione));
    IF p_iva_natura IS NOT NULL THEN
        p_iva_natura := UPPER(TRIM(p_iva_natura));
    END IF;

    -- Update
    UPDATE ana_aliquote_iva
    SET
        iva_codice = p_iva_codice,
        iva_descrizione = p_iva_descrizione,
        iva_percentuale = COALESCE(p_iva_percentuale, 0),
        iva_natura = p_iva_natura,
        is_default = COALESCE(p_is_default, FALSE),
        is_active = COALESCE(p_is_active, TRUE),
        ordinamento = COALESCE(p_ordinamento, 100),
        updated_at = NOW(),
        updated_by = p_updated_by
    WHERE iva_id = p_iva_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_CODICE';
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA';
END;
$$;

COMMENT ON FUNCTION sp_ana_aliquote_iva_update IS
'Aggiorna aliquota IVA esistente con validazione e normalizzazione UPPER CASE.';

-- =====================================================
-- PROCEDURE 6: Delete Aliquota IVA
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_aliquote_iva_delete(
    p_iva_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (SELECT 1 FROM ana_aliquote_iva WHERE iva_id = p_iva_id) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Delete
    DELETE FROM ana_aliquote_iva
    WHERE iva_id = p_iva_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'RECORD_IN_USE';
END;
$$;

COMMENT ON FUNCTION sp_ana_aliquote_iva_delete IS
'Elimina aliquota IVA. Solleva eccezione se in uso da altre tabelle.';

-- =====================================================
-- PROCEDURE 7: Set Aliquota Default
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_aliquote_iva_set_default(
    p_iva_id INTEGER,
    p_azienda_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validazione esistenza record
    IF NOT EXISTS (
        SELECT 1 FROM ana_aliquote_iva
        WHERE iva_id = p_iva_id
          AND azienda_fk = p_azienda_id
    ) THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND';
    END IF;

    -- Imposta come default
    -- Il trigger fn_check_single_default_iva rimuoverà automaticamente
    -- il flag dalle altre aliquote della stessa azienda
    UPDATE ana_aliquote_iva
    SET
        is_default = TRUE,
        updated_at = NOW()
    WHERE iva_id = p_iva_id
      AND azienda_fk = p_azienda_id;

END;
$$;

COMMENT ON FUNCTION sp_ana_aliquote_iva_set_default IS
'Imposta un''aliquota come default per azienda. Il trigger rimuove automaticamente il flag dalle altre.';

-- =====================================================
-- VERIFICA CREAZIONE
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname LIKE '%ana_aliquote_iva%';

    IF v_count >= 7 THEN
        RAISE NOTICE '✓ % stored functions/procedures create per ana_aliquote_iva', v_count;
    ELSE
        RAISE WARNING '⚠ Solo % functions/procedures trovate (attese: 7)', v_count;
    END IF;
END $$;

-- =====================================================
-- FINE SCRIPT
-- =====================================================

-- Note Implementative:
-- 1. Tutte le function SELECT ritornano dati (SETOF o record singolo)
-- 2. Tutte le procedure CUD (Create/Update/Delete) usano SECURITY DEFINER
-- 3. La normalizzazione UPPER CASE è forzata nelle procedure (codice, descrizione, natura)
-- 4. Il trigger fn_check_single_default_iva gestisce automaticamente il constraint single default
-- 5. Gestione eccezioni standard: DUPLICATE_CODICE, RECORD_NOT_FOUND, INVALID_AZIENDA, RECORD_IN_USE
-- 6. I campi audit (created_by, updated_by) sono gestiti dall'applicazione e passati alle procedure
