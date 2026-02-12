-- ============================================================================
-- FIX LOGICA CONTABILE MOCKUP - Mirania (v2 con data_documento obbligatoria)
-- Autore: Antigravity
-- Data: 2026-02-12
-- ============================================================================

DO $$
DECLARE
    v_azienda_id INTEGER := 6;
    v_user_email VARCHAR := 'mirania008@gmail.com';
    v_fornitore_test_id INTEGER := 12; -- TEST FOREIGN SUPPLIER SARL
    v_causale_ft_id INTEGER := 1;      -- FT (+)
    v_causale_pg_id INTEGER := 3;      -- PG (-)
    v_valuta_eur_id INTEGER := 2;
    v_valuta_usd_id INTEGER := 3;
    v_valuta_zar_id INTEGER := 10;
BEGIN
    -- 1. Pulizia dati esistenti per l'utente
    DELETE FROM mov_transazioni WHERE created_by = v_user_email;
    RAISE NOTICE 'Pulizia transazioni completata per %', v_user_email;

    -- 2. Inserimento FATTURE (Debiti) -> Segno 1 (Incrementa debito)
    
    -- OLIO MOTORE (45/R) - 50 EUR (Da Pagare)
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, 
        transazione_tipo_movimento, transazione_importo, transazione_valuta_id, 
        transazione_data, transazione_data_documento, transazione_numero_documento, 
        transazione_stato, transazione_causale, created_by
    ) VALUES (
        v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 50.00, v_valuta_eur_id, 
        '2026-02-04', '2026-02-04', '45/R', 
        'DA_PAGARE', 'OLIO MOTORE', v_user_email
    );

    -- SPARE PARTS TOYOTA (125/AZ) - 2500 ZAR (Da Pagare)
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, 
        transazione_tipo_movimento, transazione_importo, transazione_valuta_id, 
        transazione_data, transazione_data_documento, transazione_numero_documento, 
        transazione_stato, transazione_causale, created_by
    ) VALUES (
        v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 2500.00, v_valuta_zar_id, 
        '2026-02-07', '2026-02-07', '125/AZ', 
        'DA_PAGARE', 'SPARE PARTS TOYOTA', v_user_email
    );

    -- Servizi locali Sudafrica (Z-9988) - 4500 ZAR (Da Pagare)
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, 
        transazione_tipo_movimento, transazione_importo, transazione_valuta_id, 
        transazione_data, transazione_data_documento, transazione_numero_documento, 
        transazione_stato, transazione_causale, created_by
    ) VALUES (
        v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 4500.00, v_valuta_zar_id, 
        '2026-02-07', '2026-02-07', 'Z-9988', 
        'DA_PAGARE', 'Dati mockup - Servizi locali Sudafrica', v_user_email
    );

    -- Spese di rappresentanza estero (USD-DOC-44) - 150 USD (Pagato)
    -- Inseriamo sia la Fattura che il Pagamento per pareggiare
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, 
        transazione_tipo_movimento, transazione_importo, transazione_valuta_id, 
        transazione_data, transazione_data_documento, transazione_numero_documento, 
        transazione_stato, transazione_causale, created_by
    ) VALUES (
        v_azienda_id, v_fornitore_test_id, v_causale_ft_id, 'USCITA', 150.00, v_valuta_usd_id, 
        '2026-02-08', '2026-02-08', 'USD-DOC-44', 
        'PAGATO', 'Spese di rappresentanza estero', v_user_email
    );

    -- 3. Inserimento PAGAMENTI (Uscite) -> Segno -1 (Decrementa debito)

    -- Pagamento Fattura USD-DOC-44
    -- NOTA: data_documento è obbligatoria per USD/ZAR causa trigger fn_validate_data_documento
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_fornitore_id, transazione_causale_tipo_id, 
        transazione_tipo_movimento, transazione_importo, transazione_valuta_id, 
        transazione_data, transazione_data_documento, transazione_data_pagamento, transazione_numero_documento, 
        transazione_stato, transazione_causale, created_by
    ) VALUES (
        v_azienda_id, v_fornitore_test_id, v_causale_pg_id, 'USCITA', 150.00, v_valuta_usd_id, 
        '2026-02-08', '2026-02-08', '2026-02-08', 'USD-DOC-44', 
        'PAGATO', 'BONIFICO SALDO FATTURA USD-DOC-44', v_user_email
    );

    RAISE NOTICE 'Inserimento nuovi dati mockup completato per utente %', v_user_email;
END $$;
