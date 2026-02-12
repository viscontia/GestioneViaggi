-- ============================================================================
-- fn_get_transazioni_stampa_dettaglio
-- Restituisce i dettagli delle transazioni con chiave di raggruppamento dinamica.
-- LOGICA BASATA SU ana_tipi_causali
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_transazioni_stampa_dettaglio(
    p_azienda_id INTEGER DEFAULT NULL,
    p_fornitore_id INTEGER DEFAULT NULL,
    p_causale_tipo_id INTEGER DEFAULT NULL,
    p_stati VARCHAR[] DEFAULT NULL,
    p_viaggio_id INTEGER DEFAULT NULL,
    p_data_viaggio_id INTEGER DEFAULT NULL,
    p_valuta_id INTEGER DEFAULT NULL,
    p_data_transazione_da DATE DEFAULT NULL,
    p_data_transazione_a DATE DEFAULT NULL,
    p_data_documento_da DATE DEFAULT NULL,
    p_data_documento_a DATE DEFAULT NULL,
    p_importo_da NUMERIC DEFAULT NULL,
    p_importo_a NUMERIC DEFAULT NULL,
    p_numero_documento VARCHAR DEFAULT NULL,
    p_solo_con_documento BOOLEAN DEFAULT FALSE,
    p_solo_scadute BOOLEAN DEFAULT FALSE,
    p_solo_con_viaggio BOOLEAN DEFAULT FALSE,
    p_solo_senza_viaggio BOOLEAN DEFAULT FALSE,
    p_solo_con_fattura BOOLEAN DEFAULT FALSE,
    p_ordinamento VARCHAR DEFAULT 'FORNITORE',
    p_valuta_target_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    gruppo_chiave TEXT,
    gruppo_display TEXT,
    gruppo_ordine INTEGER,
    transazione_id INTEGER,
    transazione_data DATE,
    transazione_data_documento DATE,
    transazione_data_scadenza DATE,
    transazione_data_pagamento DATE,
    fornitore_ragione_sociale VARCHAR,
    tipo_movimento_codice VARCHAR, -- ana_tipi_causali.causale_codice
    tipo_movimento_descrizione VARCHAR, -- ana_tipi_causali.causale_descrizione
    causale_segno INTEGER, -- +1/-1
    transazione_causale TEXT,
    transazione_stato VARCHAR,
    transazione_numero_documento VARCHAR,
    valuta_codice_iso VARCHAR,
    transazione_importo NUMERIC,
    importo_valuta_target NUMERIC,
    valuta_target_iso VARCHAR,
    viaggio_descrizione VARCHAR,
    data_viaggio_inizio DATE
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_valuta_target_iso VARCHAR(3);
BEGIN
    IF p_valuta_target_id IS NOT NULL THEN
        SELECT av.valuta_codice_iso INTO v_valuta_target_iso
        FROM ana_valute av
        WHERE av.valuta_id = p_valuta_target_id;
    ELSE
        v_valuta_target_iso := 'EUR';
    END IF;

    RETURN QUERY
    SELECT 
        -- Chiave raggruppamento dinamica
        CASE 
            WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'YYYY-MM')
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN c.causale_descrizione::TEXT
            ELSE 'TUTTI'
        END as gruppo_chiave,
        
        CASE 
            WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                INITCAP(TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'TMMonth YYYY'))
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN c.causale_descrizione::TEXT
            ELSE 'Totale'
        END as gruppo_display,
        
        CASE 
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER * 100 
                + EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                CASE WHEN c.causale_segno > 0 THEN 1 ELSE 2 END
            ELSE 0
        END as gruppo_ordine,
        
        t.transazione_id,
        t.transazione_data,
        t.transazione_data_documento,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        f.ragione_sociale,
        c.causale_codice::VARCHAR,
        c.causale_descrizione::VARCHAR,
        c.causale_segno,
        t.transazione_causale,
        t.transazione_stato,
        t.transazione_numero_documento,
        v.valuta_codice_iso,
        t.transazione_importo,
        
        CASE 
            WHEN v.valuta_codice_iso = v_valuta_target_iso THEN t.transazione_importo
            WHEN v_valuta_target_iso = 'EUR' THEN t.transazione_importo_eur
            ELSE 
                ROUND(
                    t.transazione_importo_eur * COALESCE(
                        fn_get_tasso_cambio('EUR', v_valuta_target_iso, COALESCE(t.transazione_data_documento, t.transazione_data)),
                        1.0
                    ),
                    2
                )
        END as importo_valuta_target,
        
        v_valuta_target_iso as valuta_target_iso,
        vg.viaggio_descrizione_breve,
        dv.data_viaggio_data_inizio
        
    FROM mov_transazioni t
    INNER JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
    INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    INNER JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
    LEFT JOIN ana_viaggi vg ON t.transazione_viaggio_id = vg.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    
    WHERE 
        (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
        AND (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id)
        AND (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
        AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
        AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
        AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
        AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
        AND (p_data_transazione_da IS NULL OR t.transazione_data >= p_data_transazione_da)
        AND (p_data_transazione_a IS NULL OR t.transazione_data <= p_data_transazione_a)
        AND (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da)
        AND (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a)
        AND (p_importo_da IS NULL OR t.transazione_importo >= p_importo_da)
        AND (p_importo_a IS NULL OR t.transazione_importo <= p_importo_a)
        AND (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%')
        AND (NOT p_solo_con_documento OR (t.transazione_numero_documento IS NOT NULL AND t.transazione_data_documento IS NOT NULL))
        AND (NOT p_solo_scadute OR (t.transazione_data_scadenza < CURRENT_DATE AND t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')))
        AND (NOT p_solo_con_viaggio OR t.transazione_viaggio_id IS NOT NULL)
        AND (NOT p_solo_senza_viaggio OR t.transazione_viaggio_id IS NULL)
        AND (NOT p_solo_con_fattura OR t.transazione_fattura_fk IS NOT NULL)
        
    ORDER BY 
        gruppo_chiave NULLS LAST,
        CASE WHEN p_ordinamento = 'FORNITORE' THEN t.transazione_data_documento END DESC,
        CASE WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN t.transazione_data_documento END DESC,
        CASE WHEN p_ordinamento = 'IMPORTO_ASC' THEN t.transazione_importo END ASC,
        CASE WHEN p_ordinamento = 'IMPORTO_DESC' THEN t.transazione_importo END DESC;
END;
$function$;
