-- Function: get_client_travel_history
-- Description: Restituisce lo storico viaggi di un cliente con dettagli e stato calcolato.
-- Parameters:
--   p_cliente_id: ID del cliente
--   p_azienda_id: ID dell'azienda (contesto)
-- Returns: Table con dettagli viaggio e status (0=Futuro, 1=Fatto, 2=Non Partecipato)
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
        -- 0=Futuro (Giallo), 1=Fatto (Verde), 2=Non Partecipato (Rosso)
        status_desc text,
        ruolo text
    ) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT dv.data_viaggio_id,
    av.viaggio_descrizione_breve::text,
    atv.tipo_viaggi_descrizione::text,
    dv.data_viaggio_data_inizio,
    dv.data_viaggio_data_fine,
    av.viaggio_num_km,
    av.viaggio_numero_giorni,
    av.viaggio_numero_notti,
    CASE
        -- Se iscritto ma 'N' in effettuato -> Non Partecipato (Rosso)
        WHEN dv.data_viaggio_effettuato_sino = 'N' THEN 2 -- Se iscritto e 'Y', oppure data inizio passata -> Fatto (Verde)
        -- Nota: La logica "Fatto" include sia il flag esplicito 'Y' che i viaggi passati
        WHEN dv.data_viaggio_effettuato_sino = 'Y'
        OR dv.data_viaggio_data_inizio < CURRENT_DATE THEN 1 -- Altrimenti -> Futuro (Giallo)
        ELSE 0
    END as status_code,
    CASE
        WHEN dv.data_viaggio_effettuato_sino = 'N' THEN 'Non Partecipato'
        WHEN dv.data_viaggio_effettuato_sino = 'Y'
        OR dv.data_viaggio_data_inizio < CURRENT_DATE THEN 'Effettuato'
        ELSE 'In Programma'
    END as status_desc,
    atp.tipo_partecipante_descrizione::text as ruolo
FROM mov_clienti_viaggi cv
    JOIN ana_date_viaggi dv ON cv.data_viaggio_id_fk = dv.data_viaggio_id
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    LEFT JOIN ana_tipo_viaggi atv ON av.viaggio_tipo_viaggio_fk = atv.tipo_viaggi_id
    LEFT JOIN ana_tipo_partecipante atp ON cv.tipo_partecipante_id_fk = atp.tipo_partecipante_id
WHERE cv.cliente_id_fk = p_cliente_id
ORDER BY dv.data_viaggio_data_inizio DESC;
END;
$function$;