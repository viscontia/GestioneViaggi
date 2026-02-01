-- =============================================
-- Script di Verifica Movimenti e Trigger
-- =============================================
DO $$
DECLARE
    v_fornitore_id INTEGER;
    v_usd_id INTEGER;
    v_eur_id INTEGER;
    v_azienda_id INTEGER;
BEGIN
    -- Setup dati minimi per il test
    SELECT valuta_id INTO v_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';
    SELECT valuta_id INTO v_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    SELECT azienda_id INTO v_azienda_id FROM ana_aziende LIMIT 1;
    -- Prendiamo un fornitore a caso
    SELECT fornitore_id INTO v_fornitore_id FROM ana_fornitori LIMIT 1;
    
    IF v_fornitore_id IS NULL THEN
        RAISE NOTICE 'Nessun fornitore trovato, impossibile eseguire test';
        RETURN;
    END IF;

    -- INSERIMENTO TEST: 100 USD in data 2026-01-29 
    -- Tasso atteso: 0.8351 => 83.51 EUR
    INSERT INTO mov_transazioni (
        transazione_azienda_id, 
        transazione_fornitore_id, 
        transazione_tipo_movimento, 
        transazione_importo, 
        transazione_valuta_id, 
        transazione_data, 
        transazione_causale
    ) VALUES (
        v_azienda_id,
        v_fornitore_id,
        'USCITA',
        100.00,
        v_usd_id,
        '2026-01-29',
        'TEST AUTO CALC USD'
    );
    
    -- INSERIMENTO TEST: 50 EUR (Dovrebbe restare 50)
    INSERT INTO mov_transazioni (
        transazione_azienda_id, 
        transazione_fornitore_id, 
        transazione_tipo_movimento, 
        transazione_importo, 
        transazione_valuta_id, 
        transazione_data, 
        transazione_causale
    ) VALUES (
        v_azienda_id,
        v_fornitore_id,
        'USCITA',
        50.00,
        v_eur_id,
        '2026-01-29',
        'TEST AUTO CALC EUR'
    );

END $$;

-- DISPLAY RESULTS
SELECT 
    transazione_importo as amount, 
    v.valuta_codice_iso as currency, 
    transazione_importo_eur as eur_calculated,
    CASE 
        WHEN v.valuta_codice_iso = 'EUR' AND transazione_importo = transazione_importo_eur THEN 'OK'
        WHEN v.valuta_codice_iso = 'USD' AND transazione_importo_eur > 0 THEN 'OK (Converted)'
        ELSE 'ERROR'
    END as status
FROM mov_transazioni t
JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
WHERE transazione_causale LIKE 'TEST AUTO CALC%';
