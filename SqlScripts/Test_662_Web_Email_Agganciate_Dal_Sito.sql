-- ============================================================================
-- Test dello script 662: le email agganciate dal sito non aprono la scheda
--
-- Gira tutto dentro una transazione che si annulla: non lascia righe, e l'email
-- del 3870 torna quella di prima.
-- Usa il cliente 3870 (azienda 2) come «scheda senza email», svuotandola qui
-- dentro, e il primo altro cliente dell'azienda 2 con un'email come «scheda che
-- l'email ce l'ha gia'».
-- ============================================================================

BEGIN;
DO $$
DECLARE
    r           RECORD;
    v_con_email INTEGER;
    v_prima     TEXT;
BEGIN
    DELETE FROM web_otp_codici       WHERE cliente_id = 3870;
    DELETE FROM web_email_agganciate WHERE cliente_id = 3870;

    -- 1. scheda senza email: il sito aggancia l'email di chi scrive, e resta traccia
    UPDATE ana_clienti SET cliente_email = NULL WHERE cliente_id = 3870;
    ASSERT fn_web_cliente_aggancia_email(3870, 2, '  Estraneo@Example.invalid ') = true,
           'aggancio su scheda senza email: atteso true';
    ASSERT (SELECT cliente_email FROM ana_clienti WHERE cliente_id = 3870) = 'Estraneo@Example.invalid',
           'l''email non e'' finita in scheda';
    ASSERT (SELECT email FROM web_email_agganciate WHERE cliente_id = 3870 AND azienda_id = 2)
           = 'Estraneo@Example.invalid', 'aggancio non registrato';

    -- 2. quella casella non l'ha verificata nessuno: niente codice, niente riga
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'EMAIL_NON_VERIFICATA', 'atteso EMAIL_NON_VERIFICATA, ottenuto ' || r.esito;
    ASSERT r.codice IS NULL AND r.email IS NULL, 'EMAIL_NON_VERIFICATA con codice o email';
    ASSERT NOT EXISTS (SELECT 1 FROM web_otp_codici WHERE cliente_id = 3870),
           'EMAIL_NON_VERIFICATA ha scritto una riga';

    -- 2b. il confronto ignora le maiuscole: scriverla diversa non basta.
    -- (Gli spazi in testa li respinge gia' il vincolo ana_clienti_email_formato_check.)
    UPDATE ana_clienti SET cliente_email = 'ESTRANEO@example.INVALID' WHERE cliente_id = 3870;
    ASSERT (SELECT esito FROM fn_web_otp_genera(2, 3870)) = 'EMAIL_NON_VERIFICATA',
           'la stessa email scritta diversa ha sbloccato il codice';

    -- 3. il gestionale corregge l'email: la riga non corrisponde piu', il codice si'
    UPDATE ana_clienti SET cliente_email = 'vera@example.invalid' WHERE cliente_id = 3870;
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'OK', 'email corretta dal gestionale: atteso OK, ottenuto ' || r.esito;
    ASSERT r.email = 'vera@example.invalid', 'codice spedito alla casella sbagliata';

    -- 4. scheda che l'email ce l'ha gia': non si tocca e non si registra nulla
    SELECT cliente_id, cliente_email INTO v_con_email, v_prima
      FROM ana_clienti
     WHERE azienda_fk = 2 AND nullif(btrim(cliente_email), '') IS NOT NULL AND cliente_id <> 3870
     ORDER BY cliente_id LIMIT 1;
    ASSERT v_con_email IS NOT NULL, 'nessun cliente di prova con email nell''azienda 2';
    DELETE FROM web_email_agganciate WHERE cliente_id = v_con_email;
    ASSERT fn_web_cliente_aggancia_email(v_con_email, 2, 'estraneo@example.invalid') = false,
           'aggancio su scheda con email: atteso false';
    ASSERT (SELECT cliente_email FROM ana_clienti WHERE cliente_id = v_con_email) IS NOT DISTINCT FROM v_prima,
           'sovrascritta l''email di una scheda che l''aveva';
    ASSERT NOT EXISTS (SELECT 1 FROM web_email_agganciate WHERE cliente_id = v_con_email),
           'registrato un aggancio mai avvenuto';

    -- 5. azienda sbagliata: nessun aggancio, nessuna riga
    UPDATE ana_clienti SET cliente_email = NULL WHERE cliente_id = 3870;
    DELETE FROM web_email_agganciate WHERE cliente_id = 3870;
    ASSERT fn_web_cliente_aggancia_email(3870, 6, 'estraneo@example.invalid') = false,
           'aggancio sul cliente di un''altra azienda';
    ASSERT NOT EXISTS (SELECT 1 FROM web_email_agganciate WHERE cliente_id = 3870),
           'registrato un aggancio per l''azienda sbagliata';

    -- 6. anon e authenticated (dove esiste) non chiamano le funzioni e non leggono la tabella
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(r.rolname, 'fn_web_cliente_aggancia_email(integer,integer,character varying)', 'EXECUTE'),
               r.rolname || ' puo'' agganciare email';
        ASSERT NOT has_function_privilege(r.rolname, 'fn_web_otp_genera(integer,integer)', 'EXECUTE'),
               r.rolname || ' puo'' generare codici';
        ASSERT NOT has_table_privilege(r.rolname, 'web_email_agganciate', 'SELECT'),
               r.rolname || ' puo'' leggere le email agganciate';
    END LOOP;

    RAISE NOTICE 'Test 662: tutto OK';
END $$;
ROLLBACK;
