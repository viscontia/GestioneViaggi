-- ============================================================================
-- Test dello script 673. Transazione annullata: accende e spegne la mail del
-- lunedi' e controlla a chi andrebbe.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_az        integer := 2;
    v_principale text;
    v_dest      text[];
    r           record;
BEGIN
    v_principale := btrim(fn_ana_aziende_email_principale(v_az));
    ASSERT v_principale IS NOT NULL, '0: l''azienda 2 deve avere un''email principale';

    -- 1. spenta: nessuno
    UPDATE web_aziende_funzioni SET attiva = false, parametri = NULL WHERE azienda_id = v_az AND funzione = 'mail_lunedi';
    ASSERT cardinality(fn_promemoria_mail_destinatari(v_az)) = 0, '1: spenta deve dare nessuno';

    -- 2. accesa senza parametro: l'email principale
    UPDATE web_aziende_funzioni SET attiva = true WHERE azienda_id = v_az AND funzione = 'mail_lunedi';
    v_dest := fn_promemoria_mail_destinatari(v_az);
    ASSERT v_dest = ARRAY[v_principale], '2: attesa l''email principale, trovato ' || v_dest::text;

    -- 3. con parametro: quegli indirizzi, puliti
    UPDATE web_aziende_funzioni SET parametri = '{"destinatari": " a@esempio.invalid , ,b@esempio.invalid "}'
     WHERE azienda_id = v_az AND funzione = 'mail_lunedi';
    v_dest := fn_promemoria_mail_destinatari(v_az);
    ASSERT v_dest = ARRAY['a@esempio.invalid', 'b@esempio.invalid'], '3: trovato ' || v_dest::text;

    -- 4. parametro vuoto: torna l'email principale
    UPDATE web_aziende_funzioni SET parametri = '{"destinatari": "  "}' WHERE azienda_id = v_az AND funzione = 'mail_lunedi';
    ASSERT fn_promemoria_mail_destinatari(v_az) = ARRAY[v_principale], '4: vuoto = email principale';

    -- 5. riga assente o azienda inesistente: nessuno
    DELETE FROM web_aziende_funzioni WHERE azienda_id = v_az AND funzione = 'mail_lunedi';
    ASSERT cardinality(fn_promemoria_mail_destinatari(v_az)) = 0, '5: senza riga nessuno';
    ASSERT cardinality(fn_promemoria_mail_destinatari(999999)) = 0, '5: azienda inesistente';

    -- 6. chiusa ad anon/authenticated
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(r.rolname, 'fn_promemoria_mail_destinatari(integer)', 'EXECUTE'), r.rolname || ' esegue';
    END LOOP;

    RAISE NOTICE 'Test 673: tutto OK';
END $$;
ROLLBACK;
