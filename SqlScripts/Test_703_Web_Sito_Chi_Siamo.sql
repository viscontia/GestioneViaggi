-- ============================================================================
-- Test dello script 703. Transazione annullata.
-- Prima dello script deve FALLIRE (le colonne e le funzioni non esistono).
-- ============================================================================
BEGIN;
-- (dal 705 la galleria si riempie da sola con le foto dei tour: qui si guarda l'elenco senza di lei)
DO $$
DECLARE
    salva  constant text := 'fn_web_sito_chi_siamo_save(integer, text, character varying)';
    foto   constant text := 'fn_web_sito_foto_chi_siamo_save(integer, integer, text, text, integer, integer, character varying)';
    v_j    jsonb;
    v_t0   timestamptz;
    v_p    text;
BEGIN
    -- 1. le colonne
    ASSERT (SELECT count(*) FROM information_schema.columns WHERE table_name = 'web_sito_contenuti'
             AND column_name IN ('chi_siamo', 'chi_siamo_aggiornato',
                                 'chi_siamo_foto1_url', 'chi_siamo_foto1_path', 'chi_siamo_foto1_larghezza', 'chi_siamo_foto1_altezza',
                                 'chi_siamo_foto2_url', 'chi_siamo_foto2_path', 'chi_siamo_foto2_larghezza', 'chi_siamo_foto2_altezza')) = 10,
        'mancano le colonne di Chi siamo';

    -- 2. si parte vuoti: la pagina non esiste (anche senza traduzioni: il test non dipende dai dati)
    DELETE FROM web_traduzioni WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND campo IN ('chi_siamo', 'note_legali', 'privacy', 'cookie');
    PERFORM fn_web_sito_testi_legali_save(2, NULL, NULL, NULL, 'test703');
    PERFORM fn_web_sito_chi_siamo_save(2, NULL, 'test703');
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, NULL, NULL, NULL, NULL, 'test703');
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 2, NULL, NULL, NULL, NULL, 'test703');
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '[]'::jsonb, 'senza testo: nessuna pagina, non ' || fn_web_sito_pagine(2)::text;
    ASSERT fn_web_sito_pagina(2, 'IT', 'chi_siamo') IS NULL, 'Chi siamo vuota: null';

    -- 3. le foto da sole non fanno esistere la pagina (serve il testo)
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/2/a.webp', 'libreria/2/a.webp', 2000, 1333, 'test703');
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '[]'::jsonb, 'solo foto, senza testo: nessuna pagina';

    -- 4. col testo esiste, prima delle pagine legali; l'HTML vuoto di Quill non conta
    PERFORM fn_web_sito_chi_siamo_save(2, '<p><br></p>', 'test703');
    ASSERT (SELECT chi_siamo FROM web_sito_contenuti WHERE azienda_id = 2) IS NULL, 'l''HTML vuoto di Quill diventa NULL';
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Chi siamo IT</p>', 'test703');
    PERFORM fn_web_sito_testi_legali_save(2, NULL, '<p>Privacy</p>', NULL, 'test703');
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '["chi_siamo", "privacy"]'::jsonb, 'ordine delle pagine: ' || fn_web_sito_pagine(2)::text;

    -- 4-bis. un «vuoto» scritto per un'altra strada (non dal salvataggio) non fa esistere la pagina
    UPDATE web_sito_contenuti SET chi_siamo = '<p><br></p> <p>&nbsp;</p>' WHERE azienda_id = 2;
    ASSERT (fn_web_sito_pagine(2) - 'galleria') = '["privacy"]'::jsonb, 'Chi siamo «vuota» non esiste: ' || fn_web_sito_pagine(2)::text;
    ASSERT fn_web_sito_pagina(2, 'IT', 'chi_siamo') IS NULL, 'Chi siamo «vuota»: null';
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Chi siamo IT</p>', 'test703');

    -- 5. la lettura: testo, lingua, data e le foto (solo indirizzo e misure, mai il percorso interno), in ordine
    v_j := fn_web_sito_pagina(2, 'IT', 'chi_siamo');
    ASSERT v_j->>'html' = '<p>Chi siamo IT</p>' AND v_j->>'lingua' = 'IT' AND (v_j->>'aggiornato') IS NOT NULL, 'Chi siamo IT: ' || v_j::text;
    ASSERT v_j->'foto' = '[{"url": "https://x/libreria/2/a.webp", "altezza": 1333, "larghezza": 2000}]'::jsonb, 'una foto: ' || (v_j->'foto')::text;
    ASSERT v_j::text NOT LIKE '%"libreria/2/a.webp"%', 'il percorso interno dello Storage non va al pubblico';
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 2, 'https://x/libreria/2/b.webp', 'libreria/2/b.webp', 1200, 1600, 'test703');
    ASSERT jsonb_array_length(fn_web_sito_pagina(2, 'IT', 'chi_siamo')->'foto') = 2, 'due foto';
    ASSERT fn_web_sito_pagina(2, 'IT', 'chi_siamo')->'foto'->1->>'url' = 'https://x/libreria/2/b.webp', 'la seconda è la 2';
    -- solo la seconda: la lista ha quella sola (la pagina regge senza la prima)
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, NULL, NULL, NULL, NULL, 'test703');
    ASSERT fn_web_sito_pagina(2, 'IT', 'chi_siamo')->'foto' = '[{"url": "https://x/libreria/2/b.webp", "altezza": 1600, "larghezza": 1200}]'::jsonb,
        'solo la seconda: ' || (fn_web_sito_pagina(2, 'IT', 'chi_siamo')->'foto')::text;
    -- le pagine legali non hanno la chiave delle foto (la loro forma non cambia)
    ASSERT NOT (fn_web_sito_pagina(2, 'IT', 'privacy') ? 'foto'), 'la privacy resta com''era';

    -- 6. la foto vecchia si restituisce (il gestionale la cancella dallo Storage): mai due volte, mai la nuova
    PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/2/c.webp', 'libreria/2/c.webp', 2000, 1333, 'test703');
    SELECT percorso INTO v_p FROM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/2/d.webp', 'libreria/2/d.webp', 2000, 1333, 'test703');
    ASSERT v_p = 'libreria/2/c.webp', 'restituita la foto vecchia, non ' || coalesce(v_p, 'niente');
    SELECT percorso INTO v_p FROM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/2/d.webp', 'libreria/2/d.webp', 2000, 1333, 'test703');
    ASSERT v_p IS NULL, 'stessa foto: niente da cancellare';
    SELECT percorso INTO v_p FROM fn_web_sito_foto_chi_siamo_save(2, 1, NULL, NULL, NULL, NULL, 'test703');
    ASSERT v_p = 'libreria/2/d.webp', 'tolta: si restituisce quella che c''era';
    -- cambiare la 1 non tocca la 2
    ASSERT (SELECT chi_siamo_foto2_path FROM web_sito_contenuti WHERE azienda_id = 2) = 'libreria/2/b.webp', 'la 2 resta';

    -- 7. difese: posizione, foto incompleta, foto di un'altra azienda
    BEGIN PERFORM fn_web_sito_foto_chi_siamo_save(2, 3, 'https://x/libreria/2/e.webp', 'libreria/2/e.webp', 10, 10, 'test703');
          RAISE EXCEPTION 'posizione 3 accettata'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM = 'posizione 3 accettata' THEN RAISE; END IF; END;
    BEGIN PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/2/e.webp', NULL, 10, 10, 'test703');
          RAISE EXCEPTION 'foto incompleta accettata'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM = 'foto incompleta accettata' THEN RAISE; END IF; END;
    BEGIN PERFORM fn_web_sito_foto_chi_siamo_save(2, 1, 'https://x/libreria/6/e.webp', 'libreria/6/e.webp', 10, 10, 'test703');
          RAISE EXCEPTION 'foto di un''altra azienda accettata'; EXCEPTION WHEN raise_exception THEN
          IF SQLERRM LIKE '%accettata' THEN RAISE; END IF; END;

    -- 8. tradotta: il testo della lingua; non tradotta o obsoleta: l'italiano, e la lettura lo dice
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_contenuti', 2, 'chi_siamo', 'DE', '<p>Über uns DE</p>', 2, 'test703')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo, obsoleto = false;
    v_j := fn_web_sito_pagina(2, 'DE', 'chi_siamo');
    ASSERT v_j->>'html' = '<p>Über uns DE</p>' AND v_j->>'lingua' = 'DE', 'DE tradotta: ' || v_j::text;
    ASSERT fn_web_sito_pagina(2, 'FR', 'chi_siamo')->>'lingua' = 'IT', 'FR non tradotta → italiano';
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND campo = 'chi_siamo' AND lingua = 'DE';
    ASSERT fn_web_sito_pagina(2, 'DE', 'chi_siamo')->>'lingua' = 'IT', 'traduzione obsoleta → italiano';

    -- 9. la data cambia solo se cambia il testo
    UPDATE web_sito_contenuti SET chi_siamo_aggiornato = now() - interval '10 days' WHERE azienda_id = 2;
    v_t0 := (SELECT chi_siamo_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2);
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Chi siamo IT</p>', 'test703');
    ASSERT (SELECT chi_siamo_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2) = v_t0, 'testo uguale: data uguale';
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Chi siamo IT nuovo</p>', 'test703');
    ASSERT (SELECT chi_siamo_aggiornato FROM web_sito_contenuti WHERE azienda_id = 2) > v_t0, 'testo cambiato: data nuova';

    -- 10. Chi siamo non tocca il resto della scheda, e viceversa
    PERFORM fn_web_sito_testi_legali_save(2, NULL, '<p>Privacy 2</p>', NULL, 'test703');
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Motto 703', 'Titolo 703', NULL, NULL, NULL, 'test703');
    ASSERT fn_web_sito_pagina(2, 'IT', 'chi_siamo')->>'html' = '<p>Chi siamo IT nuovo</p>', 'testi legali e Home non cancellano Chi siamo';
    PERFORM fn_web_sito_chi_siamo_save(2, '<p>Ancora</p>', 'test703');
    ASSERT fn_web_sito_pagina(2, 'IT', 'privacy')->>'html' = '<p>Privacy 2</p>', 'Chi siamo non cancella la privacy';
    ASSERT fn_web_sito_home(2, 'IT')->>'motto' = 'Motto 703', 'Chi siamo non cancella la Home';

    -- 11. pagina sconosciuta: errore (resta com'era)
    BEGIN PERFORM fn_web_sito_pagina(2, 'IT', 'galleria'); RAISE EXCEPTION 'pagina inventata accettata';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM = 'pagina inventata accettata' THEN RAISE; END IF; END;

    -- 12. permessi: la lettura al pubblico, i salvataggi solo al gestionale
    CREATE ROLE test703_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test703_nessuno', salva, 'EXECUTE'), 'salvataggio del testo eseguibile da chiunque';
    ASSERT NOT has_function_privilege('test703_nessuno', foto, 'EXECUTE'), 'salvataggio della foto eseguibile da chiunque';
    ASSERT NOT has_function_privilege('test703_nessuno', 'fn_web_sito_pagina(integer, character varying, character varying)', 'EXECUTE'), 'lettura a chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', salva, 'EXECUTE'), 'anon non salva il testo';
        ASSERT NOT has_function_privilege('anon', foto, 'EXECUTE'), 'anon non salva le foto';
        ASSERT has_function_privilege('anon', 'fn_web_sito_pagina(integer, character varying, character varying)', 'EXECUTE'), 'anon legge le pagine';
        ASSERT has_function_privilege('anon', 'fn_web_sito_pagine(integer)', 'EXECUTE'), 'anon legge l''elenco';
    END IF;
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_sito_pagina'), 'SECURITY DEFINER';

    RAISE NOTICE 'Test 703: OK';
END $$;
ROLLBACK;
