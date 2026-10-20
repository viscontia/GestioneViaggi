-- ============================================================================
-- Test dello script 699. Transazione annullata.
-- Prima dello script deve FALLIRE (la colonna e la nuova firma non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    f      constant text := 'fn_web_sito_video_home_save(integer, text, text, text, text, text, text, integer, integer, numeric, character varying)';
    v_j    jsonb;
    v_old  text[];
BEGIN
    -- 1. le colonne della copertina; la vecchia firma non c'è più (una funzione sola, niente equivoci)
    ASSERT (SELECT count(*) FROM information_schema.columns WHERE table_name = 'web_sito_contenuti'
             AND column_name IN ('video_home_copertina_url', 'video_home_copertina_path')) = 2, 'mancano le colonne della copertina';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_web_sito_video_home_save' AND pronargs = 9), 'resta la firma vecchia';

    -- 2. il video con la sua copertina (il primo fotogramma): la home la legge
    PERFORM fn_web_sito_video_home_save(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test699');
    PERFORM fn_web_sito_video_home_save(2,
        'https://x/libreria/2/v1.mp4', 'libreria/2/v1.mp4', 'https://x/libreria/2/v1-tel.mp4', 'libreria/2/v1-tel.mp4',
        'https://x/libreria/2/v1.webp', 'libreria/2/v1.webp', 1744, 1308, 2, 'test699');
    v_j := fn_web_sito_home(2, 'IT')->'video';
    ASSERT v_j->>'copertina' = 'https://x/libreria/2/v1.webp', 'la home legge la copertina: ' || COALESCE(v_j::text, 'null');
    ASSERT v_j->>'computer' = 'https://x/libreria/2/v1.mp4', 'il resto del video c''è ancora';

    -- 3. il video cambia: tornano tutti e TRE i percorsi vecchi (anche la copertina: niente file orfani)
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_video_home_save(2,
        'https://x/libreria/2/v2.mp4', 'libreria/2/v2.mp4', 'https://x/libreria/2/v2-tel.mp4', 'libreria/2/v2-tel.mp4',
        'https://x/libreria/2/v2.webp', 'libreria/2/v2.webp', 1744, 1308, 2, 'test699');
    ASSERT array_length(v_old, 1) = 3 AND v_old @> ARRAY['libreria/2/v1.mp4', 'libreria/2/v1-tel.mp4', 'libreria/2/v1.webp'],
        'vecchi percorsi: ' || COALESCE(v_old::text, 'nessuno');

    -- 4. senza copertina non si registra (il gestionale la prepara sempre); fuori dalla libreria dell'azienda nemmeno
    BEGIN
        PERFORM fn_web_sito_video_home_save(2, 'https://x/libreria/2/v3.mp4', 'libreria/2/v3.mp4', 'https://x/libreria/2/v3-tel.mp4', 'libreria/2/v3-tel.mp4',
            NULL, NULL, 1744, 1308, 2, 'test699');
        RAISE EXCEPTION 'accettato senza copertina';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettato%' THEN RAISE; END IF; END;
    BEGIN
        PERFORM fn_web_sito_video_home_save(2, 'https://x/libreria/2/v3.mp4', 'libreria/2/v3.mp4', 'https://x/libreria/2/v3-tel.mp4', 'libreria/2/v3-tel.mp4',
            'https://x/libreria/6/c.webp', 'libreria/6/c.webp', 1744, 1308, 2, 'test699');
        RAISE EXCEPTION 'accettata la copertina di un''altra azienda';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'accettata%' THEN RAISE; END IF; END;

    -- 5. togliere il video toglie anche la copertina
    SELECT array_agg(percorso) INTO v_old FROM fn_web_sito_video_home_save(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'test699');
    ASSERT array_length(v_old, 1) = 3, 'togliendo il video tornano i tre percorsi';
    ASSERT fn_web_sito_home(2, 'IT')->'video' = 'null'::jsonb, 'senza video: null';

    -- 6. un video registrato prima del 699 (senza copertina): la home lo legge con copertina null, senza errori
    UPDATE web_sito_contenuti SET video_home_url = 'https://x/libreria/2/v0.mp4', video_home_telefono_url = 'https://x/libreria/2/v0-tel.mp4',
           video_home_path = 'libreria/2/v0.mp4', video_home_telefono_path = 'libreria/2/v0-tel.mp4',
           video_home_larghezza = 1744, video_home_altezza = 1308, video_home_durata = 2, video_home_aggiornato = now(),
           video_home_copertina_url = NULL, video_home_copertina_path = NULL
     WHERE azienda_id = 2;
    v_j := fn_web_sito_home(2, 'IT')->'video';
    ASSERT v_j ? 'copertina' AND v_j->'copertina' = 'null'::jsonb, 'video senza copertina: chiave presente e null';

    -- 7. permessi: il salvataggio solo al gestionale
    CREATE ROLE test699_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test699_nessuno', f, 'EXECUTE'), 'salvataggio eseguibile da chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', f, 'EXECUTE'), 'anon non salva';
        ASSERT has_function_privilege('anon', 'fn_web_sito_home(integer, character varying)', 'EXECUTE'), 'anon legge la home';
    END IF;

    RAISE NOTICE 'Test 699: OK';
END $$;
ROLLBACK;
