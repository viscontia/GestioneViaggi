-- =============================================
-- Script di Test: Integrazione Tassi di Cambio nelle Transazioni
-- Data Creazione: 2026-02-08
-- Autore: Antigravity
-- Descrizione: Script per testare la nuova integrazione dei tassi di cambio
-- =============================================

-- =============================================
-- TEST 1: Verifica che la tabella abbia i nuovi campi
-- =============================================
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'mov_transazioni'
  AND column_name IN ('transazione_tasso_cambio_applicato', 'transazione_tasso_fonte', 'transazione_tasso_data_validita')
ORDER BY column_name;

-- =============================================
-- TEST 2: Verifica valute disponibili
-- =============================================
SELECT valuta_id, valuta_codice_iso, valuta_is_base
FROM ana_valute
WHERE valuta_attiva = TRUE
ORDER BY valuta_codice_iso;

-- =============================================
-- TEST 3: Verifica tassi di cambio disponibili
-- =============================================
SELECT
    t.tasso_id,
    v1.valuta_codice_iso as valuta_da,
    v2.valuta_codice_iso as valuta_a,
    t.tasso_data_validita,
    t.tasso_valore,
    t.tasso_fonte
FROM ana_tassi_cambio t
JOIN ana_valute v1 ON t.tasso_valuta_da_fk = v1.valuta_id
JOIN ana_valute v2 ON t.tasso_valuta_a_fk = v2.valuta_id
ORDER BY t.tasso_data_validita DESC, v1.valuta_codice_iso
LIMIT 10;

-- =============================================
-- TEST 4: Inserimento tasso di cambio di test (USD -> EUR)
-- Questo simula ciò che fa l'API Frankfurter
-- =============================================
DO $$
DECLARE
    v_eur_id INTEGER;
    v_usd_id INTEGER;
BEGIN
    -- Recupera ID valute
    SELECT valuta_id INTO v_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    SELECT valuta_id INTO v_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';

    IF v_eur_id IS NOT NULL AND v_usd_id IS NOT NULL THEN
        -- Inserisce tasso di test per oggi
        INSERT INTO ana_tassi_cambio (
            tasso_valuta_da_fk,
            tasso_valuta_a_fk,
            tasso_data_validita,
            tasso_valore,
            tasso_fonte,
            tasso_note,
            created_by
        ) VALUES (
            v_eur_id,
            v_usd_id,
            CURRENT_DATE,
            1.08,  -- 1 EUR = 1.08 USD (esempio)
            'TEST_MANUAL',
            'Tasso di test per verificare funzionalità',
            'SYSTEM'
        )
        ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita)
        DO UPDATE SET
            tasso_valore = EXCLUDED.tasso_valore,
            tasso_fonte = EXCLUDED.tasso_fonte,
            tasso_note = EXCLUDED.tasso_note;

        RAISE NOTICE 'Tasso di test inserito: 1 EUR = 1.08 USD per data %', CURRENT_DATE;
    ELSE
        RAISE NOTICE 'Valute EUR o USD non trovate';
    END IF;
END $$;

-- =============================================
-- TEST 5: Tentativo di inserimento transazione USD SENZA data_documento
-- DEVE FALLIRE con errore esplicito
-- =============================================
DO $$
DECLARE
    v_azienda_id INTEGER;
    v_fornitore_id INTEGER;
    v_usd_id INTEGER;
