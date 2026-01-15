-- 1. Update fn_app_list_users to include data_nascita
DROP FUNCTION IF EXISTS public.fn_app_list_users();

CREATE OR REPLACE FUNCTION public.fn_app_list_users()
RETURNS TABLE(
    user_id uuid, 
    email text, 
    nome text, 
    cognome text, 
    role_code text, 
    role_name text, 
    azienda_id integer, 
    ragione_sociale text, 
    is_active boolean, 
    last_login_at timestamp with time zone, 
    created_at timestamp with time zone,
    data_nascita date -- [NEW]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        u.email::text, 
        u.nome::text,
        u.cognome::text,
        rm.role_code::text, 
        r.role_name::text,  
        rm.azienda_id,
        a.ragione_sociale::text, 
        COALESCE(u.is_active, true),
        u.last_login_at,
        u.created_at,
        u.data_nascita -- [NEW]
    FROM public.app_users u
    LEFT JOIN public.app_user_role_map rm ON u.user_id = rm.user_id
    LEFT JOIN public.user_roles r ON rm.role_code = r.role_code
    LEFT JOIN public.ana_aziende a ON rm.azienda_id = a.azienda_id
    ORDER BY u.created_at DESC;
END;
$$;

-- 2. Update sp_app_create_user to accept data_nascita
CREATE OR REPLACE PROCEDURE public.sp_app_create_user(
    p_email text,
    p_password text,
    p_nome text,
    p_cognome text,
    p_role_code text,
    p_azienda_id int DEFAULT NULL,
    p_data_nascita date DEFAULT NULL -- [NEW]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Check if user exists
    IF EXISTS (SELECT 1 FROM public.app_users WHERE lower(email) = lower(p_email)) THEN
        RAISE EXCEPTION 'USER_ALREADY_EXISTS';
    END IF;

    -- Insert User
    INSERT INTO public.app_users (
        email, 
        password_hash, 
        nome, 
        cognome, 
        is_active,
        created_at,
        updated_at,
        data_nascita -- [NEW]
    )
    VALUES (
        p_email::citext,
        crypt(p_password, gen_salt('bf')),
        p_nome,
        p_cognome,
        true,
        now(),
        now(),
        p_data_nascita -- [NEW]
    )
    RETURNING user_id INTO v_user_id;

    -- Assign Role
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

-- 3. Update sp_app_update_user to accept data_nascita
CREATE OR REPLACE PROCEDURE public.sp_app_update_user(
    p_user_id uuid,
    p_email text,
    p_password text, 
    p_nome text,
    p_cognome text,
    p_role_code text,
    p_azienda_id int DEFAULT NULL,
    p_is_active boolean DEFAULT NULL,
    p_data_nascita date DEFAULT NULL -- [NEW]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_password_hash text;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM public.app_users WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- Check overlap
    IF EXISTS (SELECT 1 FROM public.app_users WHERE lower(email) = lower(p_email) AND user_id <> p_user_id) THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    END IF;

    -- Prepare Password Update
    IF p_password IS NOT NULL AND length(trim(p_password)) > 0 THEN
        v_new_password_hash := crypt(p_password, gen_salt('bf'));
    ELSE
        SELECT password_hash INTO v_new_password_hash FROM public.app_users WHERE user_id = p_user_id;
    END IF;

    -- Update User Data
    UPDATE public.app_users
    SET
        email = p_email::citext,
        password_hash = v_new_password_hash,
        nome = p_nome,
        cognome = p_cognome,
        is_active = COALESCE(p_is_active, is_active),
        data_nascita = p_data_nascita, -- [NEW] Update unconditionally? Or COALESCE? Usually full update sends current value.
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Update Role Mapping
    IF EXISTS (SELECT 1 FROM public.app_user_role_map WHERE user_id = p_user_id) THEN
        UPDATE public.app_user_role_map
        SET
            role_code = p_role_code,
            azienda_id = p_azienda_id
        WHERE user_id = p_user_id;
    ELSE
        INSERT INTO public.app_user_role_map (user_id, role_code, azienda_id)
        VALUES (p_user_id, p_role_code, p_azienda_id);
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_ROLE_OR_AZIENDA';
END;
$$;
