-- =====================================================
-- Script: 09_elimina_ana_fornitori.sql
-- Descrizione: Elimina definitivamente la tabella ana_fornitori
-- ATTENZIONE: Eseguire SOLO dopo aver verificato con 08_verifica_fk_ana_fornitori.sql
-- Data: 12/02/2026
-- =====================================================

\echo '============================================'
\echo 'ELIMINAZIONE TABELLA ana_fornitori'
\echo '============================================'
\echo ''
\echo 'ATTENZIONE: Questo script eliminerà definitivamente la tabella ana_fornitori'
\echo 'Assicurati di aver:'
\echo '  1. Eseguito lo script 08_verifica_fk_ana_fornitori.sql'
\echo '  2. Verificato che non ci siano FK attive'
\echo '  3. Fatto un BACKUP completo del database'
\echo ''

-- Pausa per dare tempo all'utente di leggere
\prompt 'Premi INVIO per continuare o CTRL+C per annullare...' dummy

\echo ''
\echo 'Step 1: Verifica finale esistenza tabella'

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'ana_fornitori'
        ) THEN 'Tabella ana_fornitori trovata - procedo con eliminazione'
        ELSE 'Tabella ana_fornitori NON esiste - operazione non necessaria'
    END as stato;

\echo ''
\echo 'Step 2: Backup record in una tabella temporanea (per sicurezza)'

-- Crea una tabella di backup temporanea (solo se ana_fornitori esiste)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'ana_fornitori') THEN

        -- Elimina eventuale backup precedente
        DROP TABLE IF EXISTS ana_fornitori_backup_before_delete;

        -- Crea backup
        EXECUTE 'CREATE TABLE ana_fornitori_backup_before_delete AS SELECT * FROM ana_fornitori';

        RAISE NOTICE 'Backup creato: ana_fornitori_backup_before_delete (% record)',
            (SELECT COUNT(*) FROM ana_fornitori_backup_before_delete);

        -- Aggiungi timestamp al backup
        EXECUTE 'COMMENT ON TABLE ana_fornitori_backup_before_delete IS ''Backup eseguito il ' ||
                NOW()::timestamp::text || ' prima di eliminare ana_fornitori''';
    ELSE
        RAISE NOTICE 'ana_fornitori non esiste - skip backup';
    END IF;
END $$;

\echo ''
\echo 'Step 3: Verifica ultima volta FK attive'

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'OK - Nessuna FK attiva'
        ELSE 'ERRORE - ' || COUNT(*)::text || ' FK ancora presenti! INTERROMPERE L''ESECUZIONE!'
    END as verifica_fk
FROM information_schema.table_constraints AS tc
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'ana_fornitori';

\echo ''
\echo 'Step 4: Eliminazione tabella ana_fornitori'

-- Elimina la tabella (CASCADE elimina anche eventuali FK rimaste)
DROP TABLE IF EXISTS ana_fornitori CASCADE;

\echo ''
\echo '✓ Tabella ana_fornitori eliminata con successo!'

\echo ''
\echo 'Step 5: Verifica finale'

SELECT
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'ana_fornitori'
        ) THEN '✓ ana_fornitori NON esiste più - operazione completata!'
        ELSE '✗ ERRORE - ana_fornitori esiste ancora!'
    END as verifica_finale;

\echo ''
\echo '============================================'
\echo 'RIEPILOGO'
\echo '============================================'

SELECT
    'Backup disponibile in: ana_fornitori_backup_before_delete' as info
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'ana_fornitori_backup_before_delete'
);

\echo ''
\echo 'NOTA: La tabella di backup (ana_fornitori_backup_before_delete) verrà'
\echo 'mantenuta per sicurezza. Puoi eliminarla manualmente dopo qualche giorno'
\echo 'se sei sicuro che tutto funzioni correttamente.'
\echo ''
\echo 'Comando per eliminare il backup:'
\echo '  DROP TABLE IF EXISTS ana_fornitori_backup_before_delete;'
\echo ''
\echo '============================================'
\echo 'OPERAZIONE COMPLETATA'
\echo '============================================'
