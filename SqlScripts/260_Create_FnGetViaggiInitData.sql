-- FUNZIONE: fn_get_viaggi_init_data
-- DESCRIZIONE: Recupera tutti i lookups e le date di un viaggio in un'unica chiamata JSON.
-- AUTORE: Antigravity
-- DATA: 2026-03-14

CREATE OR REPLACE FUNCTION fn_get_viaggi_init_data(p_viaggio_id INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'Nazioni', (SELECT json_agg(json_build_object('Id', country_id, 'Name', name) ORDER BY name) FROM eba_countries),
        'TipiViaggio', (SELECT json_agg(json_build_object('Id', tipo_viaggi_id, 'Descrizione', tipo_viaggi_descrizione) ORDER BY tipo_viaggi_descrizione) FROM ana_tipo_viaggi),
        'TipiTrattamento', (SELECT json_agg(json_build_object('Id', tipo_trattamento_id, 'Descrizione', tipo_trattamento_descrizione) ORDER BY tipo_trattamento_descrizione) FROM ana_tipo_trattamento),
        'TipiPernottamento', (SELECT json_agg(json_build_object('Id', ana_tipo_pernottamento_id, 'Descrizione', ana_tipo_pernottamento_descrizione) ORDER BY ana_tipo_pernottamento_descrizione) FROM ana_tipo_pernottamento),
        'TipiAvvicinamento', (SELECT json_agg(json_build_object('Id', tipo_avvicinamento_id, 'Descrizione', tipo_avvicinamento_descrizione) ORDER BY tipo_avvicinamento_descrizione) FROM ana_tipo_avvicinamento),
        'Aziende', (SELECT json_agg(json_build_object('Id', azienda_id, 'RagioneSociale', ragione_sociale) ORDER BY ragione_sociale) FROM ana_aziende),
        'Dates', CASE
                    WHEN p_viaggio_id IS NOT NULL THEN
                        (SELECT COALESCE(json_agg(json_build_object(
                            'Id', data_viaggio_id,
                            'ViaggioIdFk', viaggio_id_fk,
                            'DataInizio', data_viaggio_data_inizio,
                            'DataFine', data_viaggio_data_fine,
                            'EffettuatoSino', data_viaggio_effettuato_sino,
                            'CostoPilota', data_viaggio_costo_pilota,
                            'CostoPasseggero', data_viaggio_costo_passeggero,
                            'TotMezzi', get_mezzi_count(data_viaggio_id),
                            'TotClienti', get_participants_count(data_viaggio_id),
                            'AziendaId', azienda_id
                        ) ORDER BY data_viaggio_data_inizio), '[]'::json) FROM ana_date_viaggi WHERE viaggio_id_fk = p_viaggio_id)
                    ELSE '[]'::json
                 END
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
