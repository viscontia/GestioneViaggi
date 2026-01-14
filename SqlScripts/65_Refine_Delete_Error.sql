-- Refine Delete Role Procedure to ensure correct error propagation

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

    -- Attempt deletion
    DELETE FROM public.user_roles WHERE lower(role_code) = v_clean_code;
    
EXCEPTION
    WHEN foreign_key_violation THEN
        -- Explicitly raise with a known code/message for the C# service to catch
        RAISE EXCEPTION 'ROLE_IN_USE' USING ERRCODE = '23503';
    WHEN OTHERS THEN
         -- Re-raise other errors
        RAISE;
END;
$$;
