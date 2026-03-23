-- ============================================================
-- Test Script: Verifica messaggi di errore Foreign Key
-- ============================================================
-- Data: 2026-03-17
-- Descrizione: Script per testare i messaggi di errore migliorati
--              del DatabaseExceptionHelper
-- ============================================================

-- ============================================================
-- PREPARAZIONE: Backup dei dati attuali
-- ============================================================

BEGIN;

-- Salva l'azienda di test
CREATE TEMP TABLE backup_azienda_test AS
SELECT * FROM ana_aziende WHERE azienda_id = 1;

-- Salva il regime fiscale di test
CREATE TEMP TABLE backup_regime_test AS
SELECT * FROM ana_regimi_fiscali WHERE regime_id = 1;

COMMIT;

-- ============================================================
-- TEST 1: UPDATE con FK non valida (NUOVO MESSAGGIO)
-- ============================================================
-- Risultato Atteso:
-- "Il valore selezionato per 'Regime Fiscale' non è valido o non esiste più nel sistema."
--
-- Risultato Precedente (ERRATO):
-- "Non è possibile eliminare l'ana_aziende perché è utilizzato in altre parti del sistema"
-- ============================================================

-- Prova 1a: UPDATE con regime_fiscale_fk non esistente
DO $$
BEGIN
    RAISE NOTICE '=== TEST 1a: UPDATE ana_aziende con regime_fiscale_fk=999 (non esistente) ===';

    BEGIN
        UPDATE ana_aziende
        SET regime_fiscale_fk = 999
        WHERE azienda_id = 1;

        RAISE NOTICE 'ERRORE: L''UPDATE non dovrebbe riuscire!';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: Foreign key violation catturato correttamente';
        RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Detail: %', PG_EXCEPTION_DETAIL();
    END;
END $$;

-- Prova 1b: UPDATE con rea_provincia_fk non esistente
DO $$
BEGIN
    RAISE NOTICE '=== TEST 1b: UPDATE ana_aziende con rea_provincia_fk=999 (non esistente) ===';

    BEGIN
        UPDATE ana_aziende
        SET rea_provincia_fk = 999
        WHERE azienda_id = 1;

        RAISE NOTICE 'ERRORE: L''UPDATE non dovrebbe riuscire!';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: Foreign key violation catturato correttamente';
        RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Detail: %', PG_EXCEPTION_DETAIL();
    END;
END $$;

-- ============================================================
-- TEST 2: DELETE di entità usata altrove (MESSAGGIO INVARIATO)
-- ============================================================
-- Risultato Atteso (INVARIATO):
-- "Non è possibile eliminare il regime fiscale perché è utilizzato in altre parti del sistema (es. azienda)."
-- ============================================================

DO $$
DECLARE
    regime_id_usato INTEGER;
BEGIN
    RAISE NOTICE '=== TEST 2: DELETE di regime fiscale usato da aziende ===';

    -- Trova un regime fiscale usato da almeno un'azienda
    SELECT regime_fiscale_fk INTO regime_id_usato
    FROM ana_aziende
    LIMIT 1;

    RAISE NOTICE 'Tentativo di eliminare regime_id: %', regime_id_usato;

    BEGIN
        DELETE FROM ana_regimi_fiscali WHERE regime_id = regime_id_usato;

        RAISE NOTICE 'ERRORE: Il DELETE non dovrebbe riuscire!';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: Foreign key violation catturato correttamente';
        RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Detail: %', PG_EXCEPTION_DETAIL();
    END;
END $$;

-- ============================================================
-- TEST 3: INSERT con FK non valida
-- ============================================================
-- Risultato Atteso:
-- "Il valore selezionato per 'Regime Fiscale' non è valido o non esiste più nel sistema."
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '=== TEST 3: INSERT ana_aziende con regime_fiscale_fk=999 (non esistente) ===';

    BEGIN
        INSERT INTO ana_aziende (
            ragione_sociale,
            forma_giuridica,
            partita_iva,
            codice_destinatario_sdi,
            telefono_principale,
            regime_fiscale_fk,
            attivo
        ) VALUES (
            'Test Azienda SRL',
            'SRL',
            '12345678901',
            '0000000',
            '+39 02 12345678',
            999,  -- Non esiste!
            TRUE
        );

        RAISE NOTICE 'ERRORE: L''INSERT non dovrebbe riuscire!';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: Foreign key violation catturato correttamente';
        RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
        RAISE NOTICE 'Message: %', SQLERRM;
        RAISE NOTICE 'Detail: %', PG_EXCEPTION_DETAIL();
    END;
END $$;

-- ============================================================
-- ANALISI DEI MESSAGGI PostgreSQL
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'ANALISI: Differenze nei messaggi PostgreSQL';
    RAISE NOTICE '=============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'DELETE che fallisce per FK (elemento usato altrove):';
    RAISE NOTICE '  Detail: "Key (regime_id)=(1) is still referenced from table \"ana_aziende\"."';
    RAISE NOTICE '  Message: "update or delete on table \"ana_regimi_fiscali\" violates..."';
    RAISE NOTICE '  PAROLA CHIAVE: "is still referenced from table"';
    RAISE NOTICE '';
    RAISE NOTICE 'INSERT/UPDATE che fallisce per FK (riferimento non valido):';
    RAISE NOTICE '  Detail: "Key (regime_fiscale_fk)=(999) is not present in table \"ana_regimi_fiscali\"."';
    RAISE NOTICE '  Message: "insert or update on table \"ana_aziende\" violates..."';
    RAISE NOTICE '  PAROLA CHIAVE: "is not present in table"';
    RAISE NOTICE '';
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'FIX IMPLEMENTATA:';
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'Il DatabaseExceptionHelper usa la presenza di';
    RAISE NOTICE '"is still referenced from table" nel Detail per distinguere';
    RAISE NOTICE 'tra DELETE (elemento usato) e INSERT/UPDATE (riferimento invalido)';
    RAISE NOTICE '';
END $$;

-- ============================================================
-- CLEANUP
-- ============================================================

-- Ripristina eventuali modifiche (non necessario se tutto è andato bene)
-- DROP TABLE IF EXISTS backup_azienda_test;
-- DROP TABLE IF EXISTS backup_regime_test;

-- ============================================================
-- VERIFICA CONSTRAINT ESISTENTI
-- ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'ana_aziende'
ORDER BY tc.table_name, tc.constraint_name;

-- Output atteso:
-- table_name  | constraint_name                          | column_name        | foreign_table_name   | foreign_column_name
-- ------------|------------------------------------------|--------------------|----------------------|--------------------
-- ana_aziende | ana_aziende_rea_provincia_fk_fkey        | rea_provincia_fk   | ana_geo_province     | provincia_id
-- ana_aziende | ana_aziende_regime_fiscale_fk_fkey       | regime_fiscale_fk  | ana_regimi_fiscali   | regime_id

-- ============================================================
-- FINE TEST
-- ============================================================
