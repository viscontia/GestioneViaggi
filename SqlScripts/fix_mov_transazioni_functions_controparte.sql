-- FIX: Aggiorna le function per usare i nomi corretti dei campi (controparte invece di fornitore)
-- Data: 2026-02-17

-- 1. Function per Tutte le Transazioni (SuperAdmin)
DROP FUNCTION IF EXISTS public.fn_get_all_transazioni(integer,integer,date,boolean,integer);

CREATE OR REPLACE FUNCTION public.fn_get_all_transazioni(
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_data_transazione date DEFAULT NULL,
    p_solo_da_pagare boolean DEFAULT false,
    p_causale_tipo_id integer DEFAULT NULL
)
RETURNS TABLE (
    transazione_id integer,
    transazione_azienda_id integer,
    transazione_viaggio_id integer,
    transazione_data_viaggio_id integer,
    transazione_controparte_id integer,
    transazione_causale_tipo_id integer,
    transazione_importo numeric,
    transazione_valuta_id integer,
    transazione_importo_eur numeric,
    transazione_data date,
    transazione_data_scadenza date,
    transazione_data_pagamento date,
    transazione_stato character varying,
    transazione_causale text,
    transazione_note text,
    transazione_numero_documento character varying,
    transazione_data_documento date,
    transazione_fattura_fk integer,
    -- Campi IVA aggiunti
    transazione_aliquota_iva_fk integer,
    transazione_imponibile_eur numeric,
    transazione_iva_eur numeric,
    transazione_lordo_eur numeric,
    transazione_iva_modalita_input character varying,
    transazione_tasso_cambio_applicato numeric,
    transazione_tasso_fonte character varying,
    transazione_tasso_data_validita date,
    -- Audit fields
    created_at timestamp with time zone,
    created_by character varying,
    updated_at timestamp with time zone,
    updated_by character varying,
    azienda_codice text,
    controparte_ragione_sociale character varying,
    valuta_codice_iso character varying,
    causale_descrizione character varying,
    causale_segno integer,
    viaggio_descrizione character varying,
    data_viaggio_inizio date
) 
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.transazione_id,
        t.transazione_azienda_id,
        t.transazione_viaggio_id,
        t.transazione_data_viaggio_id,
        t.transazione_controparte_id,
        t.transazione_causale_tipo_id,
        t.transazione_importo,
        t.transazione_valuta_id,
        t.transazione_importo_eur_old,
        t.transazione_data,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_note,
        t.transazione_numero_documento,
        t.transazione_data_documento,
        t.transazione_fattura_fk,
        -- Campi IVA
        t.transazione_aliquota_iva_fk,
        t.transazione_imponibile_eur,
        t.transazione_iva_eur,
        t.transazione_lordo_eur,
        t.transazione_iva_modalita_input,
        t.transazione_tasso_cambio_applicato,
        t.transazione_tasso_fonte,
        t.transazione_tasso_data_validita,
        -- Audit fields
        t.created_at,
        t.created_by,
        t.updated_at,
        t.updated_by,
        a.azienda_id::text as azienda_codice,
        c.ragione_sociale as controparte_ragione_sociale,
        v.valuta_codice_iso,
        tc.causale_descrizione,
        tc.causale_segno,
        vi.viaggio_descrizione_breve,
        dv.data_viaggio_data_inizio
    FROM mov_transazioni t
    JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE 
        (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id) AND
        (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id) AND
        (p_data_transazione IS NULL OR t.transazione_data = p_data_transazione) AND
        (p_solo_da_pagare IS FALSE OR t.transazione_stato = 'DA_PAGARE') AND
        (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
    ORDER BY 
        t.transazione_azienda_id ASC, 
        vi.viaggio_descrizione_breve ASC, 
        dv.data_viaggio_data_inizio DESC, 
        t.transazione_data DESC, 
        t.created_at DESC;
END;
$function$;

-- 2. Function per Transazioni per Azienda (Multi-tenant)
DROP FUNCTION IF EXISTS public.fn_get_transazioni_by_azienda(integer,integer,integer,date,boolean,integer);
-- Drop anche la versione v2 usata per il debug
DROP FUNCTION IF EXISTS public.fn_get_transazioni_by_azienda_v2(integer,integer,integer,date,boolean,integer);

CREATE OR REPLACE FUNCTION public.fn_get_transazioni_by_azienda(
    p_azienda_id integer,
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_data_transazione date DEFAULT NULL,
    p_solo_da_pagare boolean DEFAULT false,
    p_causale_tipo_id integer DEFAULT NULL
)
RETURNS TABLE (
    transazione_id integer,
    transazione_azienda_id integer,
    transazione_viaggio_id integer,
    transazione_data_viaggio_id integer,
    transazione_controparte_id integer,
    transazione_causale_tipo_id integer,
    transazione_importo numeric,
    transazione_valuta_id integer,
    transazione_importo_eur numeric,
    transazione_data date,
    transazione_data_scadenza date,
    transazione_data_pagamento date,
    transazione_stato character varying,
    transazione_causale text,
    transazione_note text,
    transazione_numero_documento character varying,
    transazione_data_documento date,
    transazione_fattura_fk integer,
    -- Campi IVA aggiunti
    transazione_aliquota_iva_fk integer,
    transazione_imponibile_eur numeric,
    transazione_iva_eur numeric,
    transazione_lordo_eur numeric,
    transazione_iva_modalita_input character varying,
    transazione_tasso_cambio_applicato numeric,
    transazione_tasso_fonte character varying,
    transazione_tasso_data_validita date,
    -- Audit fields
    created_at timestamp with time zone,
    created_by character varying,
    updated_at timestamp with time zone,
    updated_by character varying,
    azienda_codice text,
    controparte_ragione_sociale character varying,
    valuta_codice_iso character varying,
    causale_descrizione character varying,
    causale_segno integer,
    viaggio_descrizione character varying,
    data_viaggio_inizio date
) 
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.transazione_id,
        t.transazione_azienda_id,
        t.transazione_viaggio_id,
        t.transazione_data_viaggio_id,
        t.transazione_controparte_id,
        t.transazione_causale_tipo_id,
        t.transazione_importo,
        t.transazione_valuta_id,
        t.transazione_importo_eur_old,
        t.transazione_data,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_note,
        t.transazione_numero_documento,
        t.transazione_data_documento,
        t.transazione_fattura_fk,
        -- Campi IVA
        t.transazione_aliquota_iva_fk,
        t.transazione_imponibile_eur,
        t.transazione_iva_eur,
        t.transazione_lordo_eur,
        t.transazione_iva_modalita_input,
        t.transazione_tasso_cambio_applicato,
        t.transazione_tasso_fonte,
        t.transazione_tasso_data_validita,
        -- Audit fields
        t.created_at,
        t.created_by,
        t.updated_at,
        t.updated_by,
        a.azienda_id::text as azienda_codice,
        c.ragione_sociale as controparte_ragione_sociale,
        v.valuta_codice_iso,
        tc.causale_descrizione,
        tc.causale_segno,
        vi.viaggio_descrizione_breve,
        dv.data_viaggio_data_inizio
    FROM mov_transazioni t
    JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    WHERE 
        t.transazione_azienda_id = p_azienda_id AND
        (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id) AND
        (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id) AND
        (p_data_transazione IS NULL OR t.transazione_data = p_data_transazione) AND
        (p_solo_da_pagare IS FALSE OR t.transazione_stato = 'DA_PAGARE') AND
        (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
    ORDER BY 
        vi.viaggio_descrizione_breve ASC, 
        dv.data_viaggio_data_inizio DESC, 
        t.transazione_data DESC, 
        t.created_at DESC;
END;
$function$;
