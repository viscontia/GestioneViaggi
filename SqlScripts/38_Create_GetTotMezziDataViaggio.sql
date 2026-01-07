-- Function: get_totmezzi_dataviaggio
-- Description: Counts the number of participating vehicles (ana_mezzi_id_fk IS NOT NULL) for a specific trip and date.
CREATE OR REPLACE FUNCTION get_totmezzi_dataviaggio(p_viaggio_id integer, p_data_viaggio_id integer) RETURNS integer LANGUAGE sql STABLE AS $function$
SELECT CAST(COUNT(*) AS integer)
FROM mov_clienti_viaggi
WHERE viaggio_id_fk = p_viaggio_id
    AND data_viaggio_id_fk = p_data_viaggio_id
    AND ana_mezzi_id_fk IS NOT NULL;
$function$;