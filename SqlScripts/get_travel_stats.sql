CREATE OR REPLACE FUNCTION get_travel_stats(p_data_viaggio_id INT)
RETURNS TABLE (
    total_participants INT,
    total_crews INT,
    total_vehicles INT
) AS $$
DECLARE
    v_total_participants INT;
    v_total_crews INT;
BEGIN
    -- Calculate Total Participants
    SELECT COUNT(*) INTO v_total_participants
    FROM mov_clienti_viaggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id;

    -- Calculate Crews (Unique non-zero grouping keys)
    -- Logic matches get_participants_sorted: Grouping Key is PilotID (if exists) or Self ID (if Pilot)
    WITH raw_data AS (
        SELECT 
            CASE
                WHEN m.cliente_pilota_id_fk IS NOT NULL AND m.cliente_pilota_id_fk > 0 THEN m.cliente_pilota_id_fk
                WHEN tp.tipo_partecipante_pilota = true THEN m.cliente_id_fk
                ELSE 0
            END as grp_key
        FROM mov_clienti_viaggi m
        JOIN ana_tipo_partecipante tp ON m.tipo_partecipante_id_fk = tp.tipo_partecipante_id
        WHERE m.data_viaggio_id_fk = p_data_viaggio_id
    )
    SELECT COUNT(DISTINCT grp_key) INTO v_total_crews
    FROM raw_data
    WHERE grp_key > 0;

    -- Assuming 1 Vehicle per Crew
    RETURN QUERY SELECT 
        COALESCE(v_total_participants, 0), 
        COALESCE(v_total_crews, 0), 
        COALESCE(v_total_crews, 0); -- total_vehicles same as crews
END;
$$ LANGUAGE plpgsql;
