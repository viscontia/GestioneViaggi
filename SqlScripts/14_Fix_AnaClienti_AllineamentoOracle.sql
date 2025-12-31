-- =====================================================
-- Script: 14_Fix_AnaClienti_AllineamentoOracle.sql
-- Descrizione: Allineamento tabella ana_clienti a struttura Oracle
-- Data: 2025-12-26
-- =====================================================

-- STRATEGIA APPLICATA:
-- 1. Riduzione lunghezze VARCHAR per allineamento a Oracle
-- 2. Applicazione NOT NULL solo sui campi senza record NULL:
--    - cliente_sesso (0 NULL)
--    - cliente_comune_residenza_fk (0 NULL)
--    - cliente_comune_nascita_fk (0 NULL)
-- 3. NON applicato NOT NULL su campi con record NULL (gestione lato applicazione):
--    - cliente_indirizzo_residenza (59 NULL)
--    - cliente_data_nascita (33 NULL)
--    - cliente_codicefiscale (297 NULL)

BEGIN;

-- =====================================================
-- FASE 1: RIDUZIONE LUNGHEZZA VARCHAR
-- =====================================================

-- Verifica preventiva: identificare record che superano le nuove lunghezze
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM ana_clienti
    WHERE LENGTH(cliente_cognome) > 50
       OR LENGTH(cliente_nome) > 50
       OR LENGTH(cliente_indirizzo_residenza) > 100
       OR LENGTH(cliente_preftelint) > 5
       OR LENGTH(cliente_telefono) > 15;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'Trovati % record con campi che superano le lunghezze Oracle. Controllare prima di procedere.', v_count;
    END IF;

    RAISE NOTICE 'Verifica lunghezze: OK - Nessun record supera i limiti Oracle';
END $$;

-- Riduzione lunghezze VARCHAR per allineamento a Oracle
ALTER TABLE ana_clienti ALTER COLUMN cliente_cognome TYPE VARCHAR(50);
ALTER TABLE ana_clienti ALTER COLUMN cliente_nome TYPE VARCHAR(50);
ALTER TABLE ana_clienti ALTER COLUMN cliente_indirizzo_residenza TYPE VARCHAR(100);
ALTER TABLE ana_clienti ALTER COLUMN cliente_preftelint TYPE VARCHAR(5);
ALTER TABLE ana_clienti ALTER COLUMN cliente_telefono TYPE VARCHAR(15);

DO $$
BEGIN
    RAISE NOTICE 'Lunghezze VARCHAR ridotte con successo';
END $$;

-- =====================================================
-- FASE 2: GESTIONE VALORI NULL
-- =====================================================

-- Report record con valori NULL che devono diventare NOT NULL
DO $$
DECLARE
    v_sesso_null INTEGER;
    v_comune_res_null INTEGER;
    v_indirizzo_null INTEGER;
    v_comune_nasc_null INTEGER;
    v_data_nasc_null INTEGER;
    v_cf_null INTEGER;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE cliente_sesso IS NULL),
        COUNT(*) FILTER (WHERE cliente_comune_residenza_fk IS NULL),
        COUNT(*) FILTER (WHERE cliente_indirizzo_residenza IS NULL),
        COUNT(*) FILTER (WHERE cliente_comune_nascita_fk IS NULL),
        COUNT(*) FILTER (WHERE cliente_data_nascita IS NULL),
        COUNT(*) FILTER (WHERE cliente_codicefiscale IS NULL)
    INTO v_sesso_null, v_comune_res_null, v_indirizzo_null, v_comune_nasc_null, v_data_nasc_null, v_cf_null
    FROM ana_clienti;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'REPORT VALORI NULL DA GESTIRE:';
    RAISE NOTICE 'cliente_sesso: % record NULL', v_sesso_null;
    RAISE NOTICE 'cliente_comune_residenza_fk: % record NULL', v_comune_res_null;
    RAISE NOTICE 'cliente_indirizzo_residenza: % record NULL', v_indirizzo_null;
    RAISE NOTICE 'cliente_comune_nascita_fk: % record NULL', v_comune_nasc_null;
    RAISE NOTICE 'cliente_data_nascita: % record NULL', v_data_nasc_null;
    RAISE NOTICE 'cliente_codicefiscale: % record NULL', v_cf_null;
    RAISE NOTICE '==========================================';
END $$;

-- =====================================================
-- FASE 3: APPLICAZIONE CONSTRAINT NOT NULL
-- =====================================================

-- Applica NOT NULL solo sui campi senza record NULL
ALTER TABLE ana_clienti ALTER COLUMN cliente_sesso SET NOT NULL;
ALTER TABLE ana_clienti ALTER COLUMN cliente_comune_residenza_fk SET NOT NULL;
ALTER TABLE ana_clienti ALTER COLUMN cliente_comune_nascita_fk SET NOT NULL;

-- NON applicato NOT NULL su:
-- - cliente_indirizzo_residenza (59 record NULL - validazione lato applicazione)
-- - cliente_data_nascita (33 record NULL - validazione lato applicazione)
-- - cliente_codicefiscale (297 record NULL - validazione lato applicazione)

DO $$
BEGIN
    RAISE NOTICE 'Constraint NOT NULL applicati su campi senza record NULL';
    RAISE NOTICE 'Campi con validazione lato applicazione: indirizzo_residenza, data_nascita, codicefiscale';
END $$;

-- =====================================================
-- FASE 4: VERIFICA FINALE
-- =====================================================

-- Visualizza la struttura finale della tabella
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'STRUTTURA FINALE TABELLA ana_clienti:';
    RAISE NOTICE '==========================================';

    FOR rec IN
        SELECT column_name, data_type, character_maximum_length, is_nullable
        FROM information_schema.columns
        WHERE table_name = 'ana_clienti' AND table_schema = 'public'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '% | % | % | %',
            RPAD(rec.column_name, 35),
            RPAD(COALESCE(rec.data_type, 'N/A'), 25),
            COALESCE(rec.character_maximum_length::TEXT, 'N/A'),
            rec.is_nullable;
    END LOOP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Script completato con successo!';
    RAISE NOTICE '';
    RAISE NOTICE 'RIEPILOGO MODIFICHE:';
    RAISE NOTICE '- Lunghezze VARCHAR ridotte (cognome, nome, indirizzo, preftelint, telefono)';
    RAISE NOTICE '- NOT NULL applicato su: sesso, comune_residenza_fk, comune_nascita_fk';
    RAISE NOTICE '- NOT NULL NON applicato su: indirizzo_residenza, data_nascita, codicefiscale';
    RAISE NOTICE '  (validazione gestita lato applicazione C#)';
    RAISE NOTICE '==========================================';
END $$;

-- ROLLBACK; -- Decommentare per testare senza applicare modifiche
COMMIT;
