-- =============================================================================
-- 558 — Le letture dei clienti restituiscono tutto cio' che serve al model
-- =============================================================================
-- Le funzioni di lettura ESISTEVANO gia' — fn_get_all_clienti, fn_get_cliente_by_id,
-- fn_search_clienti — e restituiscono JSON con le chiavi in PascalCase, pensate per
-- essere deserializzate dritte nel model C#. Solo che nessuno le chiamava: il
-- repository si scriveva le SELECT a mano. Stesso schema di sp_ana_clienti_*.
--
-- Per poterle collegare devono restituire cio' che il model ha oggi:
--   · la CHIAVE del titolo, non solo il testo deprecato. Senza, il repository
--     leggerebbe un cliente con TitoloFk a zero e al primo salvataggio lo
--     riscriverebbe cosi';
--   · lingua e consenso, che prima passavano da chiamate separate;
--   · i COMUNI annidati (descrizione e provincia), che il repository costruiva a
--     mano dai join — join che in queste funzioni c'erano gia', inutilizzati.
--
-- Le definizioni ripartono da pg_get_functiondef, per non perdere nulla.
--
-- ⚠️ La foto resta SOLO nel dettaglio. L'elenco non la porta, ed e' giusto:
--    169 clienti pesano 189 kB senza, molto di piu' con.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_get_all_clienti(p_azienda_fk integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'ClienteId', c.cliente_id,
            'TitoloFk', c.cliente_titolo_fk,
            'Lingua', c.cliente_lingua,
            'Consenso', c.consenso_marketing,
            'Titolo', c.cliente_titolo,
            'Cognome', c.cliente_cognome,
            'Nome', c.cliente_nome,
            'Sesso', c.cliente_sesso,
            'ComuneResidenzaFk', c.cliente_comune_residenza_fk,
            'IndirizzoResidenza', c.cliente_indirizzo_residenza,
            'ComuneNascitaFk', c.cliente_comune_nascita_fk,
            'DataNascita', c.cliente_data_nascita,
            'PrefTelInt', c.cliente_preftelint,
            'Telefono', c.cliente_telefono,
            'Email', c.cliente_email,
            'CodiceFiscale', c.cliente_codicefiscale,
            'Iban', c.cliente_iban,
            'TipoDocIdentita', c.cliente_tipodoc_identita,
            'DocumentoNumero', c.cliente_documento_numero,
            'DocumentoRilasciatoDa', c.cliente_documento_rilasciato_da,
            'DocumentoRilasciatoData', c.cliente_documento_rilasciato_data,
            'DocumentoRilasciatoScadenza', c.cliente_documento_rilasciato_scadenza,
            'Note', c.cliente_note,
            'Intolleranza', c.cliente_intolleranza,
            'AziendaFk', c.azienda_fk,
            'CreatedBy', c.created_by,
            'Created', c.created,
            'UpdatedBy', c.updated_by,
            'Updated', c.updated,
            'AziendaRagioneSociale', a.ragione_sociale,
            'ViaggiFatti', COALESCE(viaggi_fatti.count, 0),
            'ViaggiDaFare', COALESCE(viaggi_futuri.count, 0),
            'ComuneNascita', CASE
                WHEN com_nas.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_nas.comune_descrizione,
                        'ProvinciaSigla', prov_nas.provincia_sigla,
                        'ProvinciaDescrizione', prov_nas.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_nas.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END,
            'ComuneResidenza', CASE
                WHEN com_res.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_res.comune_descrizione,
                        'ProvinciaSigla', prov_res.provincia_sigla,
                        'ProvinciaDescrizione', prov_res.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_res.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END
        ) ORDER BY c.cliente_cognome, c.cliente_nome
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    LEFT JOIN LATERAL (
        SELECT COUNT(*) as count
        FROM mov_clienti_viaggi mcv
        JOIN ana_date_viaggi adv ON mcv.data_viaggio_id_fk = adv.data_viaggio_id
        WHERE mcv.cliente_id_fk = c.cliente_id
          AND adv.data_viaggio_data_inizio < CURRENT_DATE
          AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM adv.data_viaggio_data_inizio) = p_filter_year)
    ) viaggi_fatti ON true
    LEFT JOIN LATERAL (
        SELECT COUNT(*) as count
        FROM mov_clienti_viaggi mcv
        JOIN ana_date_viaggi adv ON mcv.data_viaggio_id_fk = adv.data_viaggio_id
        WHERE mcv.cliente_id_fk = c.cliente_id
          AND adv.data_viaggio_data_inizio >= CURRENT_DATE
          AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM adv.data_viaggio_data_inizio) = p_filter_year)
    ) viaggi_futuri ON true
    WHERE (p_azienda_fk IS NULL OR c.azienda_fk = p_azienda_fk);

    RETURN COALESCE(v_result, '[]'::json);
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_get_cliente_by_id(p_cliente_id integer, p_azienda_fk integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'ClienteId', c.cliente_id,
            -- I comuni annidati: il repository li costruiva a mano dai join, che qui
            -- c'erano gia'. Senza, la form perderebbe descrizione e provincia.
            'ComuneNascita', CASE WHEN com_nas.comune_id IS NOT NULL THEN json_build_object(
                'Id', com_nas.comune_id, 'Nome', com_nas.comune_descrizione,
                'ProvinciaDescrizione', prov_nas.provincia_descrizione) END,
            'ComuneResidenza', CASE WHEN com_res.comune_id IS NOT NULL THEN json_build_object(
                'Id', com_res.comune_id, 'Nome', com_res.comune_descrizione,
                'ProvinciaDescrizione', prov_res.provincia_descrizione) END,
            'TitoloFk', c.cliente_titolo_fk,
            'Lingua', c.cliente_lingua,
            'Consenso', c.consenso_marketing,
        'Titolo', c.cliente_titolo,
        'Cognome', c.cliente_cognome,
        'Nome', c.cliente_nome,
        'Sesso', c.cliente_sesso,
        'ComuneResidenzaFk', c.cliente_comune_residenza_fk,
        'IndirizzoResidenza', c.cliente_indirizzo_residenza,
        'ComuneNascitaFk', c.cliente_comune_nascita_fk,
        'DataNascita', c.cliente_data_nascita,
        'PrefTelInt', c.cliente_preftelint,
        'Telefono', c.cliente_telefono,
        'Email', c.cliente_email,
        'CodiceFiscale', c.cliente_codicefiscale,
        'Iban', c.cliente_iban,
        'Foto', encode(c.cliente_foto, 'base64'),
        'CartaIdentita', encode(c.cliente_carta_identita, 'base64'),
        'TipoDocIdentita', c.cliente_tipodoc_identita,
        'DocumentoNumero', c.cliente_documento_numero,
        'DocumentoRilasciatoDa', c.cliente_documento_rilasciato_da,
        'DocumentoRilasciatoData', c.cliente_documento_rilasciato_data,
        'DocumentoRilasciatoScadenza', c.cliente_documento_rilasciato_scadenza,
        'Note', c.cliente_note,
        'FotoMimeType', c.cliente_foto_mimetype,
        'FotoFilename', c.cliente_foto_filename,
        'FotoCharset', c.cliente_foto_charset,
        'FotoUpdDate', c.cliente_foto_upd_date,
        'DocumentoMimeType', c.cliente_documento_mimetype,
        'DocumentoFilename', c.cliente_documento_filename,
        'DocumentoCharset', c.cliente_documento_chartset,
        'DocumentoUpdDate', c.cliente_documento_upd_date,
        'Intolleranza', c.cliente_intolleranza,
        'AziendaFk', c.azienda_fk,
        'CreatedBy', c.created_by,
        'Created', c.created,
        'UpdatedBy', c.updated_by,
        'Updated', c.updated,
        'AziendaRagioneSociale', a.ragione_sociale
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    WHERE c.cliente_id = p_cliente_id
      AND c.azienda_fk = p_azienda_fk;

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_search_clienti(p_azienda_fk integer, p_search_text character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
    v_search_pattern VARCHAR(102);
BEGIN
    v_search_pattern := '%' || UPPER(p_search_text) || '%';

    SELECT json_agg(
        json_build_object(
            'ClienteId', c.cliente_id,
            'TitoloFk', c.cliente_titolo_fk,
            'Lingua', c.cliente_lingua,
            'Consenso', c.consenso_marketing,
            'Cognome', c.cliente_cognome,
            'Nome', c.cliente_nome,
            'Email', c.cliente_email,
            'Telefono', c.cliente_telefono,
            'CodiceFiscale', c.cliente_codicefiscale,
            'Sesso', c.cliente_sesso,
            'DataNascita', c.cliente_data_nascita,
            'PrefTelInt', c.cliente_preftelint,
            'IndirizzoResidenza', c.cliente_indirizzo_residenza,
            'Intolleranza', c.cliente_intolleranza,
            'AziendaFk', c.azienda_fk,
            'AziendaRagioneSociale', a.ragione_sociale,
            'ComuneNascita', CASE
                WHEN com_nas.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_nas.comune_descrizione,
                        'ProvinciaSigla', prov_nas.provincia_sigla,
                        'ProvinciaDescrizione', prov_nas.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_nas.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END,
            'ComuneResidenza', CASE
                WHEN com_res.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_res.comune_descrizione,
                        'ProvinciaSigla', prov_res.provincia_sigla,
                        'ProvinciaDescrizione', prov_res.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_res.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END
        ) ORDER BY c.cliente_cognome, c.cliente_nome
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    WHERE c.azienda_fk = p_azienda_fk
      AND (
          UPPER(c.cliente_cognome) LIKE v_search_pattern
          OR UPPER(c.cliente_nome) LIKE v_search_pattern
          OR UPPER(c.cliente_email) LIKE v_search_pattern
          OR UPPER(c.cliente_codicefiscale) LIKE v_search_pattern
          OR UPPER(c.cliente_telefono) LIKE v_search_pattern
      );

    RETURN COALESCE(v_result, '[]'::json);
END;
$function$;

COMMIT;
