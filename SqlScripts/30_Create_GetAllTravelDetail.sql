-- Function: get_all_travel_detail
-- Description: Restituisce TUTTI i dettagli di un singolo viaggio (Data Viaggio) incrociando ana_date_viaggi, ana_viaggi e i vari lookup.
-- Parameters:
--   p_data_viaggio_id: ID del viaggio specifico (ana_date_viaggi)
-- Returns: Table con campi piatti di tutte le info rilevanti.
DROP FUNCTION IF EXISTS get_all_travel_detail(integer);
CREATE OR REPLACE FUNCTION get_all_travel_detail(p_data_viaggio_id integer) RETURNS TABLE (
        data_viaggio_id integer,
        viaggio_id integer,
        titolo text,
        descrizione_estesa text,
        tipo text,
        nazione text,
        data_inizio date,
        data_fine date,
        effettuato_sino char(1),
        -- Y, N, P
        km integer,
        giorni integer,
        notti integer,
        trattamento text,
        pernottamento text,
        costo_pilota integer,
        costo_passeggero integer,
        costo_passeggero_auto_guida integer,
        costo_bambino_0_2 integer,
        costo_bambino_2_6 integer,
        costo_bambino_6_12 integer,
        pasti_al_sacco char(1),
        tipo_avvicinamento text,
        note_viaggio text,
        note_data_viaggio text,
        link text
    ) LANGUAGE plpgsql AS $function$ BEGIN RETURN QUERY
SELECT dv.data_viaggio_id,
    av.viaggio_id,
    av.viaggio_descrizione_breve::text as titolo,
    av.viaggio_descrizione_estesa::text,
    atv.tipo_viaggi_descrizione::text as tipo,
    ec.name::text as nazione,
    dv.data_viaggio_data_inizio,
    dv.data_viaggio_data_fine,
    dv.data_viaggio_effettuato_sino,
    av.viaggio_num_km,
    av.viaggio_numero_giorni,
    av.viaggio_numero_notti,
    COALESCE(att.tipo_trattamento_descrizione, 'N/D')::text as trattamento,
    COALESCE(atp.ana_tipo_pernottamento_descrizione, 'N/D')::text as pernottamento,
    COALESCE(dv.data_viaggio_costo_pilota, 0),
    COALESCE(dv.data_viaggio_costo_passeggero, 0),
    COALESCE(dv.data_viaggio_costo_passeggero_auto_guida, 0),
    COALESCE(dv.data_viaggio_costo_bambino_0_2, 0),
    COALESCE(dv.data_viaggio_costo_bambino_2_6, 0),
    COALESCE(dv.data_viaggio_costo_bambino_6_12, 0),
    av.viaggio_pasti_al_sacco,
    ata.tipo_avvicinamento_descrizione::text,
    av.viaggio_note::text,
    dv.data_viaggio_note::text,
    av.viaggio_link::text
FROM ana_date_viaggi dv
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    LEFT JOIN ana_tipo_viaggi atv ON av.viaggio_tipo_viaggio_fk = atv.tipo_viaggi_id
    LEFT JOIN eba_countries ec ON av.viaggio_nazione_fk = ec.country_id
    LEFT JOIN ana_tipo_trattamento att ON av.viaggio_tipo_trattamento_fk = att.tipo_trattamento_id
    LEFT JOIN ana_tipo_pernottamento atp ON av.viaggio_tipo_pernottamento_fk = atp.ana_tipo_pernottamento_id
    LEFT JOIN ana_tipo_avvicinamento ata ON av.viaggio_tipo_avvicinamento_fk = ata.tipo_avvicinamento_id
WHERE dv.data_viaggio_id = p_data_viaggio_id;
END;
$function$;