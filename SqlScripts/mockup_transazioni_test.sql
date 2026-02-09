-- CLEANUP PREVENTIVO (OPZIONALE)
-- DELETE FROM mov_transazioni WHERE created_by = 'mirania008@gmail.com';

INSERT INTO mov_transazioni (
    transazione_azienda_id, 
    transazione_fornitore_id, 
    transazione_tipo_movimento, 
    transazione_importo, 
    transazione_valuta_id, 
    transazione_data, 
    transazione_data_documento,
    transazione_numero_documento,
    transazione_data_scadenza,
    transazione_stato, 
    transazione_causale, 
    transazione_viaggio_id, 
    transazione_data_viaggio_id,
    created_by
) VALUES 
-- 1. JOLLY TRAVEL SAS, USCITA, EUR, PAGATO, CON VIAGGIO
(6, 1, 'USCITA', 1250.00, 2, '2026-02-01', '2026-02-01', 'FT/2026/001', '2026-02-28', 'PAGATO', 'Acconto Hotel Tirana', 862, 1824, 'mirania008@gmail.com'),

-- 2. JOLLY TRAVEL SAS, ENTRATA, EUR, DA_PAGARE, CON VIAGGIO
(6, 1, 'ENTRATA', 500.00, 2, '2026-02-05', '2026-02-05', 'NC/2026/012', '2026-03-05', 'DA_PAGARE', 'Rimborso penale cancellazione', 862, 1824, 'mirania008@gmail.com'),

-- 3. TEST FOREIGN SUPPLIER SARL, USCITA, ZAR, DA_PAGARE, SENZA VIAGGIO
(6, 12, 'USCITA', 4500.00, 10, '2026-02-07', '2026-02-07', 'Z-9988', '2026-03-07', 'DA_PAGARE', 'Dati mockup - Servizi locali Sudafrica', NULL, NULL, 'mirania008@gmail.com'),

-- 4. TEST FOREIGN SUPPLIER SARL, USCITA, USD, PAGATO, SENZA VIAGGIO
(6, 12, 'USCITA', 150.00, 3, '2026-02-08', '2026-02-08', 'USD-DOC-44', '2026-02-08', 'PAGATO', 'Spese di rappresentanza estero', NULL, NULL, 'mirania008@gmail.com'),

-- 5. PIPPO, ENTRATA, EUR, PAGATO, CON VIAGGIO (ALTRO)
(6, 13, 'ENTRATA', 300.00, 2, '2026-01-20', '2026-01-20', 'DOC-PIPPO-01', '2026-01-20', 'PAGATO', 'Vendita materiale promozionale', 201, 722, 'mirania008@gmail.com'),

-- 6. PIPPO, USCITA, EUR, DA_PAGARE, SCADUTA, SENZA VIAGGIO
(6, 13, 'USCITA', 75.50, 2, '2026-01-10', '2026-01-10', 'SCAD-01', '2026-01-25', 'DA_PAGARE', 'Fattura cancelleria (SCADUTA)', NULL, NULL, 'mirania008@gmail.com');
