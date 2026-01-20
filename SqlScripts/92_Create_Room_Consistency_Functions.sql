-- Funzione di Controllo Coerenza Camera PRE-Eliminazione
CREATE OR REPLACE FUNCTION chk_room_consistency_on_delete(
    p_data_viaggio_id integer,
    p_cliente_id_to_remove integer
)
RETURNS TABLE (
    violation_detected boolean,
    room_id integer,
    room_type_desc text,
    required_seats integer,
    current_occupants_count integer,
    remaining_occupants_count integer,
    survivor_ids integer[]
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_rec RECORD;
    v_occupants_count integer := 0;
    v_occupants_ids integer[] := '{}';
    v_survivor_ids integer[] := '{}';
    v_required_seats integer;
    v_client_found boolean := false;
BEGIN
    violation_detected := false;

    -- 1. Trova la stanza del cliente per questa data
    SELECT 
        m.*, 
        t.tipo_alloggio_descrizione, 
        t.tipo_alloggio_numero_occupanti
    INTO v_room_rec
    FROM mov_clienti_alloggi m
    JOIN ana_tipo_alloggio t ON m.tipo_alloggio_id_fk = t.tipo_alloggio_id
    WHERE m.data_viaggio_id_fk = p_data_viaggio_id
      AND (
          m.cliente_id1_fk = p_cliente_id_to_remove OR
          m.cliente_id2_fk = p_cliente_id_to_remove OR
          m.cliente_id3_fk = p_cliente_id_to_remove OR
          m.cliente_id4_fk = p_cliente_id_to_remove OR
          m.cliente_id5_fk = p_cliente_id_to_remove OR
          m.cliente_id6_fk = p_cliente_id_to_remove
      )
    LIMIT 1;

    -- Se il cliente non ha stanza, nessuna violazione alloggio
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::integer, NULL::text, 0, 0, 0, NULL::integer[];
        RETURN;
    END IF;

    -- 2. Conta occupanti attuali e raccogli ID (escluso quello da rimuovere per i survivor)
    IF v_room_rec.cliente_id1_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id1_fk);
        IF v_room_rec.cliente_id1_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id1_fk); END IF;
    END IF;
    IF v_room_rec.cliente_id2_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id2_fk);
        IF v_room_rec.cliente_id2_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id2_fk); END IF;
    END IF;
    IF v_room_rec.cliente_id3_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id3_fk);
        IF v_room_rec.cliente_id3_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id3_fk); END IF;
    END IF;
    IF v_room_rec.cliente_id4_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id4_fk);
        IF v_room_rec.cliente_id4_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id4_fk); END IF;
    END IF;
    IF v_room_rec.cliente_id5_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id5_fk);
        IF v_room_rec.cliente_id5_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id5_fk); END IF;
    END IF;
    IF v_room_rec.cliente_id6_fk IS NOT NULL THEN 
        v_occupants_count := v_occupants_count + 1;
        v_occupants_ids := array_append(v_occupants_ids, v_room_rec.cliente_id6_fk);
        IF v_room_rec.cliente_id6_fk != p_cliente_id_to_remove THEN v_survivor_ids := array_append(v_survivor_ids, v_room_rec.cliente_id6_fk); END IF;
    END IF;

    room_id := v_room_rec.mov_clienti_alloggio_pk;
    required_seats := v_room_rec.tipo_alloggio_numero_occupanti;
    remaining_occupants_count := array_length(v_survivor_ids, 1);
    IF remaining_occupants_count IS NULL THEN remaining_occupants_count := 0; END IF;
    current_occupants_count := v_occupants_count;
    room_type_desc := v_room_rec.tipo_alloggio_descrizione;
    survivor_ids := v_survivor_ids;

    -- 3. Verifica Violazione
    -- Se rimangono occupanti E il loro numero è inferiore al richiesto
    IF remaining_occupants_count > 0 AND remaining_occupants_count < required_seats THEN
        violation_detected := true;
    ELSE
        violation_detected := false;
    END IF;

    RETURN NEXT;
END;
$$;


