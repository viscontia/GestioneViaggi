-- ============================================================================
-- 650 — Le cinque stampe che in produzione non c'erano
--
-- COME SI E' SCOPERTO. Ripulendo le firme duplicate (script 649) si e' fatto un
-- controllo che non era mai stato fatto: prendere TUTTI i nomi di funzione che
-- il gestionale cita nel codice e chiedere al database di produzione quali non
-- esistono. Ne sono uscite cinque, ed erano tutte della stessa famiglia:
--
--   fn_get_mov_transazioni_print_data     stampa dei movimenti contabili
--   fn_get_scadenzario_print_data         stampa dello scadenzario
--   fn_get_registro_iva_print_data        stampa del registro IVA
--   fn_get_bilancio_viaggio_print_data    stampa del bilancio viaggio
--   fn_get_fattura_attiva_print_data      stampa della fattura attiva
--
-- ⛔️ In altre parole: in produzione NESSUNA stampa contabile poteva funzionare.
-- Non e' un difetto nuovo, e' un'assenza rimasta dal go-live: sono le funzioni
-- «Fat Init» degli script 310-350, che in PROD non sono mai state applicate. Il
-- gestionale le chiama, non le trova, e la stampa non parte.
--
-- ℹ️ Perche' non se n'era accorto nessuno: per stampare servono movimenti
-- contabili, e in produzione non ce n'erano ancora. Il difetto sarebbe uscito
-- alla prima stampa vera — cioe' davanti al cliente.
--
-- COSA FA QUESTO SCRIPT. Ricrea le cinque funzioni esattamente come sono
-- nell'ambiente di sviluppo, dove sono in servizio e collaudate. Le definizioni
-- sono state LETTE dal database (pg_get_functiondef), non ricopiate a mano:
-- e' l'unico modo per essere certi che i due ambienti siano identici.
--
-- ⚠️ Dipendenze, tutte gia' presenti in PROD e verificate una per una:
-- get_company_print_info, fn_get_transazioni_stampa_dettaglio/subtotali,
-- fn_get_registro_iva, fn_get_scadenzario_stampa, fn_get_fattura_attiva_stampa,
-- fn_get_bilancio_viaggio, fn_get_bilancio_annuale_viaggi.
--
-- ⚠️ La stampa del bilancio ha bisogno anche dello script 638: con tre firme di
-- fn_get_bilancio_viaggio la chiamata qui dentro sarebbe ambigua. Per questo il
-- 638 e' stato applicato in PROD insieme a questo script, e non al rilascio.
--
-- ✅ Idempotente: sono CREATE OR REPLACE. Applicato in PROD il 2026-09-20 e
-- verificato chiamando tutte e cinque le stampe.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_get_bilancio_viaggio_print_data(p_azienda_id integer, p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date, p_anno integer DEFAULT NULL::integer, p_valuta_target_id integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_dettagli JSONB;
BEGIN
    -- 1. Recupero Info Azienda
    SELECT jsonb_build_object(
        'ragione_sociale', ragione_sociale,
        'telefono', telefono,
        'email', email,
        'sito_web', sito_web,
        'piva', piva,
        'logo_data', logo_data
    ) INTO v_azienda_info
    FROM get_company_print_info(p_azienda_id);

    -- 2. Recupero Dettagli
    -- Se p_anno è valorizzato, usiamo la versione annuale
    IF p_anno IS NOT NULL THEN
        SELECT jsonb_agg(t) INTO v_dettagli
        FROM (
            SELECT * FROM fn_get_bilancio_annuale_viaggi(p_azienda_id, p_anno)
        ) t;
    ELSE
        SELECT jsonb_agg(t) INTO v_dettagli
        FROM (
            SELECT * FROM fn_get_bilancio_viaggio(p_azienda_id, p_viaggio_id, p_data_viaggio_id, p_data_da, p_data_a)
        ) t;
    END IF;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'dettagli', COALESCE(v_dettagli, '[]'::jsonb)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_fattura_attiva_print_data(p_transazione_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_testata JSONB;
    v_righe JSONB;
BEGIN
    -- 1. Recupero Testata (già contiene info azienda e cliente)
    SELECT row_to_json(t)::jsonb INTO v_testata
    FROM (
        SELECT * FROM fn_get_fattura_attiva_stampa(p_transazione_id)
    ) t;

    -- 2. Recupero Righe
    SELECT jsonb_agg(r) INTO v_righe
    FROM (
        SELECT
            rig.riga_numero,
            rig.riga_descrizione,
            rig.riga_tipo,
            rig.riga_imponibile,
            iva.iva_codice AS aliquota_iva_codice,
            iva.iva_percentuale AS aliquota_iva_percentuale,
            iva.iva_natura AS aliquota_iva_natura,
            rig.riga_iva_valore,
            rig.riga_lordo
        FROM mov_transazioni_righe rig
        JOIN ana_aliquote_iva iva ON rig.riga_aliquota_iva_fk = iva.iva_id
        WHERE rig.transazione_fk = p_transazione_id
        ORDER BY rig.riga_numero
    ) r;

    RETURN jsonb_build_object(
        'testata', v_testata,
        'righe', COALESCE(v_righe, '[]'::jsonb)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_mov_transazioni_print_data(p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_dettagli JSONB;
    v_subtotali JSONB;
BEGIN
    -- 1. Recupero Info Azienda
    SELECT jsonb_build_object(
        'ragione_sociale', ragione_sociale,
        'telefono', telefono,
        'email', email,
        'sito_web', sito_web,
        'piva', piva,
        'logo_data', logo_data
    ) INTO v_azienda_info
    FROM get_company_print_info(p_azienda_id);

    -- 2. Recupero Dettagli
    SELECT jsonb_agg(t) INTO v_dettagli
    FROM (
        SELECT * FROM fn_get_transazioni_stampa_dettaglio(
            p_azienda_id, p_controparte_id, p_causale_tipo_id, p_stati,
            p_viaggio_id, p_data_viaggio_id, p_valuta_id,
            p_data_transazione_da, p_data_transazione_a,
            p_data_documento_da, p_data_documento_a,
            p_importo_da, p_importo_a, p_numero_documento,
            p_solo_con_documento, p_solo_scadute,
            p_solo_con_viaggio, p_solo_senza_viaggio, p_solo_con_fattura,
            p_ordinamento, p_valuta_target_id, p_causale_ciclo
        )
    ) t;

    -- 3. Recupero Subtotali
    SELECT jsonb_agg(s) INTO v_subtotali
    FROM (
        SELECT * FROM fn_get_transazioni_stampa_subtotali(
            p_azienda_id, p_controparte_id, p_causale_tipo_id, p_stati,
            p_viaggio_id, p_data_viaggio_id, p_valuta_id,
            p_data_transazione_da, p_data_transazione_a,
            p_data_documento_da, p_data_documento_a,
            p_importo_da, p_importo_a, p_numero_documento,
            p_solo_con_documento, p_solo_scadute,
            p_solo_con_viaggio, p_solo_senza_viaggio, p_solo_con_fattura,
            p_ordinamento, p_valuta_target_id, p_causale_ciclo
        )
    ) s;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'dettagli', COALESCE(v_dettagli, '[]'::jsonb),
        'subtotali', COALESCE(v_subtotali, '[]'::jsonb)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_registro_iva_print_data(p_azienda_id integer, p_periodo_da date, p_periodo_a date)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_items JSONB;
BEGIN
    -- 1. Recupero Info Azienda
    SELECT jsonb_build_object(
        'ragione_sociale', ragione_sociale,
        'telefono', telefono,
        'email', email,
        'sito_web', sito_web,
        'piva', piva,
        'logo_data', logo_data
    ) INTO v_azienda_info
    FROM get_company_print_info(p_azienda_id);

    -- 2. Recupero Dettagli Registro IVA
    SELECT jsonb_agg(t) INTO v_items
    FROM (
        SELECT * FROM fn_get_registro_iva(p_azienda_id, p_periodo_da, p_periodo_a)
    ) t;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'items', COALESCE(v_items, '[]'::jsonb)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_scadenzario_print_data(p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying, p_urgenza character varying DEFAULT NULL::character varying, p_data_scadenza_da date DEFAULT NULL::date, p_data_scadenza_a date DEFAULT NULL::date, p_viaggio_id integer DEFAULT NULL::integer, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_raggruppamento character varying DEFAULT 'URGENZA'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_info JSONB;
    v_dettagli JSONB;
BEGIN
    -- 1. Recupero Info Azienda
    SELECT jsonb_build_object(
        'ragione_sociale', ragione_sociale,
        'telefono', telefono,
        'email', email,
        'sito_web', sito_web,
        'piva', piva,
        'logo_data', logo_data
    ) INTO v_azienda_info
    FROM get_company_print_info(p_azienda_id);

    -- 2. Recupero Dettagli Scadenzario
    SELECT jsonb_agg(t) INTO v_dettagli
    FROM (
        SELECT * FROM fn_get_scadenzario_stampa(
            p_azienda_id, p_controparte_id, p_causale_ciclo, p_urgenza,
            p_data_scadenza_da, p_data_scadenza_a, p_viaggio_id,
            p_solo_con_viaggio, p_solo_senza_viaggio, p_raggruppamento
        )
    ) t;

    RETURN jsonb_build_object(
        'azienda', v_azienda_info,
        'dettagli', COALESCE(v_dettagli, '[]'::jsonb)
    );
END;
$function$
;

COMMIT;

-- ============================================================================
-- Verifica: nessuna deve rispondere «function ... does not exist».
--
--   SELECT left(fn_get_mov_transazioni_print_data(2)::text, 40);
--   SELECT left(fn_get_scadenzario_print_data(2)::text, 40);
--   SELECT left(fn_get_registro_iva_print_data(2,'2026-01-01','2026-12-31')::text, 40);
--   SELECT left(fn_get_bilancio_viaggio_print_data(2,NULL,NULL,NULL,NULL,2026)::text, 40);
-- ============================================================================
