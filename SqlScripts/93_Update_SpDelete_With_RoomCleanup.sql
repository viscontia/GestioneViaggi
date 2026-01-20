-- Aggiornamento sp_mov_clienti_viaggi_delete per gestire pulizia alloggi
CREATE OR REPLACE FUNCTION sp_mov_clienti_viaggi_delete(p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_room_id integer;
BEGIN
    -- 1. Cerca se il cliente occupa una stanza per questo viaggio
    SELECT mov_clienti_alloggio_pk INTO v_room_id
    FROM mov_clienti_alloggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id
      AND (
          cliente_id1_fk = p_cliente_id OR
          cliente_id2_fk = p_cliente_id OR
          cliente_id3_fk = p_cliente_id OR
          cliente_id4_fk = p_cliente_id OR
          cliente_id5_fk = p_cliente_id OR
          cliente_id6_fk = p_cliente_id
      )
    LIMIT 1;

    -- 2. Se occupa una stanza, rimuovilo (questo compatterà gli slot o eliminerà la stanza se vuota)
    IF v_room_id IS NOT NULL THEN
        PERFORM sp_remove_client_from_room(v_room_id, p_cliente_id);
    END IF;
    
    -- 3. Procedi con l'eliminazione standard del partecipante
    DELETE FROM mov_clienti_viaggi
    WHERE 
        viaggio_id_fk = p_viaggio_id 
        AND data_viaggio_id_fk = p_data_viaggio_id 
        AND cliente_id_fk = p_cliente_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Nessun record eliminato (Viaggio: %, Data: %, Cliente: %)', 
            p_viaggio_id, p_data_viaggio_id, p_cliente_id;
    END IF;
END;
$function$
