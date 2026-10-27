-- ============================================================================
-- Test dello script 704. Transazione annullata: dati di prova e righe di coda spariscono.
-- Prima dello script deve FALLIRE (tabelle e funzioni non esistono).
-- ============================================================================
BEGIN;
-- (dal 705 la galleria si riempie da sola con le foto dei tour: qui si guarda l'elenco senza di lei)
DO $$
DECLARE
    salva  constant text := 'fn_web_sito_faq_save(integer, jsonb, character varying)';
    coda   constant text := 'select count(*) from web_revalidate_coda where azienda_id = 2 and completata_il is null and oggetto = ''menu''';
    v_j    jsonb;
    v_n    integer;
    g1 bigint; g2 bigint; q1 bigint; q2 bigint; q3 bigint; q4 bigint; g6 bigint;
BEGIN
    -- 1. le tabelle, chiuse al pubblico (RLS accese: il sito legge solo le funzioni)
    ASSERT to_regclass('web_sito_faq_gruppi') IS NOT NULL AND to_regclass('web_sito_faq') IS NOT NULL, 'mancano le tabelle';
    ASSERT (SELECT bool_and(relrowsecurity) FROM pg_class WHERE relname IN ('web_sito_faq_gruppi', 'web_sito_faq')), 'RLS spente';

    -- 2. si parte vuoti (anche senza traduzioni di FAQ: il test non dipende dai dati)
    DELETE FROM web_traduzioni WHERE entita IN ('web_sito_faq_gruppi', 'web_sito_faq') AND azienda_id = 2;
    PERFORM fn_web_sito_faq_save(2, '[]'::jsonb, 'test704');
    PERFORM fn_web_sito_chi_siamo_save(2, NULL, 'test704');
    PERFORM fn_web_sito_testi_legali_save(2, NULL, NULL, NULL, 'test704');
    ASSERT fn_web_sito_faq(2, 'IT') = '[]'::jsonb, 'senza domande: elenco vuoto';
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '[]'::jsonb, 'senza domande: nessuna pagina, non ' || fn_web_sito_pagine(2)::text;
    ASSERT fn_web_sito_faq_list(2) = '[]'::jsonb, 'il gestionale vede vuoto';

    -- 3. due gruppi: solo le domande attive e con risposta; un gruppo senza domande visibili non si vede
    PERFORM fn_web_sito_faq_save(2, '[
      {"nome": "Prima di partire", "domande": [
         {"domanda": "Serve esperienza?", "risposta": "<p>No.</p>", "attiva": true},
         {"domanda": "Bozza", "risposta": "<p>Non ancora</p>", "attiva": false},
         {"domanda": "Senza risposta", "risposta": "<p><br></p>", "attiva": true}]},
      {"nome": "Mezzi", "domande": [
         {"domanda": "Il casco?", "risposta": "<p>Fornito.</p>", "attiva": false}]}]'::jsonb, 'test704');
    v_j := fn_web_sito_faq(2, 'IT');
    ASSERT v_j = '[{"nome": "Prima di partire", "domande": [{"lingua": "IT", "domanda": "Serve esperienza?", "risposta": "<p>No.</p>"}]}]'::jsonb,
        'solo il visibile: ' || v_j::text;
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '["faq"]'::jsonb, 'con una domanda attiva la pagina c''è: ' || fn_web_sito_pagine(2)::text;
    ASSERT (SELECT risposta FROM web_sito_faq WHERE domanda = 'Senza risposta') IS NULL, 'l''HTML vuoto di Quill diventa NULL';
    -- il gestionale vede tutto, con gli identificativi
    v_j := fn_web_sito_faq_list(2);
    ASSERT jsonb_array_length(v_j) = 2 AND jsonb_array_length(v_j->0->'domande') = 3, 'il gestionale vede tutto: ' || v_j::text;
    g1 := (v_j->0->>'id')::bigint; g2 := (v_j->1->>'id')::bigint;
    q1 := (v_j->0->'domande'->0->>'id')::bigint; q2 := (v_j->0->'domande'->1->>'id')::bigint;
    q3 := (v_j->0->'domande'->2->>'id')::bigint; q4 := (v_j->1->'domande'->0->>'id')::bigint;

    -- 4. ordine: quello dell'elenco salvato (gruppi e domande); con Chi siamo e privacy, le FAQ dopo Chi siamo
    PERFORM fn_web_sito_faq_save(2, format('[
      {"id": %s, "nome": "Mezzi", "domande": [{"id": %s, "domanda": "Il casco?", "risposta": "<p>Fornito.</p>", "attiva": true}]},
      {"id": %s, "nome": "Prima di partire", "domande": [
         {"id": %s, "domanda": "Bozza", "risposta": "<p>Pronta</p>", "attiva": true},
         {"id": %s, "domanda": "Serve esperienza?", "risposta": "<p>No.</p>", "attiva": true}]}]', g2, q4, g1, q2, q1)::jsonb, 'test704');
    v_j := fn_web_sito_faq(2, 'IT');
    ASSERT v_j->0->>'nome' = 'Mezzi' AND v_j->1->'domande'->0->>'domanda' = 'Bozza', 'ordine: ' || v_j::text;
    ASSERT NOT EXISTS (SELECT 1 FROM web_sito_faq WHERE web_sito_faq_id = q3), 'la domanda tolta dall''elenco è cancellata';
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Chi</p>', 'test704');
    PERFORM fn_web_sito_testi_legali_save(2, NULL, '<p>Privacy</p>', NULL, 'test704');
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '["chi_siamo", "faq", "privacy"]'::jsonb, 'ordine delle pagine: ' || fn_web_sito_pagine(2)::text;

    -- 5. traduzioni: nome, domanda, risposta; mancante o obsoleta → italiano, e la domanda dice in che lingua è
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by) VALUES
        ('web_sito_faq_gruppi', g2, 'nome', 'DE', 'Fahrzeuge', 2, 'test704'),
        ('web_sito_faq', q4, 'domanda', 'DE', 'Der Helm?', 2, 'test704'),
        ('web_sito_faq', q4, 'risposta', 'DE', '<p>Gestellt.</p>', 2, 'test704');
    v_j := fn_web_sito_faq(2, 'DE');
    ASSERT v_j->0 = '{"nome": "Fahrzeuge", "domande": [{"lingua": "DE", "domanda": "Der Helm?", "risposta": "<p>Gestellt.</p>"}]}'::jsonb, 'DE: ' || (v_j->0)::text;
    ASSERT v_j->1->'domande'->0->>'lingua' = 'IT', 'domanda non tradotta: IT';
    -- 6. il testo italiano cambia → la sua traduzione diventa obsoleta (le altre no); uguale → resta
    PERFORM fn_web_sito_faq_save(2, format('[
      {"id": %s, "nome": "Mezzi", "domande": [{"id": %s, "domanda": "Il casco è fornito?", "risposta": "<p>Fornito.</p>", "attiva": true}]},
      {"id": %s, "nome": "Prima di partire", "domande": [
         {"id": %s, "domanda": "Bozza", "risposta": "<p>Pronta</p>", "attiva": true},
         {"id": %s, "domanda": "Serve esperienza?", "risposta": "<p>No.</p>", "attiva": true}]}]', g2, q4, g1, q2, q1)::jsonb, 'test704');
    ASSERT (SELECT obsoleto FROM web_traduzioni WHERE entita = 'web_sito_faq' AND entita_id = q4 AND campo = 'domanda' AND lingua = 'DE'), 'domanda cambiata: traduzione obsoleta';
    ASSERT NOT (SELECT obsoleto FROM web_traduzioni WHERE entita = 'web_sito_faq' AND entita_id = q4 AND campo = 'risposta' AND lingua = 'DE'), 'risposta uguale: traduzione valida';
    ASSERT NOT (SELECT obsoleto FROM web_traduzioni WHERE entita = 'web_sito_faq_gruppi' AND entita_id = g2 AND campo = 'nome' AND lingua = 'DE'), 'nome uguale: traduzione valida';
    v_j := fn_web_sito_faq(2, 'DE');
    ASSERT v_j->0->'domande'->0->>'domanda' = 'Il casco è fornito?' AND v_j->0->'domande'->0->>'lingua' = 'IT', 'obsoleta → italiano: ' || (v_j->0)::text;
    -- tutta la domanda in una lingua: se la domanda non è tradotta, anche la risposta resta in italiano
    ASSERT v_j->0->'domande'->0->>'risposta' = '<p>Fornito.</p>', 'mai domanda e risposta in due lingue: ' || (v_j->0)::text;

    -- 7. spostare una domanda in un altro gruppo la conserva (stesso id, stesse traduzioni)
    PERFORM fn_web_sito_faq_save(2, format('[
      {"id": %s, "nome": "Mezzi", "domande": [
         {"id": %s, "domanda": "Il casco è fornito?", "risposta": "<p>Fornito.</p>", "attiva": true},
         {"id": %s, "domanda": "Serve esperienza?", "risposta": "<p>No.</p>", "attiva": true}]},
      {"id": %s, "nome": "Prima di partire", "domande": [{"id": %s, "domanda": "Bozza", "risposta": "<p>Pronta</p>", "attiva": true}]}]',
      g2, q4, q1, g1, q2)::jsonb, 'test704');
    ASSERT (SELECT gruppo_fk FROM web_sito_faq WHERE web_sito_faq_id = q1) = g2, 'domanda spostata';
    ASSERT EXISTS (SELECT 1 FROM web_traduzioni WHERE entita = 'web_sito_faq' AND entita_id = q4 AND campo = 'risposta'), 'traduzioni conservate';

    -- 8. un gruppo tolto: via le sue domande e tutte le loro traduzioni (nessuna traduzione orfana)
    PERFORM fn_web_sito_faq_save(2, format('[{"id": %s, "nome": "Prima di partire", "domande": [{"id": %s, "domanda": "Bozza", "risposta": "<p>Pronta</p>", "attiva": true}]}]', g1, q2)::jsonb, 'test704');
    ASSERT NOT EXISTS (SELECT 1 FROM web_sito_faq WHERE web_sito_faq_id IN (q4, q1)), 'domande del gruppo tolto cancellate';
    ASSERT NOT EXISTS (SELECT 1 FROM web_traduzioni WHERE (entita = 'web_sito_faq' AND entita_id IN (q4, q1))
                                                     OR (entita = 'web_sito_faq_gruppi' AND entita_id = g2)), 'traduzioni orfane';

    -- 9. difese: identificativi di un'altra azienda, nome o domanda vuoti
    INSERT INTO web_sito_faq_gruppi (azienda_id, ordine, nome, updated_by) VALUES (6, 1, 'Altra azienda', 'test704')
    RETURNING web_sito_faq_gruppi_id INTO g6;
    BEGIN PERFORM fn_web_sito_faq_save(2, format('[{"id": %s, "nome": "Rubato", "domande": []}]', g6)::jsonb, 'test704');
          RAISE EXCEPTION 'gruppo di un''altra azienda accettato'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM LIKE '%accettato' THEN RAISE; END IF; END;
    ASSERT (SELECT nome FROM web_sito_faq_gruppi WHERE web_sito_faq_gruppi_id = g6) = 'Altra azienda', 'il gruppo dell''altra azienda non cambia';
    BEGIN PERFORM fn_web_sito_faq_save(2, '[{"nome": "  ", "domande": []}]'::jsonb, 'test704');
          RAISE EXCEPTION 'gruppo senza nome accettato'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM LIKE '%accettato' THEN RAISE; END IF; END;
    BEGIN PERFORM fn_web_sito_faq_save(2, '[{"nome": "G", "domande": [{"domanda": " ", "risposta": "<p>x</p>", "attiva": true}]}]'::jsonb, 'test704');
          RAISE EXCEPTION 'domanda vuota accettata'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM LIKE '%accettata' THEN RAISE; END IF; END;
    -- e il salvataggio di un'azienda non tocca le FAQ dell'altra
    ASSERT fn_web_sito_faq(6, 'IT') = '[]'::jsonb, 'azienda 6: il gruppo senza domande non si vede';
    ASSERT EXISTS (SELECT 1 FROM web_sito_faq_gruppi WHERE web_sito_faq_gruppi_id = g6), 'azienda 2 non cancella i gruppi della 6';

    -- 10. ogni modifica avvisa la coda (tutto il sito: «menu»): FAQ e loro traduzioni
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    PERFORM fn_web_sito_faq_save(2, format('[{"id": %s, "nome": "Prima di partire!", "domande": [{"id": %s, "domanda": "Bozza", "risposta": "<p>Pronta</p>", "attiva": true}]}]', g1, q2)::jsonb, 'test704');
    EXECUTE coda INTO v_n; ASSERT v_n = 1, 'salvataggio: coda ' || v_n;
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_faq', q2, 'risposta', 'FR', '<p>Prête</p>', 2, 'test704');
    EXECUTE coda INTO v_n; ASSERT v_n = 1, 'traduzione: coda ' || v_n;

    -- 11. permessi: la lettura al pubblico, salvataggio ed elenco del gestionale no
    CREATE ROLE test704_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test704_nessuno', salva, 'EXECUTE'), 'salvataggio eseguibile da chiunque';
    ASSERT NOT has_function_privilege('test704_nessuno', 'fn_web_sito_faq_list(integer)', 'EXECUTE'), 'elenco del gestionale a chiunque';
    ASSERT NOT has_function_privilege('test704_nessuno', 'fn_web_sito_faq(integer, character varying)', 'EXECUTE'), 'lettura a chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', salva, 'EXECUTE'), 'anon non salva';
        ASSERT NOT has_function_privilege('anon', 'fn_web_sito_faq_list(integer)', 'EXECUTE'), 'anon non vede l''elenco del gestionale';
        ASSERT has_function_privilege('anon', 'fn_web_sito_faq(integer, character varying)', 'EXECUTE'), 'anon legge le FAQ';
        ASSERT NOT has_table_privilege('anon', 'web_sito_faq', 'SELECT'), 'anon legge la tabella';
    END IF;
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_sito_faq'), 'SECURITY DEFINER';
    BEGIN PERFORM fn_web_sito_faq(2, 'XX'); RAISE EXCEPTION 'lingua inventata accettata';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM = 'lingua inventata accettata' THEN RAISE; END IF; END;

    RAISE NOTICE 'Test 704: OK';
END $$;
ROLLBACK;
