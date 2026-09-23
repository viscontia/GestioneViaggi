-- ============================================================================
-- Il sito pubblico, com'è il database oggi, non leggerebbe niente
--
-- OCCASIONE. Supabase ha annunciato che dal 30 ottobre le tabelle nuove in
-- `public` non riceveranno più i permessi automatici sulla Data API: serviranno
-- GRANT espliciti a `anon`/`authenticated`/`service_role`. La verifica ha
-- confermato che **a noi non cambia nulla** — nessuna delle nostre tabelle ha
-- mai avuto quei permessi, e non li vogliamo: il sito non legge tabelle, chiama
-- funzioni. Ma la stessa verifica ha fatto emergere un difetto vero.
--
-- IL DIFETTO. `fn_web_tour_pubblicati` e `fn_web_sezioni_tipologia` sono
-- SECURITY INVOKER: girano con i privilegi di chi chiama. Chiamate come `anon`,
-- cioè come le chiamerà il sito, rispondono:
--
--     ERROR 42501: permission denied for table ana_viaggi
--
-- Finora non se n'era accorto nessuno perché il gestionale si connette come
-- superuser e vede tutto. ⚠️ Il sito pubblico no.
--
-- LA CORREZIONE. Le funzioni di **lettura pubblica** diventano SECURITY DEFINER
-- con `search_path` fissato, esattamente come `fn_web_mezzi_occupati_data`
-- (script 479) e `fn_web_recensioni_config`, che erano già state scritte così.
-- È sicuro perché ognuna riceve `p_azienda_id`, filtra da sé, e restituisce solo
-- contenuti editoriali già destinati alla pubblicazione: nessun dato personale.
--
-- ⚠️ REGOLA, da qui in avanti: **ogni funzione che il sito pubblico chiama deve
-- nascere SECURITY DEFINER con `SET search_path = public, pg_temp`**, e nessuna
-- funzione di scrittura deve essere raggiungibile da `anon`.
--
-- LA SECONDA PARTE. In PostgreSQL una funzione appena creata ha EXECUTE per
-- PUBLIC: `anon` può quindi **chiamare** anche le funzioni di servizio della
-- coda di rigenerazione. Oggi non combinano niente (sono INVOKER e `anon` non ha
-- privilegi sulle tabelle), ma è una protezione che vive per caso. Qui il
-- permesso viene tolto per davvero.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Lettura pubblica: SECURITY DEFINER + search_path fissato
--    ALTER e non CREATE OR REPLACE: il corpo non si tocca, cambia solo il modo
--    in cui la funzione viene eseguita.
-- ============================================================================

ALTER FUNCTION fn_web_tour_pubblicati(integer, character)
    SECURITY DEFINER SET search_path = public, pg_temp;

ALTER FUNCTION fn_web_sezioni_tipologia(integer, character)
    SECURITY DEFINER SET search_path = public, pg_temp;

ALTER FUNCTION fn_web_ha_tour_brevi_pubblicati(integer)
    SECURITY DEFINER SET search_path = public, pg_temp;

ALTER FUNCTION fn_web_tour_pubblicati_nome_sezione(bigint, character, character varying)
    SECURITY DEFINER SET search_path = public, pg_temp;

-- Le funzioni annidate (fn_web_prezzo_da_data, fn_web_mezzi_occupati_data,
-- fn_web_traduzioni_list_by_entita_global) non vanno toccate: dentro una
-- SECURITY DEFINER girano già con i privilegi del proprietario.

-- ============================================================================
-- 2) I permessi espliciti, al posto del default
-- ============================================================================

DO $$
DECLARE
    v_fn TEXT;
    v_lettori TEXT[];
    v_servitori TEXT[];
    v_letture TEXT[] := ARRAY[
        'fn_web_tour_pubblicati(integer, character)',
        'fn_web_sezioni_tipologia(integer, character)',
        'fn_web_ha_tour_brevi_pubblicati(integer)',
        'fn_web_tour_pubblicati_nome_sezione(bigint, character, character varying)'
    ];
    -- Funzioni di servizio della coda: le usa l'ascoltatore, mai il browser.
    v_servizio TEXT[] := ARRAY[
        'fn_web_revalidate_accoda(integer, character varying, bigint, character varying)',
        'fn_web_revalidate_prossimi(integer)',
        'fn_web_revalidate_completa(bigint[])',
        'fn_web_revalidate_fallita(bigint, text)',
        'fn_web_revalidate_pulisci(integer)'
    ];
BEGIN
    -- ⚠️ I ruoli di Supabase non ci sono tutti in locale: il database di
    -- sviluppo ha `anon` ma non `authenticated` né `service_role`. Si concede
    -- solo ai ruoli che esistono davvero, così lo stesso script gira in
    -- entrambi i posti senza diventare due script diversi.
    SELECT array_agg(r) INTO v_lettori
      FROM unnest(ARRAY['anon','authenticated','service_role']) r
     WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r);

    SELECT array_agg(r) INTO v_servitori
      FROM unnest(ARRAY['service_role']) r
     WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r);

    FOREACH v_fn IN ARRAY v_letture LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_fn);
        IF v_lettori IS NOT NULL THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %s',
                           v_fn, array_to_string(v_lettori, ', '));
        END IF;
    END LOOP;

    FOREACH v_fn IN ARRAY v_servizio LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_fn);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', v_fn);
        END IF;
        IF v_servitori IS NOT NULL THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %s',
                           v_fn, array_to_string(v_servitori, ', '));
        END IF;
    END LOOP;
END $$;

COMMIT;

-- ============================================================================
-- Verifica — le due domande che contano.
--
-- 1. Il sito legge?
--      SET ROLE anon;
--      SELECT COUNT(*) FROM fn_web_tour_pubblicati(2, 'IT');
--      SELECT * FROM fn_web_sezioni_tipologia(2, 'IT');
--      RESET ROLE;
--    atteso: righe, nessun «permission denied».
--
-- 2. Il sito NON scrive?
--      SET ROLE anon;
--      SELECT fn_web_revalidate_prossimi(1);   -- atteso: permission denied for function
--      RESET ROLE;
-- ============================================================================
