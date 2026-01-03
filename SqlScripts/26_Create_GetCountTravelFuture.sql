-- Function: get_count_travel_future
-- Description: Conta i viaggi futuri (non ancora effettuati e con data inizio > oggi) prenotati da un cliente per una specifica azienda.
-- Converted from Oracle procedure GET_COUNT_TRAVEL_FUTURE.
CREATE OR REPLACE FUNCTION get_count_travel_future(
        p_cliente_id integer,
        p_azienda_id integer
    ) RETURNS integer LANGUAGE plpgsql AS $function$
DECLARE l_ret integer;
BEGIN
SELECT COUNT(1) INTO l_ret
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
WHERE cv.cliente_id_fk = p_cliente_id
    AND dv.azienda_id = p_azienda_id
    AND dv.data_viaggio_effettuato_sino = 'N'
    AND dv.data_viaggio_data_inizio > CURRENT_DATE;
RETURN l_ret;
END;
$function$;