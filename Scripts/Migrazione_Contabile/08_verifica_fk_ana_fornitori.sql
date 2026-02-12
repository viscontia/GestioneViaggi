-- =====================================================
-- Script: 08_verifica_fk_ana_fornitori.sql
-- Descrizione: Verifica se esistono ancora FK che puntano a ana_fornitori
-- Data: 12/02/2026
-- =====================================================

\echo '============================================'
\echo 'VERIFICA FOREIGN KEY SU ana_fornitori'
\echo '============================================'
\echo ''

-- 1. Verifica se la tabella ana_fornitori esiste ancora
\echo '1. Verifica esistenza tabella ana_fornitori:'
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'ana_fornitori'
        ) THEN '✓ La tabella ana_fornitori ESISTE ancora'
        ELSE '✗ La tabella ana_fornitori NON esiste (già eliminata)'
    END as risultato;

\echo ''
\echo '2. Foreign Key che puntano a ana_fornitori:'

-- 2. Trova tutte le FK che referenziano ana_fornitori
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ Nessuna FK punta a ana_fornitori - SAFE TO DELETE'
        ELSE '✗ ATTENZIONE: ' || COUNT(*)::text || ' FK ancora attive!'
    END as risultato
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'ana_fornitori';

\echo ''
\echo '3. Dettaglio FK trovate (se presenti):'

-- 3. Dettaglio completo delle FK
SELECT
    tc.table_schema as schema_tabella,
    tc.table_name as tabella_che_referenzia,
    kcu.column_name as colonna_fk,
    ccu.table_name as tabella_referenziata,
    ccu.column_name as colonna_referenziata,
    tc.constraint_name as nome_constraint
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'ana_fornitori'
ORDER BY tc.table_name, tc.constraint_name;

\echo ''
\echo '4. Conteggio record in ana_fornitori (se esiste):'

-- 4. Conta quanti record ci sono ancora in ana_fornitori
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'ana_fornitori') THEN
        EXECUTE 'SELECT COUNT(*) as record_totali FROM ana_fornitori';
    ELSE
        RAISE NOTICE 'Tabella ana_fornitori non esiste';
    END IF;
END $$;

\echo ''
\echo '5. Verifica migrazione a ana_controparti:'

-- 5. Confronta i record tra ana_fornitori (se esiste) e ana_controparti
SELECT
    (SELECT COUNT(*) FROM ana_controparti WHERE is_fornitore = TRUE) as fornitori_in_controparti,
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables
                     WHERE table_schema = 'public' AND table_name = 'ana_fornitori')
        THEN (SELECT COUNT(*) FROM ana_fornitori)
        ELSE 0
    END as record_in_ana_fornitori,
    CASE
        WHEN (SELECT COUNT(*) FROM ana_controparti WHERE is_fornitore = TRUE) >=
             COALESCE((SELECT COUNT(*) FROM ana_fornitori), 0)
        THEN '✓ Migrazione completa'
        ELSE '✗ Possibile perdita di dati!'
    END as stato_migrazione;

\echo ''
\echo '============================================'
\echo 'CONCLUSIONE'
\echo '============================================'
\echo 'Se tutti i check sono OK (✓), è sicuro eliminare ana_fornitori'
\echo 'Comando per eliminare: DROP TABLE IF EXISTS ana_fornitori CASCADE;'
\echo '============================================'
