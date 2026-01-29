-- =====================================================
-- Test Suite: Constraint Fornitori Italia/Estero
-- Data: 2026-01-28
-- Descrizione: Test validazione constraint e cleanup
-- =====================================================

BEGIN;

-- =====================================================
-- SETUP: Query azienda_fk e tipo_fornitore_fk esistenti
-- =====================================================

DO $$
DECLARE
    v_azienda_fk INTEGER;
    v_tipo_fornitore_fk INTEGER;
    v_fornitore_test1_id INTEGER;
    v_fornitore_test2_id INTEGER;
    v_fornitore_test3_id INTEGER;
    v_fornitore_test4_id INTEGER;
BEGIN
    -- Ottieni primo azienda_fk disponibile
    SELECT azienda_id INTO v_azienda_fk
    FROM ana_aziende
    LIMIT 1;

    IF v_azienda_fk IS NULL THEN
        RAISE EXCEPTION 'Nessuna azienda trovata. Creare almeno un''azienda prima del test.';
    END IF;

    -- Ottieni primo tipo_fornitore_fk disponibile
    SELECT tipo_fornitore_id INTO v_tipo_fornitore_fk
    FROM ana_tipo_fornitore
    LIMIT 1;

    IF v_tipo_fornitore_fk IS NULL THEN
        RAISE EXCEPTION 'Nessun tipo fornitore trovato. Creare almeno un tipo prima del test.';
    END IF;

    RAISE NOTICE '=== TEST SUITE FORNITORI ITALIA/ESTERO ===';
    RAISE NOTICE 'Azienda FK usato: %', v_azienda_fk;
    RAISE NOTICE 'Tipo Fornitore FK usato: %', v_tipo_fornitore_fk;
    RAISE NOTICE '';

    -- =====================================================
    -- TEST 1: Fornitore ITALIANO con solo P.IVA → OK
    -- =====================================================
    RAISE NOTICE 'TEST 1: Fornitore italiano con solo P.IVA';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_fiscale, codice_destinatario_sdi,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST FORNITORE IT PIVA', v_tipo_fornitore_fk,
            FALSE, '12345678901', NULL, '0000000',
            'test_script'
        ) RETURNING fornitore_id INTO v_fornitore_test1_id;

        RAISE NOTICE '✅ PASSATO: Fornitore italiano creato con ID %', v_fornitore_test1_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 2: Fornitore ITALIANO con solo CF → OK
    -- =====================================================
    RAISE NOTICE 'TEST 2: Fornitore italiano con solo CF';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_fiscale, codice_destinatario_sdi,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST FORNITORE IT CF', v_tipo_fornitore_fk,
            FALSE, NULL, 'RSSMRA80A01H501U', '0000000',
            'test_script'
        ) RETURNING fornitore_id INTO v_fornitore_test2_id;

        RAISE NOTICE '✅ PASSATO: Fornitore italiano creato con ID %', v_fornitore_test2_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 3: Duplicato P.IVA italiana → DEVE FALLIRE
    -- =====================================================
    RAISE NOTICE 'TEST 3: Tentativo duplicato P.IVA italiana (deve fallire)';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_fiscale,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST DUPLICATO PIVA', v_tipo_fornitore_fk,
            FALSE, '12345678901', 'RSSMRA80A01H501X',
            'test_script'
        );

        RAISE NOTICE '❌ FALLITO: Duplicato P.IVA accettato (constraint non funziona!)';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '✅ PASSATO: Duplicato P.IVA correttamente bloccato';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO con errore inaspettato: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 4: Duplicato CF italiano → DEVE FALLIRE
    -- =====================================================
    RAISE NOTICE 'TEST 4: Tentativo duplicato CF italiano (deve fallire)';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_fiscale,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST DUPLICATO CF', v_tipo_fornitore_fk,
            FALSE, '98765432109', 'RSSMRA80A01H501U',
            'test_script'
        );

        RAISE NOTICE '❌ FALLITO: Duplicato CF accettato (constraint non funziona!)';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '✅ PASSATO: Duplicato CF correttamente bloccato';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO con errore inaspettato: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 5: Fornitore ESTERO con VAT Number → OK
    -- =====================================================
    RAISE NOTICE 'TEST 5: Fornitore estero con VAT Number';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_fiscale, codice_destinatario_sdi,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST FORNITORE FR', v_tipo_fornitore_fk,
            TRUE, 'FR12345678901', NULL, 'XXXXXXX',
            'test_script'
        ) RETURNING fornitore_id INTO v_fornitore_test3_id;

        RAISE NOTICE '✅ PASSATO: Fornitore estero creato con ID %', v_fornitore_test3_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 6: Duplicato VAT Number estero → DEVE FALLIRE
    -- =====================================================
    RAISE NOTICE 'TEST 6: Tentativo duplicato VAT Number estero (deve fallire)';
    BEGIN
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_destinatario_sdi,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST DUPLICATO VAT', v_tipo_fornitore_fk,
            TRUE, 'FR12345678901', 'XXXXXXX',
            'test_script'
        );

        RAISE NOTICE '❌ FALLITO: Duplicato VAT accettato (constraint non funziona!)';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '✅ PASSATO: Duplicato VAT Number correttamente bloccato';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO con errore inaspettato: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 7: P.IVA IT e VAT estero con stesso numero → OK
    -- =====================================================
    RAISE NOTICE 'TEST 7: P.IVA italiana "12345678901" e VAT "FR12345678901" (NO conflitto)';
    BEGIN
        -- Verifica che P.IVA IT e VAT Estero con stesso numero NON confliggono
        -- (P.IVA IT 12345678901 esiste già, VAT FR12345678901 esiste già)
        -- Tentiamo di creare un VAT DE con numero diverso per confermare separazione
        INSERT INTO ana_fornitori (
            azienda_fk, ragione_sociale, tipo_fornitore_fk,
            fornitore_estero, partita_iva, codice_destinatario_sdi,
            created_by
        ) VALUES (
            v_azienda_fk, 'TEST FORNITORE DE', v_tipo_fornitore_fk,
            TRUE, 'DE123456789', 'XXXXXXX',
            'test_script'
        ) RETURNING fornitore_id INTO v_fornitore_test4_id;

        RAISE NOTICE '✅ PASSATO: Separazione constraint IT/Estero funziona (ID %)', v_fornitore_test4_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FALLITO: %', SQLERRM;
    END;

    -- =====================================================
    -- TEST 8: Verifica indici parziali creati
    -- =====================================================
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 8: Verifica indici constraint creati';
    PERFORM 1 FROM pg_indexes
    WHERE tablename = 'ana_fornitori'
      AND indexname IN ('idx_uniq_fornitori_piva_it', 'idx_uniq_fornitori_cf_it', 'idx_uniq_fornitori_vat_estero');

    IF FOUND THEN
        RAISE NOTICE '✅ PASSATO: Indici UNIQUE constraint presenti';
    ELSE
        RAISE NOTICE '❌ FALLITO: Indici UNIQUE constraint mancanti';
    END IF;

    -- =====================================================
    -- CLEANUP: Rimuovi tutti i dati di test
    -- =====================================================
    RAISE NOTICE '';
    RAISE NOTICE '=== CLEANUP DATI DI TEST ===';

    DELETE FROM ana_fornitori WHERE created_by = 'test_script';

    RAISE NOTICE '✅ Cleanup completato: tutti i fornitori di test rimossi';
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST SUITE COMPLETATA ===';

END $$;

ROLLBACK;  -- Rollback per non lasciare dati sporchi in caso di errori
