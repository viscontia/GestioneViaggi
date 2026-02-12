-- ============================================================================
-- Reset e Caricamento Dati Corretti per Azienda 6 (Offroad Adventures)
-- Data: 2026-02-12
-- Scopo: Cancellare dati errati e ricaricare con logica contabile corretta
-- ============================================================================

-- STEP 1: Backup dati esistenti (per sicurezza)
CREATE TEMP TABLE backup_transazioni_azienda_6 AS
SELECT * FROM mov_transazioni WHERE transazione_azienda_id = 6;

-- STEP 2: Cancella tutte le transazioni dell'azienda 6
DELETE FROM mov_transazioni WHERE transazione_azienda_id = 6;

-- STEP 3: Verifica causali disponibili per l'azienda 6
SELECT causale_id, causale_codice, causale_descrizione, causale_segno, causale_is_documento
FROM ana_tipi_causali
WHERE azienda_fk = 6 AND is_active = TRUE
ORDER BY causale_id;

-- Se non ci sono causali, le creiamo
INSERT INTO ana_tipi_causali (azienda_fk, causale_codice, causale_descrizione, causale_segno, causale_is_documento, created_by)
VALUES
    (6, 'FT', 'Fattura passiva', 1, TRUE, 'mirania008@gmail.com'),
    (6, 'NC', 'Nota di Credito', -1, TRUE, 'mirania008@gmail.com'),
    (6, 'PG', 'Pagamento / Acconto', -1, FALSE, 'mirania008@gmail.com'),
    (6, 'ND', 'Nota di Debito', 1, TRUE, 'mirania008@gmail.com')
ON CONFLICT (azienda_fk, causale_codice) DO NOTHING;

-- STEP 4: Recupera ID necessari per i dati di test
DO $$
DECLARE
    v_azienda_id INTEGER := 6;
    v_fornitore_jolly_id INTEGER;
    v_fornitore_test_id INTEGER;
    v_causale_ft_id INTEGER;
    v_causale_pg_id INTEGER;
    v_causale_nc_id INTEGER;
    v_valuta_eur_id INTEGER;
    v_valuta_usd_id INTEGER;
    v_valuta_zar_id INTEGER;
