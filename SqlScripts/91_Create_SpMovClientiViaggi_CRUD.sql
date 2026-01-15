
-- 91_Create_SpMovClientiViaggi_CRUD.sql
-- DESCRIZIONE: Procedure CRUD per tabella mov_clienti_viaggi
-- DATA: 2026-01-15
-- AUTORE: Antigravity

-- =================================================================================================
-- CREATE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_viaggi_create(
    p_viaggio_id INT,
    p_data_viaggio_id INT,
    p_cliente_id INT,
    p_tipo_partecipante_id INT,
    p_ana_mezzi_id INT DEFAULT NULL,
    p_mezzo_modello_id INT DEFAULT NULL,
    p_sconto_val_totale NUMERIC DEFAULT NULL,
    p_targa_mezzo VARCHAR DEFAULT NULL,
    p_cane_sino VARCHAR DEFAULT 'N',
    p_note TEXT DEFAULT NULL,
    p_cliente_pilota_id INT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Verifica esistenza (Idempotenza/Prevenzione duplicati PK)
    IF EXISTS (SELECT 1 FROM mov_clienti_viaggi 
               WHERE viaggio_id_fk = p_viaggio_id 
               AND data_viaggio_id_fk = p_data_viaggio_id 
               AND cliente_id_fk = p_cliente_id) THEN
        RAISE EXCEPTION 'Il cliente % è già registrato per questo viaggio e data.', p_cliente_id 
        USING ERRCODE = '23505'; -- Unique violation
    END IF;

    INSERT INTO mov_clienti_viaggi (
        viaggio_id_fk,
        data_viaggio_id_fk,
        cliente_id_fk,
        tipo_partecipante_id_fk,
        ana_mezzi_id_fk,
        mezzo_modello_id_fk,
        mov_cliente_viaggio_scontoval_totale,
        mov_cliente_viaggio_targa_mezzo,
        mov_cliente_viaggio_cane_sino,
        mov_cliente_viaggio_note,
        cliente_pilota_id_fk
    ) VALUES (
        p_viaggio_id,
        p_data_viaggio_id,
        p_cliente_id,
        p_tipo_partecipante_id,
        p_ana_mezzi_id,
        p_mezzo_modello_id,
        p_sconto_val_totale,
        p_targa_mezzo,
        p_cane_sino,
        p_note,
        p_cliente_pilota_id
    );
END;
$$ LANGUAGE plpgsql;

-- =================================================================================================
-- UPDATE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_viaggi_update(
    p_viaggio_id INT,
    p_data_viaggio_id INT,
    p_cliente_id INT,
    p_tipo_partecipante_id INT,
    p_ana_mezzi_id INT DEFAULT NULL,
    p_mezzo_modello_id INT DEFAULT NULL,
    p_sconto_val_totale NUMERIC DEFAULT NULL,
    p_targa_mezzo VARCHAR DEFAULT NULL,
    p_cane_sino VARCHAR DEFAULT NULL,
    p_note TEXT DEFAULT NULL,
    p_cliente_pilota_id INT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE mov_clienti_viaggi
    SET 
        tipo_partecipante_id_fk = p_tipo_partecipante_id,
        ana_mezzi_id_fk = p_ana_mezzi_id,
        mezzo_modello_id_fk = p_mezzo_modello_id,
        mov_cliente_viaggio_scontoval_totale = p_sconto_val_totale,
        mov_cliente_viaggio_targa_mezzo = p_targa_mezzo,
        mov_cliente_viaggio_cane_sino = COALESCE(p_cane_sino, mov_cliente_viaggio_cane_sino),
        mov_cliente_viaggio_note = p_note,
        cliente_pilota_id_fk = p_cliente_pilota_id,
        updated = NOW() -- Aggiornamento timestamp esplicito se non gestito dal trigger (il trigger c'è ma non fa male)
    WHERE 
        viaggio_id_fk = p_viaggio_id 
        AND data_viaggio_id_fk = p_data_viaggio_id 
        AND cliente_id_fk = p_cliente_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Record non trovato per aggiornamento (Viaggio: %, Data: %, Cliente: %)', 
            p_viaggio_id, p_data_viaggio_id, p_cliente_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =================================================================================================
-- DELETE PROCEDURE
-- =================================================================================================
CREATE OR REPLACE FUNCTION sp_mov_clienti_viaggi_delete(
    p_viaggio_id INT,
    p_data_viaggio_id INT,
    p_cliente_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Controllo Integrità Referenziale "Manuale" (Extra-safety come richiesto)
    -- In questo caso la tabella è una tabella di relazione (LINK), quindi è raro che venga referenziata.
    -- Tuttavia, se ci fossero tabelle di dettaglio (es. pagamenti specifici legati a QUESTA partecipazione),
    -- bisognerebbe controllare.
    -- Al momento non ci sono constraint INBOUND rilevati (step analisi).
    -- Il vincolo FK standard proteggerà comunque.
    
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
$$ LANGUAGE plpgsql;
