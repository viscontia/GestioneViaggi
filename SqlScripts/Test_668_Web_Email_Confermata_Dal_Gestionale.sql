-- ============================================================================
-- Test dello script 668. Tutto in una transazione annullata: prende una scheda
-- con email, la finge agganciata dal sito, e verifica che il codice sia bloccato
-- finche' il gestionale non la conferma.
-- ============================================================================
BEGIN;
DO $$
DECLARE c RECORD; v_esito text;
BEGIN
    SELECT cliente_id, azienda_fk, cliente_email INTO c FROM ana_clienti
     WHERE nullif(btrim(cliente_email), '') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM web_email_agganciate w WHERE w.cliente_id = ana_clienti.cliente_id)
     ORDER BY cliente_id LIMIT 1;
    INSERT INTO web_email_agganciate (cliente_id, azienda_id, email) VALUES (c.cliente_id, c.azienda_fk, c.cliente_email);

    ASSERT fn_web_email_da_confermare(c.cliente_id, c.azienda_fk), '1: doveva risultare da confermare';
    SELECT esito INTO v_esito FROM fn_web_otp_genera(c.azienda_fk, c.cliente_id);
    ASSERT v_esito = 'EMAIL_NON_VERIFICATA', '1: il codice doveva essere bloccato, esito ' || v_esito;

    ASSERT NOT fn_web_email_conferma(c.cliente_id, c.azienda_fk + 1000), '2: un''altra azienda non conferma';
    ASSERT fn_web_email_da_confermare(c.cliente_id, c.azienda_fk), '2: ancora da confermare';

    ASSERT fn_web_email_conferma(c.cliente_id, c.azienda_fk), '3: la conferma doveva riuscire';
    ASSERT NOT fn_web_email_da_confermare(c.cliente_id, c.azienda_fk), '3: non piu'' da confermare';
    SELECT esito INTO v_esito FROM fn_web_otp_genera(c.azienda_fk, c.cliente_id);
    ASSERT v_esito <> 'EMAIL_NON_VERIFICATA', '3: il codice doveva tornare possibile';

    FOR v_esito IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(v_esito, 'fn_web_email_conferma(integer,integer)', 'EXECUTE'), v_esito || ' puo'' confermare';
    END LOOP;
    RAISE NOTICE 'Test 668: tutto OK';
END $$;
ROLLBACK;
