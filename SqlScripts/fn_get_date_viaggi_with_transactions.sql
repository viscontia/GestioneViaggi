-- Function: fn_get_date_viaggi_with_transactions
-- Description: Returns all fields from ana_date_viaggi for a given trip ID, plus a boolean flag indicating if transactions exist.
-- Including stats columns compatible with DataViaggioDTO mapping.

DROP FUNCTION IF EXISTS fn_get_date_viaggi_with_transactions(integer);

CREATE OR REPLACE FUNCTION fn_get_date_viaggi_with_transactions(p_viaggio_id integer)
RETURNS TABLE (
    data_viaggio_id integer,
    viaggio_id_fk integer,
    data_viaggio_data_inizio timestamp without time zone,
    data_viaggio_data_fine timestamp without time zone,
    data_viaggio_effettuato_sino character varying,
    has_transactions boolean
) 
LANGUAGE sql 
STABLE 
AS $function$
    SELECT 
        d.data_viaggio_id,
        d.viaggio_id_fk,
        d.data_viaggio_data_inizio,
        d.data_viaggio_data_fine,
        d.data_viaggio_effettuato_sino,
        EXISTS (
            SELECT 1
            FROM mov_transazioni t
            JOIN ana_tipi_causali tcx ON t.transazione_causale_tipo_id = tcx.causale_id
            WHERE t.transazione_data_viaggio_id = d.data_viaggio_id
              AND t.transazione_stato != 'ANNULLATO'
              AND tcx.causale_is_documento = TRUE
        ) as has_transactions
    FROM ana_date_viaggi d
    WHERE d.viaggio_id_fk = p_viaggio_id
    ORDER BY d.data_viaggio_data_inizio DESC;
$function$;
