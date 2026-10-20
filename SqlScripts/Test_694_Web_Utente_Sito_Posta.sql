-- ============================================================================
-- Test dello script 694. Transazione annullata.
-- Prima dello script deve FALLIRE (il ruolo e la funzione non esistono).
-- ⛔️ Il test non usa MAI la chiave vera dei segreti: per leggere il destinatario
--    spegne (nella transazione) la configurazione di posta dell'azienda.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_j       jsonb;
    v_info    integer;
    v_princ   varchar;
    f         constant text := 'fn_web_sito_posta(integer, text)';
BEGIN
    ASSERT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_posta'), 'manca il ruolo sito_posta';

    -- 1. con una chiave sbagliata: errore, mai una password
    IF EXISTS (SELECT 1 FROM ana_aziende_smtp WHERE azienda_fk = 2 AND is_active AND status = 'active'
                                              AND config_type = 'outbound' AND password_enc IS NOT NULL) THEN
        BEGIN
            v_j := fn_web_sito_posta(2, 'chiave-sbagliata');
            RAISE EXCEPTION 'chiave sbagliata accettata';
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE 'chiave sbagliata accettata' THEN RAISE; END IF;
        WHEN OTHERS THEN
            NULL;   -- «Wrong key or corrupt data»: giusto così
        END;
    END IF;

    -- 2. il destinatario: l'email scelta nella scheda «Sito web», altrimenti la principale
    UPDATE ana_aziende_smtp SET is_active = false WHERE azienda_fk = 2;   -- niente da decifrare
    v_princ := fn_ana_aziende_email_principale(2);
    SELECT email_id INTO v_info FROM ana_aziende_email
     WHERE azienda_fk = 2 AND email <> v_princ ORDER BY email_id LIMIT 1;
    IF v_info IS NULL THEN   -- serve una seconda email: se manca, se ne crea una
        INSERT INTO ana_aziende_email (azienda_fk, email, is_principale)
        VALUES (2, 'prova694@esempio.invalid', false) RETURNING email_id INTO v_info;
    END IF;
    DELETE FROM web_sito_contenuti WHERE azienda_id = 2;
    v_j := fn_web_sito_posta(2, 'non-usata');
    ASSERT v_j ? 'smtp' AND v_j ? 'destinatario' AND v_j ? 'mittente_nome', 'chiavi della risposta';
    ASSERT v_j->'smtp' = 'null'::jsonb, 'senza configurazione di posta: smtp null (niente da decifrare)';
    ASSERT v_j->>'destinatario' = v_princ, 'senza scelta: la principale';
    ASSERT v_j->>'mittente_nome' = (SELECT ragione_sociale FROM ana_aziende WHERE azienda_id = 2), 'mittente: la ragione sociale';
    PERFORM fn_web_sito_contenuti_save(2, NULL, NULL, NULL, v_info, NULL, 'test694');
    ASSERT fn_web_sito_posta(2, 'non-usata')->>'destinatario' = (SELECT email FROM ana_aziende_email WHERE email_id = v_info),
        'con la scelta: l''email scelta';

    -- 3. sito_posta fa SOLO questo
    ASSERT (SELECT prosecdef FROM pg_proc WHERE oid = f::regprocedure), 'SECURITY DEFINER';
    ASSERT has_function_privilege('sito_posta', f, 'EXECUTE'), 'sito_posta deve leggere la posta';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_guardiano_smtp(integer, text)', 'EXECUTE'), 'non la funzione del guardiano';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_get_smtp_config_for_email(integer, text)', 'EXECUTE'),
        'non la funzione interna di decifratura';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_pdf_richiesta(integer, integer, character varying, character varying)', 'EXECUTE'), 'non conta PDF';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_iscrizione_arrivo(integer, integer, character varying, character varying)', 'EXECUTE'), 'non registra arrivi';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_revalidate_prossimi(integer, integer)', 'EXECUTE'), 'non tocca la coda';
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_sito_contenuti_save(integer, bigint, character varying, character varying, integer, character varying, character varying)', 'EXECUTE'),
        'non scrive la scheda «Sito web»';
    ASSERT NOT has_table_privilege('sito_posta', 'ana_aziende_smtp', 'SELECT'), 'non legge la tabella della posta';
    ASSERT NOT has_table_privilege('sito_posta', 'ana_clienti', 'SELECT'), 'non legge i clienti';
    ASSERT NOT has_table_privilege('sito_posta', 'web_newsletter_iscritti', 'SELECT'), 'non legge gli iscritti';
    ASSERT has_schema_privilege('sito_posta', 'public', 'USAGE'), 'USAGE su public';

    -- 4. dal pubblico niente
    CREATE ROLE test694_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test694_nessuno', f, 'EXECUTE'), 'non eseguibile da chiunque (PUBLIC)';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', f, 'EXECUTE'), 'anon non legge la posta';
        ASSERT NOT has_function_privilege('authenticated', f, 'EXECUTE'), 'authenticated non legge la posta';
    END IF;

    RAISE NOTICE 'Test 694: OK';
END $$;
ROLLBACK;
