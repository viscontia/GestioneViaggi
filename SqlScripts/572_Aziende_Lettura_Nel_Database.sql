-- =============================================================================
-- 572 — L'ultimo filtro azienda scritto concatenando una stringa
-- =============================================================================
--
-- Cercato apposta dopo il 571, perche' un difetto del genere non sta mai in un
-- punto solo. Su tutto il gestionale i punti erano due: le controparti (571) e
-- questo.
--
--     sql += $" AND a.azienda_id = {currentAziendaId.Value}";
--
-- Qui c'e' un dettaglio che vale la pena guardare: nella stessa query il filtro
-- per anno usa un PARAMETRO (@year), il filtro azienda no. Chi l'ha scritta
-- sapeva parametrizzare, e proprio sulla riga che separa un'azienda dall'altra
-- ha concatenato. E' cosi' che nascono queste cose: non per ignoranza, ma
-- perche' quel valore "viene da noi" e sembra sicuro.
--
-- Non c'e' e non c'e' mai stato un buco sfruttabile: currentAziendaId e' un
-- intero preso dalla sessione. Ma l'invariante che tiene separate le aziende non
-- deve dipendere da come viene incollata una stringa.
--
-- Il resto del comportamento non cambia: chi non e' SuperAdmin passa la propria
-- azienda e vede solo quella; il SuperAdmin passa NULL e le vede tutte.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ana_aziende_get_all(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fn_ana_aziende_get_all(
    p_azienda_id  INTEGER DEFAULT NULL,   -- NULL = tutte (SuperAdmin)
    p_filter_year INTEGER DEFAULT NULL
)
RETURNS TABLE(
    azienda_id INTEGER,
    ragione_sociale VARCHAR,
    forma_giuridica VARCHAR,
    data_costituzione DATE,
    data_inizio_attivita DATE,
    capitale_sociale NUMERIC,
    socio_unico BOOLEAN,
    in_liquidazione BOOLEAN,
    partita_iva VARCHAR,
    codice_fiscale VARCHAR,
    rea_provincia_fk INTEGER,
    rea_numero VARCHAR,
    rea_data_iscrizione DATE,
    codice_destinatario_sdi VARCHAR,
    pec VARCHAR,
    sito_web VARCHAR,
    sito_web_iscrizione VARCHAR,
    telefono_principale VARCHAR,
    attivo BOOLEAN,
    regime_fiscale_fk INTEGER,
    data_creazione TIMESTAMPTZ,
    data_ultima_modifica TIMESTAMPTZ,
    rea_provincia_sigla VARCHAR,
    regime_fiscale_codice VARCHAR,
    regime_fiscale_descrizione VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.azienda_id, a.ragione_sociale, a.forma_giuridica,
        a.data_costituzione, a.data_inizio_attivita, a.capitale_sociale,
        a.socio_unico, a.in_liquidazione, a.partita_iva, a.codice_fiscale,
        a.rea_provincia_fk, a.rea_numero, a.rea_data_iscrizione,
        a.codice_destinatario_sdi, a.pec, a.sito_web, a.sito_web_iscrizione,
        a.telefono_principale, a.attivo, a.regime_fiscale_fk,
        a.data_creazione, a.data_ultima_modifica,
        p.provincia_sigla    AS rea_provincia_sigla,
        r.regime_codice      AS regime_fiscale_codice,
        r.regime_descrizione AS regime_fiscale_descrizione
    FROM ana_aziende a
    LEFT JOIN ana_geo_province p   ON a.rea_provincia_fk = p.provincia_id
    LEFT JOIN ana_regimi_fiscali r ON a.regime_fiscale_fk = r.regime_id
    -- Il confine fra le aziende, come parametro. NULL vale "tutte", ed e' il
    -- SuperAdmin: e' l'unico che le vede tutte, e lo decide chi chiama.
    WHERE (p_azienda_id IS NULL OR a.azienda_id = p_azienda_id)
      AND (p_filter_year IS NULL
           OR EXTRACT(YEAR FROM a.data_creazione) = p_filter_year)
    ORDER BY a.ragione_sociale ASC;
END;
$$;

COMMENT ON FUNCTION fn_ana_aziende_get_all(INTEGER, INTEGER) IS
'Elenco aziende con provincia REA e regime fiscale. Sostituisce la query che AziendaService
costruiva in C#, dove il filtro azienda era concatenato nella stringa mentre il filtro anno
era gia'' un parametro. NULL su p_azienda_id vale "tutte": e'' il caso del SuperAdmin.';
