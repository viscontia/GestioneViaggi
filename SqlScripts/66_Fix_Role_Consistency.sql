-- Fix overly restrictive check constraint that blocks Custom Roles.
-- Previously, it whitelistied ONLY system roles.

ALTER TABLE public.app_user_role_map DROP CONSTRAINT IF EXISTS check_role_azienda_consistency;

-- New logic:
-- 1. Global System Roles: Must have NULL azienda_id
-- 2. Company System Roles: Must have NOT NULL azienda_id
-- 3. Custom Roles (Anything else): We assume they are global for now (NULL azienda_id) or we can allow both.
--    Let's allow NULL for Custom Roles to start with.
--    Actually, safer ensuring consistency:
--    If we check against 'app_roles' (user_roles) is_system flag, we'd need a Trigger.
--    For a Check Constraint, we have to hardcode or rely on naming conventions?
--    Current constraint uses hardcoded list. Let's keep it but add "OR role_code NOT IN (...)"?
--    Better: Just relax it to allow "NOT IN (System Company Roles) AND azienda_id IS NULL"?

ALTER TABLE public.app_user_role_map
ADD CONSTRAINT check_role_azienda_consistency
CHECK (
    (
        -- Case 1: Company Roles (Strict List) -> Must have Azienda
        (role_code::text = ANY (ARRAY['azienda_admin', 'azienda_user', 'azienda_readonly']))
        AND 
        (azienda_id IS NOT NULL)
    )
    OR
    (
        -- Case 2: Everything else (Global System + Custom) -> Must NOT have Azienda
        -- We explicitly list the ones that MUST be null? 
        -- Or we just say: If NOT in Case 1, then Azienda IS NULL.
        (role_code::text <> ALL (ARRAY['azienda_admin', 'azienda_user', 'azienda_readonly']))
        AND
        (azienda_id IS NULL)
    )
);
