-- =============================================
-- Script di Verifica Integrità: mov_transazioni
-- Data Creazione: 2026-02-15
-- Autore: Claude Code
-- Descrizione: Script completo per verificare l'integrità referenziale
--              e la coerenza dei dati in mov_transazioni
-- Uso: Eseguire periodicamente per validare l'integrità del database
-- =============================================

\echo '========================================='
\echo 'VERIFICA INTEGRITÀ: mov_transazioni'
\echo 'Data: ' `date`
\echo '========================================='
\echo ''

-- =============================================
-- SEZIONE 1: VERIFICA FOREIGN KEYS
-- =============================================

\echo '=== 1. VERIFICA RECORD ORFANI (Foreign Keys) ==='
\echo ''

-- 1.1 FK: transazione_azienda_id → ana_aziende
\echo '1.1 Aziende inesistenti:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
WHERE a.azienda_id IS NULL;

-- 1.2 FK: transazione_viaggio_id → ana_viaggi
\echo ''
\echo '1.2 Viaggi inesistenti (esclusi NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_viaggi v ON t.transazione_viaggio_id = v.viaggio_id
WHERE t.transazione_viaggio_id IS NOT NULL
  AND v.viaggio_id IS NULL;

-- 1.3 FK: transazione_data_viaggio_id → ana_date_viaggi
\echo ''
\echo '1.3 Date viaggio inesistenti (esclusi NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
WHERE t.transazione_data_viaggio_id IS NOT NULL
  AND dv.data_viaggio_id IS NULL;

-- 1.4 FK: transazione_controparte_id → ana_controparti
\echo ''
\echo '1.4 Controparti inesistenti:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
WHERE c.controparte_id IS NULL;

-- 1.5 FK: transazione_causale_tipo_id → ana_tipi_causali
\echo ''
\echo '1.5 Causali tipo inesistenti:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
WHERE tc.causale_id IS NULL;

-- 1.6 FK: transazione_valuta_id → ana_valute
\echo ''
\echo '1.6 Valute inesistenti:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
WHERE v.valuta_id IS NULL;

-- 1.7 FK: transazione_aliquota_iva_fk → ana_aliquote_iva
\echo ''
\echo '1.7 Aliquote IVA inesistenti (esclusi NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t
LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
WHERE t.transazione_aliquota_iva_fk IS NOT NULL
  AND aiva.iva_id IS NULL;

-- 1.8 Self-Reference: transazione_fattura_fk → mov_transazioni
\echo ''
\echo '1.8 Fatture FK inesistenti (self-reference, esclusi NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_orfani
FROM mov_transazioni t1
LEFT JOIN mov_transazioni t2 ON t1.transazione_fattura_fk = t2.transazione_id
WHERE t1.transazione_fattura_fk IS NOT NULL
  AND t2.transazione_id IS NULL;

-- =============================================
-- SEZIONE 2: VERIFICA COERENZA CONSTRAINT
-- =============================================

\echo ''
\echo '=== 2. VERIFICA COERENZA CONSTRAINT ==='
\echo ''

-- 2.1 Constraint: viaggio/data_viaggio coerenza
\echo '2.1 Viaggio/Data Viaggio incoerenti (uno NULL, uno NOT NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni
WHERE (transazione_viaggio_id IS NULL AND transazione_data_viaggio_id IS NOT NULL)
   OR (transazione_viaggio_id IS NOT NULL AND transazione_data_viaggio_id IS NULL);

-- 2.2 Verifica: data_viaggio appartiene al viaggio corretto
\echo ''
\echo '2.2 Data Viaggio NON appartenente al viaggio:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni t
JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
WHERE t.transazione_viaggio_id IS NOT NULL
  AND dv.viaggio_id_fk != t.transazione_viaggio_id;

-- 2.3 Constraint: completezza campi IVA
\echo ''
\echo '2.3 IVA incompleta (aliquota presente ma campi NULL):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND (transazione_imponibile_eur IS NULL
       OR transazione_iva_eur IS NULL
       OR transazione_lordo_eur IS NULL);

-- 2.4 Constraint: assenza campi IVA quando aliquota NULL
\echo ''
\echo '2.4 Campi IVA valorizzati senza aliquota:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NULL
  AND (transazione_imponibile_eur IS NOT NULL
       OR transazione_iva_eur IS NOT NULL
       OR transazione_lordo_eur IS NOT NULL);

-- =============================================
-- SEZIONE 3: VERIFICA LOGICA BUSINESS
-- =============================================

\echo ''
\echo '=== 3. VERIFICA LOGICA BUSINESS ==='
\echo ''

-- 3.1 Cicli in fattura_fk (pagamenti di pagamenti)
\echo '3.1 Cicli in fattura_fk (pagamenti di pagamenti):'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠ WARNING' END as status,
    COUNT(*) as possibili_cicli
FROM mov_transazioni t1
JOIN mov_transazioni t2 ON t1.transazione_fattura_fk = t2.transazione_id
WHERE t2.transazione_fattura_fk IS NOT NULL;

