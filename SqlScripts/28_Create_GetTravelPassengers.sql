-- Function: get_travel_passengers
-- Description: Restituisce la lista dei passeggeri per un viaggio, escluso il cliente specificato.
-- Parameters:
--   p_data_viaggio_id: ID del viaggio
--   p_exclude_client_id: ID del cliente da escludere (il richiedente)
-- Returns: Table con dettaglio passeggeri (Nome completo, Ruolo)
CREATE OR REPLACE FUNCTION get_travel_passengers(
        p_data_viaggio_id integer,
        p_exclude_client_id integer
    ) RETURNS TABLE (nominativo text, ruolo text) LANGUAGE plpgsql AS $function$
DECLARE v_pilot_id integer;
BEGIN -- 1. Determina l'ID del Pilota di riferimento per il cliente escluso (il cliente "viewing")
-- Se sono un passeggero, il mio pilota è cliente_pilota_id_fk.
-- Se sono il pilota (o solo), cliente_pilota_id_fk è NULL, quindi il pilota sono io (cliente_id_fk).
SELECT COALESCE(cliente_pilota_id_fk, cliente_id_fk) INTO v_pilot_id
FROM mov_clienti_viaggi
WHERE data_viaggio_id_fk = p_data_viaggio_id
    AND cliente_id_fk = p_exclude_client_id;
RETURN QUERY
SELECT (
        CASE
            WHEN cv.cliente_pilota_id_fk IS NULL THEN 'Pilota: '
            ELSE ''
        END || c.cliente_cognome || ' ' || c.cliente_nome
    )::text as nominativo,
    atp.tipo_partecipante_descrizione::text as ruolo
FROM mov_clienti_viaggi cv
    JOIN ana_clienti c ON cv.cliente_id_fk = c.cliente_id
    LEFT JOIN ana_tipo_partecipante atp ON cv.tipo_partecipante_id_fk = atp.tipo_partecipante_id
WHERE cv.data_viaggio_id_fk = p_data_viaggio_id
    AND cv.cliente_id_fk != p_exclude_client_id -- Filtra solo chi appartiene allo stesso "Gruppo Auto" (Stesso Pilota)
    AND COALESCE(cv.cliente_pilota_id_fk, cv.cliente_id_fk) = v_pilot_id
ORDER BY c.cliente_cognome,
    c.cliente_nome;
END;
$function$;