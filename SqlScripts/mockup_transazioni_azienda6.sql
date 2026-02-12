-- Inserimento Valuta Lek Albanese
INSERT INTO ana_valute (valuta_codice_iso, valuta_descrizione, valuta_simbolo, valuta_is_base, valuta_attiva, valuta_decimali, created_by)
SELECT 'ALL', 'Lek Albanese', 'Lek', false, true, 2, 'mirania008@gmail.com'
WHERE NOT EXISTS (SELECT 1 FROM ana_valute WHERE valuta_codice_iso = 'ALL');

-- Inserimento Causale FA - Compensazione Credito per Azienda 6
INSERT INTO ana_tipi_causali (azienda_fk, causale_codice, causale_descrizione, causale_segno, is_active, created_by)
SELECT 6, 'FA', 'FA - Compensazione Credito', -1, true, 'mirania008@gmail.com'
WHERE NOT EXISTS (SELECT 1 FROM ana_tipi_causali WHERE azienda_fk = 6 AND causale_codice = 'FA');

-- Inserimento Movimenti Mockup
DO $$
DECLARE
    v_user_email VARCHAR := 'mirania008@gmail.com';
    v_azienda_id INT := 6;
    v_viaggio_id INT := 862;
    v_data_viaggio_id INT := 1824;
    v_valuta_eur INT;
    v_valuta_chf INT;
    v_valuta_all INT;
    v_causale_ft INT;
    v_causale_fa INT;
BEGIN
    -- Recupero IDs
    SELECT valuta_id INTO v_valuta_eur FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    SELECT valuta_id INTO v_valuta_chf FROM ana_valute WHERE valuta_codice_iso = 'CHF';
    SELECT valuta_id INTO v_valuta_all FROM ana_valute WHERE valuta_codice_iso = 'ALL';
    
    SELECT causale_id INTO v_causale_ft FROM ana_tipi_causali WHERE azienda_fk = v_azienda_id AND causale_codice = 'FT';
    SELECT causale_id INTO v_causale_fa FROM ana_tipi_causali WHERE azienda_fk = v_azienda_id AND causale_codice = 'FA';

    -- 1. JOLLY TRAVEL SAS (Fornitore ID 1) - Fatture Attive
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_viaggio_id, transazione_data_viaggio_id, 
        transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento,
        transazione_importo, transazione_valuta_id, transazione_data_documento, transazione_data,
        transazione_numero_documento, transazione_stato, transazione_causale, created_by
    ) VALUES 
    (v_azienda_id, v_viaggio_id, v_data_viaggio_id, 1, v_causale_fa, 'ENTRATA', 1500.00, v_valuta_eur, '2026-02-12', '2026-02-12', 'A/2026/001', 'PAGATO', 'Mockup: Fattura Attiva Jolly', v_user_email),
    (v_azienda_id, v_viaggio_id, v_data_viaggio_id, 1, v_causale_fa, 'ENTRATA', 2400.00, v_valuta_eur, '2026-02-12', '2026-02-12', 'A/2026/002', 'DA_PAGARE', 'Mockup: Fattura Attiva Jolly', v_user_email);

    -- 2. ALBERGO DEL SOLE (Fornitore ID 13) - Fattura Passiva
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_viaggio_id, transazione_data_viaggio_id, 
        transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento,
        transazione_importo, transazione_valuta_id, transazione_data_documento, transazione_data,
        transazione_numero_documento, transazione_stato, transazione_causale, created_by
    ) VALUES 
    (v_azienda_id, v_viaggio_id, v_data_viaggio_id, 13, v_causale_ft, 'USCITA', 850.00, v_valuta_eur, '2026-02-12', '2026-02-12', 'P/2026/123', 'DA_PAGARE', 'Mockup: Fattura Albergo Sole', v_user_email);

    -- 3. FOREIGN SUPPLIER SARL (Fornitore ID 12) - Fattura Passiva CHF
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_viaggio_id, transazione_data_viaggio_id, 
        transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento,
        transazione_importo, transazione_valuta_id, transazione_data_documento, transazione_data,
        transazione_numero_documento, transazione_stato, transazione_causale, created_by
    ) VALUES 
    (v_azienda_id, v_viaggio_id, v_data_viaggio_id, 12, v_causale_ft, 'USCITA', 1250.00, v_valuta_chf, '2026-02-12', '2026-02-12', 'CH/2026/99', 'DA_PAGARE', 'Mockup: Fattura Fornitore Svizzero', v_user_email);

    -- 4. TIRANA TYRES & AUTO SH.P.K. (Fornitore ID 14) - Fattura Passiva ALL
    INSERT INTO mov_transazioni (
        transazione_azienda_id, transazione_viaggio_id, transazione_data_viaggio_id, 
        transazione_fornitore_id, transazione_causale_tipo_id, transazione_tipo_movimento,
        transazione_importo, transazione_valuta_id, transazione_data_documento, transazione_data,
        transazione_numero_documento, transazione_stato, transazione_causale, created_by
    ) VALUES 
    (v_azienda_id, v_viaggio_id, v_data_viaggio_id, 14, v_causale_ft, 'USCITA', 45000.00, v_valuta_all, '2026-02-12', '2026-02-12', 'AL/2026/01', 'PAGATO', 'Mockup: Fattura Fornitore Albanese', v_user_email);

END $$;
