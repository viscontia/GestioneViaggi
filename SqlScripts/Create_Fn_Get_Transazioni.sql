-- Function per recuperare tutte le transazioni con dati correlati
-- Function per recuperare tutte le transazioni con dati correlati e filtri
CREATE OR REPLACE FUNCTION fn_get_all_transazioni(
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_data_transazione date DEFAULT NULL,
    p_solo_da_pagare boolean DEFAULT FALSE
)
RETURNS TABLE (
    transazione_id integer,
    transazione_azienda_id integer,
    transazione_viaggio_id integer,
    transazione_data_viaggio_id integer,
    transazione_fornitore_id integer,
    transazione_tipo_movimento character varying(10),
    transazione_importo numeric(10,2),
    transazione_valuta_id integer,
    transazione_importo_eur numeric(10,2),
    transazione_data date,
    transazione_data_scadenza date,
    transazione_data_pagamento date,
    transazione_stato character varying(20),
    transazione_causale text,
    transazione_note text,
    transazione_numero_documento character varying(50),
    transazione_data_documento date,
    transazione_fattura_fk integer,
    created_at timestamp with time zone,
    created_by character varying(50),
    updated_at timestamp with time zone,
    updated_by character varying(50),
    azienda_codice text,
    fornitore_ragione_sociale character varying(255),
    valuta_codice_iso character varying(3),
    viaggio_descrizione character varying(100),
    data_viaggio_inizio date
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.transazione_id,
        t.transazione_azienda_id,
        t.transazione_viaggio_id,
        t.transazione_data_viaggio_id,
        t.transazione_fornitore_id,
        t.transazione_tipo_movimento,
        t.transazione_importo,
        t.transazione_valuta_id,
        t.transazione_importo_eur,
        t.transazione_data,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_note,
        t.transazione_numero_documento,
        t.transazione_data_documento,
        t.transazione_fattura_fk,
        t.created_at,
        t.created_by,
        t.updated_at,
        t.updated_by,
        t.transazione_azienda_id::text as azienda_codice,
        f.ragione_sociale as fornitore_ragione_sociale,
        v.valuta_codice_iso,
        vi.viaggio_descrizione_breve as viaggio_descrizione,
        dv.data_viaggio_data_inizio as data_viaggio_inizio
    FROM mov_transazioni t
    JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
    JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE 
        (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id) AND
        (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id) AND
        (p_data_transazione IS NULL OR t.transazione_data = p_data_transazione) AND
        (p_solo_da_pagare IS FALSE OR t.transazione_stato = 'DA_PAGARE')
    ORDER BY 
        t.transazione_azienda_id ASC, 
        vi.viaggio_descrizione_breve ASC, 
        dv.data_viaggio_data_inizio DESC, 
        t.transazione_data DESC, 
        t.created_at DESC;
END;
$$;

-- Function per recuperare transazioni di una specifica azienda con filtri
CREATE OR REPLACE FUNCTION fn_get_transazioni_by_azienda(
    p_azienda_id integer,
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_data_transazione date DEFAULT NULL,
    p_solo_da_pagare boolean DEFAULT FALSE
)
RETURNS TABLE (
    transazione_id integer,
    transazione_azienda_id integer,
    transazione_viaggio_id integer,
    transazione_data_viaggio_id integer,
    transazione_fornitore_id integer,
    transazione_tipo_movimento character varying(10),
    transazione_importo numeric(10,2),
    transazione_valuta_id integer,
    transazione_importo_eur numeric(10,2),
    transazione_data date,
    transazione_data_scadenza date,
    transazione_data_pagamento date,
    transazione_stato character varying(20),
    transazione_causale text,
    transazione_note text,
    transazione_numero_documento character varying(50),
    transazione_data_documento date,
    transazione_fattura_fk integer,
    created_at timestamp with time zone,
    created_by character varying(50),
    updated_at timestamp with time zone,
    updated_by character varying(50),
    azienda_codice text,
    fornitore_ragione_sociale character varying(255),
    valuta_codice_iso character varying(3),
    viaggio_descrizione character varying(100),
    data_viaggio_inizio date
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.transazione_id,
        t.transazione_azienda_id,
        t.transazione_viaggio_id,
        t.transazione_data_viaggio_id,
        t.transazione_fornitore_id,
        t.transazione_tipo_movimento,
        t.transazione_importo,
        t.transazione_valuta_id,
        t.transazione_importo_eur,
        t.transazione_data,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_note,
        t.transazione_numero_documento,
        t.transazione_data_documento,
        t.transazione_fattura_fk,
        t.created_at,
        t.created_by,
        t.updated_at,
        t.updated_by,
        t.transazione_azienda_id::text as azienda_codice,
        f.ragione_sociale as fornitore_ragione_sociale,
        v.valuta_codice_iso,
        vi.viaggio_descrizione_breve as viaggio_descrizione,
        dv.data_viaggio_data_inizio as data_viaggio_inizio
    FROM mov_transazioni t
    JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
    JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE 
        t.transazione_azienda_id = p_azienda_id AND
        (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id) AND
        (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id) AND
        (p_data_transazione IS NULL OR t.transazione_data = p_data_transazione) AND
        (p_solo_da_pagare IS FALSE OR t.transazione_stato = 'DA_PAGARE')
    ORDER BY 
        vi.viaggio_descrizione_breve ASC, 
        dv.data_viaggio_data_inizio DESC, 
        t.transazione_data DESC, 
        t.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION fn_get_all_transazioni() TO app_superadmin;
GRANT EXECUTE ON FUNCTION fn_get_transazioni_by_azienda(integer) TO app_superadmin;
GRANT EXECUTE ON FUNCTION fn_get_all_transazioni() TO app_user;
GRANT EXECUTE ON FUNCTION fn_get_transazioni_by_azienda(integer) TO app_user;
