-- ============================================================================
-- fn_app_request_password_reset
-- Genera un codice di reset password a 6 cifre per l'utente specificato.
-- Implementa rate limiting e anti-enumeration.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_app_request_password_reset(
    p_email citext
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_id       UUID;
    v_nome          TEXT;
    v_azienda_id    INTEGER;
    v_role_code     VARCHAR(50);
    v_reset_code    VARCHAR(6);
    v_expires_at    TIMESTAMP WITH TIME ZONE;
    v_attempt_count INTEGER;
BEGIN
    -- 1. Controlla rate limit (max 3 tentativi in 15 minuti per email)
    SELECT COUNT(*)
    INTO v_attempt_count
    FROM password_reset_attempts
    WHERE email = p_email::varchar
      AND attempt_time > CURRENT_TIMESTAMP - INTERVAL '15 minutes';

    IF v_attempt_count >= 3 THEN
        -- Registra tentativo bloccato
        INSERT INTO password_reset_attempts (email, ip_address, success)
        VALUES (p_email::varchar, NULL, FALSE);

        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'RATE_LIMITED',
            'error_message', 'Troppi tentativi di reset. Riprova tra 15 minuti.'
        );
    END IF;

    -- 2. Verifica utente esiste e e attivo
    SELECT u.user_id, u.nome, u.azienda_id, urm.role_code
    INTO v_user_id, v_nome, v_azienda_id, v_role_code
    FROM app_users u
    LEFT JOIN app_user_role_map urm ON u.user_id = urm.user_id
    WHERE u.email = p_email
      AND u.is_active = TRUE;

    IF v_user_id IS NULL THEN
        -- Anti-enumeration: registra tentativo ma restituisci messaggio generico
        INSERT INTO password_reset_attempts (email, ip_address, success)
        VALUES (p_email::varchar, NULL, FALSE);

        -- Rispondiamo come se avessimo inviato il codice (anti-enumeration)
        RETURN jsonb_build_object(
            'success', true,
            'user_found', false,
            'error_message', NULL
        );
    END IF;

    -- 3. Disattiva token precedenti dell'utente
    UPDATE password_reset_tokens
    SET is_active = FALSE
    WHERE user_id = v_user_id
      AND is_active = TRUE;

    -- 4. Genera codice a 6 cifre random
    v_reset_code := LPAD((floor(random() * 1000000))::int::text, 6, '0');

    -- Assicurati unicita tra token attivi
    WHILE EXISTS (
        SELECT 1 FROM password_reset_tokens
        WHERE reset_token = v_reset_code AND is_active = TRUE
    ) LOOP
        v_reset_code := LPAD((floor(random() * 1000000))::int::text, 6, '0');
    END LOOP;

    -- 5. Imposta scadenza a 15 minuti
    v_expires_at := CURRENT_TIMESTAMP + INTERVAL '15 minutes';

    -- 6. Inserisce nuovo token
    INSERT INTO password_reset_tokens (
        user_id, email, reset_token, expires_at, ip_address, user_agent
    ) VALUES (
        v_user_id, p_email, v_reset_code, v_expires_at, NULL, NULL
    );

    -- 7. Registra tentativo riuscito
    INSERT INTO password_reset_attempts (email, ip_address, success)
    VALUES (p_email::varchar, NULL, TRUE);

    -- 8. Ritorna risultato con dati per invio email
    RETURN jsonb_build_object(
        'success', true,
        'user_found', true,
        'reset_code', v_reset_code,
        'user_id', v_user_id,
        'email', p_email,
        'nome', v_nome,
        'azienda_id', v_azienda_id,
        'role_code', v_role_code,
        'expires_at', v_expires_at
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'SYSTEM_ERROR',
            'error_message', 'Errore di sistema. Riprova piu tardi.'
        );
END;
$function$;

COMMENT ON FUNCTION fn_app_request_password_reset(citext) IS
'Genera un codice di reset password a 6 cifre. Rate limit: 3 tentativi/15min. Anti-enumeration: risposta generica se email non trovata.';
