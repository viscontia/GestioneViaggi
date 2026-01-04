-- Function: get_all_participants_travel
-- Description: Restituisce la lista completa dei partecipanti ad un viaggio (Data Viaggio).
-- Order: Alfabetico per Cognome.
-- Parameters:
--   p_data_viaggio_id: ID del viaggio (ana_date_viaggi)
-- Returns: Table con dettaglio partecipanti (Nominativo) - Piloti indicati con (P)
DROP FUNCTION IF EXISTS get_all_participants_travel(integer);
CREATE OR REPLACE FUNCTION get_all_participants_travel(p_data_viaggio_id integer) RETURNS TABLE (nominativo text) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT (
        c.cliente_cognome || ' ' || c.cliente_nome || CASE
            WHEN atp.tipo_partecipante_pilota IS TRUE THEN ' (P)'
            ELSE ''
        END
    )::text as nominativo
FROM mov_clienti_viaggi cv
    JOIN ana_clienti c ON cv.cliente_id_fk = c.cliente_id
    LEFT JOIN ana_tipo_partecipante atp ON cv.tipo_partecipante_id_fk = atp.tipo_partecipante_id
WHERE cv.data_viaggio_id_fk = p_data_viaggio_id
ORDER BY c.cliente_cognome ASC,
    c.cliente_nome ASC;
END;
$function$;