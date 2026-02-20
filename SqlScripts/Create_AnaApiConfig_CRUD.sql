-- =====================================================
-- CRUD FUNCTIONS: ana_api_config
-- Scopo: DB-First approach per gestione configurazioni API
-- Tabella globale (no azienda_fk) - Solo SuperAdmin
-- Creato: 20/02/2026
-- Autore: Adriano Visconti
-- =====================================================

-- =====================================================
-- 1. GET ALL - Lista tutte le configurazioni
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_api_config_get_all()
RETURNS SETOF ana_api_config
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_api_config
    ORDER BY service_code, display_order, config_key;
END;
$$;

COMMENT ON FUNCTION fn_ana_api_config_get_all IS
'Recupera tutte le configurazioni API ordinate per servizio e ordine di visualizzazione. Usato dalla griglia principale.';

-- =====================================================
-- 2. GET BY SERVICE - Configurazioni per servizio
-- =====================================================
CREATE OR REPLACE FUNCTION fn_ana_api_config_get_by_service(
    p_service_code VARCHAR(50)
)
RETURNS SETOF ana_api_config
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_api_config
    WHERE service_code = UPPER(TRIM(p_service_code))
    ORDER BY display_order, config_key;
END;
$$;

COMMENT ON FUNCTION fn_ana_api_config_get_by_service IS
'Recupera le configurazioni per un servizio specifico. Usato per lettura API key da codice.';

