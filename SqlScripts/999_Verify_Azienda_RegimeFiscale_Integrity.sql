-- =====================================================
-- VERIFICA INTEGRITÀ: ana_aziende.regime_fiscale_fk
-- =====================================================
-- Data: 2026-03-17
-- Scopo: Verificare che tutti i record ana_aziende abbiano
--        un regime_fiscale_fk valido dopo il fix del bug critico
-- =====================================================

\echo '=== VERIFICA 1: Regimi Fiscali Attivi nel Sistema ==='
SELECT
    regime_id,
    regime_codice,
    regime_descrizione,
    attivo,
    data_creazione
FROM ana_regimi_fiscali
ORDER BY regime_codice;

\echo ''
\echo '=== VERIFICA 2: Aziende con Regime Fiscale ==='
SELECT
    a.azienda_id,
    a.ragione_sociale,
    a.regime_fiscale_fk,
    r.regime_codice,
    r.regime_descrizione,
    CASE
        WHEN a.regime_fiscale_fk IS NULL THEN 'ERRORE: FK NULL'
        WHEN a.regime_fiscale_fk = 0 THEN 'ERRORE: FK = 0'
        WHEN r.regime_id IS NULL THEN 'ERRORE: REGIME NON TROVATO'
        WHEN r.attivo = false THEN 'WARNING: REGIME NON ATTIVO'
        ELSE 'OK'
    END as stato_validazione
FROM ana_aziende a
LEFT JOIN ana_regimi_fiscali r ON a.regime_fiscale_fk = r.regime_id
ORDER BY
    CASE
        WHEN a.regime_fiscale_fk IS NULL THEN 1
        WHEN a.regime_fiscale_fk = 0 THEN 2
        WHEN r.regime_id IS NULL THEN 3
        WHEN r.attivo = false THEN 4
        ELSE 5
    END,
    a.ragione_sociale;

\echo ''
\echo '=== VERIFICA 3: Conteggio Problemi ==='
SELECT
    COUNT(*) FILTER (WHERE regime_fiscale_fk IS NULL) as fk_null,
    COUNT(*) FILTER (WHERE regime_fiscale_fk = 0) as fk_zero,
    COUNT(*) FILTER (
        WHERE regime_fiscale_fk NOT IN (
            SELECT regime_id FROM ana_regimi_fiscali WHERE attivo = true
        )
        AND regime_fiscale_fk IS NOT NULL
        AND regime_fiscale_fk != 0
    ) as fk_invalido,
    COUNT(*) as totale_aziende
FROM ana_aziende;

\echo ''
\echo '=== VERIFICA 4: Aziende con Problemi di FK ==='
SELECT
    a.azienda_id,
    a.ragione_sociale,
    a.partita_iva,
    a.regime_fiscale_fk,
    a.attivo,
    CASE
        WHEN a.regime_fiscale_fk IS NULL THEN 'FK NULL - Impostare manualmente'
        WHEN a.regime_fiscale_fk = 0 THEN 'FK = 0 - Impostare manualmente'
        ELSE 'FK non trovato in ana_regimi_fiscali'
    END as tipo_problema
FROM ana_aziende a
WHERE
    a.regime_fiscale_fk IS NULL
    OR a.regime_fiscale_fk = 0
    OR a.regime_fiscale_fk NOT IN (
        SELECT regime_id FROM ana_regimi_fiscali WHERE attivo = true
    );

\echo ''
\echo '=== VERIFICA 5: Distribuzione Aziende per Regime ==='
SELECT
    r.regime_codice,
    r.regime_descrizione,
    COUNT(a.azienda_id) as numero_aziende,
    COUNT(a.azienda_id) FILTER (WHERE a.attivo = true) as aziende_attive
FROM ana_regimi_fiscali r
LEFT JOIN ana_aziende a ON r.regime_id = a.regime_fiscale_fk
WHERE r.attivo = true
GROUP BY r.regime_id, r.regime_codice, r.regime_descrizione
ORDER BY numero_aziende DESC, r.regime_codice;

\echo ''
\echo '=== VERIFICA 6: Foreign Key Constraint Check ==='
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'ana_aziende'
    AND kcu.column_name = 'regime_fiscale_fk';

\echo ''
\echo '=== SCRIPT FIX (se necessario) ==='
\echo 'Se sono stati trovati problemi, eseguire manualmente:'
\echo ''
\echo '-- Impostare regime ORDINARIO per aziende con FK NULL o 0'
\echo '-- UPDATE ana_aziende'
\echo '-- SET regime_fiscale_fk = (SELECT regime_id FROM ana_regimi_fiscali WHERE regime_codice = ''ORDINARIO'' LIMIT 1)'
\echo '-- WHERE regime_fiscale_fk IS NULL OR regime_fiscale_fk = 0;'
\echo ''
\echo '-- Verificare manualmente ogni azienda e impostare il regime corretto'
\echo ''

-- =====================================================
-- NOTE OPERATIVE
-- =====================================================
-- 1. Se questo script trova aziende con FK NULL o 0,
--    NON eseguire automaticamente l'UPDATE
-- 2. Contattare l'utente per verificare quale regime
--    fiscale assegnare a ciascuna azienda problematica
-- 3. Dopo il fix, ri-eseguire questo script per confermare
-- =====================================================
