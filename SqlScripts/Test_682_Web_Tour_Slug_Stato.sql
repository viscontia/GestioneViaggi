-- ============================================================================
-- Test dello script 682. Transazione annullata: i dati costruiti qui spariscono.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- Il viaggio di prova è quello del Ponte dell'Immacolata (741), pubblicato sia in
-- locale sia in PROD: se un giorno non lo fosse più, il test lo dice.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    r record;
    v_viaggio  integer := 741;
    v_ponte    varchar;
    v_sezione  varchar;
    v_data_b   integer;
    v_data_c   integer;
    v_n        integer;
BEGIN
    SELECT p.slug, p.descrizione_slug INTO v_ponte, v_sezione
      FROM fn_web_tour_pubblicati(2, 'IT') p WHERE p.viaggio_id = v_viaggio;
    ASSERT v_ponte IS NOT NULL, 'il viaggio di prova 741 deve essere pubblicato';

    -- 1. dati veri: ogni pubblicato è «pubblicato» con la sua sezione
    FOR r IN SELECT p.slug, p.descrizione_slug FROM fn_web_tour_pubblicati(2, 'IT') p LOOP
        ASSERT EXISTS (SELECT 1 FROM fn_web_tour_slug_stato(2) s
                        WHERE s.slug = r.slug AND s.stato = 'pubblicato' AND s.sezione_slug IS NOT DISTINCT FROM r.descrizione_slug
                          AND s.slug_nuovo IS NULL),
            'pubblicato mancante o sbagliato: ' || r.slug;
    END LOOP;
    -- le schede mai pubblicate non compaiono (il loro indirizzo non è mai stato pubblico)
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_tour_slug_stato(2) s JOIN web_tour_contenuti c
                         ON c.slug = s.slug AND c.azienda_id = 2 WHERE c.data_pubblicazione IS NULL),
        'una scheda mai pubblicata non deve comparire';
    ASSERT (SELECT count(*) FROM fn_web_tour_slug_stato(2)) = (SELECT count(DISTINCT slug) FROM fn_web_tour_slug_stato(2)),
        'nessuno slug due volte';

    -- 2. seconda edizione pubblicata (fra un anno), la prima archiviata → «sostituito»
    INSERT INTO ana_date_viaggi (viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine,
                                 data_viaggio_costo_pilota, data_viaggio_costo_passeggero, created_by, azienda_id)
    VALUES (v_viaggio, current_date + 365, current_date + 369, 1, 1, 'test682', 2) RETURNING data_viaggio_id INTO v_data_b;
    INSERT INTO web_tour_contenuti (azienda_id, viaggio_id_fk, data_viaggio_id_fk, slug, stato_pubblicazione, data_pubblicazione)
    VALUES (2, v_viaggio, v_data_b, 'prova-682-b', 'pubblicato', now());
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'archiviato' WHERE azienda_id = 2 AND slug = v_ponte;

    SELECT * INTO r FROM fn_web_tour_slug_stato(2) s WHERE s.slug = v_ponte;
    ASSERT r.stato = 'sostituito', 'atteso sostituito, ottenuto ' || coalesce(r.stato, 'niente');
    ASSERT r.slug_nuovo = 'prova-682-b' AND r.sezione_nuova = v_sezione, 'sostituito verso la nuova edizione e la sua sezione';
    ASSERT (SELECT stato FROM fn_web_tour_slug_stato(2) WHERE slug = 'prova-682-b') = 'pubblicato', 'la nuova è pubblicata';

    -- 3. una terza edizione con la partenza PIÙ VICINA: la sostituzione punta a lei
    INSERT INTO ana_date_viaggi (viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine,
                                 data_viaggio_costo_pilota, data_viaggio_costo_passeggero, created_by, azienda_id)
    VALUES (v_viaggio, current_date + 200, current_date + 204, 1, 1, 'test682', 2) RETURNING data_viaggio_id INTO v_data_c;
    INSERT INTO web_tour_contenuti (azienda_id, viaggio_id_fk, data_viaggio_id_fk, slug, stato_pubblicazione, data_pubblicazione)
    VALUES (2, v_viaggio, v_data_c, 'prova-682-c', 'pubblicato', now());
    ASSERT (SELECT slug_nuovo FROM fn_web_tour_slug_stato(2) WHERE slug = v_ponte) = 'prova-682-c',
        'la sostituzione deve puntare alla partenza più vicina';

    -- 4. tutte le edizioni archiviate → «ritirato», con la sua sezione per il link
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'archiviato' WHERE azienda_id = 2 AND slug IN ('prova-682-b', 'prova-682-c');
    FOR r IN SELECT * FROM fn_web_tour_slug_stato(2) s WHERE s.slug IN (v_ponte, 'prova-682-b', 'prova-682-c') LOOP
        ASSERT r.stato = 'ritirato' AND r.slug_nuovo IS NULL AND r.sezione_slug = v_sezione,
            'atteso ritirato con la sezione: ' || r.slug || ' → ' || r.stato;
    END LOOP;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    -- 5. un'azienda che non c'è: nessuna riga; e mai righe di un'altra azienda
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_tour_slug_stato(999999)), 'azienda inesistente: nessuna riga';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_tour_slug_stato(2) s JOIN web_tour_contenuti c ON c.slug = s.slug
                        WHERE c.azienda_id <> 2 AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c2 WHERE c2.slug = s.slug AND c2.azienda_id = 2)),
        'mai slug di un''altra azienda';

    -- 6. forma e permessi: lettura pubblica come le altre fn_web_* del sito
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_tour_slug_stato'), 'deve essere SECURITY DEFINER';
    ASSERT (SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE proname = 'fn_web_tour_slug_stato') LIKE '%search_path%',
        'search_path fissato';
    ASSERT has_function_privilege('anon', 'fn_web_tour_slug_stato(integer)', 'EXECUTE'), 'anon deve poterla chiamare';

    RAISE NOTICE 'Test 682: OK';
END $$;
ROLLBACK;
