-- Function: get_datetrips_fromtrip
-- Description: Returns all management fields for a given trip ID + vehicle count, ordered by start date DESC.
DROP FUNCTION IF EXISTS get_datetrips_fromtrip(integer);
CREATE OR REPLACE FUNCTION get_datetrips_fromtrip(p_viaggio_id integer) RETURNS TABLE (
        data_viaggio_id integer,
        viaggio_id_fk integer,
        data_viaggio_data_inizio timestamp without time zone,
        data_viaggio_data_fine timestamp without time zone,
        data_viaggio_effettuato_sino character varying,
        data_viaggio_costo_pilota integer,
        data_viaggio_costo_passeggero integer,
        data_viaggio_costo_passeggero_auto_guida integer,
        data_viaggio_costo_bambino_0_2 integer,
        data_viaggio_costo_bambino_2_6 integer,
        data_viaggio_costo_bambino_6_12 integer,
        data_viaggio_note character varying,
        azienda_id integer,
        tot_mezzi integer
    ) LANGUAGE sql STABLE AS $function$
SELECT data_viaggio_id,
    viaggio_id_fk,
    data_viaggio_data_inizio,
    data_viaggio_data_fine,
    data_viaggio_effettuato_sino,
    data_viaggio_costo_pilota,
    data_viaggio_costo_passeggero,
    data_viaggio_costo_passeggero_auto_guida,
    data_viaggio_costo_bambino_0_2,
    data_viaggio_costo_bambino_2_6,
    data_viaggio_costo_bambino_6_12,
    data_viaggio_note,
    azienda_id,
    get_totmezzi_dataviaggio(viaggio_id_fk, data_viaggio_id) as tot_mezzi
FROM ana_date_viaggi
WHERE viaggio_id_fk = p_viaggio_id
ORDER BY data_viaggio_data_inizio DESC;
$function$;