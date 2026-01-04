-- Function: get_exist_travel_customer_by_year
-- Description: Restituisce gli anni in cui un cliente ha viaggi (indipendentemente dallo stato).
-- Parameters:
--   p_cliente_id: ID del cliente
-- Returns: Table con colonna anno (integer)
DROP FUNCTION IF EXISTS get_exist_travel_customer_by_year(integer);
CREATE OR REPLACE FUNCTION get_exist_travel_customer_by_year(p_cliente_id integer) RETURNS TABLE (anno integer) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT DISTINCT EXTRACT(
        YEAR
        FROM dv.data_viaggio_data_inizio
    )::INTEGER as anno
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
WHERE cv.cliente_id_fk = p_cliente_id
ORDER BY anno DESC;
END;
$function$;