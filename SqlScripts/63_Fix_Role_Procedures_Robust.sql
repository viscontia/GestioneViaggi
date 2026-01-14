-- Refactor Role Procedures for Robustness

-- 1. Update Role Procedure (Case Insensitive, Trim)
CREATE OR REPLACE PROCEDURE public.sp_app_update_role(
    p_role_code varchar(50), 
    p_role_name varchar(100)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system boolean;
    v_clean_code text;
BEGIN
    v_clean_code := lower(trim(p_role_code));

    SELECT is_system INTO v_is_system FROM public.user_roles 
    WHERE lower(role_code) = v_clean_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;

    IF v_is_system THEN
        RAISE EXCEPTION 'CANNOT_MODIFY_SYSTEM_ROLE';
    END IF;

    UPDATE public.user_roles
    SET role_name = trim(p_role_name), updated_at = now()
    WHERE lower(role_code) = v_clean_code;
END;
$$;

-- 2. Delete Role Procedure (Case Insensitive, Trim)
CREATE OR REPLACE PROCEDURE public.sp_app_delete_role(
    p_role_code varchar(50)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system boolean;
    v_clean_code text;
BEGIN
    v_clean_code := lower(trim(p_role_code));

    SELECT is_system INTO v_is_system FROM public.user_roles 
    WHERE lower(role_code) = v_clean_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;

    IF v_is_system THEN
        RAISE EXCEPTION 'CANNOT_DELETE_SYSTEM_ROLE';
    END IF;

    DELETE FROM public.user_roles WHERE lower(role_code) = v_clean_code;
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'ROLE_IN_USE';
END;
$$;