-- 3.2 Coerenza tipo_movimento con causale_ciclo
\echo ''
\echo '3.2 Tipo movimento NON coerente con causale_ciclo:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni t
JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
WHERE (tc.causale_ciclo = 'ATTIVO' AND t.transazione_tipo_movimento != 'ENTRATA')
   OR (tc.causale_ciclo = 'PASSIVO' AND t.transazione_tipo_movimento != 'USCITA');

-- 3.3 Stato PAGATO senza data pagamento
\echo ''
\echo '3.3 Stato PAGATO senza data pagamento:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni
WHERE transazione_stato = 'PAGATO'
  AND transazione_data_pagamento IS NULL;

-- 3.4 Data pagamento con stato non-PAGATO
\echo ''
\echo '3.4 Data pagamento con stato NON PAGATO:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '⚠ WARNING' END as status,
    COUNT(*) as possibili_anomalie
FROM mov_transazioni
WHERE transazione_data_pagamento IS NOT NULL
  AND transazione_stato NOT IN ('PAGATO', 'PARZIALMENTE_PAGATO');

-- 3.5 IVA su valuta estera (deve essere NULL)
\echo ''
\echo '3.5 IVA su transazioni in valuta ESTERA:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni t
JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
WHERE v.valuta_is_base = FALSE
  AND t.transazione_aliquota_iva_fk IS NOT NULL;

-- 3.6 Causale non genera IVA ma aliquota presente
\echo ''
\echo '3.6 Causale NON genera IVA ma aliquota presente:'
SELECT
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ ERRORE' END as status,
    COUNT(*) as record_incoerenti
FROM mov_transazioni t
JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
WHERE tc.causale_genera_iva = FALSE
  AND t.transazione_aliquota_iva_fk IS NOT NULL;

-- =============================================
-- SEZIONE 4: STATISTICHE
-- =============================================

\echo ''
\echo '=== 4. STATISTICHE DATABASE ==='
\echo ''

-- 4.1 Statistiche generali
\echo '4.1 Statistiche Generali:'
SELECT
    COUNT(*) as totale_transazioni,
    COUNT(DISTINCT transazione_azienda_id) as aziende_coinvolte,
    COUNT(DISTINCT transazione_viaggio_id) as viaggi_coinvolti,
    COUNT(DISTINCT transazione_controparte_id) as controparti_coinvolte,
    COUNT(DISTINCT transazione_causale_tipo_id) as causali_utilizzate,
    COUNT(DISTINCT transazione_valuta_id) as valute_utilizzate
FROM mov_transazioni;

-- 4.2 Distribuzione per stato
\echo ''
\echo '4.2 Distribuzione per Stato:'
SELECT
    transazione_stato,
    COUNT(*) as totale,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM mov_transazioni), 0), 2) as percentuale
FROM mov_transazioni
GROUP BY transazione_stato
ORDER BY totale DESC;

-- 4.3 Transazioni con/senza IVA
\echo ''
\echo '4.3 Distribuzione IVA:'
SELECT
    CASE
        WHEN transazione_aliquota_iva_fk IS NOT NULL THEN 'Con IVA'
        ELSE 'Senza IVA'
    END as tipo_iva,
    COUNT(*) as totale,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM mov_transazioni), 0), 2) as percentuale
FROM mov_transazioni
GROUP BY tipo_iva;

-- 4.4 Transazioni generali vs viaggi
\echo ''
\echo '4.4 Distribuzione Tipo Transazione:'
SELECT
    CASE
        WHEN transazione_viaggio_id IS NULL THEN 'Generali (non legate a viaggio)'
        ELSE 'Legate a viaggio'
    END as tipo_transazione,
    COUNT(*) as totale,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM mov_transazioni), 0), 2) as percentuale
FROM mov_transazioni
GROUP BY tipo_transazione;

-- =============================================
-- RIEPILOGO FINALE
-- =============================================

\echo ''
\echo '========================================='
\echo 'VERIFICA COMPLETATA'
\echo '========================================='
\echo ''
\echo 'Legenda:'
\echo '  ✓ OK       = Nessun problema rilevato'
\echo '  ⚠ WARNING  = Possibile anomalia, da verificare'
\echo '  ✗ ERRORE   = Problema critico, da risolvere'
\echo ''
\echo 'Se tutti i controlli sono ✓ OK, l''integrità è garantita.'
\echo ''

-- =============================================
-- QUERY DIAGNOSTICHE (Opzionali)
-- =============================================
-- Decommentare le query sottostanti per visualizzare i record problematici

/*
-- Mostra record orfani su transazione_azienda_id
SELECT t.*
FROM mov_transazioni t
LEFT JOIN ana_aziende a ON t.transazione_azienda_id = a.azienda_id
WHERE a.azienda_id IS NULL;

-- Mostra transazioni con viaggio/data_viaggio incoerenti
SELECT *
FROM mov_transazioni
WHERE (transazione_viaggio_id IS NULL AND transazione_data_viaggio_id IS NOT NULL)
   OR (transazione_viaggio_id IS NOT NULL AND transazione_data_viaggio_id IS NULL);

-- Mostra transazioni PAGATO senza data pagamento
SELECT *
FROM mov_transazioni
WHERE transazione_stato = 'PAGATO'
  AND transazione_data_pagamento IS NULL;
*/