BEGIN
    -- Recupera fornitori
    SELECT fornitore_id INTO v_fornitore_jolly_id
    FROM ana_fornitori
    WHERE ragione_sociale = 'JOLLY TRAVEL SAS' AND azienda_fk = v_azienda_id;

    SELECT fornitore_id INTO v_fornitore_test_id
    FROM ana_fornitori
    WHERE ragione_sociale = 'TEST FOREIGN SUPPLIER SARL' AND azienda_fk = v_azienda_id;

    -- Recupera causali
    SELECT causale_id INTO v_causale_ft_id
    FROM ana_tipi_causali
    WHERE azienda_fk = v_azienda_id AND causale_codice = 'FT';

    SELECT causale_id INTO v_causale_pg_id
    FROM ana_tipi_causali
    WHERE azienda_fk = v_azienda_id AND causale_codice = 'PG';

    SELECT causale_id INTO v_causale_nc_id
    FROM ana_tipi_causali
    WHERE azienda_fk = v_azienda_id AND causale_codice = 'NC';

    -- Recupera valute
    SELECT valuta_id INTO v_valuta_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    SELECT valuta_id INTO v_valuta_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';
    SELECT valuta_id INTO v_valuta_zar_id FROM ana_valute WHERE valuta_codice_iso = 'ZAR';

    RAISE NOTICE 'Fornitore JOLLY: %, Fornitore TEST: %', v_fornitore_jolly_id, v_fornitore_test_id;
    RAISE NOTICE 'Causale FT: %, PG: %, NC: %', v_causale_ft_id, v_causale_pg_id, v_causale_nc_id;
    RAISE NOTICE 'Valuta EUR: %, USD: %, ZAR: %', v_valuta_eur_id, v_valuta_usd_id, v_valuta_zar_id;

    -- ========================================================================
    -- SCENARIO REALISTICO: JOLLY TRAVEL SAS
    -- ========================================================================

    -- 1. FATTURA #JT-2025-001 per servizi turistici (EUR) - DA PAGARE
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_tipo_movimento,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_documento,
        transazione_numero_documento,
        transazione_data_scadenza,
        transazione_stato,
        transazione_causale,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_jolly_id,
        v_causale_ft_id,  -- FATTURA (segno +1)
        'USCITA',  -- Costo da pagare
        1500.00,
        v_valuta_eur_id,
        '2025-01-15',
        '2025-01-15',
        'JT-2025-001',
        '2025-02-15',  -- Scadenza 30 giorni
        'DA_PAGARE',   -- Ancora da pagare!
        'SERVIZI TURISTICI SAFARI KENYA',
        'mirania008@gmail.com'
    );

    -- 2. FATTURA #JT-2025-002 per trasferimenti (ZAR) - DA PAGARE
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_documento,
        transazione_numero_documento,
        transazione_data_scadenza,
        transazione_stato,
        transazione_causale,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_jolly_id,
        v_causale_ft_id,  -- FATTURA (segno +1)
        5000.00,
        v_valuta_zar_id,
        '2025-01-20',
        '2025-01-20',
        'JT-2025-002',
        '2025-02-20',
        'DA_PAGARE',
        'TRASFERIMENTI AEROPORTUALI',
        'mirania008@gmail.com'
    );

    -- 3. PAGAMENTO parziale su fattura JT-2025-001 (EUR) - PAGATO
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_pagamento,
        transazione_stato,
        transazione_causale,
        transazione_note,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_jolly_id,
        v_causale_pg_id,  -- PAGAMENTO (segno -1)
        1000.00,
        v_valuta_eur_id,
        '2025-01-25',
        '2025-01-25',
        'PAGATO',  -- Già pagato!
        'ACCONTO SU FATTURA JT-2025-001',
        'BONIFICO BANCARIO - RIF. JT-2025-001',
        'mirania008@gmail.com'
    );

    -- 4. NOTA CREDITO per rimborso (EUR) - Ricevuta
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_documento,
        transazione_numero_documento,
        transazione_stato,
        transazione_causale,
        transazione_note,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_jolly_id,
        v_causale_nc_id,  -- NOTA CREDITO (segno -1)
        250.00,
        v_valuta_eur_id,
        '2025-02-01',
        '2025-02-01',
        'NC-JT-2025-001',
        'PAGATO',
        'NOTA CREDITO PER SERVIZIO NON EROGATO',
        'Rimborso per escursione annullata',
        'mirania008@gmail.com'
    );

    -- ========================================================================
    -- SCENARIO REALISTICO: TEST FOREIGN SUPPLIER SARL (Fornitore estero)
    -- ========================================================================

    -- 5. FATTURA in USD per ricambi auto - DA PAGARE
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_documento,
        transazione_numero_documento,
        transazione_data_scadenza,
        transazione_stato,
        transazione_causale,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_test_id,
        v_causale_ft_id,  -- FATTURA (segno +1)
        4500.00,
        v_valuta_usd_id,
        '2025-01-10',
        '2025-01-10',
        'INV-USD-2025-001',
        '2025-02-10',
        'DA_PAGARE',
        'DATI MOCKUP - SERVIZI VARI IN USD',
        'mirania008@gmail.com'
    );

    -- 6. FATTURA in ZAR per pezzi di ricambio - PARZIALMENTE PAGATO
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_documento,
        transazione_numero_documento,
        transazione_data_scadenza,
        transazione_stato,
        transazione_causale,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_test_id,
        v_causale_ft_id,  -- FATTURA (segno +1)
        2500.00,
        v_valuta_zar_id,
        '2025-01-12',
        '2025-01-12',
        'INV-ZAR-2025-001',
        '2025-02-12',
        'PARZIALMENTE_PAGATO',
        'SPARE PARTS TOYOTA',
        'mirania008@gmail.com'
    );

    -- 7. PAGAMENTO parziale su fattura in ZAR
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_fornitore_id,
        transazione_causale_tipo_id,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_pagamento,
        transazione_stato,
        transazione_causale,
        transazione_note,
        created_by
    ) VALUES (
        v_azienda_id,
        v_fornitore_test_id,
        v_causale_pg_id,  -- PAGAMENTO (segno -1)
        1500.00,
        v_valuta_zar_id,
        '2025-01-18',
        '2025-01-18',
        'PAGATO',
        'ACCONTO SU INV-ZAR-2025-001',
        'Pagato 1500 su 2500 ZAR',
        'mirania008@gmail.com'
    );

    RAISE NOTICE 'Dati di test con logica contabile corretta inseriti con successo!';

    -- Mostra riepilogo
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RIEPILOGO TRANSAZIONI INSERITE:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'JOLLY TRAVEL SAS:';
    RAISE NOTICE '  - Fattura JT-2025-001: +1500 EUR (Da Pagare)';
    RAISE NOTICE '  - Fattura JT-2025-002: +5000 ZAR (Da Pagare)';
    RAISE NOTICE '  - Pagamento su JT-2025-001: -1000 EUR (Pagato)';
    RAISE NOTICE '  - Nota Credito: -250 EUR';
    RAISE NOTICE '  → SALDO ATTESO: +250 EUR, +5000 ZAR (devi ancora pagare)';
    RAISE NOTICE '';
    RAISE NOTICE 'TEST FOREIGN SUPPLIER:';
    RAISE NOTICE '  - Fattura USD: +4500 USD (Da Pagare)';
    RAISE NOTICE '  - Fattura ZAR: +2500 ZAR (Parzialmente Pagato)';
    RAISE NOTICE '  - Pagamento parziale: -1500 ZAR';
    RAISE NOTICE '  → SALDO ATTESO: +4500 USD, +1000 ZAR (devi ancora pagare)';

END $$;

-- STEP 5: Verifica i dati inseriti
SELECT
    t.transazione_id,
    t.transazione_data,
    f.ragione_sociale as fornitore,
    c.causale_codice,
    c.causale_descrizione,
    c.causale_segno,
    t.transazione_importo,
    v.valuta_codice_iso,
    t.transazione_importo_eur,
    t.transazione_stato,
    t.transazione_causale,
    t.transazione_numero_documento
FROM mov_transazioni t
JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
WHERE t.transazione_azienda_id = 6
ORDER BY f.ragione_sociale, t.transazione_data;
