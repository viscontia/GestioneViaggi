-- ============================================================================
-- Test dello script 683. Transazione annullata: i dati costruiti qui spariscono.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    r       record;
    t       record;
    s       jsonb;
    v_n     integer;
    v_slug  varchar;
    v_cont  bigint;
    v_giorn bigint;
    v_data  integer;
    v_trad  text;
BEGIN
    -- 1. ogni scheda pubblicata: forma completa e coerente con il database
    FOR r IN SELECT p.*, c.data_viaggio_id_fk AS edizione, c.web_tour_contenuti_id AS cid
               FROM fn_web_tour_pubblicati(2, 'IT') p
               JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = p.contenuto_id
    LOOP
        s := fn_web_tour_scheda(2, r.slug, 'IT');
        ASSERT s IS NOT NULL, 'scheda pubblicata senza risultato: ' || r.slug;
        ASSERT s ?& ARRAY['tour', 'galleria', 'itinerario', 'mappa', 'altre_partenze', 'azienda'], 'chiavi mancanti: ' || r.slug;
        ASSERT s->'tour'->>'slug' = r.slug, 'slug sbagliato';
        ASSERT (s->'tour'->>'edizione_id')::integer = r.edizione, 'edizione sbagliata: ' || r.slug;
        ASSERT s->'tour'->>'paese' IS NOT DISTINCT FROM (SELECT ec.iso_alpha2 FROM ana_viaggi v JOIN eba_countries ec ON ec.country_id = v.viaggio_nazione_fk WHERE v.viaggio_id = r.viaggio_id),
            'paese sbagliato: ' || r.slug;
        -- 2. i campi del tour sono quelli di fn_web_tour_pubblicati: «pubblicato» dice la stessa cosa
        ASSERT s->'tour'->>'titolo' = r.titolo AND (s->'tour'->>'prezzo_da')::int IS NOT DISTINCT FROM r.prezzo_da
           AND s->'tour'->>'posti_stato' IS NOT DISTINCT FROM r.posti_stato AND s->'tour'->>'meta_title' IS NOT DISTINCT FROM r.meta_title
           AND s->'tour'->>'data_inizio' = r.data_inizio::text AND s->'tour'->>'descrizione_slug' IS NOT DISTINCT FROM r.descrizione_slug,
            'campi del tour diversi da fn_web_tour_pubblicati: ' || r.slug;
        -- galleria: tutte le foto di galleria, nell'ordine del gestionale
        ASSERT jsonb_array_length(s->'galleria') = (SELECT count(*) FROM web_tour_immagini WHERE web_tour_contenuti_id_fk = r.cid AND tipo = 'galleria'),
            'galleria incompleta: ' || r.slug;
        ASSERT (SELECT coalesce(jsonb_agg(x->>'url'), '[]') FROM jsonb_array_elements(s->'galleria') x)
             = (SELECT coalesce(jsonb_agg(url ORDER BY ordine, web_tour_immagini_id), '[]') FROM web_tour_immagini WHERE web_tour_contenuti_id_fk = r.cid AND tipo = 'galleria'),
            'galleria fuori ordine: ' || r.slug;
        -- itinerario: tutte le giornate in ordine, ognuna con tutti i suoi passaggi
        ASSERT jsonb_array_length(s->'itinerario') = (SELECT count(*) FROM web_tour_itinerario WHERE web_tour_contenuti_id_fk = r.cid),
            'giornate mancanti: ' || r.slug;
        FOR t IN SELECT i.web_tour_itinerario_id AS gid, row_number() OVER (ORDER BY i.ordine, i.giorno_numero, i.web_tour_itinerario_id) - 1 AS pos
                   FROM web_tour_itinerario i WHERE i.web_tour_contenuti_id_fk = r.cid LOOP
            ASSERT jsonb_array_length(s->'itinerario'->(t.pos::int)->'passaggi')
                 = (SELECT count(*) FROM web_tour_itinerario_passaggi WHERE itinerario_id_fk = t.gid),
                'passaggi mancanti o giornate fuori ordine: ' || r.slug;
        END LOOP;
        -- la mappa del tour intero c'è se il gestionale l'ha generata
        ASSERT (s->'mappa' <> 'null'::jsonb) = EXISTS (SELECT 1 FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = r.cid AND web_tour_itinerario_id_fk IS NULL AND immagine_url IS NOT NULL),
            'mappa: ' || r.slug;
        -- sui dati veri ogni viaggio ha una partenza sola
        ASSERT jsonb_array_length(s->'altre_partenze') = 0, 'altre partenze inattese: ' || r.slug;
    END LOOP;

    -- 3. traduzioni: inglese quando c'è, italiano quando manca
    SELECT i.web_tour_itinerario_id, i.web_tour_contenuti_id_fk, tr.testo, c.slug
      INTO v_giorn, v_cont, v_trad, v_slug
      FROM web_tour_itinerario i
      JOIN web_traduzioni tr ON tr.entita = 'web_tour_itinerario' AND tr.entita_id = i.web_tour_itinerario_id
                            AND tr.campo = 'titolo_giornata' AND tr.lingua = 'EN' AND NOT tr.obsoleto
      JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = i.web_tour_contenuti_id_fk
      JOIN fn_web_tour_pubblicati(2, 'IT') p ON p.slug = c.slug
     LIMIT 1;
    ASSERT v_giorn IS NOT NULL, 'serve una giornata pubblicata con il titolo tradotto in inglese';
    s := fn_web_tour_scheda(2, v_slug, 'EN');
    ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(s->'itinerario') g WHERE g->>'titolo' = btrim(v_trad)), 'titolo della giornata non tradotto';
    s := fn_web_tour_scheda(2, v_slug, 'IT');
    ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s->'itinerario') g WHERE g->>'titolo' = btrim(v_trad))
        OR btrim(v_trad) = (SELECT titolo_giornata FROM web_tour_itinerario WHERE web_tour_itinerario_id = v_giorn),
        'in italiano non deve uscire la traduzione';
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'web_tour_itinerario' AND entita_id = v_giorn AND lingua = 'EN';
    s := fn_web_tour_scheda(2, v_slug, 'EN');
    ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(s->'itinerario') g
                    WHERE g->>'titolo' = (SELECT titolo_giornata FROM web_tour_itinerario WHERE web_tour_itinerario_id = v_giorn)),
        'senza traduzione valida: il titolo italiano';

    -- 4. nessun risultato per una bozza, uno slug inventato, un'altra azienda
    ASSERT fn_web_tour_scheda(2, (SELECT slug FROM web_tour_contenuti WHERE azienda_id = 2 AND stato_pubblicazione = 'bozza' LIMIT 1), 'IT') IS NULL,
        'una bozza non deve avere scheda';
    ASSERT fn_web_tour_scheda(2, 'non-esiste-mai', 'IT') IS NULL, 'slug inventato: null';
    ASSERT fn_web_tour_scheda(999999, v_slug, 'IT') IS NULL, 'un''altra azienda: null';

    -- 5. altre partenze: una seconda edizione pubblicata dello stesso viaggio compare (e non sé stessa)
    SELECT p.viaggio_id INTO v_n FROM fn_web_tour_pubblicati(2, 'IT') p WHERE p.slug = v_slug;
    INSERT INTO ana_date_viaggi (viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine,
                                 data_viaggio_costo_pilota, data_viaggio_costo_passeggero, created_by, azienda_id)
    SELECT v_n, current_date + 400, current_date + 400 + greatest(coalesce(v.viaggio_numero_giorni, 1) - 1, 0), 1, 1, 'test683', 2
      FROM ana_viaggi v WHERE v.viaggio_id = v_n   -- la durata deve essere quella del viaggio (controllo del database)
    RETURNING data_viaggio_id INTO v_data;
    INSERT INTO web_tour_contenuti (azienda_id, viaggio_id_fk, data_viaggio_id_fk, slug, stato_pubblicazione, data_pubblicazione)
    VALUES (2, v_n, v_data, 'prova-683', 'pubblicato', now());
    s := fn_web_tour_scheda(2, v_slug, 'IT');
    ASSERT jsonb_array_length(s->'altre_partenze') = 1 AND s->'altre_partenze'->0->>'slug' = 'prova-683'
       AND s->'altre_partenze'->0 ?& ARRAY['sezione_slug', 'data_inizio', 'data_fine', 'posti_stato', 'posti_rimasti'],
        'altre partenze: attesa la nuova edizione con date e posti';
    -- e dalla nuova edizione si vede l'originale, mai sé stessa
    s := fn_web_tour_scheda(2, 'prova-683', 'IT');
    ASSERT (SELECT bool_and(x->>'slug' <> 'prova-683') FROM jsonb_array_elements(s->'altre_partenze') x)
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(s->'altre_partenze') x WHERE x->>'slug' = v_slug),
        'una scheda elenca le altre edizioni, non sé stessa';
    s := fn_web_tour_scheda(2, v_slug, 'IT');

    -- 6. dati aziendali (per il piede del PDF) e WhatsApp
    SELECT * INTO t FROM fn_web_newsletter_dati_azienda(2);
    ASSERT s->'azienda'->>'ragione_sociale' = t.ragione_sociale AND s->'azienda'->>'partita_iva' IS NOT DISTINCT FROM t.partita_iva
       AND s->'azienda'->>'email' IS NOT DISTINCT FROM t.email, 'dati aziendali diversi da fn_web_newsletter_dati_azienda';
    ASSERT s->'azienda'->>'whatsapp' IS NOT DISTINCT FROM
           (SELECT url FROM web_indirizzi WHERE azienda_id = 2 AND social = 'whatsapp' AND attivo ORDER BY ordine LIMIT 1),
        'WhatsApp dagli indirizzi web';

    -- 7. forma e permessi: lettura pubblica
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_tour_scheda'), 'deve essere SECURITY DEFINER';
    ASSERT (SELECT array_to_string(proconfig, ',') FROM pg_proc WHERE proname = 'fn_web_tour_scheda') LIKE '%search_path%', 'search_path fissato';
    ASSERT has_function_privilege('anon', 'fn_web_tour_scheda(integer, character varying, character)', 'EXECUTE'), 'anon deve poterla chiamare';

    RAISE NOTICE 'Test 683: OK';
END $$;
ROLLBACK;
