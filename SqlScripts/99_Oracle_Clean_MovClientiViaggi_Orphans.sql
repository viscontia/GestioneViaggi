
-- 99_Oracle_Clean_MovClientiViaggi_Orphans.sql
-- DESCRIZIONE: Cancellazione record orfani su Oracle (Allineamento con PostgreSQL)
-- DATA: 2026-01-15
-- AUTORE: Antigravity
-- NOTE: Usiamo un blocco PL/SQL anonimo per garantire l'esecuzione atomica ed evitare errori ORA-00933 su client che non gestiscono script con istruzioni multiple.

BEGIN
    -- Cancellazione orfani FK Cliente
    DELETE FROM mov_clienti_viaggi 
    WHERE cliente_id_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    -- Cancellazione orfani FK Pilota
    DELETE FROM mov_clienti_viaggi 
    WHERE cliente_pilota_id_fk IS NOT NULL 
    AND cliente_pilota_id_fk NOT IN (SELECT cliente_id FROM ana_clienti);

    COMMIT;
END;
/
