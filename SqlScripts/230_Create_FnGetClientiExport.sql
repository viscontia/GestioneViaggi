-- ============================================================================
-- fn_get_clienti_export
-- Restituisce i dati clienti in formato flat per export Excel.
-- Solo campi business (no FK tecnici, no blob binari).
-- Comuni e province decodificati con JOIN.
-- ============================================================================

DROP FUNCTION IF EXISTS fn_get_clienti_export(INTEGER);

CREATE OR REPLACE FUNCTION fn_get_clienti_export(
    p_azienda_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    cognome             VARCHAR,
    nome                VARCHAR,
    titolo              VARCHAR,
    sesso               CHAR(1),
    data_nascita        DATE,
    comune_nascita      TEXT,
    provincia_nascita   VARCHAR,
    indirizzo_residenza VARCHAR,
    comune_residenza    TEXT,
    provincia_residenza VARCHAR,
    prefisso_telefono   VARCHAR,
    telefono            VARCHAR,
    email               VARCHAR,
    codice_fiscale      VARCHAR,
    iban                VARCHAR,
    tipo_documento      VARCHAR,
    numero_documento    VARCHAR,
    documento_rilasciato_da VARCHAR,
    documento_data_rilascio DATE,
    documento_data_scadenza DATE,
    intolleranza        TEXT,
    note                TEXT,
    azienda             VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cliente_cognome::VARCHAR,
        c.cliente_nome::VARCHAR,
        c.cliente_titolo::VARCHAR,
        c.cliente_sesso,
        c.cliente_data_nascita::DATE,
        com_nas.comune_descrizione::TEXT,
        prov_nas.provincia_sigla::VARCHAR,
        c.cliente_indirizzo_residenza::VARCHAR,
        com_res.comune_descrizione::TEXT,
        prov_res.provincia_sigla::VARCHAR,
        c.cliente_preftelint::VARCHAR,
        c.cliente_telefono::VARCHAR,
        c.cliente_email::VARCHAR,
        c.cliente_codicefiscale::VARCHAR,
        c.cliente_iban::VARCHAR,
        c.cliente_tipodoc_identita::VARCHAR,
        c.cliente_documento_numero::VARCHAR,
        c.cliente_documento_rilasciato_da::VARCHAR,
        c.cliente_documento_rilasciato_data::DATE,
        c.cliente_documento_rilasciato_scadenza::DATE,
        c.cliente_intolleranza::TEXT,
        c.cliente_note::TEXT,
        a.ragione_sociale::VARCHAR
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    WHERE (p_azienda_id IS NULL OR c.azienda_fk = p_azienda_id)
    ORDER BY a.ragione_sociale, c.cliente_cognome, c.cliente_nome;
END;
$$;

COMMENT ON FUNCTION fn_get_clienti_export(INTEGER) IS
'Restituisce dati clienti flat per export Excel. Campi business only, comuni/province decodificati.';
