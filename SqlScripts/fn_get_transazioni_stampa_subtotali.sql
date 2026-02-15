-- ============================================================================
-- fn_get_transazioni_stampa_subtotali
-- Restituisce i sub-totali aggregati per gruppo e valuta + totali generali.
-- LOGICA ALGEBRICA BASATA SU ana_tipi_causali.causale_segno
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_transazioni_stampa_subtotali(
    p_azienda_id INTEGER DEFAULT NULL,
    p_controparte_id INTEGER DEFAULT NULL, -- ex p_fornitore_id
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
    p_ordinamento VARCHAR DEFAULT 'FORNITORE', -- Manteniamo compatibilità stringa, ma logica su Controparte
    p_valuta_target_id INTEGER DEFAULT NULL,
    p_causale_ciclo VARCHAR DEFAULT NULL -- 'ATTIVO', 'PASSIVO', o NULL
)
RETURNS TABLE (
    gruppo_chiave TEXT,
    gruppo_display TEXT,
    gruppo_ordine INTEGER,
    valuta_codice_iso VARCHAR,
    totale_valuta_originale NUMERIC, -- Saldo Algebrico del LORDO
    totale_valuta_target NUMERIC,    -- Saldo Algebrico del LORDO Convertito
    totale_fatturato_target NUMERIC, -- Somma dei soli addebiti (segno > 0)
    totale_pagato_target NUMERIC,    -- Somma dei soli accrediti/pagamenti (segno < 0) - in valore assoluto
    
    -- Nuovi totali
    totale_imponibile_target NUMERIC, -- Saldo algebrico Imponibile convertito
    totale_iva_target NUMERIC,        -- Saldo algebrico IVA convertito

    valuta_target_iso VARCHAR,
    conteggio_transazioni INTEGER,
    is_totale_generale BOOLEAN
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_valuta_target_iso VARCHAR(3);
BEGIN
    -- Recupera il codice ISO della valuta target
    IF p_valuta_target_id IS NOT NULL THEN
        SELECT av.valuta_codice_iso INTO v_valuta_target_iso
        FROM ana_valute av
        WHERE av.valuta_id = p_valuta_target_id;
    ELSE
        v_valuta_target_iso := 'EUR';
    END IF;

    RETURN QUERY
    WITH transazioni_filtrate AS (
        SELECT 
            t.*,
            c.ragione_sociale, -- ex f.ragione_sociale
            v.valuta_codice_iso as val_iso,
            ca.causale_codice,
            ca.causale_descrizione,
            ca.causale_segno,
            -- Calcolo chiave raggruppamento
            CASE 
                WHEN p_ordinamento = 'FORNITORE' THEN c.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'YYYY-MM')
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN ca.causale_descrizione::TEXT
                ELSE 'TUTTI'
            END as grp_chiave,
            -- Display name
            CASE 
                WHEN p_ordinamento = 'FORNITORE' THEN c.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                    INITCAP(TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'TMMonth YYYY'))
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN ca.causale_descrizione::TEXT 
                ELSE 'Totale Generale'
            END as grp_display,
            -- Ordine gruppo
            CASE 
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                    EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER * 100 
                    + EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                    CASE WHEN ca.causale_segno > 0 THEN 1 ELSE 2 END
                ELSE 0
            END as grp_ordine,
            
            -- Importi Convertiti (Base LORDO)
            CASE 
                WHEN v.valuta_codice_iso = v_valuta_target_iso THEN t.transazione_lordo_eur
                WHEN v_valuta_target_iso = 'EUR' THEN t.transazione_lordo_eur
                ELSE 
                    ROUND(
                        t.transazione_lordo_eur * COALESCE(
                            fn_get_tasso_cambio(v.valuta_codice_iso, v_valuta_target_iso, COALESCE(t.transazione_data_documento, t.transazione_data)),
                            1.0
                        ),
                        2
                    )
            END as importo_target,

             -- Imponibile Convertito
            CASE 
                WHEN v.valuta_codice_iso = v_valuta_target_iso THEN t.transazione_imponibile_eur
                WHEN v_valuta_target_iso = 'EUR' THEN t.transazione_imponibile_eur
                ELSE 
                    ROUND(
                        t.transazione_imponibile_eur * COALESCE(
                            fn_get_tasso_cambio(v.valuta_codice_iso, v_valuta_target_iso, COALESCE(t.transazione_data_documento, t.transazione_data)),
                            1.0
                        ),
                        2
                    )
            END as imponibile_target,

             -- IVA Convertita
            CASE 
                WHEN v.valuta_codice_iso = v_valuta_target_iso THEN t.transazione_iva_eur
                WHEN v_valuta_target_iso = 'EUR' THEN t.transazione_iva_eur
                ELSE 
                    ROUND(
                        t.transazione_iva_eur * COALESCE(
                            fn_get_tasso_cambio(v.valuta_codice_iso, v_valuta_target_iso, COALESCE(t.transazione_data_documento, t.transazione_data)),
                            1.0
                        ),
                        2
                    )
            END as iva_target

        FROM mov_transazioni t
        LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id -- ex ana_fornitori
        INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
        INNER JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
        WHERE
            (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
            AND (p_controparte_id IS NULL OR t.transazione_controparte_id = p_controparte_id)
            AND (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
            AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
            AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
            AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
            AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
            AND (p_data_transazione_da IS NULL OR t.transazione_data >= p_data_transazione_da)
            AND (p_data_transazione_a IS NULL OR t.transazione_data <= p_data_transazione_a)
            AND (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da)
            AND (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a)
            AND (p_importo_da IS NULL OR t.transazione_lordo_eur >= p_importo_da)
            AND (p_importo_a IS NULL OR t.transazione_lordo_eur <= p_importo_a)
            AND (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%')
            AND (p_causale_ciclo IS NULL OR ca.causale_ciclo = p_causale_ciclo) -- Nuovo Filtro
            AND (NOT p_solo_con_documento OR (t.transazione_numero_documento IS NOT NULL AND t.transazione_data_documento IS NOT NULL))
            AND (NOT p_solo_scadute OR (t.transazione_data_scadenza < CURRENT_DATE AND t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')))
            AND (NOT p_solo_con_viaggio OR t.transazione_viaggio_id IS NOT NULL)
            AND (NOT p_solo_senza_viaggio OR t.transazione_viaggio_id IS NULL)
            AND (NOT p_solo_con_fattura OR t.transazione_fattura_fk IS NOT NULL)
    )
    SELECT 
        tf.grp_chiave as gruppo_chiave,
        MAX(tf.grp_display) as gruppo_display,
        MAX(tf.grp_ordine) as gruppo_ordine,
        tf.val_iso as valuta_codice_iso,
        -- Saldo Algebrico Originale (LORDO)
        SUM(tf.transazione_lordo_eur * tf.causale_segno)::NUMERIC as totale_valuta_originale,
        -- Saldo Algebrico Target (LORDO)
        SUM(tf.importo_target * tf.causale_segno)::NUMERIC as totale_valuta_target,
        -- Totale Fatturato (Solo Addebiti, segno > 0)
        SUM(CASE WHEN tf.causale_segno > 0 THEN tf.importo_target ELSE 0 END)::NUMERIC as totale_fatturato_target,
        -- Totale Pagato (Solo Accrediti/Pagamenti, segno < 0)
        SUM(CASE WHEN tf.causale_segno < 0 THEN tf.importo_target ELSE 0 END)::NUMERIC as totale_pagato_target,
        
        -- Nuovi totali Imponibile e IVA
        SUM(tf.imponibile_target * tf.causale_segno)::NUMERIC as totale_imponibile_target,
        SUM(tf.iva_target * tf.causale_segno)::NUMERIC as totale_iva_target,
        
        v_valuta_target_iso as valuta_target_iso,
        COUNT(*)::INTEGER as conteggio_transazioni,
        GROUPING(tf.grp_chiave) = 1 as is_totale_generale
    FROM transazioni_filtrate tf
    GROUP BY GROUPING SETS (
        (tf.grp_chiave, tf.val_iso),
        (tf.val_iso)
    )
    ORDER BY 
        is_totale_generale,
        gruppo_ordine NULLS LAST,
        gruppo_chiave NULLS LAST,
        tf.val_iso;
END;
$function$;
