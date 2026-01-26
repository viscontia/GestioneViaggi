CREATE OR REPLACE FUNCTION public.get_participants_sorted(p_data_viaggio_id integer)
 RETURNS TABLE(
    viaggio_id integer, 
    data_id integer, 
    cliente_id integer, 
    nominativo text, 
    tipo_partecipante_id integer, 
    ruolo text, 
    note text, 
    cane_sino character varying, 
    intolleranze text, 
    mezzo_dettagli text, 
    cliente_pilota_id integer, 
    grouping_key integer, 
    is_pilot boolean, 
    telefono text, 
    email text, 
    residenza text, 
    codice_fiscale text, 
    data_nascita date, 
    luogo_nascita text,
    -- New Columns
    nazionalita text,
    tipo_documento text,
    numero_documento text,
    rilasciato_da text,
    data_rilascio date,
    data_scadenza date
 )
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH participants_with_pilot AS (
        SELECT
            v.viaggio_id_fk,
            v.data_viaggio_id_fk,
            v.cliente_id_fk,
            (c.cliente_cognome || ' ' || c.cliente_nome)::TEXT AS nom,
            v.tipo_partecipante_id_fk,
            tp.tipo_partecipante_descrizione::TEXT,
            v.mov_cliente_viaggio_note::TEXT,
            v.mov_cliente_viaggio_cane_sino,
            c.cliente_intolleranza::TEXT,
            get_mezzo_by_pilot(v.viaggio_id_fk, v.data_viaggio_id_fk, v.cliente_id_fk)::TEXT,
            v.cliente_pilota_id_fk,
            CASE
                WHEN v.cliente_pilota_id_fk IS NOT NULL AND v.cliente_pilota_id_fk > 0 THEN v.cliente_pilota_id_fk
                WHEN tp.tipo_partecipante_pilota = true THEN v.cliente_id_fk
                ELSE 0
            END AS grp_key,
            tp.tipo_partecipante_pilota, -- is_pilot flag
            c.cliente_cognome AS cognome,
            c.cliente_nome AS nome,
            -- Existing Columns
            COALESCE(c.cliente_preftelint || ' ', '') || COALESCE(c.cliente_telefono, '')::TEXT AS tel,
            COALESCE(c.cliente_email, '')::TEXT AS mail,
            CONCAT_WS(' - ', NULLIF(c.cliente_indirizzo_residenza, ''), com_res.comune_descrizione || COALESCE(' (' || prov_res.provincia_sigla || ')', ''))::TEXT AS res,
            COALESCE(c.cliente_codicefiscale, '')::TEXT AS cf,
            c.cliente_data_nascita,
            COALESCE(com_nas.comune_descrizione, '') || COALESCE(' (' || prov_nas.provincia_sigla || ')', '')::TEXT AS lnascita,
            -- New Columns
            COALESCE(UPPER(ec.nationality), 'ITALIANA')::TEXT as nazionalita, 
            COALESCE(c.cliente_tipodoc_identita, '')::TEXT as tdoc,
            COALESCE(c.cliente_documento_numero, '')::TEXT as ndoc,
            COALESCE(c.cliente_documento_rilasciato_da, '')::TEXT as released_by,
            c.cliente_documento_rilasciato_data as released_on,
            c.cliente_documento_rilasciato_scadenza as expires_on,

            -- Recupera cognome del pilota per ordinamento
            CASE
                WHEN v.cliente_pilota_id_fk IS NOT NULL AND v.cliente_pilota_id_fk > 0 THEN
                    (SELECT cp.cliente_cognome FROM ana_clienti cp WHERE cp.cliente_id = v.cliente_pilota_id_fk)
                WHEN tp.tipo_partecipante_pilota = true THEN
                    c.cliente_cognome
                ELSE
                    'ZZZZZ'  -- Non assegnati vanno alla fine
            END AS pilot_cognome
        FROM mov_clienti_viaggi v
        JOIN ana_clienti c ON v.cliente_id_fk = c.cliente_id
        JOIN ana_tipo_partecipante tp ON v.tipo_partecipante_id_fk = tp.tipo_partecipante_id
        LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
        LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
        LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
        LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
        -- Nationality Joins
        LEFT JOIN ana_geo_regioni_ita reg_nas ON prov_nas.regione_id_fk = reg_nas.regione_id
        LEFT JOIN eba_countries ec ON reg_nas.country_id_fk = ec.country_id
        WHERE v.data_viaggio_id_fk = p_data_viaggio_id
    )
    SELECT 
        cte.viaggio_id_fk,
        cte.data_viaggio_id_fk,
        cte.cliente_id_fk,
        cte.nom,
        cte.tipo_partecipante_id_fk,
        cte.tipo_partecipante_descrizione,
        cte.mov_cliente_viaggio_note,
        cte.mov_cliente_viaggio_cane_sino,
        cte.cliente_intolleranza,
        cte.get_mezzo_by_pilot,
        cte.cliente_pilota_id_fk,
        cte.grp_key,
        cte.tipo_partecipante_pilota,
        cte.tel,
        cte.mail,
        cte.res,
        cte.cf,
        cte.cliente_data_nascita,
        cte.lnascita,
        cte.nazionalita,
        cte.tdoc,
        cte.ndoc,
        cte.released_by,
        cte.released_on,
        cte.expires_on
    FROM participants_with_pilot cte
    ORDER BY
        pilot_cognome,  -- Prima per cognome pilota
        CASE WHEN cliente_id_fk = grp_key THEN 0 ELSE 1 END,  -- Pilota prima (0), passeggeri dopo (1)
        cognome,  -- Poi per cognome passeggero
        nome;     -- Infine per nome
END;
$function$
