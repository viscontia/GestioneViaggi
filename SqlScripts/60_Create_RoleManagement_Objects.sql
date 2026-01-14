-- Function to list roles
CREATE OR REPLACE FUNCTION public.fn_app_list_roles()
RETURNS TABLE (
    role_id uuid,
    role_code varchar(50),
    role_name varchar(100),
    is_system boolean,
    created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.role_id,
        r.role_code,
        r.role_name,
        r.is_system,
        r.created_at
    FROM public.user_roles r
    ORDER BY r.role_name;
END;
$$;

-- Procedure to Create Role
CREATE OR REPLACE PROCEDURE public.sp_app_create_role(
    p_role_code varchar(50),
    p_role_name varchar(100)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_roles (role_code, role_name, is_system)
    VALUES (p_role_code, p_role_name, false);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'ROLE_CODE_ALREADY_EXISTS';
END;
$$;

-- Procedure to Update Role
CREATE OR REPLACE PROCEDURE public.sp_app_update_role(
    p_role_code varchar(50), -- PK (natural key in this system)
    p_role_name varchar(100)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system boolean;
BEGIN
    SELECT is_system INTO v_is_system FROM public.user_roles WHERE role_code = p_role_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;

    IF v_is_system THEN
        RAISE EXCEPTION 'CANNOT_MODIFY_SYSTEM_ROLE';
    END IF;

    UPDATE public.user_roles
    SET role_name = p_role_name, updated_at = now()
    WHERE role_code = p_role_code;
END;
$$;

-- Procedure to Delete Role
CREATE OR REPLACE PROCEDURE public.sp_app_delete_role(
    p_role_code varchar(50)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_system boolean;
BEGIN
    SELECT is_system INTO v_is_system FROM public.user_roles WHERE role_code = p_role_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROLE_NOT_FOUND';
    END IF;

    IF v_is_system THEN
        RAISE EXCEPTION 'CANNOT_DELETE_SYSTEM_ROLE';
    END IF;

    -- FKs will handle blocking deletion if assigned to users
    DELETE FROM public.user_roles WHERE role_code = p_role_code;
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'ROLE_IN_USE';
END;
$$;
