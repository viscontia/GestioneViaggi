-- FIX: Correct table name is 'user_roles', NOT 'app_roles'

-- 1. Update Create Role (Fixing table name)
CREATE OR REPLACE PROCEDURE public.sp_app_create_role(
    p_role_code text,
    p_role_name text,
    p_is_system boolean DEFAULT false
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE lower(role_code) = lower(p_role_code)) THEN
        RAISE EXCEPTION 'ROLE_CODE_ALREADY_EXISTS';
    END IF;

    -- Corrected table name: user_roles
    INSERT INTO public.user_roles (role_code, role_name, is_system)
    VALUES (p_role_code, p_role_name, p_is_system);
END;
$$;

-- 2. Update Update Role (Fixing table name)
CREATE OR REPLACE PROCEDURE public.sp_app_update_role(
    p_role_code text,
    p_role_name text,
    p_is_system boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_code text;
BEGIN
    v_clean_code := lower(trim(p_role_code));

    IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE lower(role_code) = v_clean_code) THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;

    -- Corrected table name: user_roles
    UPDATE public.user_roles
    SET 
        role_name = trim(p_role_name),
        is_system = p_is_system,
        updated_at = now()
    WHERE lower(role_code) = v_clean_code;
END;
$$;

-- 3. Update Delete Role (Fixing table name)
CREATE OR REPLACE PROCEDURE public.sp_app_delete_role(
    p_role_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_code text;
    v_user_count int;
BEGIN
    v_clean_code := lower(trim(p_role_code));

    IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE lower(role_code) = v_clean_code) THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;
    
    IF v_clean_code = 'superadmin' THEN
        RAISE EXCEPTION 'CANNOT_DELETE_SUPERADMIN_ROLE';
    END IF;

    -- Check usage (app_user_role_map is correct, checking FK)
    SELECT count(*) INTO v_user_count FROM public.app_user_role_map WHERE lower(role_code) = v_clean_code;
    IF v_user_count > 0 THEN
        RAISE EXCEPTION 'ROLE_IN_USE' USING ERRCODE = '23503';
    END IF;

    -- Corrected table name: user_roles
    DELETE FROM public.user_roles
    WHERE lower(role_code) = v_clean_code;
END;
$$;
