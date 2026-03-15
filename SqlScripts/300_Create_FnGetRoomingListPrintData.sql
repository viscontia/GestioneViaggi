-- Function: fn_get_rooming_list_print_data
-- Description: Fat Init function to get all data for Rooming List print in a single call.
-- Parameters:
--   p_data_viaggio_id: ID of the travel date (ana_date_viaggi)
-- Returns: JSONB containing Header, Company, and Participants

CREATE OR REPLACE FUNCTION fn_get_rooming_list_print_data(p_data_viaggio_id integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_header jsonb;
    v_company jsonb;
    v_participants jsonb;
    v_azienda_id integer;
BEGIN
    -- 1. Get Header Info
    SELECT json_build_object(
        'data_viaggio_id', data_viaggio_id,
        'viaggio_id', viaggio_id,
        'titolo', titolo,
        'descrizione_estesa', descrizione_estesa,
        'nazione', nazione,
        'data_inizio', data_inizio,
        'data_fine', data_fine,
        'note_data_viaggio', note_data_viaggio,
        'tipo', tipo,
        'giorni', giorni,
        'notti', notti,
        'trattamento', trattamento,
        'pasti_al_sacco', pasti_al_sacco,
        'km', km,
        'azienda_id', azienda_id
    ) INTO v_header
    FROM get_all_travel_detail(p_data_viaggio_id);

    -- Get azienda_id for company info
    v_azienda_id := (v_header->>'azienda_id')::integer;

    -- 2. Get Company Info
    IF v_azienda_id IS NOT NULL THEN
        SELECT json_build_object(
            'ragione_sociale', ragione_sociale,
            'telefono', telefono,
            'email', email,
            'sito_web', sito_web,
            'piva', piva,
            'logo_data', logo_data -- Already base64 from get_company_print_info
        ) INTO v_company
        FROM get_company_print_info(v_azienda_id);
    ELSE
        v_company := '{}'::jsonb;
    END IF;

    -- 3. Get Participants (Rooming List Data)
    SELECT json_agg(t) INTO v_participants
    FROM (
        SELECT * FROM get_rooming_list_data(p_data_viaggio_id)
    ) t;

    -- Combine everything
    RETURN jsonb_build_object(
        'Header', v_header,
        'Company', v_company,
        'Participants', COALESCE(v_participants, '[]'::jsonb)
    );
END;
$function$;
