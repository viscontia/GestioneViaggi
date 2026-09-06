-- =============================================================================
-- 613 — Le camere portano anche l'ID del tipo, non solo il nome
-- =============================================================================
--
-- Serve per far crescere una sistemazione quando qualcuno arriva dopo: il pilota
-- iscritto da solo in CAMERA SINGOLA, e la moglie che decide di venire piu' tardi.
-- Per proporre di portarla a MATRIMONIALE il gestionale deve partire dal tipo che
-- c'e', e finora dalle camere gli arrivava solo la DESCRIZIONE.
--
-- ⛔️ Risalire al tipo dalla descrizione e' la strada che NON si prende: e' il difetto
-- tolto dai generi e dal suggerimento, dove bastava rinominare una riga per spegnere
-- una regola in silenzio.
--
-- ⚠️ Sola lettura: nessun dato modificato, due tracciati allargati di una colonna.
-- Va applicato INSIEME al gestionale, che legge il campo nuovo.
-- =============================================================================

DROP FUNCTION IF EXISTS get_rooms_with_occupants(integer);

CREATE OR REPLACE FUNCTION public.get_rooms_with_occupants(p_data_viaggio_id integer)
 RETURNS TABLE(alloggio_pk integer, tipo_alloggio text, tipo_alloggio_id integer, max_occupants integer, current_occupants integer, occupant_names text[], occupant_ids integer[], has_supplement boolean, pilot_cognome text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    WITH room_occupants AS (
        -- Esplode i 6 slot fissi in righe individuali
        SELECT
            a.mov_clienti_alloggio_pk,
            a.data_viaggio_id_fk,
            t.client_id
        FROM mov_clienti_alloggi a
        CROSS JOIN LATERAL (
            VALUES
                (a.cliente_id1_fk),
                (a.cliente_id2_fk),
                (a.cliente_id3_fk),
                (a.cliente_id4_fk),
                (a.cliente_id5_fk),
                (a.cliente_id6_fk)
        ) AS t(client_id)
        WHERE a.data_viaggio_id_fk = p_data_viaggio_id
          AND t.client_id IS NOT NULL
    ),
    enriched AS (
        -- Arricchisce con dati anagrafici e ruolo (pilota / passeggero)
        SELECT
            ro.mov_clienti_alloggio_pk,
            ro.client_id,
            (c.cliente_cognome || ' ' || c.cliente_nome)::TEXT AS nominativo,
            c.cliente_cognome,
            c.cliente_nome,
            COALESCE(tp.tipo_partecipante_pilota, FALSE) AS is_pilot
        FROM room_occupants ro
        JOIN ana_clienti c ON c.cliente_id = ro.client_id
        LEFT JOIN mov_clienti_viaggi mcv
            ON mcv.cliente_id_fk = ro.client_id
           AND mcv.data_viaggio_id_fk = ro.data_viaggio_id_fk
        LEFT JOIN ana_tipo_partecipante tp
            ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
    )
    SELECT
        a.mov_clienti_alloggio_pk::INTEGER                                     AS alloggio_pk,
        ta.tipo_alloggio_descrizione::TEXT                                     AS tipo_alloggio,
        ta.tipo_alloggio_id::INTEGER                                           AS tipo_alloggio_id,
        ta.tipo_alloggio_numero_occupanti::INTEGER                             AS max_occupants,
        COUNT(e.client_id)::INTEGER                                            AS current_occupants,
        -- Pilota primo (0), poi passeggeri in ordine alfabetico cognome+nome
        ARRAY_AGG(
            e.nominativo
            ORDER BY
                CASE WHEN e.is_pilot THEN 0 ELSE 1 END,
                e.cliente_cognome,
                e.cliente_nome
        )::TEXT[]                                                              AS occupant_names,
        ARRAY_AGG(
            e.client_id
            ORDER BY
                CASE WHEN e.is_pilot THEN 0 ELSE 1 END,
                e.cliente_cognome,
                e.cliente_nome
        )::INTEGER[]                                                           AS occupant_ids,
        (ta.tipo_alloggio_supplemento = 'Y')::BOOLEAN                         AS has_supplement,
        -- Cognome pilota per ordinare le camere all'interno della tipologia
        COALESCE(
            MIN(e.cliente_cognome) FILTER (WHERE e.is_pilot),
            'ZZZZZ'
        )::TEXT                                                                AS pilot_cognome
    FROM mov_clienti_alloggi a
    JOIN ana_tipo_alloggio ta ON a.tipo_alloggio_id_fk = ta.tipo_alloggio_id
    LEFT JOIN enriched e ON e.mov_clienti_alloggio_pk = a.mov_clienti_alloggio_pk
    WHERE a.data_viaggio_id_fk = p_data_viaggio_id
    GROUP BY
        a.mov_clienti_alloggio_pk,
        ta.tipo_alloggio_id,
        ta.tipo_alloggio_descrizione,
        ta.tipo_alloggio_numero_occupanti,
        ta.tipo_alloggio_supplemento
    ORDER BY
        ta.tipo_alloggio_descrizione,
        COALESCE(MIN(e.cliente_cognome) FILTER (WHERE e.is_pilot), 'ZZZZZ');
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_get_viaggio_partecipanti_init_data(p_viaggio_id integer, p_data_viaggio_id integer)
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
            'tipoAlloggioId', tipo_alloggio_id,
            'maxOccupants', max_occupants,
            'currentOccupants', current_occupants,
            'occupantNames', occupant_names,
            'occupantIds', occupant_ids,
            'hasSupplement', has_supplement,
            'pilotCognome', pilot_cognome
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
            -- ⚠️ Non piu' `FROM ana_tipo_alloggio` senza condizioni: solo cio' che questa
            -- partenza ammette davvero. Stessa funzione che usano l'Iscrizione Veloce e la
            -- gestione alloggi, cosi' le tre strade non possono dire cose diverse.
            SELECT json_agg(json_build_object(
                'id', a.tipo_id,
                'descrizione', a.descrizione,
                'supplemento', a.supplemento,
                'numeroOccupanti', a.posti
            ) ORDER BY a.descrizione)
            FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a
        )
    ) INTO v_result;

    RETURN v_result;
END;
$function$;
