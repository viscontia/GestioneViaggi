-- FUNZIONE: fn_get_viaggio_partecipanti_init_data
-- DESCRIZIONE: Recupera l'intero stato iniziale del dialog gestione partecipanti in un'unica chiamata JSON.
-- AUTORE: Antigravity
-- DATA: 2026-03-14

CREATE OR REPLACE FUNCTION fn_get_viaggio_partecipanti_init_data(p_viaggio_id INT, p_data_viaggio_id INT)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'Participants', (
            SELECT COALESCE(json_agg(json_build_object(
                'ViaggioId', viaggio_id,
                'DataId', data_id,
                'ClienteId', cliente_id,
                'Nominativo', nominativo,
                'TipoPartecipanteId', tipo_partecipante_id,
                'Ruolo', ruolo,
                'Note', note,
                'CaneSino', cane_sino,
                'Intolleranze', intolleranze,
                'MezzoDettagli', mezzo_dettagli,
                'ClientePilotaId', cliente_pilota_id,
                'GroupingKey', grouping_key,
                'Email', email
            )), '[]'::json) FROM get_participants_sorted(p_data_viaggio_id)
        ),
        'ParticipantsWithoutRoom', (
            SELECT COALESCE(json_agg(json_build_object(
                'ViaggioId', viaggio_id,
                'DataId', data_id,
                'ClienteId', cliente_id,
                'Nominativo', nominativo,
                'TipoPartecipanteId', tipo_partecipante_id,
                'Ruolo', ruolo,
                'Note', note,
                'CaneSino', cane_sino,
                'Intolleranze', intolleranze,
                'MezzoDettagli', mezzo_dettagli,
                'ClientePilotaId', cliente_pilota_id,
                'GroupingKey', grouping_key,
                'Email', email
            )), '[]'::json) FROM get_participants_without_accommodation(p_data_viaggio_id)
        ),
        'SummaryTitle', get_viaggio_partecipanti_summary(p_data_viaggio_id),
        'ParticipantsCount', get_participants_count(p_data_viaggio_id),
        'Rooms', (
            SELECT COALESCE(json_agg(json_build_object(
                'AlloggioPk', mov_clienti_alloggio_pk,
                'TipoAlloggio', tipo_alloggio_descrizione,
                'MaxOccupants', tipo_alloggio_numero_occupanti,
                'CurrentOccupants', current_occupants,
                'OccupantNames', occupant_names,
                'OccupantIds', occupant_ids,
                'HasSupplement', has_supplement
            )), '[]'::json) FROM get_rooms_with_occupants(p_data_viaggio_id)
        ),
        'RoomsCount', get_rooms_count(p_data_viaggio_id),
        'HeaderTitle', (
            SELECT v.viaggio_descrizione_breve || ' (Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(d.data_viaggio_data_fine, 'DD/MM/YYYY') || ')'
            FROM ana_viaggi v
            JOIN ana_date_viaggi d ON d.viaggio_id_fk = v.viaggio_id
            WHERE v.viaggio_id = p_viaggio_id AND d.data_viaggio_id = p_data_viaggio_id
        ),
        'TipoPartecipanti', (
            SELECT json_agg(json_build_object(
                'Id', tipo_partecipante_id, 
                'Descrizione', tipo_partecipante_descrizione,
                'Pilota', (tipo_partecipante_pilota = 'Y'),
                'DatiMezzoObbligatori', tipo_partecipante_dati_mezzo_obb
            )) FROM ana_tipo_partecipante ORDER BY tipo_partecipante_descrizione
        ),
        'TipoAlloggi', (
            SELECT json_agg(json_build_object(
                'Id', tipo_alloggio_id, 
                'Descrizione', tipo_alloggio_descrizione,
                'Supplemento', (tipo_alloggio_supplemento = 'Y'),
                'NumeroOccupanti', tipo_alloggio_numero_occupanti
            )) FROM ana_tipo_alloggio ORDER BY tipo_alloggio_descrizione
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
