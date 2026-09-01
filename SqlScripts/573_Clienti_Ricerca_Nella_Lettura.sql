-- =============================================================================
-- 573 — La ricerca dei clienti torna nella funzione che restituisce tutto
-- =============================================================================
--
-- Difetto introdotto il 2026-09-01 collegando fn_search_clienti alla griglia:
-- quella funzione restituisce SEDICI campi in meno di fn_get_all_clienti — i
-- cinque del documento, gli identificativi dei due comuni, IBAN, note, audit.
--
-- Chi apriva un cliente TROVATO CERCANDO riceveva quindi una scheda mutilata.
-- Il sintomo visibile era l'avviso "questa scheda e' incompleta" su dati che a
-- database c'erano tutti. Il rischio vero era un altro: salvando quel cliente,
-- i campi assenti sarebbero stati azzerati. Verificato che non e' successo a
-- nessuno — nessun cliente aggiornato dopo la modifica — ma e' stata fortuna,
-- non una difesa.
--
-- La cura non e' aggiungere i sedici campi mancanti a fn_search_clienti: sarebbe
-- una seconda lista da tenere allineata, e la prossima colonna nuova finirebbe
-- in una sola delle due. La ricerca diventa un parametro della funzione che
-- restituisce gia' tutto — stessa scelta fatta per i viaggi con lo script 570.
--
-- fn_search_clienti resta in vita per eventuali altri chiamanti, ma il
-- gestionale non la usa piu'.
-- =============================================================================

-- Un parametro in piu' crea un OVERLOAD, e la chiamata a due argomenti diventa
-- ambigua: il DROP e' obbligatorio, non cosmetico (vedi 570).
DROP FUNCTION IF EXISTS fn_get_all_clienti(integer, integer);

CREATE OR REPLACE FUNCTION public.fn_get_all_clienti(p_azienda_fk integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer, p_search_text character varying DEFAULT NULL::character varying)
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
    WHERE (p_azienda_fk IS NULL OR c.azienda_fk = p_azienda_fk)
      -- Il testo cercato, sugli stessi campi di fn_search_clienti: cognome, nome,
      -- email, codice fiscale, telefono. Sta qui e non in una funzione a parte perche'
      -- la lista dei campi restituiti dev'essere UNA: fn_search_clienti ne restituiva
      -- sedici in meno, e chi apriva un cliente trovato cercando riceveva una scheda
      -- mutilata — l'avviso "scheda incompleta" su dati che c'erano, e il rischio di
      -- azzerarli salvando.
      AND (NULLIF(btrim(COALESCE(p_search_text, '')), '') IS NULL
           OR UPPER(c.cliente_cognome)                    LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.cliente_nome, ''))          LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.cliente_email, ''))         LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.cliente_codicefiscale, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.cliente_telefono, ''))      LIKE '%' || UPPER(btrim(p_search_text)) || '%');

    RETURN COALESCE(v_result, '[]'::json);
END;
$function$;
