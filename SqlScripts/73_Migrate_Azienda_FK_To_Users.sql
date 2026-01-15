-- 1. Add azienda_id column to app_users
ALTER TABLE public.app_users 
ADD COLUMN azienda_id INT NULL;

-- 2. Add Foreign Key
ALTER TABLE public.app_users
ADD CONSTRAINT fk_app_users_azienda
FOREIGN KEY (azienda_id)
REFERENCES public.ana_aziende (azienda_id)
ON DELETE RESTRICT;

-- 3. Migrate Data from app_user_role_map
UPDATE public.app_users u
SET azienda_id = m.azienda_id
FROM public.app_user_role_map m
WHERE u.user_id = m.user_id;

-- 4. Create Integrity Trigger Function
-- This ensures that:
--   - If role is 'superadmin', azienda_id MUST be NULL.
--   - If role is NOT 'superadmin', azienda_id MUST be NOT NULL.
--   - Checks both insert/update on app_users AND insert/update on app_user_role_map (to catch role changes).

CREATE OR REPLACE FUNCTION public.fn_enforce_user_azienda_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role_code text;
    v_azienda_id int;
    v_user_id uuid;
BEGIN
    -- Determine Context
    -- If triggered app_users, we have NEW.azienda_id, need to find role.
    -- If triggered by app_user_role_map, we have NEW.role_code, need to find azienda_id from app_users (or NEW.user_id if triggered there).
    
    IF TG_TABLE_NAME = 'app_users' THEN
        v_user_id := NEW.user_id;
        v_azienda_id := NEW.azienda_id;
        -- Fetch role from map
        SELECT role_code INTO v_role_code FROM public.app_user_role_map WHERE user_id = v_user_id;
        
        -- If user is new and map not yet inserted, we might not find role. 
        -- In sp_app_create_user, user is inserted FIRST, then Map.
        -- So on INSERT app_users, role is NULL. We can't validate yet.
        -- Validation must occur DEFERRED or allowed to be null initially?
        -- ACTUALLY: The requirement is STRICT. 
        -- But physically, we insert User then Map.
        -- On Update, map exists.

        IF TG_OP = 'INSERT' THEN
             -- Allow unrestricted insert, reliance on Map trigger or SP logic?
             -- A strict constraint impossible if table B (Roles) holds the condition for Table A (Users).
             -- UNLESS we verify later.
             RETURN NEW; 
        END IF;

    ELSIF TG_TABLE_NAME = 'app_user_role_map' THEN
        v_user_id := NEW.user_id;
        v_role_code := NEW.role_code;
        -- Fetch azienda from users
        SELECT azienda_id INTO v_azienda_id FROM public.app_users WHERE user_id = v_user_id;
    END IF;

    -- Validation Logic (If we have both Role and Azienda)
    IF v_role_code IS NOT NULL THEN
        IF v_role_code = 'superadmin' THEN
            IF v_azienda_id IS NOT NULL THEN
                RAISE EXCEPTION 'INTEGRITY_VIOLATION: Superadmin must not have an Azienda assigned.';
            END IF;
        ELSE
            IF v_azienda_id IS NULL THEN
                RAISE EXCEPTION 'INTEGRITY_VIOLATION: Users with role % must have an Azienda assigned.', v_role_code;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 5. Attach Triggers
-- Note: On INSERT app_users, we don't have role yet. Logic is deferred to Map insert.
-- On INSERT app_user_role_map, we check consistency.
-- On UPDATE app_users (changing azienda), we check consistency.
-- On UPDATE app_user_role_map (changing role), we check consistency.

CREATE TRIGGER trg_check_azienda_integrity_users
AFTER UPDATE OF azienda_id ON public.app_users
FOR EACH ROW
EXECUTE FUNCTION public.fn_enforce_user_azienda_integrity();

CREATE TRIGGER trg_check_azienda_integrity_roles
AFTER INSERT OR UPDATE OF role_code ON public.app_user_role_map
FOR EACH ROW
EXECUTE FUNCTION public.fn_enforce_user_azienda_integrity();

-- 6. Cleanup app_user_role_map
-- Drop OLD constraint first
ALTER TABLE public.app_user_role_map DROP CONSTRAINT IF EXISTS check_role_azienda_consistency;
-- Drop FK column
ALTER TABLE public.app_user_role_map DROP COLUMN IF EXISTS azienda_id CASCADE;
