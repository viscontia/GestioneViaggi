-- ============================================================================
-- Debug Script: Investigate Zero Subtotals Issue
-- ============================================================================

-- 1. Check causale_segno values in ana_tipi_causali
SELECT
    causale_id,
    causale_codice,
    causale_descrizione,
    causale_segno,
    causale_attivo
FROM ana_tipi_causali
ORDER BY causale_id;

-- 2. Check sample transactions with their causale_segno
SELECT
    t.transazione_id,
    t.transazione_data,
    f.ragione_sociale as fornitore,
    t.transazione_importo,
    v.valuta_codice_iso,
    t.transazione_importo_eur,
    c.causale_codice,
    c.causale_descrizione,
    c.causale_segno,
    -- Show what the calculation would be
    CASE
        WHEN c.causale_segno > 0 THEN t.transazione_importo_eur
        ELSE 0
    END as fatturato_calc,
    CASE
        WHEN c.causale_segno < 0 THEN t.transazione_importo_eur
        ELSE 0
    END as pagato_calc
FROM mov_transazioni t
INNER JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
INNER JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
ORDER BY t.transazione_data DESC
LIMIT 20;

-- 3. Test the actual aggregation manually
SELECT
    f.ragione_sociale as gruppo,
    v.valuta_codice_iso as valuta,
    COUNT(*) as num_transazioni,
    -- Totale Fatturato (causale_segno > 0)
    SUM(CASE WHEN c.causale_segno > 0 THEN t.transazione_importo_eur ELSE 0 END) as totale_fatturato,
    -- Totale Pagato (causale_segno < 0)
    SUM(CASE WHEN c.causale_segno < 0 THEN t.transazione_importo_eur ELSE 0 END) as totale_pagato,
    -- Saldo algebrico
    SUM(t.transazione_importo_eur * c.causale_segno) as saldo
FROM mov_transazioni t
INNER JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
INNER JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
GROUP BY f.ragione_sociale, v.valuta_codice_iso
ORDER BY f.ragione_sociale, v.valuta_codice_iso;

-- 4. Check if causale_segno is NULL anywhere
SELECT
    COUNT(*) as total_transazioni,
    COUNT(c.causale_segno) as causale_segno_not_null,
    SUM(CASE WHEN c.causale_segno IS NULL THEN 1 ELSE 0 END) as causale_segno_null_count,
    SUM(CASE WHEN c.causale_segno = 0 THEN 1 ELSE 0 END) as causale_segno_zero_count,
    SUM(CASE WHEN c.causale_segno > 0 THEN 1 ELSE 0 END) as causale_segno_positive_count,
    SUM(CASE WHEN c.causale_segno < 0 THEN 1 ELSE 0 END) as causale_segno_negative_count
FROM mov_transazioni t
INNER JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id;
