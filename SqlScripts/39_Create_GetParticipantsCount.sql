-- Function: get_participants_count
-- Description: Returns the total number of participants for a specific trip date.
-- Usata per ottenere il conteggio rapido senza caricare i nomi.
CREATE OR REPLACE FUNCTION public.get_participants_count(p_data_viaggio_id integer) RETURNS integer LANGUAGE plpgsql AS $function$
DECLARE v_count integer;
BEGIN
SELECT COUNT(*) INTO v_count
FROM mov_clienti_viaggi
WHERE data_viaggio_id_fk = p_data_viaggio_id;
RETURN v_count;
END;
$function$;