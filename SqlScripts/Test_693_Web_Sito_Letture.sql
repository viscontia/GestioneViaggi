-- ============================================================================
-- Test dello script 693. Transazione annullata: dati di prova spariscono.
-- Prima dello script deve FALLIRE (le funzioni non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_foto    bigint;
    v_pub     bigint[];   -- contenuti pubblicati (IT), nell'ordine del database
    v_nonpub  bigint;     -- un contenuto dell'azienda 2 NON pubblicato
    v_j       jsonb;
    v_n       integer;
    v_testo   text;
    f         text;
BEGIN
    -- In locale ci sono pochi tour pubblicati: se ne pubblicano altri fra le bozze con partenza
    -- futura (la transazione si annulla). Mai un controllo saltato in silenzio.
    IF (SELECT count(*) FROM fn_web_tour_pubblicati(2, 'IT')) < 4 THEN
        UPDATE web_tour_contenuti c SET stato_pubblicazione = 'pubblicato'
         WHERE c.web_tour_contenuti_id IN (
               SELECT c2.web_tour_contenuti_id FROM web_tour_contenuti c2
                 JOIN ana_date_viaggi dv ON dv.data_viaggio_id = c2.data_viaggio_id_fk
                WHERE c2.azienda_id = 2 AND c2.stato_pubblicazione <> 'pubblicato' AND dv.data_viaggio_data_inizio > CURRENT_DATE
                ORDER BY c2.web_tour_contenuti_id
                LIMIT 4 - (SELECT count(*) FROM fn_web_tour_pubblicati(2, 'IT')));
    END IF;
    SELECT array_agg(contenuto_id ORDER BY ord) INTO v_pub
      FROM (SELECT contenuto_id, row_number() OVER () AS ord FROM fn_web_tour_pubblicati(2, 'IT')) t;
    ASSERT array_length(v_pub, 1) >= 4, 'servono almeno 4 tour pubblicati nell''azienda 2';
    -- un contenuto non pubblicato: se manca, se ne ritira uno
    SELECT web_tour_contenuti_id INTO v_nonpub FROM web_tour_contenuti
     WHERE azienda_id = 2 AND web_tour_contenuti_id <> ALL (v_pub) LIMIT 1;
    IF v_nonpub IS NULL THEN
        v_nonpub := v_pub[array_length(v_pub, 1)];
        UPDATE web_tour_contenuti SET stato_pubblicazione = 'bozza' WHERE web_tour_contenuti_id = v_nonpub;
        v_pub := v_pub[1:array_length(v_pub, 1) - 1];
    END IF;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_tour_pubblicati(2, 'IT') WHERE contenuto_id = v_nonpub), 'il contenuto «non pubblicato» deve esserlo davvero';

    -- 1. lingua: solo le 5 del sito
    FOREACH f IN ARRAY ARRAY['fn_web_sito_home', 'fn_web_sito_evidenza', 'fn_web_sito_piede', 'fn_web_tour_zone'] LOOP
        BEGIN
            EXECUTE format('SELECT %I(2, %L)', f, 'PT');
            RAISE EXCEPTION '%: lingua PT accettata', f;
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE '%lingua PT accettata' THEN RAISE; END IF;
        END;
    END LOOP;

    -- 2. home: senza riga → null; poi italiano e traduzioni
    DELETE FROM web_sito_contenuti WHERE azienda_id = 2;
    ASSERT fn_web_sito_home(2, 'IT') IS NULL, 'senza contenuti la home non ha dati';
    INSERT INTO web_immagini_libreria (descrizione, url, storage_path, larghezza, altezza, azienda_id, created_by)
    VALUES ('Tramonto in Ogliastra', 'https://esempio.invalid/home.jpg', 'prova/home.jpg', 2400, 1600, 2, 'test693')
    RETURNING web_immagini_libreria_id INTO v_foto;
    PERFORM fn_web_sito_contenuti_save(2, v_foto, 'Il mondo… fuori traccia', 'Tour in fuoristrada', NULL, 'Capodanno fuori traccia', 'test693');
    v_j := fn_web_sito_home(2, 'IT');
    ASSERT v_j->>'motto' = 'Il mondo… fuori traccia' AND v_j->>'frase' = 'Tour in fuoristrada', 'home in italiano';
    ASSERT v_j->'foto'->>'url' = 'https://esempio.invalid/home.jpg' AND (v_j->'foto'->>'larghezza')::int = 2400, 'foto della home';
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by) VALUES
        ('web_sito_contenuti', 2, 'motto', 'EN', 'The world… off the beaten track', 2, 'test693'),
        ('web_sito_contenuti', 2, 'motto', 'DE', 'Veraltet', 2, 'test693'),
        ('web_sito_contenuti', 2, 'motto', 'FR', '   ', 2, 'test693');
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND lingua = 'DE';
    ASSERT fn_web_sito_home(2, 'EN')->>'motto' = 'The world… off the beaten track', 'motto tradotto';
    ASSERT fn_web_sito_home(2, 'EN')->>'frase' = 'Tour in fuoristrada', 'traduzione mancante → italiano';
    ASSERT fn_web_sito_home(2, 'DE')->>'motto' = 'Il mondo… fuori traccia', 'traduzione obsoleta → italiano';
    ASSERT fn_web_sito_home(2, 'FR')->>'motto' = 'Il mondo… fuori traccia', 'traduzione vuota → italiano';
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Il mondo… fuori traccia', NULL, NULL, 'Capodanno fuori traccia', 'test693');
    ASSERT fn_web_sito_home(2, 'IT')->'foto' = 'null'::jsonb, 'senza foto: foto null, il resto c''è';

    -- 3. in evidenza: solo i tour ancora pubblicati, nell'ordine scelto, già tradotti
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_pub[2], v_nonpub, v_pub[1]], 'test693');
    v_j := fn_web_sito_evidenza(2, 'IT');
    ASSERT v_j->>'titolo' = 'Capodanno fuori traccia', 'titolo del blocco';
    ASSERT jsonb_array_length(v_j->'tour') = 2, 'il tour non pubblicato sparisce';
    ASSERT (v_j->'tour'->0->>'contenuto_id')::bigint = v_pub[2] AND (v_j->'tour'->1->>'contenuto_id')::bigint = v_pub[1], 'nell''ordine scelto';
    ASSERT v_j->'tour'->0 ? 'prezzo_da' AND v_j->'tour'->0 ? 'posti_stato' AND v_j->'tour'->0 ? 'descrizione_slug',
        'gli stessi campi di fn_web_tour_pubblicati (le card del sito)';
    ASSERT (SELECT fn_web_sito_evidenza(2, 'EN')->'tour'->0->>'titolo')
         = (SELECT titolo FROM fn_web_tour_pubblicati(2, 'EN') WHERE contenuto_id = v_pub[2] LIMIT 1), 'titoli tradotti';
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_nonpub], 'test693');
    ASSERT fn_web_sito_evidenza(2, 'IT') IS NULL, 'nessun tour pubblicato in evidenza → null';
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[]::bigint[], 'test693');
    ASSERT fn_web_sito_evidenza(2, 'IT') IS NULL, 'nessun tour scelto → null';

    -- 4. piede: dati dell'azienda, contatti e social, garanzie solo se ci sono
    PERFORM fn_ana_aziende_garanzie_save(2, NULL, NULL, NULL, NULL);
    UPDATE ana_aziende SET data_inizio_attivita = DATE '2018-03-01', data_costituzione = DATE '2015-01-01' WHERE azienda_id = 2;
    v_j := fn_web_sito_piede(2, 'IT');
    FOREACH f IN ARRAY ARRAY['ragione_sociale', 'forma_giuridica', 'partita_iva', 'codice_fiscale', 'rea', 'capitale_sociale',
                             'socio_unico', 'anno_inizio', 'sede', 'telefono', 'email', 'whatsapp', 'social', 'polizza_rc', 'fondo_garanzia'] LOOP
        ASSERT v_j ? f, format('piede: manca la chiave %s', f);
    END LOOP;
    ASSERT (v_j->>'anno_inizio')::int = 2018, 'anno d''inizio dall''inizio attività';
    UPDATE ana_aziende SET data_inizio_attivita = NULL WHERE azienda_id = 2;
    ASSERT (fn_web_sito_piede(2, 'IT')->>'anno_inizio')::int = 2015, 'senza inizio attività: la costituzione';
    ASSERT v_j->'polizza_rc' = 'null'::jsonb AND v_j->'fondo_garanzia' = 'null'::jsonb, 'garanzie assenti → null';
    PERFORM fn_ana_aziende_garanzie_save(2, 'Compagnia Prova', 'RC-1', NULL, 'Fondo n. 7');
    v_j := fn_web_sito_piede(2, 'IT');
    ASSERT v_j->'polizza_rc'->>'compagnia' = 'Compagnia Prova' AND v_j->'fondo_garanzia'->>'estremi' = 'Fondo n. 7', 'garanzie presenti';
    ASSERT v_j->>'email' = fn_ana_aziende_email_principale(2), 'email del piede = la principale';
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_j->'social') s
     WHERE s->>'social' IS NULL OR s->>'social' = 'whatsapp';
    ASSERT v_n = 0, 'fra i social né WhatsApp né indirizzi che non sono social';
    ASSERT (v_j->>'whatsapp') IS NOT DISTINCT FROM
           (SELECT url FROM web_indirizzi WHERE azienda_id = 2 AND social = 'whatsapp' AND attivo ORDER BY ordine LIMIT 1), 'WhatsApp';

    -- 5. zone: centro del riquadro, mai la traccia; tour vicini nella stessa zona; senza mappa niente
    v_j := fn_web_tour_zone(2, 'IT');
    v_testo := v_j::text;
    ASSERT v_testo NOT LIKE '%gpx%' AND v_testo NOT LIKE '%bbox%' AND v_testo NOT LIKE '%min_lat%', 'mai traccia né riquadro';
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_j) z, jsonb_array_elements(z->'tour') t;
    ASSERT v_n = (SELECT count(*) FROM fn_web_tour_pubblicati(2, 'IT') p
                   WHERE EXISTS (SELECT 1 FROM web_tour_mappa m WHERE m.web_tour_contenuti_id_fk = p.contenuto_id AND m.bbox_min_lat IS NOT NULL)),
        'ogni tour pubblicato con la mappa compare una volta';
    -- due tour a pochi km: una zona sola
    UPDATE web_tour_mappa SET bbox_min_lat = 39.80, bbox_max_lat = 39.90, bbox_min_lon = 9.50, bbox_max_lon = 9.60
     WHERE web_tour_contenuti_id_fk IN (v_pub[1], v_pub[2]);
    UPDATE web_tour_mappa SET bbox_min_lat = 39.82, bbox_max_lat = 39.92 WHERE web_tour_contenuti_id_fk = v_pub[2];
    SELECT count(*) INTO v_n FROM jsonb_array_elements(fn_web_tour_zone(2, 'IT')) z
     WHERE (SELECT count(*) FROM jsonb_array_elements(z->'tour') t
             WHERE (t->>'contenuto_id')::bigint IN (v_pub[1], v_pub[2])) = 2;
    ASSERT v_n = 1, 'due tour vicini nella stessa zona';
    -- senza mappa: non compare
    DELETE FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = v_pub[3];
    ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(fn_web_tour_zone(2, 'IT')) z, jsonb_array_elements(z->'tour') t
                        WHERE (t->>'contenuto_id')::bigint = v_pub[3]), 'un tour senza mappa non compare';
    -- un tour non pubblicato non compare anche se ha la mappa
    ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(fn_web_tour_zone(2, 'IT')) z, jsonb_array_elements(z->'tour') t
                        WHERE (t->>'contenuto_id')::bigint = v_nonpub), 'un tour non pubblicato non compare';

    -- 6. permessi: le quattro letture aperte ad anon, le tabelle no
    FOREACH f IN ARRAY ARRAY['fn_web_sito_home(integer, character varying)', 'fn_web_sito_evidenza(integer, character varying)',
                             'fn_web_sito_piede(integer, character varying)', 'fn_web_tour_zone(integer, character varying)'] LOOP
        ASSERT (SELECT prosecdef FROM pg_proc WHERE oid = f::regprocedure), format('%s: SECURITY DEFINER', f);
        ASSERT (SELECT array_to_string(proconfig, ',') LIKE '%search_path=public, pg_temp%' FROM pg_proc WHERE oid = f::regprocedure),
            format('%s: search_path fissato', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            ASSERT has_function_privilege('anon', f, 'EXECUTE'), format('%s: anon deve poterla chiamare', f);
        END IF;
    END LOOP;
    -- un ruolo senza permessi non le esegue: il permesso è SOLO quello dato ad anon/authenticated
    CREATE ROLE test693_nessuno NOLOGIN;
    FOREACH f IN ARRAY ARRAY['fn_web_sito_home(integer, character varying)', 'fn_web_sito_evidenza(integer, character varying)',
                             'fn_web_sito_piede(integer, character varying)', 'fn_web_tour_zone(integer, character varying)'] LOOP
        ASSERT NOT has_function_privilege('test693_nessuno', f, 'EXECUTE'), format('%s: eseguibile da chiunque (PUBLIC)', f);
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', 'fn_web_sito_testo(character varying, bigint, character varying, character varying, text)', 'EXECUTE'),
            'l''aiuto per le traduzioni non è pubblico';
        ASSERT NOT has_table_privilege('anon', 'web_sito_contenuti', 'SELECT'), 'anon non legge la tabella';
        ASSERT NOT has_table_privilege('anon', 'ana_aziende', 'SELECT'), 'anon non legge l''anagrafica';
    END IF;

    RAISE NOTICE 'Test 693: OK';
END $$;
ROLLBACK;
