-- ============================================================================
-- fn_get_fattura_attiva_print_data
-- Funzione "Fat Init" per la Fattura Attiva.
-- Consolda: Testatata (fn_get_fattura_attiva_stampa) + Righe.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_fattura_attiva_print_data(
    p_transazione_id INTEGER
)
RETURNS JSONB
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
$function$;
