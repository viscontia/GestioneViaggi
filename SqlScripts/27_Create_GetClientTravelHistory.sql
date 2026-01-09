-- Function: get_client_travel_history
-- Description: Restituisce lo storico viaggi di un cliente con dettagli dettagliati, utilizzando la function get_all_travel_detail.
-- Parameters:
--   p_cliente_id: ID del cliente
--   p_azienda_id: ID dell'azienda (contesto)
-- Returns: Table con dettagli viaggio e status
DROP FUNCTION IF EXISTS get_client_travel_history(integer, integer);
CREATE OR REPLACE FUNCTION get_client_travel_history(
        p_cliente_id integer,
        p_azienda_id integer
    ) RETURNS TABLE (
        data_viaggio_id integer,
        titolo text,
        tipo text,
        data_inizio date,
        data_fine date,
        km integer,
        giorni integer,
        notti integer,
        status_code integer,
        -- 0=Futuro, 1=Fatto, 2=Non Partecipato
        status_desc text,
        ruolo text,
        trattamento text,
        pernottamento text,
        costo_pilota integer,
        costo_passeggero integer
    ) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT d.data_viaggio_id,
    d.titolo,
    d.tipo,
    d.data_inizio,
    d.data_fine,
    d.km,
    d.giorni,
    d.notti,
    CASE
        WHEN d.effettuato_sino = 'N' AND d.data_inizio < CURRENT_DATE THEN 2
        WHEN d.effettuato_sino = 'Y'
        OR d.data_inizio < CURRENT_DATE THEN 1
        ELSE 0
    END as status_code,
    CASE
        WHEN d.effettuato_sino = 'N' AND d.data_inizio < CURRENT_DATE THEN 'Non Partecipato'
        WHEN d.effettuato_sino = 'Y'
        OR d.data_inizio < CURRENT_DATE THEN 'Effettuato'
        ELSE 'In Programma'
    END as status_desc,
    atp.tipo_partecipante_descrizione::text as ruolo,
    d.trattamento,
    d.pernottamento,
    d.costo_pilota,
    d.costo_passeggero
FROM mov_clienti_viaggi cv
    CROSS JOIN LATERAL get_all_travel_detail(cv.data_viaggio_id_fk) d
    LEFT JOIN ana_tipo_partecipante atp ON cv.tipo_partecipante_id_fk = atp.tipo_partecipante_id
WHERE cv.cliente_id_fk = p_cliente_id
ORDER BY d.data_inizio DESC;
END;
$function$;