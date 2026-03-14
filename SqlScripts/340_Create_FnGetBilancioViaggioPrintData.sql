-- ============================================================================
-- fn_get_bilancio_viaggio_print_data
-- Funzione "Fat Init" per il Bilancio Viaggio (Singolo o Annuale).
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_bilancio_viaggio_print_data(
    p_azienda_id INTEGER,
    p_viaggio_id INTEGER DEFAULT NULL,
    p_data_viaggio_id INTEGER DEFAULT NULL,
    p_data_da DATE DEFAULT NULL,
    p_data_a DATE DEFAULT NULL,
    p_anno INTEGER DEFAULT NULL,
    p_valuta_target_id INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_dettagli JSONB;
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

    -- 2. Recupero Dettagli
    -- Se p_anno è valorizzato, usiamo la versione annuale
    IF p_anno IS NOT NULL THEN
        SELECT jsonb_agg(t) INTO v_dettagli
        FROM (
            SELECT * FROM fn_get_bilancio_annuale_viaggi(p_azienda_id, p_anno)
        ) t;
    ELSE
        SELECT jsonb_agg(t) INTO v_dettagli
        FROM (
            SELECT * FROM fn_get_bilancio_viaggio(p_azienda_id, p_viaggio_id, p_data_viaggio_id, p_data_da, p_data_a)
        ) t;
    END IF;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'dettagli', COALESCE(v_dettagli, '[]'::jsonb)
    );
END;
$function$;
