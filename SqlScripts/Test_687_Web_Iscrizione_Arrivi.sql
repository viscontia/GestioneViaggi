-- ============================================================================
-- Test dello script 687. Transazione annullata: gli arrivi di prova spariscono.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_ed    integer;
    v_altra integer;
    a1 bigint; a2 bigint; a3 bigint; a4 bigint;
    imp1 constant varchar := repeat('a1', 32);   -- 64 caratteri esadecimali
    imp2 constant varchar := repeat('b2', 32);
    v_ok boolean;
BEGIN
    SELECT data_viaggio_id INTO v_ed FROM ana_date_viaggi WHERE azienda_id = 2 ORDER BY data_viaggio_id DESC LIMIT 1;
    SELECT data_viaggio_id INTO v_altra FROM ana_date_viaggi WHERE azienda_id <> 2 LIMIT 1;

    -- 1. lo stesso visitatore sulla stessa edizione nella stessa ora: un arrivo solo
    a1 := fn_web_iscrizione_arrivo(2, v_ed, 'sito', imp1);
    a2 := fn_web_iscrizione_arrivo(2, v_ed, 'sito', imp1);
    ASSERT a1 IS NOT NULL AND a1 = a2, 'stesso visitatore nella stessa ora: atteso lo stesso arrivo';
    -- un altro visitatore: un altro arrivo
    a3 := fn_web_iscrizione_arrivo(2, v_ed, 'sito', imp2);
    ASSERT a3 <> a1, 'visitatori diversi: arrivi diversi';
    -- 2. dopo un'ora lo stesso visitatore conta di nuovo
    UPDATE web_iscrizione_arrivi SET arrivato_il = now() - interval '61 minutes' WHERE arrivo_id = a1;
    a4 := fn_web_iscrizione_arrivo(2, v_ed, 'sito', imp1);
    ASSERT a4 <> a1, 'dopo un''ora: arrivo nuovo';

    -- 3. un'edizione di un'altra azienda è un errore, non un arrivo
    IF v_altra IS NOT NULL THEN
        BEGIN
            PERFORM fn_web_iscrizione_arrivo(2, v_altra, 'sito', imp1);
            RAISE EXCEPTION 'edizione di un''altra azienda accettata';
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE 'edizione di un''altra azienda accettata' THEN RAISE; END IF;
        END;
    END IF;
    -- 4. l'impronta è un codice di 64 caratteri esadecimali: mai un IP o altro testo
    BEGIN
        PERFORM fn_web_iscrizione_arrivo(2, v_ed, 'sito', '192.168.1.10');
        RAISE EXCEPTION 'impronta non valida accettata';
    EXCEPTION WHEN check_violation OR raise_exception THEN
        IF SQLERRM LIKE 'impronta non valida accettata' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM fn_web_iscrizione_arrivo(2, v_ed, 'Sito Web <script>', imp1);
        RAISE EXCEPTION 'provenienza non valida accettata';
    EXCEPTION WHEN check_violation OR raise_exception THEN
        IF SQLERRM LIKE 'provenienza non valida accettata' THEN RAISE; END IF;
    END;

    -- 5. concluso: si segna una volta; la seconda non cambia la data; un altro arrivo non si tocca
    v_ok := fn_web_iscrizione_arrivo_concluso(2, a3);
    ASSERT v_ok AND (SELECT concluso_il FROM web_iscrizione_arrivi WHERE arrivo_id = a3) IS NOT NULL, 'arrivo concluso';
    UPDATE web_iscrizione_arrivi SET concluso_il = now() - interval '1 day' WHERE arrivo_id = a3;
    PERFORM fn_web_iscrizione_arrivo_concluso(2, a3);
    ASSERT (SELECT concluso_il FROM web_iscrizione_arrivi WHERE arrivo_id = a3) < now() - interval '23 hours',
        'una seconda conclusione non sposta la data';
    ASSERT (SELECT concluso_il FROM web_iscrizione_arrivi WHERE arrivo_id = a4) IS NULL, 'gli altri arrivi non si toccano';
    ASSERT NOT fn_web_iscrizione_arrivo_concluso(999999, a4), 'un''altra azienda non conclude i miei arrivi';
    ASSERT NOT fn_web_iscrizione_arrivo_concluso(2, -1), 'arrivo inesistente: false';

    -- 6. dal pubblico non si legge né si scrive niente
    ASSERT NOT has_function_privilege('anon', 'fn_web_iscrizione_arrivo(integer, integer, character varying, character varying)', 'EXECUTE'), 'anon non registra arrivi';
    ASSERT NOT has_function_privilege('anon', 'fn_web_iscrizione_arrivo_concluso(integer, bigint)', 'EXECUTE'), 'anon non conclude arrivi';
    ASSERT NOT has_function_privilege('authenticated', 'fn_web_iscrizione_arrivo(integer, integer, character varying, character varying)', 'EXECUTE'), 'authenticated no';
    ASSERT NOT has_table_privilege('anon', 'web_iscrizione_arrivi', 'SELECT') AND NOT has_table_privilege('anon', 'web_iscrizione_arrivi', 'INSERT'),
        'la tabella degli arrivi non è del pubblico';
    ASSERT NOT has_table_privilege('authenticated', 'web_iscrizione_arrivi', 'SELECT'), 'authenticated non legge gli arrivi';
    ASSERT (SELECT relrowsecurity FROM pg_class WHERE relname = 'web_iscrizione_arrivi'), 'RLS attiva sulla tabella';

    RAISE NOTICE 'Test 687: OK';
END $$;
ROLLBACK;
