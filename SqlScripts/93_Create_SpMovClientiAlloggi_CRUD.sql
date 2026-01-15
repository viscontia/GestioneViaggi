
-- 93_Create_SpMovClientiAlloggi_CRUD.sql
-- DESCRIZIONE: Procedure CRUD per tabella mov_clienti_alloggi
-- DATA: 2026-01-15
-- AUTORE: Antigravity

-- =================================================================================================
-- CREATE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_alloggi_create(
    p_viaggio_id INT,
    p_data_viaggio_id INT,
    p_tipo_alloggio_id INT,
    p_cliente_id1 INT,
    p_cliente_id2 INT DEFAULT NULL,
    p_cliente_id3 INT DEFAULT NULL,
    p_cliente_id4 INT DEFAULT NULL,
    p_cliente_id5 INT DEFAULT NULL,
    p_cliente_id6 INT DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_new_id INT;
BEGIN
    -- Generazione ID da sequenza (se non gestito da default column)
    v_new_id := nextval('mov_clienti_alloggi_seq');

    INSERT INTO mov_clienti_alloggi (
        mov_clienti_alloggio_pk,
        viaggio_id_fk,
        data_viaggio_id_fk,
        tipo_alloggio_id_fk,
        cliente_id1_fk,
        cliente_id2_fk,
        cliente_id3_fk,
        cliente_id4_fk,
        cliente_id5_fk,
        cliente_id6_fk
    ) VALUES (
        v_new_id,
        p_viaggio_id,
        p_data_viaggio_id,
        p_tipo_alloggio_id,
        p_cliente_id1,
        p_cliente_id2,
        p_cliente_id3,
        p_cliente_id4,
        p_cliente_id5,
        p_cliente_id6
    );

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- =================================================================================================
-- UPDATE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_alloggi_update(
    p_pk INT,
    p_viaggio_id INT,
    p_data_viaggio_id INT,
    p_tipo_alloggio_id INT,
    p_cliente_id1 INT,
    p_cliente_id2 INT DEFAULT NULL,
    p_cliente_id3 INT DEFAULT NULL,
    p_cliente_id4 INT DEFAULT NULL,
    p_cliente_id5 INT DEFAULT NULL,
    p_cliente_id6 INT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE mov_clienti_alloggi
    SET 
        viaggio_id_fk = p_viaggio_id,
        data_viaggio_id_fk = p_data_viaggio_id,
        tipo_alloggio_id_fk = p_tipo_alloggio_id,
        cliente_id1_fk = p_cliente_id1,
        cliente_id2_fk = p_cliente_id2,
        cliente_id3_fk = p_cliente_id3,
        cliente_id4_fk = p_cliente_id4,
        cliente_id5_fk = p_cliente_id5,
        cliente_id6_fk = p_cliente_id6,
        updated = NOW()
    WHERE 
        mov_clienti_alloggio_pk = p_pk;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Record Alloggio non trovato per aggiornamento (PK: %)', p_pk;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =================================================================================================
-- DELETE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_alloggi_delete(
    p_pk INT
)
RETURNS VOID AS $$
BEGIN
    DELETE FROM mov_clienti_alloggi
    WHERE mov_clienti_alloggio_pk = p_pk;

    IF NOT FOUND THEN
        RAISE NOTICE 'Nessun record Alloggio eliminato (PK: %)', p_pk;
    END IF;
END;
$$ LANGUAGE plpgsql;
