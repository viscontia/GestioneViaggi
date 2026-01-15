
-- 99_Oracle_Clean_MovClientiAlloggi_Orphans.sql
-- DESCRIZIONE: Pulizia orfani su mov_clienti_alloggi
-- DATA: 2026-01-15
-- AUTORE: Antigravity
-- FIX: ORA-01407. cliente_id1_fk è NOT NULL, quindi se l'orfano è lui dobbiamo cancellare la riga.

BEGIN
    -- 1. Se l'orfano è il PRIMO cliente (obbligatorio), CANCELLIAMO l'intera riga
    DELETE FROM mov_clienti_alloggi 
    WHERE cliente_id1_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- 2. Per gli altri (opzionali), mettiamo a NULL
    
    -- Update cliente_id2_fk
    UPDATE mov_clienti_alloggi 
    SET cliente_id2_fk = NULL 
    WHERE cliente_id2_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- Update cliente_id3_fk
    UPDATE mov_clienti_alloggi 
    SET cliente_id3_fk = NULL 
    WHERE cliente_id3_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- Update cliente_id4_fk
    UPDATE mov_clienti_alloggi 
    SET cliente_id4_fk = NULL 
    WHERE cliente_id4_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- Update cliente_id5_fk
    UPDATE mov_clienti_alloggi 
    SET cliente_id5_fk = NULL 
    WHERE cliente_id5_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- Update cliente_id6_fk
    UPDATE mov_clienti_alloggi 
    SET cliente_id6_fk = NULL 
    WHERE cliente_id6_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    COMMIT;
END;
/
