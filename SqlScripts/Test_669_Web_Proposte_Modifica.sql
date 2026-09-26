-- ============================================================================
-- Test dello script 669: le proposte di modifica dal sito (L12-bis).
-- Tutto in una transazione annullata. Ogni controllo e' un ASSERT: il primo che
-- non torna ferma lo script.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    c        RECORD;
    v_prima  TEXT;
    v_id1    BIGINT;
    v_id2    BIGINT;
    v_msg    TEXT;
    v_ruolo  TEXT;
BEGIN
    SELECT cliente_id, azienda_fk INTO c FROM ana_clienti
     WHERE azienda_fk = 2 AND nullif(btrim(cliente_email), '') IS NOT NULL
     ORDER BY cliente_id LIMIT 1;
    SELECT md5((to_jsonb(x) - 'updated' - 'updated_by')::text) INTO v_prima FROM ana_clienti x WHERE x.cliente_id = c.cliente_id;

    -- 1. si tengono solo i campi ammessi
    v_id1 := fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid',
                                  '{"cliente_telefono":"3331234567","cliente_nome":"HACK"}');
    ASSERT (SELECT dati FROM web_proposte_modifica WHERE proposta_id = v_id1) = '{"cliente_telefono":"3331234567"}'::jsonb,
           '1: nei dati doveva restare solo il telefono';

    -- 2. la scheda non cambia
    ASSERT v_prima = (SELECT md5((to_jsonb(x) - 'updated' - 'updated_by')::text) FROM ana_clienti x WHERE x.cliente_id = c.cliente_id),
           '2: la proposta ha cambiato la scheda';

    -- 3. una seconda proposta sostituisce la prima
    v_id2 := fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_indirizzo_residenza":"VIA NUOVA 1"}');
    ASSERT (SELECT stato FROM web_proposte_modifica WHERE proposta_id = v_id1) = 'SOSTITUITA', '3: la prima doveva essere sostituita';
    ASSERT (SELECT count(*) FROM web_proposte_modifica WHERE cliente_id = c.cliente_id AND stato = 'IN_ATTESA') = 1,
           '3: doveva restarne una sola in attesa';

    -- 4. la quarta del giorno e' rifiutata
    PERFORM fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_telefono":"3330000001"}');
    BEGIN
        PERFORM fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_telefono":"3330000002"}');
        RAISE EXCEPTION 'KO 4: accettata la quarta proposta del giorno';
    EXCEPTION WHEN check_violation THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg ILIKE '%troppe%', '4: messaggio inatteso: ' || v_msg;
    END;
    DELETE FROM web_proposte_modifica WHERE cliente_id = c.cliente_id;

    -- 5. nessun dato ammesso
    BEGIN
        PERFORM fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_nome":"HACK","cliente_telefono":"  "}');
        RAISE EXCEPTION 'KO 5: accettata una proposta senza dati';
    EXCEPTION WHEN check_violation THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg ILIKE '%nessun dato%', '5: messaggio inatteso: ' || v_msg;
    END;

    -- 6. data non valida
    BEGIN
        PERFORM fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_documento_rilasciato_scadenza":"2026-13-45"}');
        RAISE EXCEPTION 'KO 6: accettata una data impossibile';
    EXCEPTION WHEN check_violation THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg ILIKE '%non sono scritti in modo valido%', '6: messaggio inatteso: ' || v_msg;
    END;

    -- 6-bis. il tipo di documento e' un codice di testo, e passa
    DELETE FROM web_proposte_modifica WHERE cliente_id = c.cliente_id;
    v_id1 := fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid',
                                  '{"cliente_tipodoc_identita":"CI","cliente_documento_rilasciato_scadenza":"2036-01-31"}');
    ASSERT (SELECT dati ->> 'cliente_tipodoc_identita' FROM web_proposte_modifica WHERE proposta_id = v_id1) = 'CI',
           '6-bis: il tipo di documento doveva restare';
    DELETE FROM web_proposte_modifica WHERE cliente_id = c.cliente_id;

    -- 7. cliente di un'altra azienda
    BEGIN
        PERFORM fn_web_proposta_crea(6, c.cliente_id, 'x@example.invalid', '{"cliente_telefono":"3331234567"}');
        RAISE EXCEPTION 'KO 7: accettata una proposta per la scheda di un''altra azienda';
    EXCEPTION WHEN check_violation THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg ILIKE '%non trovata%', '7: messaggio inatteso: ' || v_msg;
    END;

    -- 8. chiuse ad anon e authenticated
    FOR v_ruolo IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_web_proposta_crea(integer,integer,character varying,jsonb)', 'EXECUTE'),
               v_ruolo || ' puo'' creare proposte';
        ASSERT NOT has_table_privilege(v_ruolo, 'web_proposte_modifica', 'SELECT'), v_ruolo || ' legge le proposte';
    END LOOP;

    RAISE NOTICE 'Test 669: tutto OK';
END $$;
ROLLBACK;
