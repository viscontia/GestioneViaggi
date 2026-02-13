-- =====================================================
-- Script: 07_crea_view_reportistica.sql
-- Descrizione: Creazione view per reportistica contabile
-- Data: 12/02/2026
-- Ultima Modifica: 13/02/2026
--
-- IMPORTANTE: Il calcolo dei residui usa transazione_fattura_fk per
-- identificare i pagamenti PG/IN già registrati, NON la tabella mov_pagamenti.
-- Questo allineamento è necessario per coerenza con MovTransazioniService.PagaOraAsync()
-- =====================================================

-- ===========================================
-- VIEW 1: vw_partitario_fornitori
-- ===========================================
CREATE OR REPLACE VIEW public.vw_partitario_fornitori AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    c.nome_breve,
    t.transazione_id,
    t.transazione_data,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    ca.causale_codice,
    ca.causale_descrizione,
    t.transazione_importo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere)
    (t.transazione_importo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo con window function
    SUM(t.transazione_importo_eur * ca.causale_segno)
        OVER (
            PARTITION BY c.controparte_id
            ORDER BY t.transazione_data, t.transazione_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as saldo_progressivo,

    -- Stato transazione
    t.transazione_stato,
    t.transazione_data_scadenza,

    -- Residuo (solo per transazioni non pagate completamente)
    -- NOTA: Usa transazione_fattura_fk per calcolare pagamenti già registrati (transazioni PG/IN)
    CASE
        WHEN t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
        THEN (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(ABS(pg.transazione_importo_eur))
             FROM mov_transazioni pg
             WHERE pg.transazione_fattura_fk = t.transazione_id
               AND pg.transazione_stato = 'PAGATO'), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note,
    t.transazione_causale

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE ca.causale_ciclo = 'PASSIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_fornitore = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;

COMMENT ON VIEW vw_partitario_fornitori IS 'Estratto conto fornitori con saldo progressivo e residui da pagare';

-- ===========================================
-- VIEW 2: vw_partitario_clienti
-- ===========================================
CREATE OR REPLACE VIEW public.vw_partitario_clienti AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    c.nome_breve,
    t.transazione_id,
    t.transazione_data,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    ca.causale_codice,
    ca.causale_descrizione,
    t.transazione_importo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere)
    (t.transazione_importo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo
    SUM(t.transazione_importo_eur * ca.causale_segno)
        OVER (
            PARTITION BY c.controparte_id
            ORDER BY t.transazione_data, t.transazione_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as saldo_progressivo,

    -- Stato
    t.transazione_stato,
    t.transazione_data_scadenza,

    -- Residuo
    -- NOTA: Usa transazione_fattura_fk per calcolare incassi già registrati (transazioni IN)
    CASE
        WHEN t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
        THEN (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(ABS(pg.transazione_importo_eur))
             FROM mov_transazioni pg
             WHERE pg.transazione_fattura_fk = t.transazione_id
               AND pg.transazione_stato = 'PAGATO'), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note,
    t.transazione_causale

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE ca.causale_ciclo = 'ATTIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_cliente = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;

COMMENT ON VIEW vw_partitario_clienti IS 'Estratto conto clienti con saldo progressivo e residui da incassare';

-- ===========================================
-- VIEW 3: vw_margini_viaggi
-- ===========================================
CREATE OR REPLACE VIEW public.vw_margini_viaggi AS
SELECT
    v.viaggio_id,
    v.viaggio_descrizione_breve,

    -- Ricavi (ciclo ATTIVO)
    COALESCE(SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_importo_eur * ca.causale_segno
        ELSE 0
    END), 0) as ricavi_totali_eur,

    -- Costi (ciclo PASSIVO, valore assoluto)
    COALESCE(SUM(CASE
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN ABS(t.transazione_importo_eur * ca.causale_segno)
        ELSE 0
    END), 0) as costi_totali_eur,

    -- Margine (ricavi - costi)
    COALESCE(SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_importo_eur * ca.causale_segno
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN (t.transazione_importo_eur * ca.causale_segno) * -1
        ELSE 0
    END), 0) as margine_eur,

    -- Margine percentuale
    CASE
        WHEN SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno ELSE 0 END) > 0
        THEN (
            COALESCE(SUM(CASE
                WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno
                WHEN ca.causale_ciclo = 'PASSIVO' THEN (t.transazione_importo_eur * ca.causale_segno) * -1
                ELSE 0
            END), 0) /
            SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno ELSE 0 END)
        ) * 100
        ELSE 0
    END as margine_percentuale,

    -- Conteggi
    COUNT(DISTINCT CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_id END) as num_transazioni_attive,
    COUNT(DISTINCT CASE WHEN ca.causale_ciclo = 'PASSIVO' THEN t.transazione_id END) as num_transazioni_passive

FROM ana_viaggi v
LEFT JOIN mov_transazioni t ON v.viaggio_id = t.transazione_viaggio_id
    AND t.transazione_stato <> 'ANNULLATO'
LEFT JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
GROUP BY v.viaggio_id, v.viaggio_descrizione_breve
ORDER BY v.viaggio_descrizione_breve;

COMMENT ON VIEW vw_margini_viaggi IS 'Calcolo margini per viaggio (ricavi - costi) con percentuali';

-- ===========================================
-- VIEW 4: vw_scadenzario
-- ===========================================
CREATE OR REPLACE VIEW public.vw_scadenzario AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    ca.causale_ciclo,
    ca.causale_descrizione,
    t.transazione_id,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    t.transazione_data_scadenza,
    t.transazione_importo_eur * ca.causale_segno as importo,

    -- Residuo da pagare/incassare
    -- NOTA: Usa transazione_fattura_fk per calcolare pagamenti/incassi già registrati
    (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
        (SELECT SUM(ABS(pg.transazione_importo_eur))
         FROM mov_transazioni pg
         WHERE pg.transazione_fattura_fk = t.transazione_id
           AND pg.transazione_stato = 'PAGATO'), 0
    ) as residuo,

    -- Giorni alla scadenza (negativo = scaduto)
    t.transazione_data_scadenza - CURRENT_DATE as giorni_a_scadenza,

    -- Classificazione urgenza
    CASE
        WHEN t.transazione_data_scadenza < CURRENT_DATE THEN 'SCADUTO'
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 7 THEN 'URGENTE'
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 30 THEN 'IN_SCADENZA'
        ELSE 'NORMALE'
    END as urgenza,

    t.transazione_stato,
    t.transazione_viaggio_id,
    t.transazione_note

FROM mov_transazioni t
JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
  AND t.transazione_data_scadenza IS NOT NULL
  AND t.transazione_stato <> 'ANNULLATO'
ORDER BY
    CASE
        WHEN t.transazione_data_scadenza < CURRENT_DATE THEN 1
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 7 THEN 2
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 30 THEN 3
        ELSE 4
    END,
    t.transazione_data_scadenza;

COMMENT ON VIEW vw_scadenzario IS 'Scadenzario pagamenti/incassi con classificazione urgenza';

-- ===========================================
-- Verifica creazione view
-- ===========================================
SELECT 'View create con successo!' as risultato;
SELECT viewname, definition IS NOT NULL as definizione_ok
FROM pg_views
WHERE schemaname = 'public'
  AND viewname LIKE 'vw_%'
ORDER BY viewname;
