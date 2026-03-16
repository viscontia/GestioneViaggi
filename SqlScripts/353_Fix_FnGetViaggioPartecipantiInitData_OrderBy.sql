-- FIX: fn_get_viaggio_partecipanti_init_data - Corregge ORDER BY in json_agg
-- DESCRIZIONE: Sposta ORDER BY all'interno di json_agg per evitare errori GROUP BY
-- AUTORE: Antigravity
-- DATA: 2026-03-16
-- ISSUE: ORDER BY deve essere dentro json_agg, non fuori dalla subquery

CREATE OR REPLACE FUNCTION fn_get_viaggio_partecipanti_init_data(p_viaggio_id integer, p_data_viaggio_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'participants', (SELECT COALESCE(json_agg(json_build_object(
            'viaggioId', viaggio_id,
            'dataId', data_id,
            'clienteId', cliente_id,
            'nominativo', nominativo,
            'tipoPartecipanteId', tipo_partecipante_id,
            'ruolo', ruolo,
            'note', note,
            'caneSino', cane_sino,
            'intolleranze', intolleranze,
            'mezzoDettagli', mezzo_dettagli,
            'clientePilotaId', cliente_pilota_id,
            'groupingKey', grouping_key,
            'email', email
        )), '[]'::json) FROM get_participants_sorted(p_data_viaggio_id)),
        'participantsWithoutRoom', (SELECT COALESCE(json_agg(json_build_object(
            'viaggioId', viaggio_id,
            'dataId', data_id,
            'clienteId', cliente_id,
            'nominativo', nominativo,
            'tipoPartecipanteId', tipo_partecipante_id,
            'ruolo', ruolo,
            'note', note,
            'caneSino', cane_sino,
            'intolleranze', intolleranze,
            'mezzoDettagli', mezzo_dettagli,
            'clientePilotaId', cliente_pilota_id,
            'groupingKey', grouping_key
        )), '[]'::json) FROM get_participants_without_accommodation(p_data_viaggio_id)),
        'summaryTitle', get_viaggio_partecipanti_summary(p_data_viaggio_id),
        'participantsCount', get_participants_count(p_data_viaggio_id),
        'rooms', (SELECT COALESCE(json_agg(json_build_object(
            'alloggioPk', alloggio_pk,
            'tipoAlloggio', tipo_alloggio,
            'maxOccupants', max_occupants,
            'currentOccupants', current_occupants,
            'occupantNames', occupant_names,
            'occupantIds', occupant_ids,
            'hasSupplement', has_supplement
        )), '[]'::json) FROM get_rooms_with_occupants(p_data_viaggio_id)),
        'roomsCount', get_rooms_count(p_data_viaggio_id),
        'headerTitle', (
            SELECT v.viaggio_descrizione_breve || ' (Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(d.data_viaggio_data_fine, 'DD/MM/YYYY') || ')'
            FROM ana_viaggi v
            JOIN ana_date_viaggi d ON d.viaggio_id_fk = v.viaggio_id
            WHERE v.viaggio_id = p_viaggio_id AND d.data_viaggio_id = p_data_viaggio_id
        ),
        'tipoPartecipanti', (
            SELECT json_agg(json_build_object(
                'id', tipo_partecipante_id,
                'descrizione', tipo_partecipante_descrizione,
                'pilota', tipo_partecipante_pilota,
                'datiMezzoObbligatori', (tipo_partecipante_dati_mezzo_obb = 'Y')
            ) ORDER BY tipo_partecipante_descrizione)
            FROM ana_tipo_partecipante
        ),
        'tipoAlloggi', (
            SELECT json_agg(json_build_object(
                'id', tipo_alloggio_id,
                'descrizione', tipo_alloggio_descrizione,
                'supplemento', (tipo_alloggio_supplemento = 'Y'),
                'numeroOccupanti', tipo_alloggio_numero_occupanti
            ) ORDER BY tipo_alloggio_descrizione)
            FROM ana_tipo_alloggio
        )
    ) INTO v_result;

    RETURN v_result;
END;
$function$;
