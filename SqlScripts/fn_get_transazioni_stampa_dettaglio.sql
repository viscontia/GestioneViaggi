-- ============================================================================
-- fn_get_transazioni_stampa_dettaglio
-- Restituisce i dettagli delle transazioni con chiave di raggruppamento 
-- calcolata dinamicamente in base all'ordinamento selezionato.
-- Converte gli importi nella valuta target dell'utente.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_transazioni_stampa_dettaglio(
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
    p_valuta_target_id INTEGER DEFAULT NULL  -- Valuta utente per conversione
)
RETURNS TABLE (
    -- Chiave raggruppamento dinamica
    gruppo_chiave TEXT,
    gruppo_display TEXT,
    gruppo_ordine INTEGER,  -- Per ordinamento gruppi
    -- Dati transazione
    transazione_id INTEGER,
    transazione_data DATE,
    transazione_data_documento DATE,
    transazione_data_scadenza DATE,
    transazione_data_pagamento DATE,
    fornitore_ragione_sociale VARCHAR,
    transazione_tipo_movimento VARCHAR,
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
    -- Recupera il codice ISO della valuta target
    IF p_valuta_target_id IS NOT NULL THEN
        SELECT av.valuta_codice_iso INTO v_valuta_target_iso
        FROM ana_valute av
        WHERE av.valuta_id = p_valuta_target_id;
    ELSE
        -- Default EUR se non specificato
        v_valuta_target_iso := 'EUR';
    END IF;

    RETURN QUERY
    SELECT 
        -- Calcolo chiave raggruppamento dinamica
        CASE 
            WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'YYYY-MM')
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN t.transazione_tipo_movimento::TEXT
            ELSE NULL  -- IMPORTO_ASC/DESC non hanno raggruppamento
        END as gruppo_chiave,
        
        -- Display name leggibile
        CASE 
            WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                INITCAP(TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'TMMonth YYYY'))
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                CASE t.transazione_tipo_movimento 
                    WHEN 'ENTRATA' THEN 'Entrate' 
                    WHEN 'USCITA' THEN 'Uscite' 
                END
            ELSE NULL
        END as gruppo_display,
        
        -- Ordine per gruppi (per ordinamento coerente)
        CASE 
            WHEN p_ordinamento = 'FORNITORE' THEN ROW_NUMBER() OVER (PARTITION BY f.ragione_sociale ORDER BY f.ragione_sociale)::INTEGER
            WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN 
                EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER * 100 
                + EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER
            WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 
                CASE t.transazione_tipo_movimento WHEN 'ENTRATA' THEN 1 ELSE 2 END
            ELSE 0
        END as gruppo_ordine,
        
        -- Dati transazione
        t.transazione_id,
        t.transazione_data,
        t.transazione_data_documento,
        t.transazione_data_scadenza,
        t.transazione_data_pagamento,
        f.ragione_sociale,
        t.transazione_tipo_movimento,
        t.transazione_causale,
        t.transazione_stato,
        t.transazione_numero_documento,
        v.valuta_codice_iso,
        t.transazione_importo,
        
        -- Conversione nella valuta target
        CASE 
            WHEN v.valuta_codice_iso = v_valuta_target_iso THEN t.transazione_importo
            WHEN v_valuta_target_iso = 'EUR' THEN t.transazione_importo_eur
            ELSE 
                -- Converti da EUR alla valuta target usando il tasso storicizzato
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
    LEFT JOIN ana_viaggi vg ON t.transazione_viaggio_id = vg.viaggio_id
    LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    
    WHERE 
        -- Filtro Azienda
        (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
        -- Filtro Fornitore
        AND (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id)
        -- Filtro Tipo Movimento
        AND (p_tipo_movimento IS NULL OR t.transazione_tipo_movimento = p_tipo_movimento)
        -- Filtro Stati (array)
        AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
        -- Filtro Viaggio
        AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
        -- Filtro Data Viaggio
        AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
        -- Filtro Valuta
        AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
        -- Filtro Data Transazione
        AND (p_data_transazione_da IS NULL OR t.transazione_data >= p_data_transazione_da)
        AND (p_data_transazione_a IS NULL OR t.transazione_data <= p_data_transazione_a)
        -- Filtro Data Documento
        AND (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da)
        AND (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a)
        -- Filtro Importo
        AND (p_importo_da IS NULL OR t.transazione_importo >= p_importo_da)
        AND (p_importo_a IS NULL OR t.transazione_importo <= p_importo_a)
        -- Filtro Numero Documento (LIKE)
        AND (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%')
        -- Checkbox Solo con documento
        AND (NOT p_solo_con_documento OR (t.transazione_numero_documento IS NOT NULL AND t.transazione_data_documento IS NOT NULL))
        -- Checkbox Solo scadute
        AND (NOT p_solo_scadute OR (t.transazione_data_scadenza < CURRENT_DATE AND t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')))
        -- Checkbox Solo con viaggio
        AND (NOT p_solo_con_viaggio OR t.transazione_viaggio_id IS NOT NULL)
        -- Checkbox Solo senza viaggio
        AND (NOT p_solo_senza_viaggio OR t.transazione_viaggio_id IS NULL)
        -- Checkbox Solo con fattura
        AND (NOT p_solo_con_fattura OR t.transazione_fattura_fk IS NOT NULL)
        
    ORDER BY 
        -- Ordinamento primario per gruppo
        gruppo_chiave NULLS LAST,
        -- Ordinamento secondario
        CASE WHEN p_ordinamento = 'FORNITORE' THEN t.transazione_data_documento END DESC,
        CASE WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN t.transazione_data_documento END DESC,
        CASE WHEN p_ordinamento = 'IMPORTO_ASC' THEN t.transazione_importo END ASC,
        CASE WHEN p_ordinamento = 'IMPORTO_DESC' THEN t.transazione_importo END DESC,
        CASE WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN f.ragione_sociale END;
END;
$function$;

-- Commenti
COMMENT ON FUNCTION fn_get_transazioni_stampa_dettaglio IS 
'Restituisce i dettagli delle transazioni per la stampa PDF con chiave di raggruppamento dinamica.
Parametri:
  - p_ordinamento: FORNITORE, DATA_DOCUMENTO, IMPORTO_ASC, IMPORTO_DESC, TIPO_MOVIMENTO
  - p_valuta_target_id: ID della valuta nella quale convertire gli importi (default EUR)
Output include gruppo_chiave e gruppo_display per rotture di controllo.';
