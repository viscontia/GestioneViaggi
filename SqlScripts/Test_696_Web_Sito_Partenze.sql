-- ============================================================================
-- Test dello script 696. Transazione annullata.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_j   jsonb;
    v_n   integer;
    f     constant text := 'fn_web_sito_partenze(integer, character varying)';
BEGIN
    -- pochi tour pubblicati in locale: se ne pubblicano altri fra le bozze con partenza futura
    IF (SELECT count(*) FROM fn_web_tour_pubblicati(2, 'IT')) < 3 THEN
        UPDATE web_tour_contenuti c SET stato_pubblicazione = 'pubblicato'
         WHERE c.web_tour_contenuti_id IN (
               SELECT c2.web_tour_contenuti_id FROM web_tour_contenuti c2
                 JOIN ana_date_viaggi dv ON dv.data_viaggio_id = c2.data_viaggio_id_fk
                WHERE c2.azienda_id = 2 AND c2.stato_pubblicazione <> 'pubblicato' AND dv.data_viaggio_data_inizio > CURRENT_DATE
                ORDER BY c2.web_tour_contenuti_id LIMIT 3);
    END IF;

    -- 1. le stesse partenze di fn_web_tour_pubblicati (una definizione sola di «pubblicato»)
    v_j := fn_web_sito_partenze(2, 'IT');
    ASSERT jsonb_array_length(v_j) = (SELECT count(*) FROM fn_web_tour_pubblicati(2, 'IT')), 'le stesse partenze dei pubblicati';
    ASSERT jsonb_array_length(v_j) >= 3, 'servono almeno 3 partenze per provare l''ordine';

    -- 2. in ordine di data di partenza (poi titolo), non nell'ordine del catalogo
    SELECT count(*) INTO v_n FROM (
        SELECT (e->>'data_inizio')::date AS d, e->>'titolo' AS t,
               lag((e->>'data_inizio')::date) OVER (ORDER BY o) AS d_prima, lag(e->>'titolo') OVER (ORDER BY o) AS t_prima
          FROM jsonb_array_elements(v_j) WITH ORDINALITY AS x(e, o)) z
     WHERE d < d_prima OR (d = d_prima AND t < t_prima);
    ASSERT v_n = 0, 'le partenze sono in ordine di data';
    -- (il catalogo resta nel suo ordine: qui si prova che la funzione riordina davvero)
    UPDATE web_tour_contenuti SET ordine = -ordine WHERE azienda_id = 2;
    ASSERT (SELECT array_agg(e->>'contenuto_id' ORDER BY o) FROM jsonb_array_elements(fn_web_sito_partenze(2, 'IT')) WITH ORDINALITY AS x(e, o))
         = (SELECT array_agg(e->>'contenuto_id' ORDER BY o) FROM jsonb_array_elements(v_j) WITH ORDINALITY AS x(e, o)),
        'l''ordine del catalogo non cambia le partenze';

    -- 3. i campi delle card (gli stessi di fn_web_tour_pubblicati), tradotti
    ASSERT v_j->0 ? 'prezzo_da' AND v_j->0 ? 'posti_stato' AND v_j->0 ? 'descrizione_slug' AND v_j->0 ? 'durata_testo', 'campi delle card';
    ASSERT (SELECT bool_and(e->>'titolo' IS NOT NULL) FROM jsonb_array_elements(fn_web_sito_partenze(2, 'EN')) e), 'titoli in inglese';

    -- 4. lingua controllata; nessuna partenza → elenco vuoto, non null
    BEGIN
        PERFORM fn_web_sito_partenze(2, 'PT');
        RAISE EXCEPTION 'lingua PT accettata';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM LIKE 'lingua PT accettata' THEN RAISE; END IF;
    END;
    ASSERT fn_web_sito_partenze(999999, 'IT') = '[]'::jsonb, 'azienda senza partenze: []';

    -- 5. permessi: solo anon/authenticated, SECURITY DEFINER, search_path fissato
    ASSERT (SELECT prosecdef FROM pg_proc WHERE oid = f::regprocedure), 'SECURITY DEFINER';
    ASSERT (SELECT array_to_string(proconfig, ',') LIKE '%search_path=public, pg_temp%' FROM pg_proc WHERE oid = f::regprocedure), 'search_path';
    CREATE ROLE test696_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test696_nessuno', f, 'EXECUTE'), 'non eseguibile da chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT has_function_privilege('anon', f, 'EXECUTE'), 'anon deve poterla chiamare';
    END IF;

    RAISE NOTICE 'Test 696: OK';
END $$;
ROLLBACK;
