-- ============================================================
-- 241: Aggiornamento fn_get_fattura_attiva_stampa con campi SDI
-- Aggiunge: regime_codice_sdi, tipo_cassa_sdi,
--           cassa_prev_percentuale, tipo_documento_sdi
-- Data: 2026-03-07
-- ============================================================

DROP FUNCTION IF EXISTS fn_get_fattura_attiva_stampa(INTEGER);

CREATE OR REPLACE FUNCTION fn_get_fattura_attiva_stampa(p_transazione_id INTEGER)
RETURNS TABLE (
    -- Transazione
    transazione_id INTEGER,
    transazione_data DATE,
    transazione_data_documento DATE,
    transazione_data_scadenza DATE,
    transazione_numero_documento VARCHAR,
    transazione_stato VARCHAR,
    transazione_causale TEXT,
    transazione_numero_protocollo_iva INTEGER,
    transazione_imponibile_eur NUMERIC,
    transazione_iva_eur NUMERIC,
    transazione_lordo_eur NUMERIC,
    transazione_tipo_movimento VARCHAR,
    -- Azienda (emittente)
    azienda_id INTEGER,
    azienda_ragione_sociale VARCHAR,
    azienda_forma_giuridica VARCHAR,
    azienda_partita_iva VARCHAR,
    azienda_codice_fiscale VARCHAR,
    azienda_telefono VARCHAR,
    azienda_pec VARCHAR,
    azienda_sito_web VARCHAR,
    azienda_codice_sdi VARCHAR,
    azienda_rea_numero VARCHAR,
    azienda_rea_provincia_sigla VARCHAR,
    azienda_capitale_sociale NUMERIC,
    azienda_socio_unico BOOLEAN,
    azienda_in_liquidazione BOOLEAN,
    -- Regime fiscale
    regime_codice VARCHAR,
    regime_descrizione VARCHAR,
    regime_is_iva_detraibile BOOLEAN,
    -- SDI: Nuovi campi regime
    regime_codice_sdi VARCHAR,
    tipo_cassa_sdi VARCHAR,
    cassa_prev_percentuale NUMERIC,
    -- Sede principale
    sede_indirizzo VARCHAR,
    sede_numero_civico VARCHAR,
    sede_cap VARCHAR,
    sede_comune VARCHAR,
    sede_provincia_sigla VARCHAR,
    sede_telefono VARCHAR,
    sede_email VARCHAR,
    -- Logo
    logo_data BYTEA,
    -- Controparte (cliente)
    controparte_id INTEGER,
    controparte_ragione_sociale VARCHAR,
    controparte_indirizzo VARCHAR,
    controparte_cap VARCHAR,
    controparte_comune VARCHAR,
    controparte_provincia_sigla VARCHAR,
    controparte_partita_iva VARCHAR,
    controparte_codice_fiscale VARCHAR,
    controparte_codice_sdi VARCHAR,
    controparte_pec VARCHAR,
    controparte_fornitore_estero BOOLEAN,
    -- Causale
    causale_descrizione VARCHAR,
    causale_ciclo VARCHAR,
    causale_codice VARCHAR,
    -- SDI: Tipo documento
    tipo_documento_sdi VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- Transazione
        t.transazione_id,
        t.transazione_data,
        t.transazione_data_documento,
        t.transazione_data_scadenza,
        t.transazione_numero_documento,
        t.transazione_stato,
        t.transazione_causale,
        t.transazione_numero_protocollo_iva,
        t.transazione_imponibile_eur,
        t.transazione_iva_eur,
        t.transazione_lordo_eur,
        t.transazione_tipo_movimento,
        -- Azienda
        a.azienda_id,
        a.ragione_sociale,
        a.forma_giuridica,
        a.partita_iva,
        a.codice_fiscale,
        a.telefono_principale,
        a.pec,
        a.sito_web,
        a.codice_destinatario_sdi,
        a.rea_numero,
        rea_p.provincia_sigla AS azienda_rea_provincia_sigla,
        a.capitale_sociale,
        a.socio_unico,
        a.in_liquidazione,
        -- Regime fiscale
        rf.regime_codice,
        rf.regime_descrizione,
        rf.is_iva_detraibile,
        -- SDI: Nuovi campi regime
        rf.regime_codice_sdi,
        rf.tipo_cassa_sdi,
        rf.cassa_prev_percentuale,
        -- Sede principale
        s.indirizzo AS sede_indirizzo,
        s.numero_civico AS sede_numero_civico,
        sc.comune_cap AS sede_cap,
        sc.comune_descrizione AS sede_comune,
        sp.provincia_sigla AS sede_provincia_sigla,
        s.telefono AS sede_telefono,
        s.email AS sede_email,
        -- Logo
        (SELECT al.binary_data
         FROM ana_aziende_logo al
         WHERE al.azienda_fk = a.azienda_id
           AND al.is_active = true
           AND al.is_default = true
         LIMIT 1) AS logo_data,
        -- Controparte (cliente)
        c.controparte_id,
        c.ragione_sociale AS controparte_ragione_sociale,
        c.indirizzo AS controparte_indirizzo,
        cc.comune_cap AS controparte_cap,
        cc.comune_descrizione AS controparte_comune,
        cp.provincia_sigla AS controparte_provincia_sigla,
        c.partita_iva AS controparte_partita_iva,
        c.codice_fiscale AS controparte_codice_fiscale,
        c.codice_destinatario_sdi AS controparte_codice_sdi,
        c.pec AS controparte_pec,
        c.fornitore_estero AS controparte_fornitore_estero,
        -- Causale
        tc.causale_descrizione,
        tc.causale_ciclo,
        tc.causale_codice,
        -- SDI: Tipo documento
        tc.tipo_documento_sdi
    FROM mov_transazioni t
    JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
    JOIN ana_regimi_fiscali rf ON a.regime_fiscale_fk = rf.regime_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    -- Sede principale dell'azienda
    LEFT JOIN LATERAL (
        SELECT s2.indirizzo, s2.numero_civico, s2.comune_fk, s2.telefono, s2.email
        FROM ana_aziende_sedi s2
        WHERE s2.azienda_fk = a.azienda_id AND s2.is_principale = TRUE
        LIMIT 1
    ) s ON TRUE
    LEFT JOIN ana_geo_comuni sc ON s.comune_fk = sc.comune_id
    LEFT JOIN ana_geo_province sp ON sc.comune_provincia_fk = sp.provincia_id
    -- Provincia REA
    LEFT JOIN ana_geo_province rea_p ON a.rea_provincia_fk = rea_p.provincia_id
    -- Comune/Provincia controparte
    LEFT JOIN ana_geo_comuni cc ON c.comune_fk = cc.comune_id
    LEFT JOIN ana_geo_province cp ON cc.comune_provincia_fk = cp.provincia_id
    WHERE t.transazione_id = p_transazione_id
      AND tc.causale_ciclo = 'ATTIVO';
END;
$$;

COMMENT ON FUNCTION fn_get_fattura_attiva_stampa(INTEGER)
    IS 'Recupera tutti i dati per stampa/export fattura attiva, inclusi campi SDI (regime_codice_sdi, tipo_cassa_sdi, tipo_documento_sdi)';
