-- Function: fn_get_travel_print_data
-- Description: Consolidated "Fat Init" function for travel printing data.
-- Aggregates data from multiple sources into a single JSONB object.

DROP FUNCTION IF EXISTS fn_get_travel_print_data(INT);

CREATE OR REPLACE FUNCTION fn_get_travel_print_data(p_data_viaggio_id INT)
RETURNS JSONB AS $$
DECLARE
    v_header JSONB;
    v_company JSONB;
    v_participants JSONB;
    v_stats JSONB;
    v_pilots_by_vehicle JSONB;
    v_azienda_id INT;
BEGIN
    -- 1. Get Header Info
    SELECT to_jsonb(t) INTO v_header FROM (
        SELECT * FROM get_all_travel_detail(p_data_viaggio_id)
    ) t;
    
    IF v_header IS NULL THEN
        RETURN NULL;
    END IF;

    v_azienda_id := (v_header->>'azienda_id')::INT;

    -- 2. Get Company Info
    SELECT to_jsonb(t) INTO v_company FROM (
        SELECT * FROM get_company_print_info(v_azienda_id)
    ) t;

    -- 3. Get Participants Sorted
    SELECT jsonb_agg(to_jsonb(t)) INTO v_participants FROM (
        SELECT * FROM get_participants_sorted(p_data_viaggio_id)
    ) t;

    -- 4. Get Stats
    SELECT to_jsonb(t) INTO v_stats FROM (
        SELECT * FROM get_travel_stats(p_data_viaggio_id)
    ) t;

    -- 5. Get Pilots Grouped by Vehicle
    SELECT jsonb_agg(to_jsonb(t)) INTO v_pilots_by_vehicle FROM (
        SELECT * FROM get_pilots_grouped_by_vehicle(p_data_viaggio_id)
    ) t;

    -- Final JSON Construction
    RETURN jsonb_build_object(
        'Header', v_header,
        'Company', v_company,
        'Participants', v_participants,
        'Stats', v_stats,
        'PilotsByVehicle', v_pilots_by_vehicle
    );
END;
$$ LANGUAGE plpgsql;
