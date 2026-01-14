-- Stored Procedure to Hard Delete User
CREATE OR REPLACE PROCEDURE public.sp_app_delete_user(
    p_user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email text;
BEGIN
    -- Get email for logging/error reporting
    SELECT email INTO v_email FROM public.app_users WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- Attempt Delete. 
    -- Logic: app_user_role_map has ON DELETE CASCADE (confirmed in analysis).
    -- Audit_login has ON DELETE CASCADE (confirmed in analysis).
    -- Referential Integrity (Logos, etc.) has ON DELETE RESTRICT (confirmed in analysis).
    -- So if there are blocking dependencies, this DELETE statement will fail with a FK violation, which is what we want.

    DELETE FROM public.app_users WHERE user_id = p_user_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        -- Re-raise with a friendly code that UI can intercept
        RAISE EXCEPTION 'USER_HAS_DEPENDENCIES';
END;
$$;
