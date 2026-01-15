DO $$
DECLARE
    v_email text := 'test_debug_login@example.com';
    v_password text := 'TestPass123!';
    v_user_id uuid;
    v_login_result jsonb;
BEGIN
    -- 1. Cleanup previous run
    DELETE FROM app_users WHERE email = v_email;

    -- 2. Create User via SP
    CALL sp_app_create_user(
        v_email,
        v_password,
        'Test',
        'Debug',
        'azienda_admin', -- valid role
        2, -- valid azienda
        NULL::date -- data_nascita
    );

    -- 3. Try to Login via Function
    v_login_result := fn_app_login(v_email::citext, v_password);
    
    -- 4. Check Result
    RAISE NOTICE 'Login Result: %', v_login_result;

    IF (v_login_result->>'success')::boolean IS TRUE THEN
        RAISE NOTICE 'SUCCESS: User created and logged in successfully.';
    ELSE
        RAISE NOTICE 'FAILURE: Login failed. Error: %', v_login_result->>'error';
    END IF;

    -- 5. Cleanup
    -- DELETE FROM app_users WHERE email = v_email; 
END $$;
