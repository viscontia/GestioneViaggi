-- Fix FK Constraints to ensure roles cannot be deleted if in use.

DO $$
BEGIN
    -- 1. App User Role Map: Change CASCADE to RESTRICT
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_user_role_map_role_code_fkey') THEN
        ALTER TABLE public.app_user_role_map DROP CONSTRAINT app_user_role_map_role_code_fkey;
    END IF;

    ALTER TABLE public.app_user_role_map
    ADD CONSTRAINT app_user_role_map_role_code_fkey
    FOREIGN KEY (role_code)
    REFERENCES public.user_roles (role_code)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

    -- 2. Sys Menu Role Grants: Change CASCADE to RESTRICT
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sys_menu_role_grants_role_code_fkey') THEN
        ALTER TABLE public.sys_menu_role_grants DROP CONSTRAINT sys_menu_role_grants_role_code_fkey;
    END IF;

    -- If this table exists (it should), fix it too.
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sys_menu_role_grants') THEN
         ALTER TABLE public.sys_menu_role_grants
         ADD CONSTRAINT sys_menu_role_grants_role_code_fkey
         FOREIGN KEY (role_code)
         REFERENCES public.user_roles (role_code)
         ON DELETE RESTRICT
         ON UPDATE CASCADE;
    END IF;

END $$;
