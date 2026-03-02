-- Function: Elenco fatture attive filtrato per pagina di ricerca
-- Data: 2026-03-02

DROP FUNCTION IF EXISTS fn_get_fatture_attive_elenco(INTEGER, INTEGER, DATE, DATE, NUMERIC, NUMERIC, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fn_get_fatture_attive_elenco(
    p_azienda_id INTEGER,
    p_controparte_id INTEGER DEFAULT NULL,
    p_data_doc_da DATE DEFAULT NULL,
    p_data_doc_a DATE DEFAULT NULL,
    p_importo_da NUMERIC DEFAULT NULL,
    p_importo_a NUMERIC DEFAULT NULL,
    p_stato VARCHAR DEFAULT NULL,
    p_numero_documento VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    transazione_id INTEGER,
    transazione_data DATE,
    data_documento DATE,
    numero_documento VARCHAR,
    numero_protocollo_iva INTEGER,
    controparte_ragione_sociale VARCHAR,
    imponibile_eur NUMERIC,
    iva_eur NUMERIC,
    lordo_eur NUMERIC,
    stato VARCHAR,
    data_scadenza DATE,
    causale_descrizione VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.transazione_id,
        t.transazione_data,
        t.transazione_data_documento AS data_documento,
        t.transazione_numero_documento AS numero_documento,
        t.transazione_numero_protocollo_iva AS numero_protocollo_iva,
        c.ragione_sociale AS controparte_ragione_sociale,
        t.transazione_imponibile_eur AS imponibile_eur,
        t.transazione_iva_eur AS iva_eur,
        t.transazione_lordo_eur AS lordo_eur,
        t.transazione_stato AS stato,
        t.transazione_data_scadenza AS data_scadenza,
        tc.causale_descrizione
    FROM mov_transazioni t
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    WHERE t.transazione_azienda_id = p_azienda_id
      AND tc.causale_ciclo = 'ATTIVO'
      AND (p_controparte_id IS NULL OR t.transazione_controparte_id = p_controparte_id)
      AND (p_data_doc_da IS NULL OR COALESCE(t.transazione_data_documento, t.transazione_data) >= p_data_doc_da)
      AND (p_data_doc_a IS NULL OR COALESCE(t.transazione_data_documento, t.transazione_data) <= p_data_doc_a)
      AND (p_importo_da IS NULL OR COALESCE(t.transazione_lordo_eur, t.transazione_importo) >= p_importo_da)
      AND (p_importo_a IS NULL OR COALESCE(t.transazione_lordo_eur, t.transazione_importo) <= p_importo_a)
      AND (p_stato IS NULL OR t.transazione_stato = p_stato)
      AND (p_numero_documento IS NULL OR t.transazione_numero_documento ILIKE '%' || p_numero_documento || '%')
    ORDER BY COALESCE(t.transazione_data_documento, t.transazione_data) DESC, t.created_at DESC;
END;
$$;
