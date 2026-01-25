-- Function: get_pilots_grouped_by_vehicle
-- Description: Restituisce SOLO i piloti raggruppati per Marca e Modello del mezzo con tutti i dati anagrafici
-- Parameters:
--   p_data_viaggio_id: ID del viaggio specifico (ana_date_viaggi)
-- Returns: Table con piloti ordinati per marca, modello, cognome
-- Used by: TravelPrintService.cs per stampa scheda viaggio - sezione veicoli

DROP FUNCTION IF EXISTS get_pilots_grouped_by_vehicle(integer);

CREATE OR REPLACE FUNCTION get_pilots_grouped_by_vehicle(p_data_viaggio_id integer)
RETURNS TABLE(
    viaggio_id integer,
    data_id integer,
    cliente_id integer,
    nominativo text,
    marca text,
    modello text,
    targa text,
    telefono text,
    email text,
    residenza text,
    codice_fiscale text,
    data_nascita date,
    luogo_nascita text
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        v.viaggio_id_fk::integer,
        v.data_viaggio_id_fk::integer,
        v.cliente_id_fk::integer,
        (c.cliente_cognome || ' ' || c.cliente_nome)::text AS nominativo,
        COALESCE(m.ana_mezzi_descrizione, 'N/D')::text AS marca,
        COALESCE(mod_v.mezzo_modello_descrizione, 'N/D')::text AS modello,
        COALESCE(v.mov_cliente_viaggio_targa_mezzo, '')::text AS targa,
        (COALESCE(c.cliente_preftelint || ' ', '') || COALESCE(c.cliente_telefono, ''))::text AS telefono,
        COALESCE(c.cliente_email, '')::text AS email,
        CONCAT_WS(' - ', NULLIF(c.cliente_indirizzo_residenza, ''), com_res.comune_descrizione || COALESCE(' (' || prov_res.provincia_sigla || ')', ''))::text AS residenza,
        COALESCE(c.cliente_codicefiscale, '')::text AS codice_fiscale,
        c.cliente_data_nascita,
        (COALESCE(com_nas.comune_descrizione, '') || COALESCE(' (' || prov_nas.provincia_sigla || ')', ''))::text AS luogo_nascita
    FROM mov_clienti_viaggi v
    JOIN ana_clienti c ON v.cliente_id_fk = c.cliente_id
    JOIN ana_tipo_partecipante tp ON v.tipo_partecipante_id_fk = tp.tipo_partecipante_id
    LEFT JOIN ana_mezzi m ON v.ana_mezzi_id_fk = m.ana_mezzi_id
    LEFT JOIN ana_mezzi_modelli mod_v ON v.mezzo_modello_id_fk = mod_v.mezzo_modello_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    WHERE v.data_viaggio_id_fk = p_data_viaggio_id
      AND tp.tipo_partecipante_pilota = true  -- SOLO PILOTI
    ORDER BY
        COALESCE(m.ana_mezzi_descrizione, 'N/D'),  -- Ordina per marca
        COALESCE(mod_v.mezzo_modello_descrizione, 'N/D'),  -- Poi per modello
        c.cliente_cognome,  -- Poi per cognome
        c.cliente_nome;     -- Infine per nome
END;
$function$;
