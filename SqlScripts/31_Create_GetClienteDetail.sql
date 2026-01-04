-- Function: get_cliente_detail
-- Description: Restituisce TUTTE le informazioni anagrafiche e documentali di un cliente, incluse le decodifiche di comuni e province.
-- Parameters:
--   p_cliente_id: ID univoco del cliente.
-- Returns: Table con tutti i campi di ana_clienti + lookup.
DROP FUNCTION IF EXISTS get_cliente_detail(integer);
CREATE OR REPLACE FUNCTION get_cliente_detail(p_cliente_id integer) RETURNS TABLE (
        cliente_id integer,
        cliente_titolo character varying(10),
        cliente_cognome character varying(50),
        cliente_nome character varying(50),
        cliente_sesso character(1),
        cliente_comune_residenza_fk integer,
        cliente_indirizzo_residenza character varying(100),
        cliente_comune_nascita_fk integer,
        cliente_data_nascita date,
        cliente_preftelint character varying(5),
        cliente_telefono character varying(15),
        cliente_email character varying(100),
        cliente_codicefiscale character varying(16),
        cliente_iban character varying(34),
        cliente_foto bytea,
        cliente_carta_identita bytea,
        cliente_tipodoc_identita character varying(10),
        cliente_documento_numero character varying(50),
        cliente_documento_rilasciato_da character varying(100),
        cliente_documento_rilasciato_data date,
        cliente_documento_rilasciato_scadenza date,
        cliente_note text,
        cliente_foto_mimetype character varying(50),
        cliente_foto_filename character varying(255),
        cliente_foto_charset character varying(20),
        cliente_foto_upd_date date,
        cliente_documento_mimetype character varying(50),
        cliente_documento_filename character varying(255),
        cliente_documento_chartset character varying(20),
        -- Mantenuto typo 'chartset' per compatibilità DB
        cliente_documento_upd_date date,
        cliente_intolleranza text,
        azienda_fk integer,
        created_by character varying(50),
        created timestamp with time zone,
        updated_by character varying(50),
        updated timestamp with time zone,
        azienda_ragione_sociale character varying(100),
        comune_nascita_nome character varying(255),
        comune_nascita_provincia character varying(2),
        comune_residenza_nome character varying(255),
        comune_residenza_provincia character varying(2)
    ) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT c.cliente_id,
    c.cliente_titolo,
    c.cliente_cognome,
    c.cliente_nome,
    c.cliente_sesso,
    c.cliente_comune_residenza_fk,
    c.cliente_indirizzo_residenza,
    c.cliente_comune_nascita_fk,
    c.cliente_data_nascita,
    c.cliente_preftelint,
    c.cliente_telefono,
    c.cliente_email,
    c.cliente_codicefiscale,
    c.cliente_iban,
    c.cliente_foto,
    c.cliente_carta_identita,
    c.cliente_tipodoc_identita,
    c.cliente_documento_numero,
    c.cliente_documento_rilasciato_da,
    c.cliente_documento_rilasciato_data,
    c.cliente_documento_rilasciato_scadenza,
    c.cliente_note,
    c.cliente_foto_mimetype,
    c.cliente_foto_filename,
    c.cliente_foto_charset,
    c.cliente_foto_upd_date,
    c.cliente_documento_mimetype,
    c.cliente_documento_filename,
    c.cliente_documento_chartset,
    c.cliente_documento_upd_date,
    c.cliente_intolleranza,
    c.azienda_fk,
    c.created_by,
    c.created,
    c.updated_by,
    c.updated,
    a.ragione_sociale::character varying(100),
    com_nas.comune_descrizione::character varying(255),
    prov_nas.provincia_sigla::character varying(2),
    com_res.comune_descrizione::character varying(255),
    prov_res.provincia_sigla::character varying(2)
FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
WHERE c.cliente_id = p_cliente_id;
END;
$function$;