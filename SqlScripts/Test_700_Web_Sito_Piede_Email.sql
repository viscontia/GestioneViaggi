-- ============================================================================
-- Test dello script 700. Transazione annullata.
-- Prima dello script deve FALLIRE (il piede mostra sempre l'email principale).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_princ  text;
    v_altra  integer;
BEGIN
    v_princ := fn_ana_aziende_email_principale(2);
    ASSERT v_princ IS NOT NULL, 'serve un''email principale per l''azienda 2';
    INSERT INTO ana_aziende_email (azienda_fk, email, is_principale, reparto_fk)
    SELECT 2, 'messaggi-test700@example.com', false, e.reparto_fk FROM ana_aziende_email e WHERE e.azienda_fk = 2 LIMIT 1
    RETURNING email_id INTO v_altra;
    INSERT INTO web_sito_contenuti (azienda_id) VALUES (2) ON CONFLICT (azienda_id) DO NOTHING;

    -- 1. scelta l'email dei messaggi del sito: il sito mostra quella (chi scrive a mano e chi usa il modulo
    --    arrivano nella stessa casella), in tutte le lingue
    UPDATE web_sito_contenuti SET email_messaggi_fk = v_altra WHERE azienda_id = 2;
    ASSERT fn_web_sito_piede(2, 'IT')->>'email' = 'messaggi-test700@example.com', 'il piede mostra l''email dei messaggi del sito';
    ASSERT fn_web_sito_piede(2, 'DE')->>'email' = 'messaggi-test700@example.com', 'anche in tedesco';

    -- 1-bis. la scelta di un'ALTRA azienda non arriva mai nel piede dell'azienda 2 (costruita qui: in locale
    --        spesso solo l'azienda 2 ha la scheda «Sito web», e un filtro sbagliato non si vedrebbe)
    DECLARE v_az integer; v_sua integer;
    BEGIN
        SELECT a.azienda_id INTO v_az FROM ana_aziende a WHERE a.azienda_id <> 2 ORDER BY 1 LIMIT 1;
        INSERT INTO ana_aziende_email (azienda_fk, email, is_principale, reparto_fk)
        SELECT v_az, 'altra-azienda-test700@example.com', false, e.reparto_fk FROM ana_aziende_email e LIMIT 1
        RETURNING email_id INTO v_sua;
        INSERT INTO web_sito_contenuti (azienda_id, email_messaggi_fk) VALUES (v_az, v_sua)
        ON CONFLICT (azienda_id) DO UPDATE SET email_messaggi_fk = EXCLUDED.email_messaggi_fk;
        ASSERT fn_web_sito_piede(2, 'IT')->>'email' = 'messaggi-test700@example.com', 'il piede dell''azienda 2 resta suo';
    END;

    -- 2. nessuna scelta: l'email principale, come prima del 700
    UPDATE web_sito_contenuti SET email_messaggi_fk = NULL WHERE azienda_id = 2;
    ASSERT fn_web_sito_piede(2, 'IT')->>'email' = v_princ, 'senza scelta: la principale';

    -- 3. senza la riga della scheda «Sito web»: la principale
    DELETE FROM web_sito_evidenza WHERE azienda_id = 2;
    DELETE FROM web_sito_contenuti WHERE azienda_id = 2;
    ASSERT fn_web_sito_piede(2, 'IT')->>'email' = v_princ, 'senza scheda: la principale';

    -- 4. l'email principale resta quella di prima (fatture, newsletter, gestionale non cambiano)
    ASSERT fn_ana_aziende_email_principale(2) = v_princ, 'la principale non cambia';

    -- 5. permessi invariati
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT has_function_privilege('anon', 'fn_web_sito_piede(integer, character varying)', 'EXECUTE'), 'anon legge il piede';
    END IF;
    CREATE ROLE test700_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test700_nessuno', 'fn_web_sito_piede(integer, character varying)', 'EXECUTE'), 'non a chiunque';

    RAISE NOTICE 'Test 700: OK';
END $$;
ROLLBACK;
