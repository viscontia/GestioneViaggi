-- ========================================
-- Script: 401_Create_SpAnaDateViaggiCrud.sql
-- Descrizione: Stored procedures CRUD per ana_date_viaggi
-- Data: 2026-03-16
-- Autore: Sistema DB-First Migration
-- ========================================

-- ========================================
-- 1. STORED PROCEDURE: sp_ana_date_viaggi_create
-- ========================================
CREATE OR REPLACE FUNCTION sp_ana_date_viaggi_create(
    p_viaggio_id_fk INTEGER,
    p_data_viaggio_data_inizio DATE,
    p_data_viaggio_data_fine DATE,
    p_data_viaggio_effettuato_sino CHAR(1),
    p_data_viaggio_costo_pilota INTEGER,
    p_data_viaggio_costo_passeggero INTEGER,
    p_data_viaggio_costo_passeggero_auto_guida INTEGER,
    p_data_viaggio_costo_bambino_0_2 INTEGER,
    p_data_viaggio_costo_bambino_2_6 INTEGER,
    p_data_viaggio_costo_bambino_6_12 INTEGER,
    p_data_viaggio_note VARCHAR(250),
    p_azienda_id INTEGER,
    p_created_by VARCHAR(255)
) RETURNS INTEGER AS $$
DECLARE
    v_data_viaggio_id INTEGER;
BEGIN
    INSERT INTO ana_date_viaggi (
        viaggio_id_fk,
        data_viaggio_data_inizio,
        data_viaggio_data_fine,
        data_viaggio_effettuato_sino,
        data_viaggio_costo_pilota,
        data_viaggio_costo_passeggero,
        data_viaggio_costo_passeggero_auto_guida,
        data_viaggio_costo_bambino_0_2,
        data_viaggio_costo_bambino_2_6,
        data_viaggio_costo_bambino_6_12,
        data_viaggio_note,
        azienda_id,
        created_by
    ) VALUES (
        p_viaggio_id_fk,
        p_data_viaggio_data_inizio,
        p_data_viaggio_data_fine,
        p_data_viaggio_effettuato_sino,
        p_data_viaggio_costo_pilota,
        p_data_viaggio_costo_passeggero,
        p_data_viaggio_costo_passeggero_auto_guida,
        p_data_viaggio_costo_bambino_0_2,
        p_data_viaggio_costo_bambino_2_6,
        p_data_viaggio_costo_bambino_6_12,
        p_data_viaggio_note,
        p_azienda_id,
        p_created_by
    )
    RETURNING data_viaggio_id INTO v_data_viaggio_id;

    RETURN v_data_viaggio_id;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 2. STORED PROCEDURE: sp_ana_date_viaggi_update
-- ========================================
CREATE OR REPLACE FUNCTION sp_ana_date_viaggi_update(
    p_data_viaggio_id INTEGER,
    p_data_viaggio_data_inizio DATE,
    p_data_viaggio_data_fine DATE,
    p_data_viaggio_effettuato_sino CHAR(1),
    p_data_viaggio_costo_pilota INTEGER,
    p_data_viaggio_costo_passeggero INTEGER,
    p_data_viaggio_costo_passeggero_auto_guida INTEGER,
    p_data_viaggio_costo_bambino_0_2 INTEGER,
    p_data_viaggio_costo_bambino_2_6 INTEGER,
    p_data_viaggio_costo_bambino_6_12 INTEGER,
    p_data_viaggio_note VARCHAR(250),
    p_azienda_id INTEGER,
    p_updated_by VARCHAR(255),
    p_updated TIMESTAMP WITH TIME ZONE
) RETURNS VOID AS $$
BEGIN
    UPDATE ana_date_viaggi SET
        data_viaggio_data_inizio = p_data_viaggio_data_inizio,
        data_viaggio_data_fine = p_data_viaggio_data_fine,
        data_viaggio_effettuato_sino = p_data_viaggio_effettuato_sino,
        data_viaggio_costo_pilota = p_data_viaggio_costo_pilota,
        data_viaggio_costo_passeggero = p_data_viaggio_costo_passeggero,
        data_viaggio_costo_passeggero_auto_guida = p_data_viaggio_costo_passeggero_auto_guida,
        data_viaggio_costo_bambino_0_2 = p_data_viaggio_costo_bambino_0_2,
        data_viaggio_costo_bambino_2_6 = p_data_viaggio_costo_bambino_2_6,
        data_viaggio_costo_bambino_6_12 = p_data_viaggio_costo_bambino_6_12,
        data_viaggio_note = p_data_viaggio_note,
        azienda_id = p_azienda_id,
        updated_by = p_updated_by,
        updated = p_updated
    WHERE data_viaggio_id = p_data_viaggio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Data viaggio con ID % non trovata', p_data_viaggio_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 3. STORED PROCEDURE: sp_ana_date_viaggi_delete
-- ========================================
CREATE OR REPLACE FUNCTION sp_ana_date_viaggi_delete(
    p_data_viaggio_id INTEGER
) RETURNS TABLE (
    deleted BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    v_clienti_count BIGINT;
    v_alloggi_count BIGINT;
BEGIN
    -- Validazione: verifica dipendenze in mov_clienti_viaggi e mov_clienti_alloggi
    SELECT COUNT(1) INTO v_clienti_count
    FROM mov_clienti_viaggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id;

    SELECT COUNT(1) INTO v_alloggi_count
    FROM mov_clienti_alloggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id;

    -- Se esistono dipendenze, restituisci errore
    IF v_clienti_count > 0 OR v_alloggi_count > 0 THEN
        deleted := FALSE;
        error_message := format(
            'Impossibile eliminare la data: esistono dati collegati (%s%s%s).',
            CASE WHEN v_clienti_count > 0 THEN v_clienti_count || ' clienti' ELSE '' END,
            CASE WHEN v_clienti_count > 0 AND v_alloggi_count > 0 THEN ' e ' ELSE '' END,
            CASE WHEN v_alloggi_count > 0 THEN v_alloggi_count || ' alloggi' ELSE '' END
        );
        RETURN NEXT;
        RETURN;
    END IF;

    -- Elimina la data viaggio
    DELETE FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id;

    IF FOUND THEN
        deleted := TRUE;
        error_message := NULL;
    ELSE
        deleted := FALSE;
        error_message := 'Data viaggio non trovata';
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Fine Script
-- ========================================
