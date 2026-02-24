-- ============================================================================
-- fn_get_smtp_config_for_email
-- Recupera la configurazione SMTP attiva (outbound) per un'azienda.
-- Usata dal servizio C# per inviare email tramite SMTP aziendale.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_smtp_config_for_email(
    p_azienda_id integer
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'smtp_id', s.smtp_id,
        'host', s.host,
        'port', s.port,
        'username', s.username,
        'password', s.password_enc->>'value',
        'use_tls', s.use_tls,
        'use_starttls', s.use_starttls,
        'security_method', s.security_method,
        'from_name', s.from_name,
        'from_email', s.from_email
    )
    INTO v_result
    FROM ana_aziende_smtp s
    WHERE s.azienda_fk = p_azienda_id
      AND s.is_active = TRUE
      AND s.status = 'active'
      AND s.config_type = 'outbound'
    ORDER BY s.priority ASC
    LIMIT 1;

    RETURN v_result; -- NULL se nessuna config trovata
END;
$function$;

COMMENT ON FUNCTION fn_get_smtp_config_for_email(integer) IS
'Recupera la prima configurazione SMTP outbound attiva per azienda. Ritorna NULL se non configurata.';
