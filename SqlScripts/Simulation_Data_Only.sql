-- Script per inserire SOLO le transazioni
-- Utente: mirania008@gmail.com (Azienda 6)
-- Target: mov_transazioni

BEGIN;

-- 1. Gennaio 2026: Ciclo Passivo (IVA 10%) - Importo 1100 (1000 + 100)
-- Fornitore: ALBERGO DEL SOLE (ID 13)
-- Stato: PAGATO (con pagamento collegato)
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_tipo_movimento,
    transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_pagamento,
    transazione_causale, transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 13, 1, 
    'USCITA',
    '2026-01-15', '2026-01-15', 'HOT-001', '2026-01-20',
    'Soggiorno Autisti Gennaio', 'Soggiorno Autisti Gennaio', 1100.00, 2, 
    2, 'PAGATO', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- Pagamento collegato
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_tipo_movimento,
    transazione_data, transazione_data_documento, transazione_numero_documento, transazione_data_pagamento,
    transazione_causale, transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 13, 3, 
    'USCITA',
    '2026-01-20', '2026-01-20', 'BONIFICO-2026-01', '2026-01-20',
    'Bonifico Albergo - Saldo HOT-001', 'Bonifico Albergo - Saldo HOT-001', -1100.00, 2, 
    5, 'PAGATO', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 2. Febbraio 2026: Ciclo Passivo Estero (IVA 0%) - Importo 500
-- Fornitore: FOREIGN SUPPLIER SARL (ID 12)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_tipo_movimento,
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_causale, transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 12, 1, 
    'USCITA',
    '2026-02-10', '2026-02-10', 'INV-EU-99', 
    'Servizi Web Cloud Hosting', 'Servizi Web Cloud Hosting', 500.00, 2, 
    5, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 3. Marzo 2026: Ciclo Passivo (IVA 22%) - Importo 3050 (2500 + 550)
-- Fornitore: PISTONI E CILINDRI S.P.A. (ID 16)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_tipo_movimento,
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_causale, transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 16, 1, 
    'USCITA',
    '2026-03-05', '2026-03-05', 'FT-MAN-2026', 
    'Manutenzione Straordinaria Mezzi', 'Manutenzione Straordinaria Mezzi', 3050.00, 2, 
    1, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 4. Aprile 2026: Ciclo Attivo (IVA 22%) - Importo 2440 (2000 + 440)
-- Cliente: JOLLY TRAVEL SAS (ID 1)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_tipo_movimento,
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_causale, transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 1, 27, 
    'ENTRATA',
    '2026-04-12', '2026-04-12', 'FT-2026-001', 
    'Noleggio Bus per Tour', 'Noleggio Bus per Tour', 2440.00, 2, 
    1, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

COMMIT;
