-- Function: get_viaggio_partecipanti
-- Description: Retrieves participants for a trip date, grouping them by Pilot.
-- Returns: GruppoId (Pilot Client ID), Pilot Name formatted, List of Passengers formatted.
-- Uses: get_customer_nationality(cliente_id)

CREATE OR REPLACE FUNCTION get_viaggio_partecipanti(p_data_viaggio_id INT)
RETURNS TABLE (
    gruppo_id INT,
    pilota_nominativo TEXT,
    passeggeri_nominativi TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH raw_participants AS (
        SELECT
            m.cliente_pilota_id_fk,
            c.cliente_id,
            c.cliente_cognome AS cognome,
            c.cliente_nome AS nome,
            get_customer_nationality(c.cliente_id) AS nazione_iso,
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.cliente_data_nascita))::INT AS anni,
            COALESCE(tp.tipo_partecipante_pilota, false) AS is_pilota
        FROM mov_clienti_viaggi m
        JOIN ana_clienti c ON m.cliente_id_fk = c.cliente_id
        LEFT JOIN ana_tipo_partecipante tp ON m.tipo_partecipante_id_fk = tp.tipo_partecipante_id
        WHERE m.data_viaggio_id_fk = p_data_viaggio_id
    ),
    formatted_participants AS (
        SELECT
            -- FIX: For Pilots, GroupID is their own ID. For Passengers, it's the FK.
            CASE 
                WHEN is_pilota THEN cliente_id 
                ELSE cliente_pilota_id_fk 
            END as gid,
            is_pilota,
            cognome,
            -- Format: "COGNOME Nome (ISO) Anni XX"
            UPPER(cognome) || ' ' || INITCAP(nome) || 
            ' (' || COALESCE(nazione_iso, '?') || ') ' || 
            'Anni ' || COALESCE(anni::TEXT, '?') AS nominativo_fmt
        FROM raw_participants
    ),
    pilots AS (
        SELECT gid, nominativo_fmt, cognome
        FROM formatted_participants
        WHERE is_pilota = true
    ),
    passengers AS (
        SELECT
            gid,
            STRING_AGG(nominativo_fmt, E'\n' ORDER BY cognome ASC) AS passenger_list
        FROM formatted_participants
        WHERE is_pilota = false
        GROUP BY gid
    )
    SELECT
        p.gid AS gruppo_id,
        p.nominativo_fmt::TEXT AS pilota_nominativo,
        COALESCE(pas.passenger_list, '')::TEXT AS passeggeri_nominativi
    FROM pilots p
    LEFT JOIN passengers pas ON p.gid = pas.gid
    ORDER BY p.cognome ASC;
END;
$$ LANGUAGE plpgsql;