-- ============================================================================
-- Test dello script 708. Transazione annullata: nessun dato resta.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_az2  integer := 2;
    v_az   integer := (SELECT min(azienda_id) FROM ana_aziende WHERE azienda_id <> 2);   -- un'altra azienda
    v_dv   integer := (SELECT min(data_viaggio_id) FROM ana_date_viaggi WHERE azienda_id = 2);
    v_dv2  integer := (SELECT max(data_viaggio_id) FROM ana_date_viaggi WHERE azienda_id = 2);
    v_dal  timestamptz := date_trunc('day', now()) - interval '7 days';
    v_al   timestamptz := date_trunc('day', now());
    v_imp  char(64) := repeat('a', 64);
    j      jsonb;
    t      jsonb;
BEGIN
    ASSERT v_dv IS NOT NULL AND v_dv2 IS NOT NULL AND v_dv <> v_dv2, 'servono due date di viaggio dell''azienda 2';
    DELETE FROM web_iscrizione_arrivi;
    DELETE FROM web_pdf_richieste;
    DELETE FROM web_newsletter_iscritti WHERE email ILIKE '%@prova708.test';
    DELETE FROM web_newsletter_soppressioni WHERE email ILIKE '%@prova708.test';

    -- arrivi: 3 nella settimana sulla prima data (2 conclusi, uno di questi concluso DOPO la settimana), 1 sulla
    -- seconda; fuori: uno prima della settimana (ma concluso dentro, sulla seconda data), uno dopo, uno dell'altra azienda
    INSERT INTO web_iscrizione_arrivi (azienda_id, data_viaggio_id, provenienza, impronta, arrivato_il, concluso_il) VALUES
        (v_az2, v_dv,  'sito', v_imp, v_dal + interval '1 day',  v_dal + interval '1 day 1 hour'),
        (v_az2, v_dv,  'sito', v_imp, v_dal + interval '2 days', v_al + interval '1 hour'),
        (v_az2, v_dv,  'sito', v_imp, v_dal + interval '3 days', NULL),
        (v_az2, v_dv2, 'sito', v_imp, v_al - interval '1 second', NULL),
        (v_az2, v_dv2, 'sito', v_imp, v_dal - interval '1 second', v_dal + interval '2 hours'),   -- arrivo prima, concluso dentro
        (v_az2, v_dv,  'sito', v_imp, v_al, NULL);
    IF v_az IS NOT NULL AND EXISTS (SELECT 1 FROM ana_date_viaggi WHERE azienda_id = v_az) THEN
        INSERT INTO web_iscrizione_arrivi (azienda_id, data_viaggio_id, provenienza, impronta, arrivato_il)
        VALUES (v_az, (SELECT min(data_viaggio_id) FROM ana_date_viaggi WHERE azienda_id = v_az), 'sito', v_imp, v_dal + interval '1 day');
    END IF;

    -- PDF: 2 sulla seconda data, 1 sulla prima proprio all'inizio della settimana (dentro), 1 alla fine (fuori)
    INSERT INTO web_pdf_richieste (azienda_id, data_viaggio_id, lingua, impronta, richiesta_il) VALUES
        (v_az2, v_dv2, 'IT', v_imp, v_dal + interval '1 day'),
        (v_az2, v_dv2, 'DE', v_imp, v_dal + interval '2 days'),
        (v_az2, v_dv,  'FR', v_imp, v_dal),
        (v_az2, v_dv,  'IT', v_imp, v_al);

    -- newsletter: 2 confermati dal sito nella settimana (uno poi disiscritto), 1 confermato prima, 1 in attesa,
    -- 1 attivo da un'altra fonte; disiscritti dal sito: 1 nella settimana, 1 prima; 1 soppresso per un altro motivo
    INSERT INTO web_newsletter_iscritti (azienda_id, email, lingua, stato, consenso, consenso_fonte, conferma_usata, created_by, token_disiscrizione) VALUES
        (v_az2, 'a@prova708.test', 'IT', 'attivo',      true,  'sito, doppio consenso', v_dal + interval '1 day', 'test', md5(random()::text)),
        (v_az2, 'b@prova708.test', 'DE', 'disiscritto', false, 'sito, doppio consenso', v_dal + interval '2 days', 'test', md5(random()::text)),
        (v_az2, 'c@prova708.test', 'IT', 'attivo',      true,  'sito, doppio consenso', v_dal - interval '1 day', 'test', md5(random()::text)),
        (v_az2, 'd@prova708.test', 'IT', 'in_attesa',   false, NULL, NULL, 'test', md5(random()::text)),
        (v_az2, 'e@prova708.test', 'IT', 'attivo',      true,  'gestionale', NULL, 'test', md5(random()::text)),
        (v_az2, 'h@prova708.test', 'IT', 'attivo',      true,  'gestionale', v_dal + interval '1 day', 'test', md5(random()::text));
    INSERT INTO web_newsletter_soppressioni (azienda_id, email, motivo, created_by, created) VALUES
        (v_az2, 'b@prova708.test', 'disiscritto dal sito', 'sito', v_dal + interval '3 days'),
        (v_az2, 'f@prova708.test', 'disiscritto dal sito', 'sito', v_dal - interval '1 day'),
        (v_az2, 'g@prova708.test', 'rimbalzo',             'test', v_dal + interval '3 days');

    j := fn_web_statistiche_settimana(v_az2, v_dal, v_al);

    -- totali: arrivi 4 (nella settimana), conclusi 2 (concluso_il nella settimana), PDF 3
    ASSERT (j->'totali') = '{"arrivi": 4, "conclusi": 2, "pdf": 3}'::jsonb, 'totali: ' || (j->'totali')::text;
    ASSERT (j->'newsletter') = '{"nuovi": 2, "disiscritti": 1}'::jsonb, 'newsletter: ' || (j->'newsletter')::text;

    -- per edizione, in ordine di arrivi: la prima data (3 arrivi, 2 conclusi), poi la seconda (1, 0); titolo leggibile e data
    ASSERT jsonb_array_length(j->'tour') = 2, 'due edizioni: ' || (j->'tour')::text;
    t := j->'tour'->0;
    ASSERT (t->>'data_viaggio_id')::int = v_dv AND (t->>'arrivi')::int = 3 AND (t->>'conclusi')::int = 1 AND (t->>'pdf')::int = 1,
           'prima edizione: ' || t::text;
    ASSERT t->>'titolo' = (SELECT fn_web_titolo_leggibile(v.viaggio_descrizione_breve) FROM ana_date_viaggi d
                             JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk WHERE d.data_viaggio_id = v_dv), 'titolo leggibile';
    ASSERT (t->>'partenza')::date = (SELECT data_viaggio_data_inizio::date FROM ana_date_viaggi WHERE data_viaggio_id = v_dv), 'partenza';
    t := j->'tour'->1;
    ASSERT (t->>'data_viaggio_id')::int = v_dv2 AND (t->>'arrivi')::int = 1 AND (t->>'conclusi')::int = 1 AND (t->>'pdf')::int = 2,
           'seconda edizione: ' || t::text;

    -- una settimana vuota: zeri e nessuna edizione
    j := fn_web_statistiche_settimana(v_az2, v_dal - interval '1 year', v_dal - interval '51 weeks');
    ASSERT j = '{"totali": {"arrivi": 0, "conclusi": 0, "pdf": 0}, "newsletter": {"nuovi": 0, "disiscritti": 0}, "tour": []}'::jsonb,
           'settimana vuota: ' || j::text;

    -- intervallo al contrario: errore
    BEGIN
        PERFORM fn_web_statistiche_settimana(v_az2, v_al, v_dal);
        RAISE EXCEPTION 'doveva fallire';
    EXCEPTION WHEN raise_exception THEN
        ASSERT SQLERRM LIKE 'Intervallo%', 'messaggio: ' || SQLERRM;
    END;

    -- permessi: solo il guardiano (in PROD una funzione nuova nasce eseguibile da chiunque)
    ASSERT has_function_privilege('sito_guardiano', 'fn_web_statistiche_settimana(integer, timestamptz, timestamptz)', 'EXECUTE'), 'guardiano';
    ASSERT NOT has_function_privilege('public', 'fn_web_statistiche_settimana(integer, timestamptz, timestamptz)', 'EXECUTE'), 'public';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', 'fn_web_statistiche_settimana(integer, timestamptz, timestamptz)', 'EXECUTE'), 'anon';
        ASSERT NOT has_function_privilege('authenticated', 'fn_web_statistiche_settimana(integer, timestamptz, timestamptz)', 'EXECUTE'), 'authenticated';
    END IF;
    ASSERT NOT has_function_privilege('sito_posta', 'fn_web_statistiche_settimana(integer, timestamptz, timestamptz)', 'EXECUTE'), 'sito_posta no';

    RAISE NOTICE 'Test 708: tutto ok';
END $$;
ROLLBACK;
