-- Dati aziendali per intestazione e footer della newsletter (Fase 3).
-- Design: "Estensione Progetto WEB/Documenti/2026-08-09-Newsletter_Blocchi_design.md" §6.5
--
-- Il footer e' componibile per azienda (quali campi, in quale ordine): questa function
-- restituisce TUTTI i campi disponibili in una sola lettura, e la composizione decide quali
-- mostrare. Meglio una query sola che sei letture separate al momento di ogni anteprima.
--
-- L'indirizzo si compone dalla sede principale (ana_aziende_sedi.is_principale), che e' dove
-- vivono indirizzo, comune e provincia. L'email dalla sede principale o, in mancanza,
-- dall'email aziendale principale.

CREATE OR REPLACE FUNCTION fn_web_newsletter_dati_azienda(p_azienda_id INTEGER)
RETURNS TABLE(
    ragione_sociale VARCHAR,
    partita_iva     VARCHAR,
    indirizzo       VARCHAR,
    email           VARCHAR,
    telefono        VARCHAR,
    sito_web        VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT
        a.ragione_sociale,
        a.partita_iva,
        (SELECT NULLIF(BTRIM(CONCAT_WS(', ',
                    NULLIF(BTRIM(CONCAT_WS(' ',
                        NULLIF(BTRIM(s.indirizzo), ''),
                        NULLIF(BTRIM(s.numero_civico), ''))), ''),
                    NULLIF(BTRIM(CONCAT_WS(' ',
                        NULLIF(BTRIM(c.comune_cap), ''),
                        NULLIF(BTRIM(c.comune_descrizione), ''))), '')
               )), '')::VARCHAR
           FROM ana_aziende_sedi s
           LEFT JOIN ana_geo_comuni c ON c.comune_id = s.comune_fk
          WHERE s.azienda_fk = a.azienda_id
          ORDER BY s.is_principale DESC, s.sede_id
          LIMIT 1) AS indirizzo,
        COALESCE(
            (SELECT NULLIF(BTRIM(s.email), '') FROM ana_aziende_sedi s
              WHERE s.azienda_fk = a.azienda_id
              ORDER BY s.is_principale DESC, s.sede_id LIMIT 1),
            (SELECT NULLIF(BTRIM(e.email), '') FROM ana_aziende_email e
              WHERE e.azienda_fk = a.azienda_id
              ORDER BY e.is_principale DESC, e.email_id LIMIT 1)
        )::VARCHAR AS email,
        a.telefono_principale,
        a.sito_web
      FROM ana_aziende a
     WHERE a.azienda_id = p_azienda_id;
$$;
