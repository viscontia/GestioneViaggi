-- Script per creare la function fn_get_viaggi_with_transactions
-- Restituisce solo i viaggi che hanno almeno un movimento contabile

DROP FUNCTION IF EXISTS fn_get_viaggi_with_transactions(integer);

CREATE OR REPLACE FUNCTION fn_get_viaggi_with_transactions(p_azienda_id integer)
RETURNS TABLE (
    viaggio_id integer,
    viaggio_descrizione_breve character varying(255),
    viaggio_descrizione_estesa text,
    viaggio_numero_giorni integer,
    viaggio_numero_notti integer,
    viaggio_pasti_al_sacco character(1),
    viaggio_num_km integer,
    viaggio_note text,
    viaggio_link character varying(500),
    viaggio_nazione_fk integer,
    viaggio_tipo_viaggio_fk integer,
    viaggio_tipo_trattamento_fk integer,
    viaggio_tipo_pernottamento_fk integer,
    viaggio_tipo_avvicinamento_fk integer,
    azienda_id integer,
    created_by character varying(50),
    created timestamp with time zone,
    updated_by character varying(50),
    updated timestamp with time zone,
    nazione_nome character varying(100),
    tipo_viaggi_descrizione character varying(100),
    tipo_trattamento_descrizione character varying(100),
    ana_tipo_pernottamento_descrizione character varying(100),
    tipo_avvicinamento_descrizione character varying(100),
    azienda_nome character varying(255),
    matching_dates_count integer
) AS $function$
BEGIN
    RETURN QUERY
    SELECT v.viaggio_id,
           v.viaggio_descrizione_breve,
           v.viaggio_descrizione_estesa,
           v.viaggio_numero_giorni,
           v.viaggio_numero_notti,
           v.viaggio_pasti_al_sacco,
           v.viaggio_num_km,
           v.viaggio_note,
           v.viaggio_link,
           v.viaggio_nazione_fk,
           v.viaggio_tipo_viaggio_fk,
           v.viaggio_tipo_trattamento_fk,
           v.viaggio_tipo_pernottamento_fk,
           v.viaggio_tipo_avvicinamento_fk,
           v.azienda_id,
           v.created_by,
           v.created,
           v.updated_by,
           v.updated,
           c.name as nazione_nome,
           t.tipo_viaggi_descrizione,
           tr.tipo_trattamento_descrizione,
           p.ana_tipo_pernottamento_descrizione,
           a.tipo_avvicinamento_descrizione,
           az.ragione_sociale as azienda_nome,
           (
                SELECT COUNT(1)::integer
                FROM ana_date_viaggi d
                WHERE d.viaggio_id_fk = v.viaggio_id
           ) as matching_dates_count
    FROM ana_viaggi v
    LEFT JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
    LEFT JOIN ana_tipo_viaggi t ON v.viaggio_tipo_viaggio_fk = t.tipo_viaggi_id
    LEFT JOIN ana_tipo_trattamento tr ON v.viaggio_tipo_trattamento_fk = tr.tipo_trattamento_id
    LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
    LEFT JOIN ana_tipo_avvicinamento a ON v.viaggio_tipo_avvicinamento_fk = a.tipo_avvicinamento_id
    LEFT JOIN ana_aziende az ON v.azienda_id = az.azienda_id
    WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR v.azienda_id = p_azienda_id)
      AND EXISTS (
          SELECT 1
          FROM mov_transazioni tx
          JOIN ana_tipi_causali tcx ON tx.transazione_causale_tipo_id = tcx.causale_id
          JOIN ana_date_viaggi dv ON tx.transazione_data_viaggio_id = dv.data_viaggio_id
          WHERE dv.viaggio_id_fk = v.viaggio_id
            AND tx.transazione_stato != 'ANNULLATO'
            AND tcx.causale_is_documento = TRUE
      )
    ORDER BY c.name, t.tipo_viaggi_descrizione, v.viaggio_descrizione_breve;
END;
$function$ LANGUAGE plpgsql STABLE;
