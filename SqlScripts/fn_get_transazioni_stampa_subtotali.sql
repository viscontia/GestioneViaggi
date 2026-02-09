-- ============================================================================
-- fn_get_transazioni_stampa_subtotali
-- Restituisce i sub-totali aggregati per gruppo e valuta + totali generali.
-- Usa GROUPING SETS per calcolare sia i sub-totali che i totali generali.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_transazioni_stampa_subtotali(
    p_azienda_id INTEGER DEFAULT NULL,
    p_fornitore_id INTEGER DEFAULT NULL,
    p_tipo_movimento VARCHAR DEFAULT NULL,
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
    valuta_codice_iso VARCHAR,
    totale_valuta_originale NUMERIC,
    totale_valuta_target NUMERIC,
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
            f.ragione_sociale,
            v.valuta_codice_iso as val_iso,
            -- Calcolo chiave raggruppamento
            CASE 
                WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'YYYY-MM')
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN t.transazione_tipo_movimento::TEXT
                ELSE 'TUTTI'  -- Per IMPORTO_ASC/DESC c'è solo totale generale
            END as grp_chiave,
            -- Display name
            CASE 
                WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                    INITCAP(TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'TMMonth YYYY'))
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                    CASE t.transazione_tipo_movimento 
                        WHEN 'ENTRATA' THEN 'Entrate' 
                        WHEN 'USCITA' THEN 'Uscite' 
                    END
                ELSE 'Totale Generale'
            END as grp_display,
            -- Ordine gruppo
            CASE 
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                    EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER * 100 
                    + EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                    CASE t.transazione_tipo_movimento WHEN 'ENTRATA' THEN 1 ELSE 2 END
                ELSE 0
            END as grp_ordine,
            -- Importo convertito
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
            END as importo_target
        FROM mov_transazioni t
        INNER JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
        INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
        WHERE 
            (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
            AND (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id)
            AND (p_tipo_movimento IS NULL OR t.transazione_tipo_movimento = p_tipo_movimento)
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
    )
    SELECT 
        tf.grp_chiave as gruppo_chiave,
        MAX(tf.grp_display) as gruppo_display,
        MAX(tf.grp_ordine) as gruppo_ordine,
        tf.val_iso as valuta_codice_iso,
        SUM(tf.transazione_importo)::NUMERIC as totale_valuta_originale,
        SUM(tf.importo_target)::NUMERIC as totale_valuta_target,
        v_valuta_target_iso as valuta_target_iso,
        COUNT(*)::INTEGER as conteggio_transazioni,
        GROUPING(tf.grp_chiave) = 1 as is_totale_generale
    FROM transazioni_filtrate tf
    GROUP BY GROUPING SETS (
        (tf.grp_chiave, tf.val_iso),  -- Sub-totali per gruppo e valuta
        (tf.val_iso)                   -- Totali generali per valuta
    )
    ORDER BY 
        is_totale_generale,  -- Prima i sub-totali, poi i totali generali
        gruppo_ordine NULLS LAST,
        gruppo_chiave NULLS LAST,
        tf.val_iso;
END;
$function$;

-- Commenti
COMMENT ON FUNCTION fn_get_transazioni_stampa_subtotali IS 
'Restituisce i sub-totali aggregati per gruppo e valuta per la stampa PDF.
Usa GROUPING SETS per calcolare:
  - Sub-totali per ogni gruppo (fornitore/mese/tipo) e valuta
  - Totali generali per valuta (is_totale_generale = true)
Include conteggio transazioni per ogni aggregazione.';
