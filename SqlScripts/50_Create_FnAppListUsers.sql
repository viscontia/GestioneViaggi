-- Function to list users with Role and Azienda details
CREATE OR REPLACE FUNCTION public.fn_app_list_users()
RETURNS TABLE (
    user_id uuid,
    email text,
    nome text,
    cognome text,
    role_code varchar(50),
    role_name varchar(100),
    azienda_id int,
    ragione_sociale text,
    is_active boolean,
    last_login_at timestamptz,
    created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.email::text,
        u.nome,
        u.cognome,
        rm.role_code,
        r.role_name,
        rm.azienda_id,
        a.ragione_sociale,
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
