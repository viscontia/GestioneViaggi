-- ============================================================================
-- Test dello script 681. Transazione annullata: niente resta scritto.
-- Prima dello script deve FALLIRE (il ruolo e la funzione non esistono).
-- La decifratura vera (con la chiave dei segreti) si prova collegandosi come
-- sito_guardiano dal programma del guardiano: qui la chiave non c'è.
-- ============================================================================
BEGIN;
DO $$
DECLARE v jsonb;
BEGIN
    -- il ruolo esiste e nasce senza accesso (il login si dà a mano)
    ASSERT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_guardiano'), 'manca il ruolo sito_guardiano';

    -- la funzione porta: SECURITY DEFINER, percorso fissato CON extensions (pgcrypto sta lì)
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_guardiano_smtp'), 'deve essere SECURITY DEFINER';
    ASSERT (SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE proname = 'fn_web_guardiano_smtp')
           LIKE '%extensions%', 'search_path senza extensions: pgp_sym_decrypt non si troverebbe';

    -- chi può chiamarla: SOLO sito_guardiano
    ASSERT has_function_privilege('sito_guardiano', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'sito_guardiano deve poterla chiamare';
    ASSERT NOT has_function_privilege('anon', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'anon NON deve poterla chiamare';
    ASSERT NOT has_function_privilege('authenticated', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'authenticated NON deve poterla chiamare';
    ASSERT NOT has_function_privilege('sito_rigenera', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'sito_rigenera NON deve poterla chiamare';

    -- sito_guardiano non legge niente direttamente, e non tocca la coda
    ASSERT NOT has_table_privilege('sito_guardiano', 'ana_aziende_smtp', 'SELECT'), 'sito_guardiano NON deve leggere ana_aziende_smtp';
    ASSERT NOT has_table_privilege('sito_guardiano', 'ana_clienti', 'SELECT'), 'sito_guardiano NON deve leggere ana_clienti';
    ASSERT NOT has_function_privilege('sito_guardiano', 'fn_web_revalidate_prossimi(integer, integer)', 'EXECUTE'), 'sito_guardiano NON deve toccare la coda';
    ASSERT NOT has_function_privilege('sito_guardiano', 'fn_get_smtp_config_for_email(integer, text)', 'EXECUTE'), 'la funzione interna resta solo del proprietario';
    ASSERT has_schema_privilege('sito_guardiano', 'public', 'USAGE'), 'senza USAGE su public non vede la funzione (679)';

    -- un'azienda senza configurazione: NULL, non un errore
    ASSERT fn_web_guardiano_smtp(999999, 'chiave-qualunque') IS NULL, 'azienda inesistente: atteso NULL';

    -- con una chiave sbagliata la decifratura fallisce (prova che decifra davvero, e che senza chiave non si legge)
    IF EXISTS (SELECT 1 FROM ana_aziende_smtp WHERE azienda_fk = 2 AND is_active AND status = 'active'
                AND config_type = 'outbound' AND password_enc IS NOT NULL) THEN
        BEGIN
            v := fn_web_guardiano_smtp(2, 'chiave-sbagliata');
            RAISE EXCEPTION 'con la chiave sbagliata doveva fallire, ha restituito %', v ->> 'host';
        EXCEPTION WHEN external_routine_exception OR data_exception OR others THEN
            IF SQLERRM LIKE 'con la chiave sbagliata%' THEN RAISE; END IF;
        END;
    END IF;

    RAISE NOTICE 'Test 681: OK';
END $$;
ROLLBACK;
