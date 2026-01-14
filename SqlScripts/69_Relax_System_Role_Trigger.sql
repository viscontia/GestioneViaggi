-- Relax trigger to allow deleting system roles (except superadmin)

CREATE OR REPLACE FUNCTION public.fn_trg_user_roles_protect_system()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- CHANGED: Only protect 'superadmin' specifically.
        -- Allow deleting other system roles (the SP might have extra checks, but the trigger was too strict).
        IF lower(OLD.role_code) = 'superadmin' THEN
            RAISE EXCEPTION 'CANNOT_DELETE_SUPERADMIN_ROLE';
        END IF;

        -- Deprecated check: 
        -- IF OLD.is_system THEN RAISE EXCEPTION 'CANNOT_DELETE_SYSTEM_ROLE'; END IF;
        
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Prevent changing the role_code of system roles (identity protection)
        IF OLD.is_system AND (lower(OLD.role_code) <> lower(NEW.role_code)) THEN
             RAISE EXCEPTION 'CANNOT_MODIFY_SYSTEM_ROLE_CODE';
        END IF;
        
        -- Allow other updates (is_system flag, name, etc.)
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;
