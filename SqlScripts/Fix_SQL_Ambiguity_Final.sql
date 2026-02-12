-- ============================================================================
-- FIX DEFINITIVO: AMBIGUITÀ E NOMI COLONNE STAMPA MOVIMENTI
-- Autore: Antigravity
-- Data: 2026-02-12
-- ============================================================================

-- Rimuovo tutte le possibili varianti precedenti per evitare conflitti di firma
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_dettaglio(integer, integer, integer, text[], integer, integer, integer, date, date, date, date, numeric, numeric, text, boolean, boolean, boolean, boolean, boolean, text, integer);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_dettaglio(integer, integer, integer, varchar[], integer, integer, integer, date, date, date, date, numeric, numeric, varchar, boolean, boolean, boolean, boolean, boolean, varchar, integer);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, integer, text[], integer, integer, integer, date, date, date, date, numeric, numeric, text, boolean, boolean, boolean, boolean, boolean, text, integer);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, integer, varchar[], integer, integer, integer, date, date, date, date, numeric, numeric, varchar, boolean, boolean, boolean, boolean, boolean, varchar, integer);

-- 1. FUNCTION DETTAGLIO
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
             f.ragione_sociale as f_ragione_sociale,
             tc.causale_codice as tm_codice,
             tc.causale_descrizione as tm_desc,
             tc.causale_segno as t_segno,
             t.transazione_causale as t_causale,
             t.transazione_stato as t_stato,
             t.transazione_numero_documento as t_num_doc,
             v.valuta_codice_iso as v_iso,
             t.transazione_importo as t_importo,
             CASE 
                 WHEN t.transazione_valuta_id = p_valuta_target_id THEN t.transazione_importo
                 ELSE COALESCE(t.transazione_importo_eur * NULLIF(fn_get_tasso_cambio(2, p_valuta_target_id, CURRENT_DATE), 0), 0)
             END as t_imp_target,
             vt.valuta_codice_iso as vt_iso,
             -- NOMI REALI DB: viaggio_descrizione_breve e data_viaggio_data_inizio
             av.viaggio_descrizione_breve as v_desc,
             adv.data_viaggio_data_inizio as v_data_inizio
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
                     WHEN p_ordinamento = 'FORNITORE' THEN fd.f_ragione_sociale
                     ELSE TO_CHAR(fd.transazione_data_documento, 'YYYY-MM')
                 END
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN fd.tm_desc
             ELSE 'GENERALE'
         END as g_chiave,
         CASE 
             WHEN p_ordinamento IN ('FORNITORE', 'DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN 
                 CASE 
                     WHEN p_ordinamento = 'FORNITORE' THEN fd.f_ragione_sociale
                     ELSE TO_CHAR(fd.transazione_data_documento, 'Month YYYY')
                 END
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN fd.tm_desc
             ELSE 'Tutte le transazioni'
         END as g_display,
         CASE 
             WHEN p_ordinamento = 'FORNITORE' THEN 1
             WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN CAST(TO_CHAR(fd.transazione_data_documento, 'YYYYMM') AS INTEGER)
             WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 1
             ELSE 1
         END as g_ordine,
         fd.transazione_id,
         fd.transazione_data,
         fd.transazione_data_documento,
         fd.transazione_data_scadenza,
         fd.transazione_data_pagamento,
         fd.f_ragione_sociale,
         fd.tm_codice,
         fd.tm_desc,
         fd.t_segno,
         fd.t_causale,
         fd.t_stato,
         fd.t_num_doc,
         fd.v_iso,
         fd.t_importo,
         fd.t_imp_target,
         fd.vt_iso,
         fd.v_desc,
         fd.v_data_inizio
     FROM filtered_data fd
     ORDER BY 
         g_ordine ASC,
         g_chiave NULLS LAST,
         CASE WHEN p_ordinamento = 'FORNITORE' THEN fd.transazione_data_documento END ASC,
         CASE WHEN p_ordinamento = 'DATA_DOCUMENTO' THEN fd.transazione_data_documento END ASC,
         CASE WHEN p_ordinamento = 'DATA_DOCUMENTO_DESC' THEN fd.transazione_data_documento END DESC,
         CASE WHEN p_ordinamento = 'IMPORTO_ASC' THEN fd.t_importo END ASC,
         CASE WHEN p_ordinamento = 'IMPORTO_DESC' THEN fd.t_importo END DESC,
         fd.transazione_id ASC;
 END;
 $function$;

-- 2. FUNCTION SUBTOTALI
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
             t.transazione_importo as b_importo,
             t.transazione_valuta_id,
             v.valuta_codice_iso as b_val_iso,
             f.ragione_sociale as b_fornitore_rs,
             t.transazione_data_documento as b_data_doc,
             tc.causale_codice as bt_codice,
             tc.causale_descrizione as bt_desc,
             tc.causale_segno as b_segno,
             CASE 
                 WHEN t.transazione_valuta_id = p_valuta_target_id THEN t.transazione_importo
                 ELSE COALESCE(t.transazione_importo_eur * NULLIF(fn_get_tasso_cambio(2, p_valuta_target_id, CURRENT_DATE), 0), 0)
             END as b_imp_target,
             vt.valuta_codice_iso as bt_iso
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
                 WHEN p_ordinamento = 'FORNITORE' THEN bd.b_fornitore_rs
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN TO_CHAR(bd.b_data_doc, 'YYYY-MM')
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN bd.bt_desc
                 ELSE 'GENERALE'
             END as s_key,
             CASE 
                 WHEN p_ordinamento = 'FORNITORE' THEN bd.b_fornitore_rs
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN TO_CHAR(bd.b_data_doc, 'Month YYYY')
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN bd.bt_desc
                 ELSE 'Tutte le transazioni'
             END as s_display,
             CASE 
                 WHEN p_ordinamento = 'FORNITORE' THEN 1
                 WHEN p_ordinamento IN ('DATA_DOCUMENTO', 'DATA_DOCUMENTO_DESC') THEN CAST(TO_CHAR(bd.b_data_doc, 'YYYYMM') AS INTEGER)
                 WHEN p_ordinamento = 'TIPO_MOVIMENTO' THEN 1
                 ELSE 1
             END as s_order,
             bd.b_val_iso,
             SUM(bd.b_importo * bd.b_segno) as s_tot_orig,
             SUM(bd.b_imp_target * bd.b_segno) as s_tot_target,
             SUM(CASE WHEN bd.b_segno > 0 THEN bd.b_imp_target ELSE 0 END) as s_tot_fatt,
             SUM(CASE WHEN bd.b_segno < 0 THEN bd.b_imp_target ELSE 0 END) as s_tot_pag,
             MAX(bd.bt_iso) as s_t_iso,
             COUNT(*) as s_cnt
         FROM base_data bd
         GROUP BY GROUPING SETS (
             (s_key, s_display, s_order, bd.b_val_iso),
             (bd.b_val_iso)
         )
     )
     SELECT 
         COALESCE(gd.s_key, 'TOTALE_GENERALE'),
         COALESCE(gd.s_display, 'TOTALE GENERALE'),
         COALESCE(gd.s_order, 999999),
         gd.b_val_iso,
         gd.s_tot_orig,
         gd.s_tot_target,
         gd.s_tot_fatt,
         gd.s_tot_pag,
         gd.s_t_iso,
         gd.s_cnt,
         (gd.s_key IS NULL) as is_total
     FROM grouped_data gd
     ORDER BY 
         is_total,
         gruppo_ordine NULLS LAST,
         gruppo_chiave NULLS LAST,
         gd.b_val_iso;
 END;
 $function$;
