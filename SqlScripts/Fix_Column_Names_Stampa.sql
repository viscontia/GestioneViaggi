-- ============================================================================
-- FIX NOMI COLONNE STAMPA MOVIMENTI
-- Autore: Antigravity
-- Data: 2026-02-12
-- ============================================================================

-- 1. DROP versione con tipi varchar se esiste (per evitare conflitti di firma)
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_dettaglio(integer, integer, integer, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);

-- 2. CREATE OR REPLACE FUNCTION principale (Dettaglio)
CREATE OR REPLACE FUNCTION public.fn_get_transazioni_stampa_dettaglio(
    p_azienda_id integer, 
    p_fornitore_id integer, 
    p_causale_tipo_id integer, 
    p_stati text[], 
    p_viaggio_id integer, 
    p_data_viaggio_id integer, 
    p_valuta_id integer, 
    p_data_trans_da date, 
    p_data_trans_a date, 
    p_data_doc_da date, 
    p_data_doc_a date, 
    p_importo_da numeric, 
    p_importo_a numeric, 
    p_num_doc text, 
    p_solo_con_doc boolean, 
    p_solo_scadute boolean, 
    p_solo_con_viaggio boolean, 
    p_solo_senza_viaggio boolean, 
    p_solo_con_fattura boolean, 
    p_ordinamento text, 
    p_valuta_target_id integer
)
 RETURNS TABLE(
    gruppo_chiave text, 
    gruppo_display text, 
    gruppo_ordine integer, 
    transazione_id integer, 
    transazione_data date, 
    transazione_data_documento date, 
    transazione_data_scadenza date, 
    transazione_data_pagamento date, 
    fornitore_ragione_sociale text, 
    tipo_movimento_codice text, 
    tipo_movimento_descrizione text, 
    causale_segno integer, 
    transazione_causale text, 
    transazione_stato text, 
    transazione_numero_documento text, 
    valuta_codice_iso text, 
    transazione_importo numeric, 
    importo_valuta_target numeric, 
    valuta_target_iso text, 
    viaggio_descrizione text, 
    data_viaggio_inizio date
 )
 LANGUAGE plpgsql
 AS $function$
 BEGIN
     RETURN QUERY
     WITH filtered_data AS (
         SELECT 
             t.transazione_id,
             t.transazione_data,
             t.transazione_data_documento,
             t.transazione_data_scadenza,
             t.transazione_data_pagamento,
             f.ragione_sociale as fornitore_rs,
             tc.causale_codice as tm_codice,
             tc.causale_descrizione as tm_desc,
             tc.causale_segno,
             t.transazione_causale,
             t.transazione_stato,
             t.transazione_numero_documento,
             v.valuta_codice_iso,
             t.transazione_importo,
             CASE 
                 WHEN t.transazione_valuta_id = p_valuta_target_id THEN t.transazione_importo
                 ELSE COALESCE(t.transazione_importo_eur * NULLIF(fn_get_tasso_cambio(2, p_valuta_target_id, CURRENT_DATE), 0), 0)
             END as imp_target,
             vt.valuta_codice_iso as target_iso,
             -- FIX: Nomi colonne corretti per ana_viaggi e ana_date_viaggi
             av.viaggio_descrizione_breve as viaggio_desc,
             adv.data_viaggio_data_inizio as data_inizio
         FROM mov_transazioni t
         JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
         JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
         JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
         JOIN ana_valute vt ON vt.valuta_id = p_valuta_target_id
         LEFT JOIN ana_viaggi av ON t.transazione_viaggio_id = av.viaggio_id
         LEFT JOIN ana_date_viaggi adv ON t.transazione_data_viaggio_id = adv.data_viaggio_id
         WHERE t.transazione_azienda_id = p_azienda_id
           AND (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id)
           AND (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
           AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
           AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
           AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
           AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
           AND (p_data_trans_da IS NULL OR t.transazione_data >= p_data_trans_da)
           AND (p_data_trans_a IS NULL OR t.transazione_data <= p_data_trans_a)
           AND (p_data_doc_da IS NULL OR t.transazione_data_documento >= p_data_doc_da)
           AND (p_data_doc_a IS NULL OR t.transazione_data_documento <= p_data_doc_a)
           AND (p_importo_da IS NULL OR ABS(t.transazione_importo) >= p_importo_da)
           AND (p_importo_a IS NULL OR ABS(t.transazione_importo) <= p_importo_a)
           AND (p_num_doc IS NULL OR t.transazione_numero_documento ILIKE '%' || p_num_doc || '%')
           AND (p_solo_con_doc = FALSE OR t.transazione_numero_documento IS NOT NULL)
           AND (p_solo_scadute = FALSE OR (t.transazione_stato = 'DA_PAGARE' AND t.transazione_data_scadenza < CURRENT_DATE))
           AND (p_solo_con_viaggio = FALSE OR t.transazione_viaggio_id IS NOT NULL)
           AND (p_solo_senza_viaggio = FALSE OR t.transazione_viaggio_id IS NULL)
           AND (p_solo_con_fattura = FALSE OR tc.causale_codice = 'FT')
     )
     SELECT 
         CASE 
             WHEN p_ordinamento IN ('FORNITORE', 'DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN 
                 CASE 
                     WHEN p_ordinamento = 'FORNITORE' THEN fornitore_rs
                     ELSE TO_CHAR(transazione_data_documento, 'YYYY-MM')
                 END
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN tm_desc
             ELSE 'GENERALE'
         END as g_chiave,
         CASE 
             WHEN p_ordinamento IN ('FORNITORE', 'DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN 
                 CASE 
                     WHEN p_ordinamento = 'FORNITORE' THEN fornitore_rs
                     ELSE TO_CHAR(transazione_data_documento, 'Month YYYY')
                 END
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN tm_desc
             ELSE 'Tutte le transazioni'
         END as g_display,
         CASE 
             WHEN p_ordinamento = 'FORNITORE' THEN 1
             WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN CAST(TO_CHAR(transazione_data_documento, 'YYYYMM') AS INTEGER)
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 1
             ELSE 1
         END as g_ordine,
         fd.transazione_id,
         fd.transazione_data,
         fd.transazione_data_documento,
         fd.transazione_data_scadenza,
         fd.transazione_data_pagamento,
         fd.fornitore_rs,
         fd.tm_codice,
         fd.tm_desc,
         fd.causale_segno,
         fd.transazione_causale,
         fd.transazione_stato,
         fd.transazione_numero_documento,
         fd.valuta_codice_iso,
         fd.transazione_importo,
         fd.imp_target,
         fd.target_iso,
         fd.viaggio_desc,
         fd.data_inizio
     FROM filtered_data fd
     ORDER BY 
         g_ordine ASC,
         g_chiave NULLS LAST,
         CASE WHEN p_ordinamento = 'FORNITORE' THEN transazione_data_documento END ASC,
         CASE WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN transazione_data_documento END ASC,
         CASE WHEN p_ordinamento = 'DATA_DOCUMENTO_DESC' THEN transazione_data_documento END DESC,
         CASE WHEN p_ordinamento = 'IMPORTO_ASC' THEN transazione_importo END ASC,
         CASE WHEN p_ordinamento = 'IMPORTO_DESC' THEN transazione_importo END DESC,
         transazione_id ASC;
 END;
 $function$;

-- 3. DROP versione con tipi varchar se esiste (per Subtotali)
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, integer, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);

-- 4. CREATE OR REPLACE FUNCTION Subtotali
CREATE OR REPLACE FUNCTION public.fn_get_transazioni_stampa_subtotali(
    p_azienda_id integer,
    p_fornitore_id integer,
    p_causale_tipo_id integer,
    p_stati text[],
    p_viaggio_id integer,
    p_data_viaggio_id integer,
    p_valuta_id integer,
    p_data_trans_da date,
    p_data_trans_a date,
    p_data_doc_da date,
    p_data_doc_a date,
    p_importo_da numeric,
    p_importo_a numeric,
    p_num_doc text,
    p_solo_con_doc boolean,
    p_solo_scadute boolean,
    p_solo_con_viaggio boolean,
    p_solo_senza_viaggio boolean,
    p_solo_con_fattura boolean,
    p_ordinamento text,
    p_valuta_target_id integer
)
 RETURNS TABLE(
    gruppo_chiave text,
    gruppo_display text,
    gruppo_ordine integer,
    valuta_codice_iso character varying,
    totale_valuta_originale numeric,
    totale_valuta_target numeric,
    totale_fatturato_target numeric,
    totale_pagato_target numeric,
    valuta_target_iso character varying,
    conteggio_transazioni bigint,
    is_totale_generale boolean
 )
 LANGUAGE plpgsql
 AS $function$
 BEGIN
     RETURN QUERY
     WITH base_data AS (
         SELECT 
             t.transazione_id,
             t.transazione_importo,
             t.transazione_valuta_id,
             v.valuta_codice_iso as val_iso,
             f.ragione_sociale as fornitore_rs,
             t.transazione_data_documento,
             tc.causale_codice as tm_codice,
             tc.causale_descrizione as tm_desc,
             tc.causale_segno,
             CASE 
                 WHEN t.transazione_valuta_id = p_valuta_target_id THEN t.transazione_importo
                 ELSE COALESCE(t.transazione_importo_eur * NULLIF(fn_get_tasso_cambio(2, p_valuta_target_id, CURRENT_DATE), 0), 0)
             END as imp_target,
             vt.valuta_codice_iso as t_iso
         FROM mov_transazioni t
         JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
         JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
         JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
         JOIN ana_valute vt ON vt.valuta_id = p_valuta_target_id
         LEFT JOIN ana_viaggi av ON t.transazione_viaggio_id = av.viaggio_id
         LEFT JOIN ana_date_viaggi adv ON t.transazione_data_viaggio_id = adv.data_viaggio_id
         WHERE t.transazione_azienda_id = p_azienda_id
           AND (p_fornitore_id IS NULL OR t.transazione_fornitore_id = p_fornitore_id)
           AND (p_causale_tipo_id IS NULL OR t.transazione_causale_tipo_id = p_causale_tipo_id)
           AND (p_stati IS NULL OR t.transazione_stato = ANY(p_stati))
           AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
           AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
           AND (p_valuta_id IS NULL OR t.transazione_valuta_id = p_valuta_id)
           AND (p_data_trans_da IS NULL OR t.transazione_data >= p_data_trans_da)
           AND (p_data_trans_a IS NULL OR t.transazione_data <= p_data_trans_a)
           AND (p_data_doc_da IS NULL OR t.transazione_data_documento >= p_data_doc_da)
           AND (p_data_doc_a IS NULL OR t.transazione_data_documento <= p_data_doc_a)
           AND (p_importo_da IS NULL OR ABS(t.transazione_importo) >= p_importo_da)
           AND (p_importo_a IS NULL OR ABS(t.transazione_importo) <= p_importo_a)
           AND (p_num_doc IS NULL OR t.transazione_numero_documento ILIKE '%' || p_num_doc || '%')
           AND (p_solo_con_doc = FALSE OR t.transazione_numero_documento IS NOT NULL)
           AND (p_solo_scadute = FALSE OR (t.transazione_stato = 'DA_PAGARE' AND t.transazione_data_scadenza < CURRENT_DATE))
           AND (p_solo_con_viaggio = FALSE OR t.transazione_viaggio_id IS NOT NULL)
           AND (p_solo_senza_viaggio = FALSE OR t.transazione_viaggio_id IS NULL)
           AND (p_solo_con_fattura = FALSE OR tc.causale_codice = 'FT')
     ),
     grouped_data AS (
         SELECT 
             CASE 
                 WHEN p_ordinamento = 'FORNITORE' THEN fornitore_rs
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN TO_CHAR(transazione_data_documento, 'YYYY-MM')
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN tm_desc
                 ELSE 'GENERALE'
             END as g_key,
             CASE 
                 WHEN p_ordinamento = 'FORNITORE' THEN fornitore_rs
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN TO_CHAR(transazione_data_documento, 'Month YYYY')
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN tm_desc
                 ELSE 'Tutte le transazioni'
             END as g_display,
             CASE 
                 WHEN p_ordinamento = 'FORNITORE' THEN 1
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN CAST(TO_CHAR(transazione_data_documento, 'YYYYMM') AS INTEGER)
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 1
                 ELSE 1
             END as g_order,
             val_iso,
             SUM(transazione_importo * causale_segno) as tot_orig,
             SUM(imp_target * causale_segno) as tot_target,
             SUM(CASE WHEN causale_segno > 0 THEN imp_target ELSE 0 END) as tot_fatt,
             SUM(CASE WHEN causale_segno < 0 THEN imp_target ELSE 0 END) as tot_pag,
             MAX(t_iso) as t_iso,
             COUNT(*) as cnt
         FROM base_data
         GROUP BY GROUPING SETS (
             (g_key, g_display, g_order, val_iso),
             (val_iso)
         )
     )
     SELECT 
         COALESCE(g_key, 'TOTALE_GENERALE'),
         COALESCE(g_display, 'TOTALE GENERALE'),
         COALESCE(g_order, 999999),
         val_iso,
         tot_orig,
         tot_target,
         tot_fatt,
         tot_pag,
         t_iso,
         cnt,
         (g_key IS NULL) as is_total
     FROM grouped_data
     ORDER BY 
         is_total,
         g_order NULLS LAST,
         g_key NULLS LAST,
         val_iso;
 END;
 $function$;
