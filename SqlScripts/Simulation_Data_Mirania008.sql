-- Script per simulazione dati contabili
-- Utente: mirania008@gmail.com (Azienda 6)
-- Target: mov_transazioni

BEGIN;

-- 0. Inserimento Tassi Cambio EUR -> EUR (ID 2 -> 2)
-- Disabilito trigger reverse per evitare errore duplicate key su stessa valuta
ALTER TABLE ana_tassi_cambio DISABLE TRIGGER trg_insert_rate_copy_reverse;

-- Gennaio
INSERT INTO ana_tassi_cambio (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a, tasso_valore, created_by)
VALUES ('2026-01-15', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a) DO NOTHING;

INSERT INTO ana_tassi_cambio (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a, tasso_valore, created_by)
VALUES ('2026-01-20', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a) DO NOTHING;

-- Febbraio
INSERT INTO ana_tassi_cambio (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a, tasso_valore, created_by)
VALUES ('2026-02-10', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a) DO NOTHING;

-- Marzo
INSERT INTO ana_tassi_cambio (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a, tasso_valore, created_by)
VALUES ('2026-03-05', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a) DO NOTHING;

-- Aprile
INSERT INTO ana_tassi_cambio (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a, tasso_valore, created_by)
VALUES ('2026-04-12', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_coppia_data, tasso_valuta_da, tasso_valuta_a) DO NOTHING;

ALTER TABLE ana_tassi_cambio ENABLE TRIGGER trg_insert_rate_copy_reverse;


-- 1. Gennaio 2026: Ciclo Passivo (IVA 10%) - Importo 1100 (1000 + 100)
-- Fornitore: ALBERGO DEL SOLE (ID 13)
-- Stato: PAGATO (con pagamento collegato)
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 13, 1, '2026-01-15', '2026-01-15', 'HOT-001', 
    'Soggiorno Autisti Gennaio', 1100.00, 2, 
    2, 'PAGATO', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- Pagamento collegato
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_data, transazione_data_documento, 
    transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 13, 3, '2026-01-20', '2026-01-20', 
    'Bonifico Albergo - Saldo HOT-001', -1100.00, 2, 
    NULL, 'PAGATO', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 2. Febbraio 2026: Ciclo Passivo Estero (IVA 0%) - Importo 500
-- Fornitore: FOREIGN SUPPLIER SARL (ID 12)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 12, 1, '2026-02-10', '2026-02-10', 'INV-EU-99', 
    'Servizi Web Cloud Hosting', 500.00, 2, 
    5, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 3. Marzo 2026: Ciclo Passivo (IVA 22%) - Importo 3050 (2500 + 550)
-- Fornitore: PISTONI E CILINDRI S.P.A. (ID 16)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 16, 1, '2026-03-05', '2026-03-05', 'FT-MAN-2026', 
    'Manutenzione Straordinaria Mezzi', 3050.00, 2, 
    1, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

-- 4. Aprile 2026: Ciclo Attivo (IVA 22%) - Importo 2440 (2000 + 440)
-- Cliente: JOLLY TRAVEL SAS (ID 1)
-- Stato: DA_PAGARE
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_controparte_id, transazione_causale_tipo_id, 
    transazione_data, transazione_data_documento, transazione_numero_documento,
    transazione_note, transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_stato, created_by
) VALUES (
    6, 1, 27, '2026-04-12', '2026-04-12', 'FT-2026-001', 
    'Noleggio Bus per Tour', 2440.00, 2, 
    1, 'DA_PAGARE', 'dcba3981-ff43-4ea7-a241-d50fb62a778e'
);

COMMIT;
