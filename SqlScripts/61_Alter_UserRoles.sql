-- 1. Alter Table user_roles
-- Assuming Foreign Keys point to role_code (Business Key), we can recreate the ID.

DO $$
BEGIN
    -- 1. Check/Drop existing role_id if it's not consistent (e.g. UUID)
    -- We want it to be INT IDENTITY. simpler to drop and recreate if it exists and is not referenced.
    -- Safety check: ensure no FK constraint references role_id directly (usually role_code is used).
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_roles' AND column_name = 'role_id') THEN
        ALTER TABLE public.user_roles DROP COLUMN role_id CASCADE;
    END IF;

    -- 2. Add role_id as IDENTITY
    ALTER TABLE public.user_roles ADD COLUMN role_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

    -- 3. Ensure role_code is Unique and Not Null
    ALTER TABLE public.user_roles ALTER COLUMN role_code SET NOT NULL;
    
    -- Add Constraint if not exists
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_user_roles_code') THEN
        ALTER TABLE public.user_roles ADD CONSTRAINT uk_user_roles_code UNIQUE (role_code);
    END IF;

    -- 4. Ensure created_at / updated_at / is_system
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_roles' AND column_name = 'is_system') THEN
         ALTER TABLE public.user_roles ADD COLUMN is_system BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_roles' AND column_name = 'created_at') THEN
         ALTER TABLE public.user_roles ADD COLUMN created_at TIMESTAMPTZ DEFAULT now();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_roles' AND column_name = 'updated_at') THEN
         ALTER TABLE public.user_roles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
    END IF;

END $$;

-- 5. Create Trigger Function for Audit (if not exists generic one, create specific)
-- Assuming we want specific simple one for now or reuse metadata one if available. 
-- Let's make a specific one to be safe and atomic.

CREATE OR REPLACE FUNCTION public.fn_trg_user_roles_update_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_roles_audit ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit
    BEFORE UPDATE ON public.user_roles
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_user_roles_update_audit();

-- 6. Protection Trigger for System Roles
CREATE OR REPLACE FUNCTION public.fn_trg_user_roles_protect_system()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        IF OLD.is_system THEN
            RAISE EXCEPTION 'CANNOT_DELETE_SYSTEM_ROLE';
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.is_system AND (OLD.role_code <> NEW.role_code) THEN
             RAISE EXCEPTION 'CANNOT_MODIFY_SYSTEM_ROLE_CODE';
        END IF;
        -- Allow renaming description? Maybe, but usually system roles are fixed.
        -- Let's block critical changes.
    END IF;
    RETURN NULL; -- Ignored for AFTER triggers, but this should be BEFORE
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_roles_protect_system ON public.user_roles;
CREATE TRIGGER trg_user_roles_protect_system
    BEFORE DELETE OR UPDATE ON public.user_roles
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_user_roles_protect_system();


-- 7. Update Functions
-- List Roles
DROP FUNCTION IF EXISTS public.fn_app_list_roles();
CREATE OR REPLACE FUNCTION public.fn_app_list_roles()
RETURNS TABLE (
    role_id int,
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

-- Create Role (No ID input)
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
