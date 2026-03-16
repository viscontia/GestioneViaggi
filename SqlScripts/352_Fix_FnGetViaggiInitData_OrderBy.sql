-- FIX: fn_get_viaggi_init_data - Corregge ORDER BY in json_agg
-- DESCRIZIONE: Sposta ORDER BY all'interno di json_agg per evitare errori GROUP BY
-- AUTORE: Antigravity
-- DATA: 2026-03-16
-- ISSUE: ORDER BY deve essere dentro json_agg, non fuori dalla subquery

CREATE OR REPLACE FUNCTION fn_get_viaggi_init_data(p_viaggio_id INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'nazioni', (SELECT json_agg(json_build_object('id', country_id, 'name', name) ORDER BY name) FROM eba_countries),
        'tipi_viaggio', (SELECT json_agg(json_build_object('id', tipo_viaggi_id, 'descrizione', tipo_viaggi_descrizione) ORDER BY tipo_viaggi_descrizione) FROM ana_tipo_viaggi),
        'tipi_trattamento', (SELECT json_agg(json_build_object('id', tipo_trattamento_id, 'descrizione', tipo_trattamento_descrizione) ORDER BY tipo_trattamento_descrizione) FROM ana_tipo_trattamento),
        'tipi_pernottamento', (SELECT json_agg(json_build_object('id', ana_tipo_pernottamento_id, 'descrizione', ana_tipo_pernottamento_descrizione) ORDER BY ana_tipo_pernottamento_descrizione) FROM ana_tipo_pernottamento),
        'tipi_avvicinamento', (SELECT json_agg(json_build_object('id', tipo_avvicinamento_id, 'descrizione', tipo_avvicinamento_descrizione) ORDER BY tipo_avvicinamento_descrizione) FROM ana_tipo_avvicinamento),
        'aziende', (SELECT json_agg(json_build_object('azienda_id', azienda_id, 'ragione_sociale', ragione_sociale) ORDER BY ragione_sociale) FROM ana_aziende),
        'dates', CASE
                    WHEN p_viaggio_id IS NOT NULL THEN
                        (SELECT COALESCE(json_agg(json_build_object(
                            'id', data_viaggio_id,
                            'viaggioIdFk', viaggio_id_fk,
                            'dataInizio', data_viaggio_data_inizio,
                            'dataFine', data_viaggio_data_fine,
                            'effettuatoSino', data_viaggio_effettuato_sino,
                            'costoPilota', data_viaggio_costo_pilota,
                            'costoPasseggero', data_viaggio_costo_passeggero,
                            'totMezzi', get_mezzi_count(data_viaggio_id),
                            'totClienti', get_participants_count(data_viaggio_id),
                            'aziendaId', azienda_id
                        ) ORDER BY data_viaggio_data_inizio), '[]'::json)
                        FROM ana_date_viaggi WHERE viaggio_id_fk = p_viaggio_id)
                    ELSE '[]'::json
                 END
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
