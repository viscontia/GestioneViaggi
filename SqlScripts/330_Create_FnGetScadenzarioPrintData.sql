-- ============================================================================
-- fn_get_scadenzario_print_data
-- Funzione "Fat Init" per lo Scadenzario.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_scadenzario_print_data(
    p_azienda_id INTEGER DEFAULT NULL,
    p_controparte_id INTEGER DEFAULT NULL,
    p_causale_ciclo VARCHAR DEFAULT NULL,
    p_urgenza VARCHAR DEFAULT NULL,
    p_data_scadenza_da DATE DEFAULT NULL,
    p_data_scadenza_a DATE DEFAULT NULL,
    p_viaggio_id INTEGER DEFAULT NULL,
    p_solo_con_viaggio BOOLEAN DEFAULT FALSE,
    p_solo_senza_viaggio BOOLEAN DEFAULT FALSE,
    p_raggruppamento VARCHAR DEFAULT 'URGENZA'
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

    -- 2. Recupero Dettagli Scadenzario
    SELECT jsonb_agg(t) INTO v_dettagli
    FROM (
        SELECT * FROM fn_get_scadenzario_stampa(
            p_azienda_id, p_controparte_id, p_causale_ciclo, p_urgenza,
            p_data_scadenza_da, p_data_scadenza_a, p_viaggio_id,
            p_solo_con_viaggio, p_solo_senza_viaggio, p_raggruppamento
        )
    ) t;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'dettagli', COALESCE(v_dettagli, '[]'::jsonb)
    );
END;
$function$;
