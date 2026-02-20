-- =====================================================
-- FUNCTION: fn_get_api_config_value
-- Scopo: Recupera il valore di una singola configurazione API
--        dato il service_code e il config_key.
--        Approccio DB-First: la logica di validazione e
--        restituzione è interamente nel database.
-- Creato: 20/02/2026
-- Autore: Adriano Visconti
-- =====================================================

CREATE OR REPLACE FUNCTION fn_get_api_config_value(
    p_service_code VARCHAR(50),
    p_config_key   VARCHAR(100)
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_value TEXT;
    v_is_active BOOLEAN;
BEGIN
    -- Normalizzazione input
    p_service_code := UPPER(TRIM(p_service_code));
    p_config_key   := UPPER(TRIM(p_config_key));

    -- Validazione parametri
    IF p_service_code IS NULL OR p_service_code = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: Il codice servizio è obbligatorio per recuperare la configurazione API.';
    END IF;

    IF p_config_key IS NULL OR p_config_key = '' THEN
        RAISE EXCEPTION 'INVALID_DATA: La chiave di configurazione è obbligatoria per recuperare il valore.';
    END IF;

    -- Recupero valore e stato attivo
    SELECT ac.config_value, ac.is_active
      INTO v_value, v_is_active
      FROM ana_api_config ac
     WHERE ac.service_code = p_service_code
       AND ac.config_key   = p_config_key;

    -- Verifica esistenza
    IF NOT FOUND THEN
        RAISE EXCEPTION 'CONFIG_NOT_FOUND: Nessuna configurazione trovata per il servizio "%" con chiave "%".', p_service_code, p_config_key;
    END IF;

    -- Verifica che la configurazione sia attiva
    IF NOT v_is_active THEN
        RAISE EXCEPTION 'CONFIG_DISABLED: La configurazione "%" del servizio "%" è disattivata. Attivarla dalla sezione Configurazione API.', p_config_key, p_service_code;
    END IF;

    -- Verifica che il valore non sia vuoto
    IF v_value IS NULL OR TRIM(v_value) = '' THEN
        RAISE EXCEPTION 'CONFIG_EMPTY: La configurazione "%" del servizio "%" non ha un valore impostato. Inserirlo dalla sezione Configurazione API.', p_config_key, p_service_code;
    END IF;

    RETURN v_value;
END;
$$;

COMMENT ON FUNCTION fn_get_api_config_value(VARCHAR, VARCHAR) IS
'Recupera il valore di una singola configurazione API attiva per service_code e config_key. '
'Validazioni: parametri obbligatori, esistenza record, stato attivo, valore non vuoto. '
'Usato da CurrencyApiService per recuperare API key dinamicamente dal DB invece che dal codice.';
