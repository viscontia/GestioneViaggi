-- ============================================================================
-- Test dello script 670 (L12-bis). Transazione annullata.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    c RECORD; v_id bigint; v_msg text; v_prima text; v_email text; v_ruolo text; n integer;
BEGIN
    SELECT cliente_id, azienda_fk, cliente_telefono INTO c FROM ana_clienti
     WHERE azienda_fk = 2 AND nullif(btrim(cliente_email), '') IS NOT NULL
       AND cliente_documento_rilasciato_data IS NOT NULL
     ORDER BY cliente_id LIMIT 1;

    -- 1. lettura: una riga per campo, con archivio e proposta
    v_id := fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid', '{"cliente_telefono":"3339998887"}');
    SELECT count(*) INTO n FROM fn_web_proposta_del_cliente(c.cliente_id, 2);
    ASSERT n = 1, '1: attesa una riga, trovate ' || n;
    ASSERT (SELECT proposto FROM fn_web_proposta_del_cliente(c.cliente_id, 2)) = '3339998887', '1: valore proposto';
    ASSERT (SELECT count(*) FROM fn_web_proposte_in_attesa(2) WHERE cliente_id = c.cliente_id) = 1, '1: in attesa';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_proposta_del_cliente(c.cliente_id, 6)), '1: un''altra azienda non la vede';

    -- 2. approvazione: la scheda cambia, firmata
    SELECT email INTO v_email FROM fn_web_proposta_approva(v_id, 2, 'gestionale:prova');
    ASSERT v_email = 'x@example.invalid', '2: email di chi ha proposto';
    ASSERT (SELECT cliente_telefono FROM ana_clienti WHERE cliente_id = c.cliente_id) = '3339998887', '2: telefono non aggiornato';
    ASSERT (SELECT updated_by FROM ana_clienti WHERE cliente_id = c.cliente_id) = 'gestionale:prova', '2: firma';
    ASSERT (SELECT stato FROM web_proposte_modifica WHERE proposta_id = v_id) = 'APPROVATA', '2: stato';

    -- 3. non si approva due volte
    BEGIN
        PERFORM fn_web_proposta_approva(v_id, 2, 'gestionale:prova');
        RAISE EXCEPTION 'KO 3: approvata due volte';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- 4. dati che la validazione rifiuta: niente cambia, la proposta resta in attesa
    SELECT md5((to_jsonb(x) - 'updated' - 'updated_by')::text) INTO v_prima FROM ana_clienti x WHERE x.cliente_id = c.cliente_id;
    v_id := fn_web_proposta_crea(2, c.cliente_id, 'x@example.invalid',
            '{"cliente_documento_rilasciato_data":"2030-01-01","cliente_documento_rilasciato_scadenza":"2020-01-01"}');
    BEGIN
        PERFORM fn_web_proposta_approva(v_id, 2, 'gestionale:prova');
        RAISE EXCEPTION 'KO 4: approvata una scadenza prima del rilascio';
    EXCEPTION WHEN others THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg NOT LIKE 'KO 4%', v_msg;
    END;
    ASSERT v_prima = (SELECT md5((to_jsonb(x) - 'updated' - 'updated_by')::text) FROM ana_clienti x WHERE x.cliente_id = c.cliente_id),
           '4: la scheda e'' cambiata';
    ASSERT (SELECT stato FROM web_proposte_modifica WHERE proposta_id = v_id) = 'IN_ATTESA', '4: doveva restare in attesa';

    -- 5. scarto: la scheda non cambia
    ASSERT NOT fn_web_proposta_scarta(v_id, 6, 'gestionale:prova'), '5: un''altra azienda non scarta';
    ASSERT fn_web_proposta_scarta(v_id, 2, 'gestionale:prova'), '5: scarto';
    ASSERT (SELECT stato FROM web_proposte_modifica WHERE proposta_id = v_id) = 'SCARTATA', '5: stato';
    ASSERT v_prima = (SELECT md5((to_jsonb(x) - 'updated' - 'updated_by')::text) FROM ana_clienti x WHERE x.cliente_id = c.cliente_id),
           '5: la scheda e'' cambiata';

    -- 6. chiuse ad anon e authenticated
    FOR v_ruolo IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_web_proposta_approva(bigint,integer,character varying)', 'EXECUTE'), v_ruolo;
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_web_proposta_del_cliente(integer,integer)', 'EXECUTE'), v_ruolo;
    END LOOP;
    RAISE NOTICE 'Test 670: tutto OK';
END $$;
ROLLBACK;
