-- Stored Procedure to Update User
CREATE OR REPLACE PROCEDURE public.sp_app_update_user(
    p_user_id uuid,
    p_email text,
    p_password text, -- Pass NULL or Empty to keep existing
    p_nome text,
    p_cognome text,
    p_role_code text,
    p_azienda_id int DEFAULT NULL,
    p_is_active boolean DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_password_hash text;
BEGIN
    -- 1. Check if user exists
    IF NOT EXISTS (SELECT 1 FROM public.app_users WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- 2. Check overlap (if email changed)
    IF EXISTS (SELECT 1 FROM public.app_users WHERE lower(email) = lower(p_email) AND user_id <> p_user_id) THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    END IF;

    -- 3. Prepare Password Update
    IF p_password IS NOT NULL AND length(trim(p_password)) > 0 THEN
        v_new_password_hash := crypt(p_password, gen_salt('bf'));
    ELSE
        -- Keep existing hash
        SELECT password_hash INTO v_new_password_hash FROM public.app_users WHERE user_id = p_user_id;
    END IF;

    -- 4. Update User Data
    UPDATE public.app_users
    SET
        email = p_email::citext,
        password_hash = v_new_password_hash,
        nome = p_nome,
        cognome = p_cognome,
        is_active = COALESCE(p_is_active, is_active),
        updated_at = now()
    WHERE user_id = p_user_id;

    -- 5. Update Role Mapping
    -- We assume 1 role per user as per current architecture (app_user_role_map is 1:1 logically or we treat it as main role)
    -- First, check if map exists
    IF EXISTS (SELECT 1 FROM public.app_user_role_map WHERE user_id = p_user_id) THEN
        UPDATE public.app_user_role_map
        SET
            role_code = p_role_code,
            azienda_id = p_azienda_id
        WHERE user_id = p_user_id;
    ELSE
        -- Should not happen for valid users, but handle safe
        INSERT INTO public.app_user_role_map (user_id, role_code, azienda_id)
        VALUES (p_user_id, p_role_code, p_azienda_id);
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'INVALID_ROLE_OR_AZIENDA';
END;
$$;