BEGIN
    -- Recupera ID necessari
    SELECT azienda_id INTO v_azienda_id FROM ana_aziende LIMIT 1;
    SELECT fornitore_id INTO v_fornitore_id FROM ana_fornitori LIMIT 1;
    SELECT valuta_id INTO v_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';

    IF v_azienda_id IS NOT NULL AND v_fornitore_id IS NOT NULL AND v_usd_id IS NOT NULL THEN
        BEGIN
            INSERT INTO mov_transazioni (
                transazione_azienda_id,
                transazione_fornitore_id,
                transazione_tipo_movimento,
                transazione_importo,
                transazione_valuta_id,
                transazione_data,
                transazione_stato,
                transazione_causale,
                transazione_data_documento,  -- NULL!
                created_by
            ) VALUES (
                v_azienda_id,
                v_fornitore_id,
                'USCITA',
                1000.00,
                v_usd_id,
                CURRENT_DATE,
                'DA_PAGARE',
                'TEST TRANSAZIONE USD SENZA DATA DOCUMENTO',
                NULL,  -- Questo dovrebbe causare un errore!
                'SYSTEM'
            );

            RAISE NOTICE 'ERRORE: L''inserimento avrebbe dovuto fallire!';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'OK - Inserimento bloccato come previsto: %', SQLERRM;
        END;
    END IF;
END $$;

-- =============================================
-- TEST 6: Inserimento transazione USD CON data_documento
-- DEVE RIUSCIRE e calcolare automaticamente importo EUR
-- =============================================
DO $$
DECLARE
    v_azienda_id INTEGER;
    v_fornitore_id INTEGER;
    v_usd_id INTEGER;
    v_transazione_id INTEGER;
BEGIN
    -- Recupera ID necessari
    SELECT azienda_id INTO v_azienda_id FROM ana_aziende LIMIT 1;
    SELECT fornitore_id INTO v_fornitore_id FROM ana_fornitori LIMIT 1;
    SELECT valuta_id INTO v_usd_id FROM ana_valute WHERE valuta_codice_iso = 'USD';

    IF v_azienda_id IS NOT NULL AND v_fornitore_id IS NOT NULL AND v_usd_id IS NOT NULL THEN
        INSERT INTO mov_transazioni (
            transazione_azienda_id,
            transazione_fornitore_id,
            transazione_tipo_movimento,
            transazione_importo,
            transazione_valuta_id,
            transazione_data,
            transazione_data_documento,  -- PRESENTE!
            transazione_numero_documento, -- PRESENTE (richiesto da constraint)
            transazione_stato,
            transazione_causale,
            created_by
        ) VALUES (
            v_azienda_id,
            v_fornitore_id,
            'USCITA',
            1000.00,
            v_usd_id,
            CURRENT_DATE,
            CURRENT_DATE,  -- Data documento
            'TEST-USD-001', -- Numero documento
            'DA_PAGARE',
            'TEST TRANSAZIONE USD CON DATA DOCUMENTO',
            'SYSTEM'
        )
        RETURNING transazione_id INTO v_transazione_id;

        -- Verifica risultato
        RAISE NOTICE 'Transazione inserita con ID: %', v_transazione_id;

        -- Mostra i dettagli della transazione
        PERFORM * FROM (
            SELECT
                transazione_id,
                transazione_importo as importo_originale,
                valuta_codice_iso as valuta,
                transazione_importo_eur as importo_eur_calcolato,
                transazione_tasso_cambio_applicato as tasso_applicato,
                transazione_tasso_fonte as fonte_tasso,
                transazione_tasso_data_validita as data_validita_tasso
            FROM mov_transazioni t
            JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
            WHERE transazione_id = v_transazione_id
        ) AS risultato;

    END IF;
END $$;

-- =============================================
-- TEST 7: Visualizza tutte le transazioni di test
-- =============================================
SELECT
    t.transazione_id,
    t.transazione_data,
    t.transazione_data_documento,
    t.transazione_causale,
    t.transazione_importo,
    v.valuta_codice_iso,
    t.transazione_importo_eur,
    t.transazione_tasso_cambio_applicato,
    t.transazione_tasso_fonte,
    t.transazione_tasso_data_validita
FROM mov_transazioni t
JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
WHERE t.transazione_causale LIKE 'TEST%'
ORDER BY t.transazione_id DESC;

-- =============================================
-- CLEANUP: Elimina le transazioni di test
-- =============================================
-- DELETE FROM mov_transazioni WHERE transazione_causale LIKE 'TEST%';
-- RAISE NOTICE 'Transazioni di test eliminate';
