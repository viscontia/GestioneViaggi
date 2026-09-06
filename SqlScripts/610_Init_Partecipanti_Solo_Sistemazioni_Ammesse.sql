-- =============================================================================
-- 610 — La quinta strada offriva tende su viaggi in albergo (e viceversa)
-- =============================================================================
--
-- Trovato da Adriano il 2026-09-06 con la prova D2: su PIRENEI IN FUORISTRADA
-- («SOLO CAMPI TENDATI»), assegnando un passeggero, la tendina delle sistemazioni
-- mostrava «sia albergo che tende».
--
-- Il dato era giusto — il viaggio ha il pernottamento giusto, che ammette solo
-- TENDA — e le funzioni pure: `fn_alloggi_tipi_ammessi(1899)` risponde con le
-- quattro tende e «nessuna camera», e nient'altro.
--
-- ⚠️ Era una STRADA CHE NON CI PASSAVA. Le schede che compongono una sistemazione
-- sono cinque; tre chiamano `fn_alloggi_tipi_ammessi`, ma la scheda dei
-- partecipanti prende tutto da un unico blocco iniziale — questa funzione — che si
-- leggeva `ana_tipo_alloggio` per intero, senza guardare il viaggio.
--
-- E' esattamente il difetto che questo lavoro doveva chiudere: una regola applicata
-- in un punto solo del percorso. Offrire l'elenco intero e' cio' che ha prodotto le
-- 17 assegnazioni incoerenti trovate in produzione.
--
-- ⚠️ Nessun dato modificato, solo la funzione. Su PROD la definizione e' IDENTICA
-- a quella locale (md5 `1f1da53d…`, verificato in sola lettura il 2026-09-06),
-- quindi lo script si applica senza sorprese.
--
-- ⚠️ Da qui in poi, senza una partenza la tendina resta VUOTA invece di mostrare
-- tutto. E' voluto: se non si sa su quale partenza si sta lavorando, non si sa
-- nemmeno cosa sia ammesso, e un elenco completo sarebbe una risposta inventata.
-- =============================================================================

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
