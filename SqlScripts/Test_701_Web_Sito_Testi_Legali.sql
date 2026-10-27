-- ============================================================================
-- Test dello script 701. Transazione annullata.
-- Prima dello script deve FALLIRE (le colonne e le funzioni non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    salva  constant text := 'fn_web_sito_testi_legali_save(integer, text, text, text, character varying)';
    v_j    jsonb;
    v_t0   timestamptz;
    v_az   integer;
BEGIN
    -- 1. le colonne
    ASSERT (SELECT count(*) FROM information_schema.columns WHERE table_name = 'web_sito_contenuti'
             AND column_name IN ('note_legali', 'privacy', 'cookie', 'note_legali_aggiornato', 'privacy_aggiornato', 'cookie_aggiornato')) = 6,
        'mancano le colonne dei testi legali';

    -- 2. si parte vuoti: nessuna pagina legale esiste; leggerne una dà null. Anche senza traduzioni (dal 2026-10-25
    --    ci sono i testi provvisori tradotti: il test non deve dipendere dai dati; la transazione si annulla)
    DELETE FROM web_traduzioni WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND campo IN ('note_legali', 'privacy', 'cookie');
    PERFORM fn_web_sito_testi_legali_save(2, NULL, NULL, NULL, 'test701');
    ASSERT fn_web_sito_pagine(2) = '[]'::jsonb, 'senza testi: nessuna pagina, non ' || fn_web_sito_pagine(2)::text;
    ASSERT fn_web_sito_pagina(2, 'IT', 'privacy') IS NULL, 'pagina vuota: null';

    -- 3. salvati due testi: esistono quelle due pagine, in un ordine fisso; l'HTML vuoto di Quill non conta
    PERFORM fn_web_sito_testi_legali_save(2, '<p>Note IT</p>', '<p>Privacy IT</p>', '<p><br></p>', 'test701');
    ASSERT fn_web_sito_pagine(2) = '["note_legali", "privacy"]'::jsonb, 'pagine: ' || fn_web_sito_pagine(2)::text;
    ASSERT (SELECT cookie FROM web_sito_contenuti WHERE azienda_id = 2) IS NULL, 'l''HTML vuoto di Quill diventa NULL';
    v_j := fn_web_sito_pagina(2, 'IT', 'privacy');
    ASSERT v_j->>'html' = '<p>Privacy IT</p>' AND v_j->>'lingua' = 'IT' AND (v_j->>'aggiornato') IS NOT NULL, 'privacy IT: ' || v_j::text;

    -- 3-bis. un «vuoto» arrivato per un'altra strada (scritto direttamente, non dal salvataggio) non fa esistere la pagina
    UPDATE web_sito_contenuti SET cookie = '<p><br></p> <p>&nbsp;</p>' WHERE azienda_id = 2;
    ASSERT fn_web_sito_pagine(2) = '["note_legali", "privacy"]'::jsonb, 'un cookie «vuoto» non esiste: ' || fn_web_sito_pagine(2)::text;
    ASSERT fn_web_sito_pagina(2, 'IT', 'cookie') IS NULL, 'pagina cookie «vuota»: null';
    UPDATE web_sito_contenuti SET cookie = NULL WHERE azienda_id = 2;

    -- 4. tradotta: il testo della lingua; non tradotta: l'italiano, e la lettura lo dice (lingua = IT)
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_contenuti', 2, 'privacy', 'DE', '<p>Datenschutz DE</p>', 2, 'test701')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo, obsoleto = false;
    v_j := fn_web_sito_pagina(2, 'DE', 'privacy');
    ASSERT v_j->>'html' = '<p>Datenschutz DE</p>' AND v_j->>'lingua' = 'DE', 'privacy DE tradotta: ' || v_j::text;
    v_j := fn_web_sito_pagina(2, 'FR', 'privacy');
    ASSERT v_j->>'html' = '<p>Privacy IT</p>' AND v_j->>'lingua' = 'IT', 'privacy FR non tradotta → italiano: ' || v_j::text;
    -- una traduzione obsoleta non si mostra
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND campo = 'privacy' AND lingua = 'DE';
    ASSERT fn_web_sito_pagina(2, 'DE', 'privacy')->>'lingua' = 'IT', 'traduzione obsoleta → italiano';

    -- 5. la data dell'ultimo aggiornamento cambia solo se cambia QUEL testo
    UPDATE web_sito_contenuti SET privacy_aggiornato = now() - interval '10 days' WHERE azienda_id = 2;
    v_t0 := (SELECT privacy_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2);
    PERFORM fn_web_sito_testi_legali_save(2, '<p>Note IT cambiate</p>', '<p>Privacy IT</p>', NULL, 'test701');
    ASSERT (SELECT privacy_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2) = v_t0, 'privacy invariata: data invariata';
    PERFORM fn_web_sito_testi_legali_save(2, '<p>Note IT cambiate</p>', '<p>Privacy IT nuova</p>', NULL, 'test701');
    ASSERT (SELECT privacy_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2) > v_t0, 'privacy cambiata: data nuova';

    -- 6. i testi legali non toccano il resto della scheda, e viceversa
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Motto 701', 'Titolo 701', NULL, NULL, NULL, 'test701');
    ASSERT fn_web_sito_pagina(2, 'IT', 'note_legali')->>'html' = '<p>Note IT cambiate</p>', 'la scheda Home non cancella i testi legali';
    ASSERT fn_web_sito_home(2, 'IT')->>'motto' = 'Motto 701', 'i testi legali non cancellano la Home';

    -- 7. una pagina che non esiste, una lingua sbagliata: errore (non un null silenzioso)
    BEGIN
        PERFORM fn_web_sito_pagina(2, 'IT', 'segreti');
        RAISE EXCEPTION 'accettata la pagina «segreti»';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettata%' THEN RAISE; END IF; END;
    BEGIN
        PERFORM fn_web_sito_pagina(2, 'PT', 'privacy');
        RAISE EXCEPTION 'accettata la lingua PT';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettata%' THEN RAISE; END IF; END;

    -- 8. un'altra azienda: le sue pagine sono le sue
    SELECT a.azienda_id INTO v_az FROM ana_aziende a WHERE a.azienda_id <> 2 ORDER BY 1 LIMIT 1;
    PERFORM fn_web_sito_testi_legali_save(v_az, NULL, NULL, '<p>Cookie altra</p>', 'test701');
    ASSERT fn_web_sito_pagine(v_az) = '["cookie"]'::jsonb, 'pagine dell''altra azienda';
    ASSERT fn_web_sito_pagina(2, 'IT', 'cookie') IS NULL, 'il cookie dell''altra azienda non è dell''azienda 2';

    -- 9. cambiare un testo legale avvisa la coda (il trigger della 692)
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    PERFORM fn_web_sito_testi_legali_save(2, '<p>Note IT ancora</p>', '<p>Privacy IT nuova</p>', NULL, 'test701');
    ASSERT EXISTS (SELECT 1 FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL), 'coda avvisata';

    -- 10. permessi: le letture al pubblico, il salvataggio solo al gestionale
    CREATE ROLE test701_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test701_nessuno', salva, 'EXECUTE'), 'salvataggio eseguibile da chiunque';
    ASSERT NOT has_function_privilege('test701_nessuno', 'fn_web_sito_pagina(integer, character varying, character varying)', 'EXECUTE'), 'lettura a chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', salva, 'EXECUTE'), 'anon non salva';
        ASSERT has_function_privilege('anon', 'fn_web_sito_pagina(integer, character varying, character varying)', 'EXECUTE'), 'anon legge le pagine';
        ASSERT has_function_privilege('anon', 'fn_web_sito_pagine(integer)', 'EXECUTE'), 'anon legge l''elenco';
    END IF;
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_sito_pagina'), 'SECURITY DEFINER';

    RAISE NOTICE 'Test 701: OK';
END $$;
ROLLBACK;
