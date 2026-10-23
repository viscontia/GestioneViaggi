-- ============================================================================
-- Test dello script 702. Transazione annullata.
-- Prima dello script deve FALLIRE (le impronte vecchie restano).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_ed2  integer;
    v_edx  integer;
    v_azx  integer;
    v_imp  constant text := repeat('a', 64);
BEGIN
    SELECT data_viaggio_id INTO v_ed2 FROM ana_date_viaggi WHERE azienda_id = 2 ORDER BY 1 LIMIT 1;
    SELECT azienda_id, data_viaggio_id INTO v_azx, v_edx FROM ana_date_viaggi WHERE azienda_id <> 2 ORDER BY 2 LIMIT 1;
    ASSERT v_ed2 IS NOT NULL AND v_edx IS NOT NULL, 'servono edizioni di due aziende';
    DELETE FROM web_pdf_richieste;

    -- impronte di 11 mesi (restano) e di 13 mesi (via), di due aziende diverse
    INSERT INTO web_pdf_richieste (azienda_id, data_viaggio_id, lingua, impronta, richiesta_il) VALUES
        (2,     v_ed2, 'IT', repeat('1', 64), now() - interval '11 months'),
        (2,     v_ed2, 'IT', repeat('2', 64), now() - interval '13 months'),
        (v_azx, v_edx, 'DE', repeat('3', 64), now() - interval '11 months'),
        (v_azx, v_edx, 'DE', repeat('4', 64), now() - interval '13 months');

    -- un conteggio qualunque fa pulizia: le impronte oltre i 12 mesi spariscono, di TUTTE le aziende
    ASSERT fn_web_pdf_richiesta(2, v_ed2, 'IT', v_imp), 'il conteggio funziona come prima';
    ASSERT NOT EXISTS (SELECT 1 FROM web_pdf_richieste WHERE richiesta_il < now() - interval '12 months'), 'impronte oltre 12 mesi rimaste';
    ASSERT (SELECT count(*) FROM web_pdf_richieste WHERE richiesta_il < now() - interval '10 months') = 2, 'le impronte di 11 mesi restano (due)';
    ASSERT EXISTS (SELECT 1 FROM web_pdf_richieste WHERE azienda_id = v_azx AND impronta = repeat('3', 64)), 'l''altra azienda: resta la sua di 11 mesi';

    -- il resto non cambia: la stessa persona nella stessa ora non si conta due volte
    ASSERT NOT fn_web_pdf_richiesta(2, v_ed2, 'IT', v_imp), 'doppio conteggio nella stessa ora';

    -- permessi invariati: solo sito_statistiche (oltre al proprietario)
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_statistiche') THEN
        ASSERT has_function_privilege('sito_statistiche', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'), 'sito_statistiche conta';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'), 'anon non conta';
    END IF;

    RAISE NOTICE 'Test 702: OK';
END $$;
ROLLBACK;
