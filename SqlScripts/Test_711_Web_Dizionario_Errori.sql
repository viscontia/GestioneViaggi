-- ============================================================================
-- Test dello script 711. Transazione annullata.
-- Prima dello script deve FALLIRE (il dizionario non c'è).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_diz   jsonb;
    v_hint  text;
    v_det   text;
    v_msg   text;
    v_state text;
    v_n     integer;
BEGIN
    -- 1. completezza: ogni codice ha le 5 lingue, e ogni testo usa esattamente i valori dichiarati
    ASSERT (SELECT count(*) FROM web_errori) >= 6, 'servono almeno i codici COMUNE_ di partenza';
    SELECT count(*) INTO v_n FROM web_errori e
     WHERE (SELECT count(*) FROM web_errori_testi t WHERE t.codice = e.codice) <> 5;
    ASSERT v_n = 0, format('%s codici senza tutte e 5 le lingue', v_n);
    SELECT count(*) INTO v_n
      FROM web_errori_testi t JOIN web_errori e USING (codice)
     WHERE ARRAY(SELECT DISTINCT m[1] FROM regexp_matches(t.testo, '\{([a-z_]+)\}', 'g') m ORDER BY 1)
           <> ARRAY(SELECT x FROM unnest(e.parametri) x ORDER BY 1);
    ASSERT v_n = 0, format('%s testi con valori diversi da quelli dichiarati', v_n);

    -- 2. forma dei codici e delle lingue
    BEGIN
        INSERT INTO web_errori (codice, area) VALUES ('iscr-minuscolo', 'ISCR');
        RAISE EXCEPTION 'codice fuori forma accettato';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO web_errori_testi (codice, lingua, testo) VALUES ('COMUNE_ERRORE_IMPREVISTO', 'PT', 'x');
        RAISE EXCEPTION 'lingua sconosciuta accettata';
    EXCEPTION WHEN check_violation OR unique_violation THEN NULL;
    END;

    -- 3. la lettura per i programmi: una lingua, con l'italiano dove manca
    v_diz := fn_web_errori('EN');
    ASSERT v_diz ? 'COMUNE_SERVIZIO_NON_DISPONIBILE', 'manca un codice nel dizionario inglese';
    ASSERT v_diz ->> 'COMUNE_SERVIZIO_NON_DISPONIBILE' <> fn_web_errori('IT') ->> 'COMUNE_SERVIZIO_NON_DISPONIBILE', 'inglese uguale all''italiano';
    ASSERT fn_web_errori('en') = v_diz, 'la lingua si accetta anche minuscola';
    ASSERT fn_web_errori('XX') = fn_web_errori('IT'), 'lingua sconosciuta: italiano';
    INSERT INTO web_errori (codice, area, nota) VALUES ('COMUNE_PROVA_711', 'COMUNE', 'solo per il test');
    INSERT INTO web_errori_testi (codice, lingua, testo) VALUES ('COMUNE_PROVA_711', 'IT', 'Prova solo in italiano');
    ASSERT fn_web_errori('DE') ->> 'COMUNE_PROVA_711' = 'Prova solo in italiano', 'manca il tedesco: deve valere l''italiano';

    -- 4. il testo riempito
    ASSERT fn_errore_testo('COMUNE_CAMPO_TROPPO_LUNGO', 'IT', '{"campo":"Note","massimo":200}')
           LIKE '%«Note»%200%', 'valori non sostituiti';
    ASSERT fn_errore_testo('COMUNE_NON_ESISTE', 'IT', '{}') = 'COMUNE_NON_ESISTE', 'codice sconosciuto: il codice stesso';

    -- 5. l'errore sollevato da una funzione SQL: messaggio italiano, codice nel suggerimento, valori nel dettaglio
    BEGIN
        PERFORM fn_errore('COMUNE_CAMPO_TROPPO_LUNGO', '{"campo":"Note","massimo":200}');
        RAISE EXCEPTION 'fn_errore non ha sollevato';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT, v_det = PG_EXCEPTION_DETAIL, v_state = RETURNED_SQLSTATE;
    END;
    ASSERT v_state = 'P0001', format('SQLSTATE %s', v_state);
    ASSERT v_hint = 'errore:COMUNE_CAMPO_TROPPO_LUNGO', format('suggerimento %s', v_hint);
    ASSERT v_det::jsonb = '{"campo":"Note","massimo":200}'::jsonb, format('dettaglio %s', v_det);
    ASSERT v_msg = fn_errore_testo('COMUNE_CAMPO_TROPPO_LUNGO', 'IT', '{"campo":"Note","massimo":200}'), 'messaggio non italiano';

    -- 6. permessi: la lettura al pubblico, il resto no
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT has_function_privilege('anon', 'fn_web_errori(varchar)', 'EXECUTE'), 'anon deve leggere il dizionario';
        ASSERT NOT has_function_privilege('anon', 'fn_errore(varchar, jsonb)', 'EXECUTE'), 'anon non solleva errori';
        ASSERT NOT has_table_privilege('anon', 'web_errori_testi', 'SELECT'), 'anon non legge le tabelle';
    END IF;

    RAISE NOTICE 'Test 711: OK';
END $$;
ROLLBACK;