-- Procedura Helper: Rimuove un cliente specifico da una stanza (senza controlli) e compatta/elimina la stanza
CREATE OR REPLACE FUNCTION sp_remove_client_from_room(
    p_room_id integer,
    p_cliente_id integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_rec RECORD;
    v_new_slots integer[];
    v_count integer;
BEGIN
    -- Seleziona stanza con lock
    SELECT * INTO v_room_rec FROM mov_clienti_alloggi 
    WHERE mov_clienti_alloggio_pk = p_room_id FOR UPDATE;

    IF NOT FOUND THEN RETURN; END IF;

    -- Costruisci array degli occupanti RIMANENTI (escludendo quello da rimuovere)
    v_new_slots := ARRAY[]::integer[];
    
    IF v_room_rec.cliente_id1_fk IS NOT NULL AND v_room_rec.cliente_id1_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id1_fk); END IF;
    IF v_room_rec.cliente_id2_fk IS NOT NULL AND v_room_rec.cliente_id2_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id2_fk); END IF;
    IF v_room_rec.cliente_id3_fk IS NOT NULL AND v_room_rec.cliente_id3_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id3_fk); END IF;
    IF v_room_rec.cliente_id4_fk IS NOT NULL AND v_room_rec.cliente_id4_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id4_fk); END IF;
    IF v_room_rec.cliente_id5_fk IS NOT NULL AND v_room_rec.cliente_id5_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id5_fk); END IF;
    IF v_room_rec.cliente_id6_fk IS NOT NULL AND v_room_rec.cliente_id6_fk != p_cliente_id THEN v_new_slots := array_append(v_new_slots, v_room_rec.cliente_id6_fk); END IF;

    v_count := array_length(v_new_slots, 1);

    IF v_count IS NULL OR v_count = 0 THEN
        -- Nessun occupante rimasto: elimina stanza
        DELETE FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = p_room_id;
    ELSE
        -- Aggiorna slots (compattati)
        UPDATE mov_clienti_alloggi
        SET
            cliente_id1_fk = CASE WHEN 1 <= v_count THEN v_new_slots[1] ELSE NULL END,
            cliente_id2_fk = CASE WHEN 2 <= v_count THEN v_new_slots[2] ELSE NULL END,
            cliente_id3_fk = CASE WHEN 3 <= v_count THEN v_new_slots[3] ELSE NULL END,
            cliente_id4_fk = CASE WHEN 4 <= v_count THEN v_new_slots[4] ELSE NULL END,
            cliente_id5_fk = CASE WHEN 5 <= v_count THEN v_new_slots[5] ELSE NULL END,
            cliente_id6_fk = CASE WHEN 6 <= v_count THEN v_new_slots[6] ELSE NULL END,
            updated = NOW() -- Track update
        WHERE mov_clienti_alloggio_pk = p_room_id;
    END IF;
END;
$$;


-- Procedura Risoluzione: SPOSTA i superstiti in una nuova stanza e pulisce la vecchia
-- Attenzione: il cliente "cancellando" viene rimosso implicitamente dalla vecchia stanza perché verrà svuotata/eliminata
CREATE OR REPLACE FUNCTION sp_resolve_room_violation_move(
    p_old_room_id integer,
    p_new_tipo_alloggio_id integer,
    p_survivor_ids integer[] -- ID dei clienti da spostare
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_rec RECORD;
    v_new_room_id integer;
    i integer;
BEGIN
    SELECT * INTO v_old_rec FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = p_old_room_id;
    
    -- 1. Definitivo: Rimuovi i survivor dalla vecchia stanza
    FOREACH i IN ARRAY p_survivor_ids
    LOOP
        PERFORM sp_remove_client_from_room(p_old_room_id, i);
    END LOOP;

    -- 2. Crea NUOVA stanza
    INSERT INTO mov_clienti_alloggi (
        viaggio_id_fk, 
        data_viaggio_id_fk, 
        tipo_alloggio_id_fk,
        cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, 
        cliente_id4_fk, cliente_id5_fk, cliente_id6_fk,
        created
    )
    VALUES (
        v_old_rec.viaggio_id_fk,
        v_old_rec.data_viaggio_id_fk,
        p_new_tipo_alloggio_id,
        -- Assegna slots in ordine
        CASE WHEN array_length(p_survivor_ids, 1) >= 1 THEN p_survivor_ids[1] ELSE NULL END,
        CASE WHEN array_length(p_survivor_ids, 1) >= 2 THEN p_survivor_ids[2] ELSE NULL END,
        CASE WHEN array_length(p_survivor_ids, 1) >= 3 THEN p_survivor_ids[3] ELSE NULL END,
        CASE WHEN array_length(p_survivor_ids, 1) >= 4 THEN p_survivor_ids[4] ELSE NULL END,
        CASE WHEN array_length(p_survivor_ids, 1) >= 5 THEN p_survivor_ids[5] ELSE NULL END,
        CASE WHEN array_length(p_survivor_ids, 1) >= 6 THEN p_survivor_ids[6] ELSE NULL END,
        NOW()
    );

    -- Nota: Il "cancellando" rimasto da solo nella vecchia stanza (se c'era solo lui oltre ai survivor) 
    -- verrà gestito quando si chiamerà sp_remove_client_from_room anche per lui 
    -- oppure quando sp_mov_clienti_viaggi_delete verrà aggiornata per chiamare il cleanup.
END;
$$;


-- Procedura Risoluzione: PARCHEGGIA i superstiti (rimuove dalla stanza senza riassegnare)
CREATE OR REPLACE FUNCTION sp_resolve_room_violation_park(
    p_room_id integer,
    p_survivor_ids integer[]
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    i integer;
BEGIN
    -- Semplicemente rimuove i survivor dalla stanza corrente
    FOREACH i IN ARRAY p_survivor_ids
    LOOP
        PERFORM sp_remove_client_from_room(p_room_id, i);
    END LOOP;
END;
$$;
