-- ============================================================================
-- Test dello script 692. Transazione annullata: dati di prova e righe di coda spariscono.
-- (Aggiornato col 695: titolo e sottotitolo al posto della frase.)
-- Prima dello script deve FALLIRE (le tabelle e le funzioni non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_foto      bigint;
    v_foto_alt  bigint;
    v_email     integer;
    v_email_alt integer;
    v_tour      bigint[];
    v_tour_alt  bigint;
    v_r         record;
    v_n         integer;
    -- c'è in attesa un «menu» per l'azienda 2?
    c           text := 'select count(*) from web_revalidate_coda where azienda_id = 2 and completata_il is null and oggetto = ''menu''';
BEGIN
    -- dati di prova: una foto per l'azienda 2 e una per un'altra azienda
    INSERT INTO web_immagini_libreria (descrizione, url, storage_path, azienda_id, created_by)
    VALUES ('prova 692', 'https://esempio.invalid/a.jpg', 'prova/a.jpg', 2, 'test692')
    RETURNING web_immagini_libreria_id INTO v_foto;
    INSERT INTO web_immagini_libreria (descrizione, url, storage_path, azienda_id, created_by)
    SELECT 'prova 692 altra', 'https://esempio.invalid/b.jpg', 'prova/b.jpg', azienda_id, 'test692'
      FROM ana_aziende WHERE azienda_id <> 2 ORDER BY azienda_id LIMIT 1
    RETURNING web_immagini_libreria_id INTO v_foto_alt;
    SELECT email_id INTO v_email FROM ana_aziende_email WHERE azienda_fk = 2 ORDER BY is_principale, email_id LIMIT 1;
    SELECT email_id INTO v_email_alt FROM ana_aziende_email WHERE azienda_fk <> 2 LIMIT 1;
    SELECT array_agg(web_tour_contenuti_id ORDER BY web_tour_contenuti_id) INTO v_tour
      FROM (SELECT web_tour_contenuti_id FROM web_tour_contenuti WHERE azienda_id = 2 ORDER BY web_tour_contenuti_id LIMIT 4) t;
    SELECT web_tour_contenuti_id INTO v_tour_alt FROM web_tour_contenuti WHERE azienda_id <> 2 LIMIT 1;
    ASSERT v_email IS NOT NULL, 'serve un''email dell''azienda 2';
    ASSERT array_length(v_tour, 1) = 4, 'servono 4 contenuti web dell''azienda 2';

    -- 1. le tabelle ci sono, protette
    ASSERT (SELECT relrowsecurity FROM pg_class WHERE relname = 'web_sito_contenuti'), 'RLS su web_sito_contenuti';
    ASSERT (SELECT relrowsecurity FROM pg_class WHERE relname = 'web_sito_evidenza'), 'RLS su web_sito_evidenza';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_table_privilege('anon', 'web_sito_contenuti', 'SELECT'), 'anon non legge web_sito_contenuti';
        ASSERT NOT has_table_privilege('anon', 'web_sito_evidenza', 'SELECT'), 'anon non legge web_sito_evidenza';
        ASSERT NOT has_function_privilege('anon', 'fn_web_sito_contenuti_save(integer, bigint, character varying, character varying, character varying, integer, character varying, character varying)', 'EXECUTE'),
            'anon non salva i contenuti';
        ASSERT NOT has_function_privilege('anon', 'fn_web_sito_evidenza_save(integer, bigint[], character varying)', 'EXECUTE'), 'anon non salva l''evidenza';
        ASSERT NOT has_function_privilege('anon', 'fn_ana_aziende_garanzie_save(integer, character varying, character varying, character varying, character varying)', 'EXECUTE'),
            'anon non salva le garanzie';
    END IF;

    -- 2. contenuti: salvataggio, rilettura, campi vuoti → NULL
    PERFORM fn_web_sito_contenuti_save(2, v_foto, '  Il mondo… fuori traccia ', 'Tour in fuoristrada', NULL, v_email, '', 'test692');
    SELECT * INTO v_r FROM fn_web_sito_contenuti_get(2);
    ASSERT v_r.foto_home_fk = v_foto AND v_r.email_messaggi_fk = v_email, 'foto ed email salvate';
    ASSERT v_r.motto = 'Il mondo… fuori traccia', 'motto senza spazi ai bordi';
    ASSERT v_r.evidenza_titolo IS NULL, 'titolo vuoto → NULL';
    -- un secondo salvataggio aggiorna la stessa riga
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Motto 2', NULL, NULL, NULL, 'Capodanno fuori traccia', 'test692');
    ASSERT (SELECT count(*) FROM web_sito_contenuti WHERE azienda_id = 2) = 1, 'una riga per azienda';
    SELECT * INTO v_r FROM fn_web_sito_contenuti_get(2);
    ASSERT v_r.motto = 'Motto 2' AND v_r.foto_home_fk IS NULL AND v_r.evidenza_titolo = 'Capodanno fuori traccia', 'aggiornata';

    -- 3. foto ed email di un'altra azienda: rifiutate (anche scrivendo direttamente in tabella)
    ASSERT v_email_alt IS NOT NULL AND v_foto_alt IS NOT NULL, 'servono un''email e una foto di un''altra azienda';
    IF v_email_alt IS NOT NULL THEN
        BEGIN
            PERFORM fn_web_sito_contenuti_save(2, NULL, NULL, NULL, NULL, v_email_alt, NULL, 'test692');
            RAISE EXCEPTION 'email di un''altra azienda accettata';
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE 'email di un''altra azienda accettata' THEN RAISE; END IF;
        END;
    END IF;
    IF v_foto_alt IS NOT NULL THEN
        BEGIN
            UPDATE web_sito_contenuti SET foto_home_fk = v_foto_alt WHERE azienda_id = 2;
            RAISE EXCEPTION 'foto di un''altra azienda accettata';
        EXCEPTION WHEN raise_exception THEN
            IF SQLERRM LIKE 'foto di un''altra azienda accettata' THEN RAISE; END IF;
        END;
    END IF;

    -- 4. in evidenza: fino a 3, nell'ordine dato, niente doppioni né tour di altre aziende
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_tour[3], v_tour[1], v_tour[2]], 'test692');
    ASSERT (SELECT array_agg(web_tour_contenuti_id ORDER BY ordine) FROM fn_web_sito_evidenza_list(2)) = ARRAY[v_tour[3], v_tour[1], v_tour[2]],
        'evidenza nell''ordine dato';
    BEGIN
        PERFORM fn_web_sito_evidenza_save(2, v_tour, 'test692');
        RAISE EXCEPTION 'quattro tour in evidenza accettati';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM LIKE 'quattro tour in evidenza accettati' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_tour[1], v_tour[1]], 'test692');
        RAISE EXCEPTION 'doppione in evidenza accettato';
    EXCEPTION WHEN raise_exception OR unique_violation THEN
        IF SQLERRM LIKE 'doppione in evidenza accettato' THEN RAISE; END IF;
    END;
    -- In locale i contenuti web sono tutti dell'azienda 2: se manca un tour di un'altra azienda,
    -- se ne «presta» uno (la transazione si annulla). Mai un controllo saltato in silenzio.
    IF v_tour_alt IS NULL THEN
        v_tour_alt := v_tour[4];
        UPDATE web_tour_contenuti SET azienda_id = (SELECT min(azienda_id) FROM ana_aziende WHERE azienda_id <> 2)
         WHERE web_tour_contenuti_id = v_tour_alt;
    END IF;
    ASSERT (SELECT azienda_id FROM web_tour_contenuti WHERE web_tour_contenuti_id = v_tour_alt) <> 2, 'serve un tour di un''altra azienda';
    BEGIN
        PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_tour_alt], 'test692');
        RAISE EXCEPTION 'tour di un''altra azienda accettato';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM LIKE 'tour di un''altra azienda accettato' THEN RAISE; END IF;
    END;
    ASSERT (SELECT count(*) FROM fn_web_sito_evidenza_list(2)) = 3, 'dopo i rifiuti resta l''elenco di prima';
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[]::bigint[], 'test692');
    ASSERT (SELECT count(*) FROM fn_web_sito_evidenza_list(2)) = 0, 'elenco vuoto = nessun tour in evidenza';

    -- 5. garanzie del tour operator nell'anagrafica
    PERFORM fn_ana_aziende_garanzie_save(2, ' Compagnia Prova ', 'RC-123', '', 'Fondo Prova n. 7');
    SELECT * INTO v_r FROM fn_ana_aziende_garanzie_get(2);
    ASSERT v_r.polizza_rc_compagnia = 'Compagnia Prova' AND v_r.polizza_rc_numero = 'RC-123', 'polizza salvata';
    ASSERT v_r.fondo_garanzia_ente IS NULL AND v_r.fondo_garanzia_estremi = 'Fondo Prova n. 7', 'fondo: vuoto → NULL';

    -- 6. ogni modifica avvisa la coda (tutto il sito: «menu»)
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Motto 3', NULL, NULL, NULL, NULL, 'test692');
    EXECUTE c INTO v_n; ASSERT v_n = 1, 'web_sito_contenuti: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    PERFORM fn_web_sito_evidenza_save(2, ARRAY[v_tour[1]], 'test692');
    EXECUTE c INTO v_n; ASSERT v_n = 1, 'web_sito_evidenza: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_contenuti', 2, 'motto', 'EN', 'The world… off the beaten track', 2, 'test692');
    EXECUTE c INTO v_n; ASSERT v_n = 1, 'traduzione dei contenuti del sito: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_newsletter_blocchi', -692, 'titolo', 'EN', 'prova', 2, 'test692');
    EXECUTE c INTO v_n; ASSERT v_n = 0, 'una traduzione che il sito non usa non avvisa la coda';

    RAISE NOTICE 'Test 692: OK';
END $$;
ROLLBACK;
