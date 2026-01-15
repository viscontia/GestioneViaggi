-- Enhanced User Deletion with "Orphan Reference" Protection

CREATE OR REPLACE PROCEDURE public.sp_app_delete_user(IN p_user_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email text;
    v_count int;
BEGIN
    -- 1. Check User Existence
    SELECT email INTO v_email FROM public.app_users WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- 2. Explicit Check: ana_aziende_logo (Has FK, but we want a custom message)
    SELECT count(*) INTO v_count FROM public.ana_aziende_logo 
    WHERE created_by = p_user_id OR updated_by = p_user_id OR approved_by = p_user_id;
    
    IF v_count > 0 THEN
        RAISE EXCEPTION 'USER_HAS_OPERATIONAL_DATA';
    END IF;

    -- 3. Explicit Check: Orphaned References (No FKs yet)
    -- Checking: ana_viaggi, ana_clienti, mov_clienti_viaggi, mov_clienti_alloggi
    
    -- ana_viaggi
    SELECT count(*) INTO v_count FROM public.ana_viaggi WHERE created_by = p_user_id OR updated_by = p_user_id;
    IF v_count > 0 THEN RAISE EXCEPTION 'USER_HAS_OPERATIONAL_DATA'; END IF;

    -- ana_clienti
    SELECT count(*) INTO v_count FROM public.ana_clienti WHERE created_by = p_user_id OR updated_by = p_user_id;
    IF v_count > 0 THEN RAISE EXCEPTION 'USER_HAS_OPERATIONAL_DATA'; END IF;

    -- mov_clienti_viaggi
    SELECT count(*) INTO v_count FROM public.mov_clienti_viaggi WHERE created_by = p_user_id OR updated_by = p_user_id;
    IF v_count > 0 THEN RAISE EXCEPTION 'USER_HAS_OPERATIONAL_DATA'; END IF;

    -- mov_clienti_alloggi
    SELECT count(*) INTO v_count FROM public.mov_clienti_alloggi WHERE created_by = p_user_id OR updated_by = p_user_id;
    IF v_count > 0 THEN RAISE EXCEPTION 'USER_HAS_OPERATIONAL_DATA'; END IF;

    -- 4. Safe Delete (Cascades to roles, audit_login, preferences)
    DELETE FROM public.app_users WHERE user_id = p_user_id;
    
EXCEPTION
    WHEN foreign_key_violation THEN
        -- Fallback for any other constraint we missed
        RAISE EXCEPTION 'USER_HAS_DEPENDENCIES';
END;
$$;
