-- 1. Update fn_app_login to support auditing
-- We add p_ip and p_user_agent optional parameters to allow capturing client info
DROP FUNCTION IF EXISTS public.fn_app_login(citext, text);

CREATE OR REPLACE FUNCTION public.fn_app_login(
    p_email citext, 
    p_password text,
    p_ip inet DEFAULT inet_client_addr(), -- Defaults to connection IP
    p_user_agent text DEFAULT 'Unknown'
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
  v_ok   boolean;
  v_user_id uuid;
BEGIN
  -- 1. Fetch User
  SELECT u.user_id, u.email, u.nome, u.cognome, u.password_hash, u.last_login_at,
         m.role_code, r.role_name, 
         u.azienda_id,
         COALESCE(u.is_active, TRUE) AS is_active
    INTO v_user
  FROM public.app_users u
  LEFT JOIN public.app_user_role_map m ON m.user_id = u.user_id
  LEFT JOIN public.user_roles r        ON r.role_code = m.role_code
  WHERE lower(u.email) = lower(p_email)
  ORDER BY u.created_at DESC
  LIMIT 1;

  -- 2. User Not Found
  IF NOT FOUND THEN
     -- Cannot log to audit_login because user_id (FK) is required and unknown.
     -- Security Note: We do not log invalid emails to avoid enumeration/spam in logs if not mapped to a user.
     RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  v_user_id := v_user.user_id;

  -- 3. Check Active
  IF (v_user.is_active IS NOT TRUE) THEN
    -- Audit Lockout/Fail
    INSERT INTO public.audit_login (user_id, event_type, ip, user_agent, created_at)
    VALUES (v_user_id, 'LOCKOUT', p_ip, p_user_agent, now());

    RETURN jsonb_build_object('success', false, 'error', 'USER_SUSPENDED_OR_INACTIVE');
  END IF;

  -- 4. Verify Password
  SELECT (v_user.password_hash = crypt(p_password, v_user.password_hash)) INTO v_ok;
  
  IF NOT v_ok THEN
    -- Audit Fail
    INSERT INTO public.audit_login (user_id, event_type, ip, user_agent, created_at)
    VALUES (v_user_id, 'LOGIN_FAIL', p_ip, p_user_agent, now());

    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PASSWORD');
  END IF;

  -- 5. Success
  -- Audit Success
  INSERT INTO public.audit_login (user_id, event_type, ip, user_agent, created_at)
  VALUES (v_user_id, 'LOGIN_SUCCESS', p_ip, p_user_agent, now());

  -- Update last login
  UPDATE public.app_users SET last_login_at = now() WHERE user_id = v_user.user_id;

  -- Return User Data
  RETURN jsonb_build_object(
    'success', true,
    'user', jsonb_build_object(
      'user_id',       v_user.user_id,
      'tenant_id',     '',
      'email',         v_user.email,
      'nome',          v_user.nome,
      'cognome',       v_user.cognome,
      'role_code',     v_user.role_code,
      'role_name',     v_user.role_name,
      'azienda_id',    v_user.azienda_id,
      'last_login_at', v_user.last_login_at
    )
  );
END;
$function$;

-- 2. Create Cleanup Function
CREATE OR REPLACE FUNCTION public.cleanup_audit_login(p_days int)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_rows_deleted int;
BEGIN
    DELETE FROM public.audit_login
    WHERE created_at < (now() - (p_days || ' days')::interval);
    
    GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
    
    RETURN v_rows_deleted;
END;
$function$;

-- 3. Grant permissions (if needed, assuming admin_viaggi owns schemas or is superuser context)
-- GRANT EXECUTE ON FUNCTION public.cleanup_audit_login(int) TO admin_viaggi;
