-- ============================================================================
-- Test dello script 679. Transazione annullata: niente resta nella coda.
-- ============================================================================
BEGIN;
DO $$
BEGIN
    -- 1. il ruolo esiste e non è superuser
    ASSERT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_rigenera' AND NOT rolsuper AND NOT rolbypassrls),
        '1: ruolo sito_rigenera';
    -- 2. vede lo schema e può chiamare le quattro funzioni della coda
    ASSERT has_schema_privilege('sito_rigenera', 'public', 'USAGE'), '2: USAGE sullo schema public';
    ASSERT has_function_privilege('sito_rigenera', 'fn_web_revalidate_prossimi(integer,integer)', 'EXECUTE'), '2: prossimi';
    ASSERT has_function_privilege('sito_rigenera', 'fn_web_revalidate_completa(bigint[])', 'EXECUTE'), '2: completa';
    ASSERT has_function_privilege('sito_rigenera', 'fn_web_revalidate_fallita(bigint,text)', 'EXECUTE'), '2: fallita';
    ASSERT has_function_privilege('sito_rigenera', 'fn_web_revalidate_pulisci(integer)', 'EXECUTE'), '2: pulisci';
    -- 3. e nient'altro: niente clienti, niente coda diretta, non accoda, non legge i tour
    ASSERT NOT has_table_privilege('sito_rigenera', 'ana_clienti', 'SELECT'), '3: legge i clienti';
    ASSERT NOT has_table_privilege('sito_rigenera', 'web_revalidate_coda', 'SELECT'), '3: legge la tabella della coda';
    ASSERT NOT has_function_privilege('sito_rigenera', 'fn_web_revalidate_accoda(integer,character varying,bigint,character varying)', 'EXECUTE'), '3: può accodare';
    ASSERT NOT has_function_privilege('sito_rigenera', 'fn_web_tour_pubblicati(integer,character)', 'EXECUTE'), '3: legge i tour';
    -- 4. le funzioni della coda non sono più di tutti
    ASSERT NOT has_function_privilege('public', 'fn_web_revalidate_prossimi(integer,integer)', 'EXECUTE'), '4: prossimi aperta a PUBLIC';
    ASSERT NOT has_function_privilege('public', 'fn_web_revalidate_completa(bigint[])', 'EXECUTE'), '4: completa aperta a PUBLIC';
    -- 5. girano coi diritti del proprietario e search_path fissato
    ASSERT (SELECT bool_and(prosecdef AND proconfig::text LIKE '%search_path%') FROM pg_proc
             WHERE proname IN ('fn_web_revalidate_prossimi','fn_web_revalidate_completa',
                               'fn_web_revalidate_fallita','fn_web_revalidate_pulisci')), '5: SECURITY DEFINER e search_path';
    -- 6. la vecchia firma senza azienda non esiste più
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid::regprocedure::text = 'fn_web_revalidate_prossimi(integer)'), '6: vecchia firma';
    -- 7. il filtro per azienda: una riga dell'azienda 999 non esce chiedendo l'azienda 2
    PERFORM fn_web_revalidate_accoda(999, 'menu', NULL, 'test_679');
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_revalidate_prossimi(500, 2) WHERE azienda_id = 999), '7: filtro azienda';
    ASSERT EXISTS (SELECT 1 FROM fn_web_revalidate_prossimi(500, 999)), '7: la riga 999 esce chiedendo la 999';
    RAISE NOTICE 'Test 679: controlli OK';
END $$;

-- 8. come sito_rigenera le chiamate funzionano davvero
SELECT fn_web_revalidate_accoda(999, 'menu', NULL, 'test_679_bis');
SET ROLE sito_rigenera;
SELECT 'come sito_rigenera: righe prese = ' || count(*) AS prova FROM fn_web_revalidate_prossimi(500, 999);
SELECT 'come sito_rigenera: completate = ' || fn_web_revalidate_completa(ARRAY(SELECT 0::bigint)) AS prova;
RESET ROLE;
ROLLBACK;
