-- ============================================================================
-- fn_get_mov_transazioni_print_data
-- Funzione "Fat Init" per la stampa Movimenti Transazioni.
-- Restituisce in un unico JSON:
-- 1. Header (Info Azienda)
-- 2. Dettagli (Transazioni)
-- 3. Subtotali (Aggregati per gruppo)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_mov_transazioni_print_data(
    p_azienda_id INTEGER DEFAULT NULL,
    p_controparte_id INTEGER DEFAULT NULL,
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
    p_valuta_target_id INTEGER DEFAULT NULL,
    p_causale_ciclo VARCHAR DEFAULT NULL
)
RETURNS JSONB
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
$function$;
