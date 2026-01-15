-- Fix type mismatch in fn_app_list_users
-- Explicitly casting all string columns to TEXT to match RETURNS TABLE definition

DROP FUNCTION IF EXISTS public.fn_app_list_users();

CREATE OR REPLACE FUNCTION public.fn_app_list_users()
RETURNS TABLE(
    user_id uuid, 
    email text, 
    nome text, 
    cognome text, 
    role_code text, -- Changed to text for safety
    role_name text, -- Changed to text for safety
    azienda_id integer, 
    ragione_sociale text, 
    is_active boolean, 
    last_login_at timestamp with time zone, 
    created_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        u.email::text, -- Explicit cast from citext
        u.nome::text,
        u.cognome::text,
        rm.role_code::text, -- Explicit cast from varchar(50)
        r.role_name::text,  -- Explicit cast from varchar(100)
        rm.azienda_id,
        a.ragione_sociale::text, -- Explicit cast from varchar(255)
        COALESCE(u.is_active, true),
        u.last_login_at,
        u.created_at
    FROM public.app_users u
    LEFT JOIN public.app_user_role_map rm ON u.user_id = rm.user_id
    LEFT JOIN public.user_roles r ON rm.role_code = r.role_code
    LEFT JOIN public.ana_aziende a ON rm.azienda_id = a.azienda_id
    ORDER BY u.created_at DESC;
END;
$$;
