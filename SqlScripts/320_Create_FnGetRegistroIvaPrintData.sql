-- ============================================================================
-- fn_get_registro_iva_print_data
-- Funzione "Fat Init" per la stampa Registro IVA.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_registro_iva_print_data(
    p_azienda_id INTEGER,
    p_periodo_da DATE,
    p_periodo_a DATE
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_items JSONB;
BEGIN
    -- 1. Recupero Info Azienda
    SELECT jsonb_build_object(
        'ragione_sociale', ragione_sociale,
        'telefono', telefono,
        'email', email,
        'sito_web', sito_web,
        'piva', piva,
        'logo_data', logo_data
    ) INTO v_azienda_info
    FROM get_company_print_info(p_azienda_id);

    -- 2. Recupero Dettagli Registro IVA
    SELECT jsonb_agg(t) INTO v_items
    FROM (
        SELECT * FROM fn_get_registro_iva(p_azienda_id, p_periodo_da, p_periodo_a)
    ) t;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'items', COALESCE(v_items, '[]'::jsonb)
    );
END;
$function$;
