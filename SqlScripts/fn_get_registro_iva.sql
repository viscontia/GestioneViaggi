-- ============================================================================
-- fn_get_registro_iva
-- Restituisce il dettaglio delle fatture con IVA per il Registro IVA
-- (Acquisti e Vendite), filtrate per periodo e azienda.
-- Solo transazioni EUR con causale_genera_iva = TRUE.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_registro_iva(
    p_azienda_id INTEGER,
    p_data_documento_da DATE DEFAULT NULL,
    p_data_documento_a DATE DEFAULT NULL
)
RETURNS TABLE (
    causale_ciclo VARCHAR,
    transazione_id INTEGER,
    transazione_data_documento DATE,
    transazione_numero_documento VARCHAR,
    controparte_ragione_sociale VARCHAR,
    causale_codice VARCHAR,
    causale_descrizione VARCHAR,
    aliquota_iva_codice VARCHAR,
    aliquota_iva_percentuale NUMERIC,
    aliquota_iva_descrizione VARCHAR,
    imponibile_eur NUMERIC,
    iva_eur NUMERIC,
    lordo_eur NUMERIC,
    causale_segno INTEGER
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        ca.causale_ciclo::VARCHAR,
        t.transazione_id,
        t.transazione_data_documento,
        t.transazione_numero_documento,
        c.ragione_sociale AS controparte_ragione_sociale,
        ca.causale_codice::VARCHAR,
        ca.causale_descrizione::VARCHAR,
        iva.iva_codice::VARCHAR AS aliquota_iva_codice,
        iva.iva_percentuale AS aliquota_iva_percentuale,
        iva.iva_descrizione::VARCHAR AS aliquota_iva_descrizione,
        COALESCE(t.transazione_imponibile_eur, 0)::NUMERIC AS imponibile_eur,
        COALESCE(t.transazione_iva_eur, 0)::NUMERIC AS iva_eur,
        COALESCE(t.transazione_lordo_eur, t.transazione_importo, 0)::NUMERIC AS lordo_eur,
        ca.causale_segno
    FROM mov_transazioni t
    INNER JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
    LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
    LEFT JOIN ana_aliquote_iva iva ON t.transazione_aliquota_iva_fk = iva.iva_id
    WHERE
        t.transazione_azienda_id = p_azienda_id
        AND ca.causale_genera_iva = TRUE
        AND v.valuta_codice_iso = 'EUR'
        AND t.transazione_stato != 'ANNULLATO'
        AND (p_data_documento_da IS NULL OR t.transazione_data_documento >= p_data_documento_da)
        AND (p_data_documento_a IS NULL OR t.transazione_data_documento <= p_data_documento_a)
    ORDER BY
        -- PASSIVO (Acquisti) first, then ATTIVO (Vendite)
        CASE ca.causale_ciclo WHEN 'PASSIVO' THEN 1 WHEN 'ATTIVO' THEN 2 ELSE 3 END,
        t.transazione_data_documento ASC,
        t.transazione_numero_documento ASC;
END;
$function$;
