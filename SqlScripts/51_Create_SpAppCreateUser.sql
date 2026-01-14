-- Stored Procedure to Create User
CREATE OR REPLACE PROCEDURE public.sp_app_create_user(
    p_email text,
    p_password text,
    p_nome text,
    p_cognome text,
    p_role_code text,
    p_azienda_id int DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- 1. Check if user exists
    IF EXISTS (SELECT 1 FROM public.app_users WHERE lower(email) = lower(p_email)) THEN
        RAISE EXCEPTION 'USER_ALREADY_EXISTS';
    END IF;

    -- 2. Insert User (with hashed password)
    INSERT INTO public.app_users (
        email, 
        password_hash, 
        nome, 
        cognome, 
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        p_email::citext,
        crypt(p_password, gen_salt('bf')),
        p_nome,
        p_cognome,
        true,
        now(),
        now()
    )
    RETURNING user_id INTO v_user_id;

    -- 3. Assign Role (and Azienda if applicable)
    -- Azienda is required for non-Superadmin/TenantAdmin roles usually, but validation is handled by FK/Checks mostly.
    -- Better enforce here if needed, but let's stick to base logic.
    
    INSERT INTO public.app_user_role_map (
        user_id,
        role_code,
        azienda_id
    )
    VALUES (
        v_user_id,
        p_role_code,
        p_azienda_id
    );

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'USER_ALREADY_EXISTS';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_ROLE_OR_AZIENDA';
END;
$$;
