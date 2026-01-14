-- Fix Trigger Return Values
-- BEFORE triggers must return NEW (Update/Insert) or OLD (Delete) to proceed.
-- Returning NULL cancels the operation silently.

CREATE OR REPLACE FUNCTION public.fn_trg_user_roles_protect_system()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        IF OLD.is_system THEN
            RAISE EXCEPTION 'CANNOT_DELETE_SYSTEM_ROLE';
        END IF;
        RETURN OLD; -- Crucial: Return OLD to proceed with deletion
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.is_system AND (OLD.role_code <> NEW.role_code) THEN
             RAISE EXCEPTION 'CANNOT_MODIFY_SYSTEM_ROLE_CODE';
        END IF;
        RETURN NEW; -- Crucial: Return NEW to proceed with update
    END IF;
    
    RETURN NULL; -- Should not be reached for DELETE/UPDATE triggers
END;
$$ LANGUAGE plpgsql;
