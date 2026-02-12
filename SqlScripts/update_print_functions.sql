DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_dettaglio(integer, integer, character varying, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, character varying, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);

-- Aggiornamento della function DETTAGLIO
CREATE OR REPLACE FUNCTION public.fn_get_transazioni_stampa_dettaglio(
    p_azienda_id integer DEFAULT NULL,
    p_fornitore_id integer DEFAULT NULL,
    p_causale_tipo_id integer DEFAULT NULL,  -- Sostituito p_tipo_movimento
    p_stati character varying[] DEFAULT NULL,
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_valuta_id integer DEFAULT NULL,
    p_data_transazione_da date DEFAULT NULL,
    p_data_transazione_a date DEFAULT NULL,
    p_data_documento_da date DEFAULT NULL,
    p_data_documento_a date DEFAULT NULL,
    p_importo_da numeric DEFAULT NULL,
    p_importo_a numeric DEFAULT NULL,
    p_numero_documento character varying DEFAULT NULL,
    p_solo_con_documento boolean DEFAULT false,
    p_solo_scadute boolean DEFAULT false,
    p_solo_con_viaggio boolean DEFAULT false,
    p_solo_senza_viaggio boolean DEFAULT false,
    p_solo_con_fattura boolean DEFAULT false,
    p_ordinamento character varying DEFAULT 'FORNITORE',
    p_valuta_target_id integer DEFAULT NULL
)
RETURNS TABLE (
    gruppo_chiave text,
    gruppo_display text,
    gruppo_ordine integer,
    transazione_id integer,
    transazione_data date,
    transazione_data_documento date,
    transazione_data_scadenza date,
    transazione_data_pagamento date,
    fornitore_ragione_sociale character varying,
    tipo_movimento_codice character varying,
    tipo_movimento_descrizione character varying,
    causale_segno integer,
    transazione_causale text,
    transazione_stato character varying,
    transazione_numero_documento character varying,
    valuta_codice_iso character varying,
    transazione_importo numeric,
    importo_valuta_target numeric,
    valuta_target_iso character varying,
    viaggio_descrizione character varying,
    data_viaggio_inizio date
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH filtered_data AS (
        SELECT
            t.*,
            f.ragione_sociale as fornitore_ragione_sociale,
            tc.causale_codice as tipo_movimento_codice,
            tc.causale_descrizione as tipo_movimento_descrizione,
            tc.causale_segno,
            v.valuta_codice_iso,
            vi.viaggio_descrizione_breve,
            dv.data_viaggio_data_inizio,
            -- Calcolo importo in valuta target (se non fornito, usa EUR come target)
            CASE
                WHEN p_valuta_target_id IS NULL THEN t.transazione_importo_eur
                WHEN t.transazione_valuta_id = p_valuta_target_id THEN t.transazione_importo
                ELSE (t.transazione_importo_eur / COALESCE(
                    (SELECT tasso_cambio FROM ana_tassi_cambio
                     WHERE tasso_valuta_id = p_valuta_target_id
                       AND tasso_data_validita <= COALESCE(t.transazione_data_documento, t.transazione_data)
                     ORDER BY tasso_data_validita DESC LIMIT 1), 1))
            END as importo_v_target
        FROM mov_transazioni t
        JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
        JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
        JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
        LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
        LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
        WHERE
            (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id) AND
            (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id) AND
            (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id) AND
            (p_stati IS NULL OR t.transazione_stato = ANY(p_stati)) AND
            (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id) AND
            (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id) AND
            (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id) AND
            (p_data_transazione_da IS NULL OR t.transazione_data >= p_data_transazione_da) AND
            (p_data_transazione_a IS NULL OR t.transazione_data <= p_data_transazione_a) AND
            (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da) AND
            (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a) AND
            (p_importo_da IS NULL OR ABS(t.transazione_importo) >= p_importo_da) AND
            (p_importo_a IS NULL OR ABS(t.transazione_importo) <= p_importo_a) AND
            (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%') AND
            (p_solo_con_documento IS FALSE OR t.transazione_numero_documento IS NOT NULL) AND
            (p_solo_scadute IS FALSE OR (t.transazione_stato = 'DA_PAGARE' AND t.transazione_data_scadenza < CURRENT_DATE)) AND
            (p_solo_con_viaggio IS FALSE OR t.transazione_viaggio_id IS NOT NULL) AND
            (p_solo_senza_viaggio IS FALSE OR t.transazione_viaggio_id IS NULL) AND
            (p_solo_con_fattura IS FALSE OR t.transazione_fattura_fk IS NOT NULL)
    ),
    grouped_data AS (
        SELECT
            *,
            CASE
                WHEN p_ordinamento = 'FORNITORE' THEN fornitore_ragione_sociale::text
                WHEN p_ordinamento = 'VIAGGIO' THEN COALESCE(viaggio_descrizione_breve, 'SENZA VIAGGIO')::text
                WHEN p_ordinamento = 'DATA' THEN to_char(transazione_data, 'YYYY-MM')::text
                WHEN p_ordinamento = 'STATO' THEN transazione_stato::text
                ELSE 'GENERALE'
            END as g_chiave,
            CASE
                WHEN p_ordinamento = 'FORNITORE' THEN fornitore_ragione_sociale::text
                WHEN p_ordinamento = 'VIAGGIO' THEN COALESCE(viaggio_descrizione_breve, 'SENZA VIAGGIO')::text
                WHEN p_ordinamento = 'DATA' THEN to_char(transazione_data, 'Month YYYY')::text
                WHEN p_ordinamento = 'STATO' THEN transazione_stato::text
                ELSE 'Report Transazioni'
            END as g_display,
            CASE
                WHEN p_ordinamento = 'DATA' THEN cast(to_char(transazione_data, 'YYYYMM') as integer)
                ELSE 0
            END as g_ordine
        FROM filtered_data
    )
    SELECT
        g_chiave, g_display, g_ordine,
        transazione_id, transazione_data, transazione_data_documento, transazione_data_scadenza, transazione_data_pagamento,
        fornitore_ragione_sociale, tipo_movimento_codice, tipo_movimento_descrizione, causale_segno,
        transazione_causale, transazione_stato, transazione_numero_documento, valuta_codice_iso,
        transazione_importo, importo_v_target,
        (SELECT valuta_codice_iso FROM ana_valute WHERE valuta_id = COALESCE(p_valuta_target_id, (SELECT valuta_id FROM ana_valute WHERE valuta_is_base LIMIT 1))),
        viaggio_descrizione_breve, data_viaggio_data_inizio
    FROM grouped_data
    ORDER BY g_ordine ASC, g_display ASC, transazione_data DESC, transazione_id DESC;
END;
$function$;

-- ============================================================================
-- Aggiornamento della function SUBTOTALI (VERSIONE CORRETTA CON 11 COLONNE)
-- NOTA: Questa è la versione corretta che include totale_fatturato_target e totale_pagato_target
-- Fix Date: 2026-02-12 - Resolved zero subtotals issue in PDF generation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_transazioni_stampa_subtotali(
    p_azienda_id integer DEFAULT NULL,
    p_fornitore_id integer DEFAULT NULL,
    p_causale_tipo_id integer DEFAULT NULL,
    p_stati character varying[] DEFAULT NULL,
    p_viaggio_id integer DEFAULT NULL,
    p_data_viaggio_id integer DEFAULT NULL,
    p_valuta_id integer DEFAULT NULL,
    p_data_transazione_da date DEFAULT NULL,
    p_data_transazione_a date DEFAULT NULL,
    p_data_documento_da date DEFAULT NULL,
    p_data_documento_a date DEFAULT NULL,
    p_importo_da numeric DEFAULT NULL,
    p_importo_a numeric DEFAULT NULL,
    p_numero_documento character varying DEFAULT NULL,
    p_solo_con_documento boolean DEFAULT false,
    p_solo_scadute boolean DEFAULT false,
    p_solo_con_viaggio boolean DEFAULT false,
    p_solo_senza_viaggio boolean DEFAULT false,
    p_solo_con_fattura boolean DEFAULT false,
    p_ordinamento character varying DEFAULT 'FORNITORE',
    p_valuta_target_id integer DEFAULT NULL
)
RETURNS TABLE (
    gruppo_chiave text,
    gruppo_display text,
    gruppo_ordine integer,
    valuta_codice_iso character varying,
    totale_valuta_originale numeric,
    totale_valuta_target numeric,
    totale_fatturato_target numeric,
    totale_pagato_target numeric,
    valuta_target_iso character varying,
    conteggio_transazioni integer,
    is_totale_generale boolean
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
            c.causale_codice,
            c.causale_descrizione,
            c.causale_segno,
            -- Calcolo chiave raggruppamento
            CASE
                WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'YYYY-MM')
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN c.causale_descrizione::TEXT
                ELSE 'TUTTI'
            END as grp_chiave,
            -- Display name
            CASE
                WHEN p_ordinamento = 'FORNITORE' THEN f.ragione_sociale::TEXT
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN
                    INITCAP(TO_CHAR(COALESCE(t.transazione_data_documento, t.transazione_data), 'TMMonth YYYY'))
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN c.causale_descrizione::TEXT
                ELSE 'Totale Generale'
            END as grp_display,
            -- Ordine gruppo
            CASE
                WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN
                    EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER * 100
                    + EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER
                WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN
                    CASE WHEN c.causale_segno > 0 THEN 1 ELSE 2 END
                ELSE 0
            END as grp_ordine,
            -- Importo convertito (Valore Assoluto)
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
        INNER JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
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
    )
    SELECT
        tf.grp_chiave as gruppo_chiave,
        MAX(tf.grp_display) as gruppo_display,
        MAX(tf.grp_ordine) as gruppo_ordine,
        tf.val_iso as valuta_codice_iso,
        -- Saldo Algebrico Originale
        SUM(tf.transazione_importo * tf.causale_segno)::NUMERIC as totale_valuta_originale,
        -- Saldo Algebrico Target
        SUM(tf.importo_target * tf.causale_segno)::NUMERIC as totale_valuta_target,
        -- Totale Fatturato (Solo Addebiti, segno > 0)
        SUM(CASE WHEN tf.causale_segno > 0 THEN tf.importo_target ELSE 0 END)::NUMERIC as totale_fatturato_target,
        -- Totale Pagato (Solo Accrediti/Pagamenti, segno < 0)
        SUM(CASE WHEN tf.causale_segno < 0 THEN tf.importo_target ELSE 0 END)::NUMERIC as totale_pagato_target,

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
