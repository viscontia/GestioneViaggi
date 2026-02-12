-- ============================================================================
-- SOLO INSERIMENTO DATI CORRETTI (dopo aver cancellato quelli vecchi manualmente)
-- ============================================================================

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
    SELECT causale_id INTO v_causale_ft_id FROM ana_tipi_causali WHERE azienda_fk = v_azienda_id AND causale_codice = 'FT';
    SELECT causale_id INTO v_causale_pg_id FROM ana_tipi_causali WHERE azienda_fk = v_azienda_id AND causale_codice = 'PG';
    SELECT causale_id INTO v_causale_nc_id FROM ana_tipi_causali WHERE azienda_fk = v_azienda_id AND causale_codice = 'NC';

    -- Recupera valute
    SELECT valuta_id INTO v_valuta_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    SELECT valuta_id INTO v_valuta_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';
    SELECT valuta_id INTO v_valuta_zar_id FROM ana_valute WHERE valuta_codice_iso = 'ZAR';

    -- 1. FATTURA EUR - Da Pagare
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_scadenza, transazione_stato, transazione_causale, created_by)
    VALUES (v_azienda_id, v_fornitore_jolly_id, v_causale_ft_id, 'USCITA', 1500.00, v_valuta_eur_id, '2025-01-15', '2025-01-15', 'JT-2025-001', '2025-02-15', 'DA_PAGARE', 'SERVIZI TURISTICI SAFARI KENYA', 'mirania008@gmail.com');

    -- 2. FATTURA ZAR - Da Pagare
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_scadenza, transazione_stato, transazione_causale, created_by)
    VALUES (v_azienda_id, v_fornitore_jolly_id, v_causale_ft_id, 'USCITA', 5000.00, v_valuta_zar_id, '2025-01-20', '2025-01-20', 'JT-2025-002', '2025-02-20', 'DA_PAGARE', 'TRASFERIMENTI AEROPORTUALI', 'mirania008@gmail.com');

    -- 3. PAGAMENTO parziale - Pagato
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_pagamento, transazione_stato, transazione_causale, transazione_note, created_by)
    VALUES (v_azienda_id, v_fornitore_jolly_id, v_causale_pg_id, 'USCITA', 1000.00, v_valuta_eur_id, '2025-01-25', '2025-01-25', 'PAGATO', 'ACCONTO SU FATTURA JT-2025-001', 'BONIFICO BANCARIO', 'mirania008@gmail.com');

    -- 4. NOTA CREDITO
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_documento, transazione_numero_documento, transazione_stato, transazione_causale, transazione_note, created_by)
    VALUES (v_azienda_id, v_fornitore_jolly_id, v_causale_nc_id, 'ENTRATA', 250.00, v_valuta_eur_id, '2025-02-01', '2025-02-01', 'NC-JT-2025-001', 'PAGATO', 'NOTA CREDITO SERVIZIO NON EROGATO', 'Rimborso escursione', 'mirania008@gmail.com');

    -- 5. FATTURA USD - Da Pagare
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_scadenza, transazione_stato, transazione_causale, created_by)
    VALUES (v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 4500.00, v_valuta_usd_id, '2025-01-10', '2025-01-10', 'INV-USD-2025-001', '2025-02-10', 'DA_PAGARE', 'SERVIZI VARI IN USD', 'mirania008@gmail.com');

    -- 6. FATTURA ZAR - Parzialmente Pagato
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_scadenza, transazione_stato, transazione_causale, created_by)
    VALUES (v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 2500.00, v_valuta_zar_id, '2025-01-12', '2025-01-12', 'INV-ZAR-2025-001', '2025-02-12', 'PARZIALMENTE_PAGATO', 'SPARE PARTS TOYOTA', 'mirania008@gmail.com');

    -- 7. PAGAMENTO parziale ZAR
    INSERT INTO mov_transazioni (transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento, transazione_importo, transazione_valuta_id, transazione_data, transazione_data_pagamento, transazione_stato, transazione_causale, transazione_note, created_by)
    VALUES (v_azienda_id, v_fornitore_test_id, v_causale_pg_id, 'USCITA', 1500.00, v_valuta_zar_id, '2025-01-18', '2025-01-18', 'PAGATO', 'ACCONTO SU INV-ZAR-2025-001', 'Pagato 1500/2500', 'mirania008@gmail.com');

    RAISE NOTICE 'Dati corretti inseriti!';
END $$;