-- =====================================================
-- 3. CREATE - Crea nuova configurazione
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_api_config_create(
    p_service_code VARCHAR(50),
    p_service_name VARCHAR(100),
    p_config_key VARCHAR(100),
    p_config_value TEXT DEFAULT NULL,
    p_config_type VARCHAR(20) DEFAULT 'TEXT',
    p_config_description VARCHAR(255) DEFAULT NULL,
    p_is_secret BOOLEAN DEFAULT FALSE,
    p_is_active BOOLEAN DEFAULT TRUE,
    p_display_order SMALLINT DEFAULT 0,
    p_created_by VARCHAR(50) DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    -- Normalizzazione UPPER CASE
    p_service_code := UPPER(TRIM(p_service_code));
    p_service_name := UPPER(TRIM(p_service_name));
    p_config_key := UPPER(TRIM(p_config_key));
    p_config_type := UPPER(TRIM(p_config_type));
    p_config_description := UPPER(TRIM(p_config_description));

    -- Validazioni base
    IF p_service_code = '' OR p_service_code IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: Il codice servizio è obbligatorio';
    END IF;

    IF p_service_name = '' OR p_service_name IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: Il nome servizio è obbligatorio';
    END IF;

    IF p_config_key = '' OR p_config_key IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: La chiave di configurazione è obbligatoria';
    END IF;

    IF p_config_type NOT IN ('TEXT', 'API_KEY', 'URL', 'SECRET', 'BOOLEAN') THEN
        RAISE EXCEPTION 'INVALID_DATA: Il tipo deve essere TEXT, API_KEY, URL, SECRET o BOOLEAN';
    END IF;

    -- Insert
    INSERT INTO ana_api_config (
        service_code, service_name, config_key,
        config_value, config_type, config_description,
        is_secret, is_active, display_order,
        created_at, created_by, updated_at, updated_by
    ) VALUES (
        p_service_code, p_service_name, p_config_key,
        p_config_value, p_config_type, p_config_description,
        p_is_secret, p_is_active, p_display_order,
        CURRENT_TIMESTAMP, p_created_by, CURRENT_TIMESTAMP, p_created_by
    )
    RETURNING config_id INTO v_new_id;

    RETURN v_new_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_KEY: Configurazione con chiave % già esistente per il servizio %', p_config_key, p_service_code;
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA: Violazione constraint di validazione';
END;
$$;

COMMENT ON FUNCTION sp_ana_api_config_create IS
'Crea nuova configurazione API con validazione completa e normalizzazione automatica UPPER CASE su service_code, config_key, config_type.';

-- =====================================================
-- 4. UPDATE - Aggiorna configurazione esistente
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_api_config_update(
    p_config_id INTEGER,
    p_service_code VARCHAR(50),
    p_service_name VARCHAR(100),
    p_config_key VARCHAR(100),
    p_config_value TEXT,
    p_config_type VARCHAR(20),
    p_config_description VARCHAR(255),
    p_is_secret BOOLEAN,
    p_is_active BOOLEAN,
    p_display_order SMALLINT,
    p_updated_by VARCHAR(50)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verifica esistenza
    SELECT EXISTS(SELECT 1 FROM ana_api_config WHERE config_id = p_config_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Configurazione % non trovata', p_config_id;
    END IF;

    -- Normalizzazione UPPER CASE
    p_service_code := UPPER(TRIM(p_service_code));
    p_service_name := UPPER(TRIM(p_service_name));
    p_config_key := UPPER(TRIM(p_config_key));
    p_config_type := UPPER(TRIM(p_config_type));
    p_config_description := UPPER(TRIM(p_config_description));

    -- Validazioni
    IF p_service_code = '' OR p_service_code IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: Il codice servizio è obbligatorio';
    END IF;

    IF p_service_name = '' OR p_service_name IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: Il nome servizio è obbligatorio';
    END IF;

    IF p_config_key = '' OR p_config_key IS NULL THEN
        RAISE EXCEPTION 'INVALID_DATA: La chiave di configurazione è obbligatoria';
    END IF;

    IF p_config_type NOT IN ('TEXT', 'API_KEY', 'URL', 'SECRET', 'BOOLEAN') THEN
        RAISE EXCEPTION 'INVALID_DATA: Il tipo deve essere TEXT, API_KEY, URL, SECRET o BOOLEAN';
    END IF;

    -- Update
    UPDATE ana_api_config SET
        service_code = p_service_code,
        service_name = p_service_name,
        config_key = p_config_key,
        config_value = p_config_value,
        config_type = p_config_type,
        config_description = p_config_description,
        is_secret = p_is_secret,
        is_active = p_is_active,
        display_order = p_display_order,
        updated_at = CURRENT_TIMESTAMP,
        updated_by = p_updated_by
    WHERE config_id = p_config_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_KEY: Configurazione con chiave % già esistente per il servizio %', p_config_key, p_service_code;
    WHEN check_violation THEN
        RAISE EXCEPTION 'INVALID_DATA: Violazione constraint di validazione';
END;
$$;

COMMENT ON FUNCTION sp_ana_api_config_update IS
'Aggiorna configurazione API esistente con validazione completa e normalizzazione automatica UPPER CASE.';

-- =====================================================
-- 5. DELETE - Elimina singola configurazione
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_api_config_delete(
    p_config_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verifica esistenza
    SELECT EXISTS(SELECT 1 FROM ana_api_config WHERE config_id = p_config_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Configurazione % non trovata', p_config_id;
    END IF;

    -- Elimina
    DELETE FROM ana_api_config WHERE config_id = p_config_id;
END;
$$;

COMMENT ON FUNCTION sp_ana_api_config_delete IS
'Elimina una singola configurazione API per ID.';

-- =====================================================
-- 6. DELETE SERVICE - Elimina tutte le config di un servizio
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ana_api_config_delete_service(
    p_service_code VARCHAR(50)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    p_service_code := UPPER(TRIM(p_service_code));

    -- Verifica che esista almeno una configurazione
    SELECT COUNT(*) FROM ana_api_config WHERE service_code = p_service_code INTO v_count;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Nessuna configurazione trovata per il servizio %', p_service_code;
    END IF;

    -- Elimina tutte le configurazioni del servizio
    DELETE FROM ana_api_config WHERE service_code = p_service_code;
END;
$$;

COMMENT ON FUNCTION sp_ana_api_config_delete_service IS
'Elimina tutte le configurazioni di un servizio specifico. Usato per rimuovere un intero servizio.';
