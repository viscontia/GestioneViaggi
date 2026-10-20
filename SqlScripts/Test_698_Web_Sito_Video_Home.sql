-- ============================================================================
-- Test dello script 698. Transazione annullata.
-- Prima dello script deve FALLIRE (le colonne e la funzione non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    f      constant text := 'fn_web_sito_video_home_save(integer, text, text, text, text, integer, integer, numeric, character varying)';
    v_j    jsonb;
    v_old  text[];
    v_ver  bigint;
BEGIN
    -- 1. le colonne del video
    ASSERT (SELECT count(*) FROM information_schema.columns WHERE table_name = 'web_sito_contenuti'
             AND column_name IN ('foto_home_url', 'foto_home_path', 'foto_home_larghezza', 'foto_home_altezza')) = 4,
        'mancano colonne della foto';
    ASSERT (SELECT count(*) FROM information_schema.columns WHERE table_name = 'web_sito_contenuti'
             AND column_name IN ('video_home_url', 'video_home_path', 'video_home_telefono_url', 'video_home_telefono_path',
                                 'video_home_larghezza', 'video_home_altezza', 'video_home_durata', 'video_home_aggiornato')) = 8,
        'mancano colonne del video';

    -- 2. il primo video: niente di vecchio da cancellare; la home lo legge
    PERFORM fn_web_sito_video_home_save(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test698');   -- si parte senza video
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_video_home_save(2,
        'https://x/libreria/2/home-a.mp4', 'libreria/2/home-a.mp4', 'https://x/libreria/2/home-a-tel.mp4', 'libreria/2/home-a-tel.mp4',
        1920, 1080, 20, 'test698');
    ASSERT v_old IS NULL, 'primo video: niente da cancellare';
    v_j := fn_web_sito_home(2, 'IT')->'video';
    ASSERT v_j->>'computer' = 'https://x/libreria/2/home-a.mp4' AND v_j->>'telefono' = 'https://x/libreria/2/home-a-tel.mp4', 'la home legge il video';
    ASSERT (v_j->>'larghezza')::int = 1920 AND (v_j->>'altezza')::int = 1080, 'misure';
    v_ver := (v_j->>'versione')::bigint;
    ASSERT v_ver > 0, 'versione';
    -- i percorsi dello Storage non escono verso il pubblico
    ASSERT NOT (fn_web_sito_home(2, 'IT')::text LIKE '%"libreria/2/home-a.mp4"%'), 'il percorso interno non va al sito';

    -- 3. il video cambia: si restituiscono i percorsi del vecchio, la versione cambia
    PERFORM pg_sleep(0.01);
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_video_home_save(2,
        'https://x/libreria/2/home-b.mp4', 'libreria/2/home-b.mp4', 'https://x/libreria/2/home-b-tel.mp4', 'libreria/2/home-b-tel.mp4',
        1920, 1440, 2, 'test698');
    ASSERT v_old @> ARRAY['libreria/2/home-a-tel.mp4', 'libreria/2/home-a.mp4'] AND array_length(v_old, 1) = 2, 'vecchi percorsi: ' || COALESCE(v_old::text, 'nessuno');
    ASSERT (fn_web_sito_home(2, 'IT')->'video'->>'versione')::bigint <> v_ver, 'la versione cambia col video';

    -- 4. gli altri dati della home restano (il salvataggio della scheda non tocca il video, e viceversa)
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Motto 698', 'Titolo 698', NULL, NULL, NULL, 'test698');
    ASSERT fn_web_sito_home(2, 'IT')->'video'->>'computer' = 'https://x/libreria/2/home-b.mp4', 'la scheda non cancella il video';
    ASSERT fn_web_sito_home(2, 'IT')->>'motto' = 'Motto 698', 'il video non cancella la scheda';

    -- 5. cambiare il video avvisa la coda
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    PERFORM fn_web_sito_video_home_save(2,
        'https://x/libreria/2/home-c.mp4', 'libreria/2/home-c.mp4', 'https://x/libreria/2/home-c-tel.mp4', 'libreria/2/home-c-tel.mp4',
        1920, 1440, 2, 'test698');
    ASSERT EXISTS (SELECT 1 FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL), 'coda avvisata';

    -- 6. togliere il video: tutto NULL, si restituiscono i vecchi, la home non ha più video
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_video_home_save(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test698');
    ASSERT array_length(v_old, 1) = 2, 'togliendo il video si restituiscono i vecchi';
    ASSERT fn_web_sito_home(2, 'IT')->'video' = 'null'::jsonb, 'senza video: null';

    -- 7. rifiuti: dati a metà, file di un'altra azienda, durata oltre 20 s
    BEGIN
        PERFORM fn_web_sito_video_home_save(2, 'https://x/libreria/2/d.mp4', 'libreria/2/d.mp4', NULL, NULL, 1920, 1080, 10, 'test698');
        RAISE EXCEPTION 'accettato senza versione da telefono';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettato%' THEN RAISE; END IF; END;
    BEGIN
        PERFORM fn_web_sito_video_home_save(2, 'https://x/libreria/6/d.mp4', 'libreria/6/d.mp4', 'https://x/libreria/6/t.mp4', 'libreria/6/t.mp4', 1920, 1080, 10, 'test698');
        RAISE EXCEPTION 'accettato il file di un''altra azienda';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettato%' THEN RAISE; END IF; END;
    BEGIN
        PERFORM fn_web_sito_video_home_save(2, 'https://x/libreria/2/d.mp4', 'libreria/2/d.mp4', 'https://x/libreria/2/t.mp4', 'libreria/2/t.mp4', 1920, 1080, 45, 'test698');
        RAISE EXCEPTION 'accettato un video di 45 s';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettato%' THEN RAISE; END IF; END;

    -- 8. la foto della home caricata dalla scheda (2000 px, a parte dalla libreria delle newsletter)
    UPDATE web_sito_contenuti SET foto_home_fk = (SELECT min(web_immagini_libreria_id) FROM web_immagini_libreria WHERE azienda_id = 2) WHERE azienda_id = 2;
    PERFORM fn_web_sito_foto_home_save(2, NULL, NULL, NULL, NULL, 'test698');
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_foto_home_save(2, 'https://x/libreria/2/home-f1.webp', 'libreria/2/home-f1.webp', 2000, 1333, 'test698');
    ASSERT v_old IS NULL, 'prima foto: niente da cancellare (la foto della libreria NON si cancella)';
    v_j := fn_web_sito_home(2, 'IT')->'foto';
    ASSERT v_j->>'url' = 'https://x/libreria/2/home-f1.webp' AND (v_j->>'larghezza')::int = 2000, 'la home legge la foto della scheda: ' || COALESCE(v_j::text, 'null');
    ASSERT (SELECT foto_home_fk FROM web_sito_contenuti WHERE azienda_id = 2) IS NULL, 'la scelta dalla libreria si spegne: una foto sola';
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_foto_home_save(2, 'https://x/libreria/2/home-f2.webp', 'libreria/2/home-f2.webp', 2000, 1333, 'test698');
    ASSERT v_old = ARRAY['libreria/2/home-f1.webp'], 'foto cambiata: si restituisce la vecchia';
    BEGIN
        PERFORM fn_web_sito_foto_home_save(2, 'https://x/libreria/6/f.webp', 'libreria/6/f.webp', 2000, 1333, 'test698');
        RAISE EXCEPTION 'accettata la foto di un''altra azienda';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettata%' THEN RAISE; END IF; END;
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_foto_home_save(2, NULL, NULL, NULL, NULL, 'test698');
    ASSERT v_old = ARRAY['libreria/2/home-f2.webp'] AND fn_web_sito_home(2, 'IT')->'foto' = 'null'::jsonb, 'foto tolta';
    -- finché Antonio non carica la foto dalla scheda, resta quella scelta dalla libreria (com'è oggi in PROD)
    UPDATE web_sito_contenuti SET foto_home_fk = (SELECT min(web_immagini_libreria_id) FROM web_immagini_libreria WHERE azienda_id = 2) WHERE azienda_id = 2;
    ASSERT fn_web_sito_home(2, 'IT')->'foto'->>'url' IS NOT NULL, 'ripiego sulla foto della libreria';

    -- 9. permessi: il salvataggio solo al gestionale
    CREATE ROLE test698_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test698_nessuno', f, 'EXECUTE'), 'salvataggio eseguibile da chiunque';
    ASSERT NOT has_function_privilege('test698_nessuno', 'fn_web_sito_foto_home_save(integer, text, text, integer, integer, character varying)', 'EXECUTE'), 'foto: eseguibile da chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', f, 'EXECUTE'), 'anon non salva';
        ASSERT NOT has_function_privilege('anon', 'fn_web_sito_foto_home_save(integer, text, text, integer, integer, character varying)', 'EXECUTE'), 'anon non salva la foto';
        ASSERT has_function_privilege('anon', 'fn_web_sito_home(integer, character varying)', 'EXECUTE'), 'anon legge la home';
    END IF;

    RAISE NOTICE 'Test 698: OK';
END $$;
ROLLBACK;
