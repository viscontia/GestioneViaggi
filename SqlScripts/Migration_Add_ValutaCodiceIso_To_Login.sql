-- =============================================
-- Migration: Add valuta_codice_iso to fn_app_login
-- Data: 2026-02-08
-- Descrizione: Aggiorna fn_app_login per includere valuta_codice_iso nel JSON restituito
--              tramite JOIN con ana_valute
-- =============================================

CREATE OR REPLACE FUNCTION public.fn_app_login(p_email citext, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
  v_ok   boolean;
BEGIN
  -- Query aggiornata per includere valuta_default_id e valuta_codice_iso
  SELECT u.user_id, u.email, u.nome, u.cognome, u.password_hash, u.last_login_at,
         m.role_code, r.role_name,
         u.azienda_id,
         u.valuta_default_id,
         v.valuta_codice_iso, -- [AGGIUNTO] Codice ISO della valuta
         COALESCE(u.is_active, TRUE) AS is_active
    INTO v_user
  FROM public.app_users u
  LEFT JOIN public.app_user_role_map m ON m.user_id = u.user_id
  LEFT JOIN public.user_roles r        ON r.role_code = m.role_code
  LEFT JOIN public.ana_valute v        ON v.valuta_id = u.valuta_default_id -- [AGGIUNTO] JOIN con ana_valute
  WHERE lower(u.email) = lower(p_email)
  ORDER BY u.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF (v_user.is_active IS NOT TRUE) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_SUSPENDED_OR_INACTIVE');
  END IF;

  -- Verifica password
  SELECT (v_user.password_hash = crypt(p_password, v_user.password_hash)) INTO v_ok;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PASSWORD');
  END IF;

  -- Aggiorna ultimo login
  UPDATE public.app_users SET last_login_at = now() WHERE user_id = v_user.user_id;

  -- Restituisce dati utente (con valuta_default_id e valuta_codice_iso)
  RETURN jsonb_build_object(
    'success', true,
    'user', jsonb_build_object(
      'user_id',           v_user.user_id,
      'tenant_id',         '',
      'email',             v_user.email,
      'nome',              v_user.nome,
      'cognome',           v_user.cognome,
      'role_code',         v_user.role_code,
      'role_name',         v_user.role_name,
      'azienda_id',        v_user.azienda_id,
      'last_login_at',     v_user.last_login_at,
      'valuta_default_id', v_user.valuta_default_id,
      'valuta_codice_iso', COALESCE(v_user.valuta_codice_iso, 'EUR') -- [AGGIUNTO] Codice ISO con fallback a EUR
    )
  );
END;
$function$;

-- =============================================
-- Aggiorna anche fn_app_login_text (versione text)
-- =============================================

CREATE OR REPLACE FUNCTION public.fn_app_login_text(p_email text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
  v_ok   boolean;
BEGIN
  -- Query aggiornata per includere valuta_default_id e valuta_codice_iso
  SELECT u.user_id, u.email, u.nome, u.cognome, u.password_hash, u.last_login_at,
         m.role_code, r.role_name,
         u.azienda_id,
         u.valuta_default_id,
         v.valuta_codice_iso, -- [AGGIUNTO] Codice ISO della valuta
         COALESCE(u.is_active, TRUE) AS is_active
    INTO v_user
  FROM public.app_users u
  LEFT JOIN public.app_user_role_map m ON m.user_id = u.user_id
  LEFT JOIN public.user_roles r        ON r.role_code = m.role_code
  LEFT JOIN public.ana_valute v        ON v.valuta_id = u.valuta_default_id -- [AGGIUNTO] JOIN con ana_valute
  WHERE lower(u.email) = lower(p_email)
  ORDER BY u.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF (v_user.is_active IS NOT TRUE) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_SUSPENDED_OR_INACTIVE');
  END IF;

  -- Verifica password
  SELECT (v_user.password_hash = crypt(p_password, v_user.password_hash)) INTO v_ok;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PASSWORD');
  END IF;

  -- Aggiorna ultimo login
  UPDATE public.app_users SET last_login_at = now() WHERE user_id = v_user.user_id;

  -- Restituisce dati utente (con valuta_default_id e valuta_codice_iso)
  RETURN jsonb_build_object(
    'success', true,
    'user', jsonb_build_object(
      'user_id',           v_user.user_id,
      'tenant_id',         '',
      'email',             v_user.email,
      'nome',              v_user.nome,
      'cognome',           v_user.cognome,
      'role_code',         v_user.role_code,
      'role_name',         v_user.role_name,
      'azienda_id',        v_user.azienda_id,
      'last_login_at',     v_user.last_login_at,
      'valuta_default_id', v_user.valuta_default_id,
      'valuta_codice_iso', COALESCE(v_user.valuta_codice_iso, 'EUR') -- [AGGIUNTO] Codice ISO con fallback a EUR
    )
  );
END;
$function$;

-- =============================================
-- Verifica
-- =============================================
-- SELECT fn_app_login_text('test@example.com', 'password_qui');
