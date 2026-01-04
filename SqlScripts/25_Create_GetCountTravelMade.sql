-- Function: get_count_travel_made
-- Description: Conta i viaggi effettuati da un cliente per una specifica azienda.
-- Converted from Oracle procedure GET_COUNT_TRAVEL_MADE.
CREATE OR REPLACE FUNCTION get_count_travel_made(
        p_cliente_id integer,
        p_azienda_id integer
    ) RETURNS integer LANGUAGE plpgsql AS $function$
DECLARE l_ret integer;
BEGIN
SELECT COUNT(1) INTO l_ret
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
WHERE cv.cliente_id_fk = p_cliente_id
    AND dv.data_viaggio_effettuato_sino = 'Y';
RETURN l_ret;
END;
$function$;