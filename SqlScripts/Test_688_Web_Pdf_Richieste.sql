-- ============================================================================
-- Test dello script 688. Transazione annullata: i conteggi di prova spariscono.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_ed    integer;
    v_altra integer;
    imp1 constant varchar := repeat('c3', 32);
    imp2 constant varchar := repeat('d4', 32);
BEGIN
    SELECT data_viaggio_id INTO v_ed FROM ana_date_viaggi WHERE azienda_id = 2 ORDER BY data_viaggio_id DESC LIMIT 1;
    SELECT data_viaggio_id INTO v_altra FROM ana_date_viaggi WHERE azienda_id <> 2 LIMIT 1;

    -- 1. una volta per visitatore, edizione e lingua in un'ora
    ASSERT fn_web_pdf_richiesta(2, v_ed, 'IT', imp1), 'la prima richiesta si conta';
    ASSERT NOT fn_web_pdf_richiesta(2, v_ed, 'IT', imp1), 'la stessa richiesta nella stessa ora non si conta due volte';
    ASSERT fn_web_pdf_richiesta(2, v_ed, 'EN', imp1), 'un''altra lingua è un altro PDF: si conta';
    ASSERT fn_web_pdf_richiesta(2, v_ed, 'IT', imp2), 'un altro visitatore si conta';
    ASSERT (SELECT count(*) FROM web_pdf_richieste WHERE data_viaggio_id = v_ed AND impronta IN (imp1, imp2)) = 3, 'tre conteggi';
    -- 2. dopo un'ora lo stesso visitatore conta di nuovo
    UPDATE web_pdf_richieste SET richiesta_il = now() - interval '61 minutes' WHERE impronta = imp1 AND lingua = 'IT';
    ASSERT fn_web_pdf_richiesta(2, v_ed, 'IT', imp1), 'dopo un''ora si conta di nuovo';

    -- 3. errori, non conteggi: altra azienda, formati sbagliati (anche se la richiesta esiste già)
    IF v_altra IS NOT NULL THEN
        BEGIN
            PERFORM fn_web_pdf_richiesta(2, v_altra, 'IT', imp1);
            RAISE EXCEPTION 'edizione di un''altra azienda accettata';
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE 'edizione di un''altra azienda accettata' THEN RAISE; END IF;
        END;
    END IF;
    BEGIN
        PERFORM fn_web_pdf_richiesta(2, v_ed, 'IT', '10.0.0.1');
        RAISE EXCEPTION 'impronta non valida accettata';
    EXCEPTION WHEN raise_exception OR check_violation THEN
        IF SQLERRM LIKE 'impronta non valida accettata' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM fn_web_pdf_richiesta(2, v_ed, 'PT', imp1);
        RAISE EXCEPTION 'lingua non valida accettata';
    EXCEPTION WHEN raise_exception OR check_violation THEN
        IF SQLERRM LIKE 'lingua non valida accettata' THEN RAISE; END IF;
    END;

    -- 4. sito_statistiche fa SOLO questo
    ASSERT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_statistiche'), 'manca il ruolo sito_statistiche';
    ASSERT has_function_privilege('sito_statistiche', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'),
        'sito_statistiche deve poter contare';
    ASSERT NOT has_table_privilege('sito_statistiche', 'web_pdf_richieste', 'SELECT'), 'sito_statistiche non legge i conteggi';
    ASSERT NOT has_table_privilege('sito_statistiche', 'web_pdf_richieste', 'INSERT'), 'sito_statistiche non scrive direttamente';
    ASSERT NOT has_table_privilege('sito_statistiche', 'ana_clienti', 'SELECT'), 'sito_statistiche non legge i clienti';
    ASSERT NOT has_function_privilege('sito_statistiche', 'fn_web_iscrizione_arrivo(integer, integer, character varying, character varying)', 'EXECUTE'), 'non registra arrivi';
    ASSERT NOT has_function_privilege('sito_statistiche', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'non legge la posta';
    ASSERT NOT has_function_privilege('sito_statistiche', 'fn_web_revalidate_prossimi(integer, integer)', 'EXECUTE'), 'non tocca la coda';
    ASSERT has_schema_privilege('sito_statistiche', 'public', 'USAGE'), 'USAGE su public (679)';

    -- 5. dal pubblico niente
    ASSERT NOT has_function_privilege('anon', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'), 'anon non conta';
    ASSERT NOT has_function_privilege('authenticated', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'), 'authenticated no';
    ASSERT NOT has_table_privilege('anon', 'web_pdf_richieste', 'SELECT') AND NOT has_table_privilege('anon', 'web_pdf_richieste', 'INSERT'), 'tabella non pubblica';
    ASSERT (SELECT relrowsecurity FROM pg_class WHERE relname = 'web_pdf_richieste'), 'RLS attiva';
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_pdf_richiesta'), 'SECURITY DEFINER';

    RAISE NOTICE 'Test 688: OK';
END $$;
ROLLBACK;
