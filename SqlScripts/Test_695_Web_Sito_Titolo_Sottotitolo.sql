-- ============================================================================
-- Test dello script 695. Transazione annullata.
-- Prima dello script deve FALLIRE (la colonna e la nuova funzione non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_j jsonb;
    v_r record;
BEGIN
    -- 1. le colonne: frase_home rinominata, sottotitolo aggiunto
    ASSERT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'web_sito_contenuti' AND column_name = 'titolo_home'), 'manca titolo_home';
    ASSERT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'web_sito_contenuti' AND column_name = 'sottotitolo_home'), 'manca sottotitolo_home';
    ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'web_sito_contenuti' AND column_name = 'frase_home'), 'frase_home deve sparire';
    ASSERT NOT EXISTS (SELECT 1 FROM web_traduzioni WHERE entita = 'web_sito_contenuti' AND campo = 'frase_home'), 'traduzioni con il vecchio nome rimaste';
    -- la vecchia firma del salvataggio non c'è più (una sola funzione, niente equivoci)
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_web_sito_contenuti_save' AND pronargs = 7), 'resta la vecchia fn_web_sito_contenuti_save';

    -- 2. salvataggio con titolo e sottotitolo (testi vuoti → NULL)
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Il mondo… fuori traccia', '  Non seguire le strade già tracciate. ', 'Esplora i luoghi più selvaggi', NULL, NULL, 'test695');
    SELECT * INTO v_r FROM fn_web_sito_contenuti_get(2);
    ASSERT v_r.titolo_home = 'Non seguire le strade già tracciate.' AND v_r.sottotitolo_home = 'Esplora i luoghi più selvaggi', 'titolo e sottotitolo salvati';
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Il mondo… fuori traccia', 'Titolo', '', NULL, NULL, 'test695');
    ASSERT (SELECT sottotitolo_home FROM fn_web_sito_contenuti_get(2)) IS NULL, 'sottotitolo vuoto → NULL';

    -- 3. la home per il sito: titolo e sottotitolo, tradotti con ripiego sull'italiano
    PERFORM fn_web_sito_contenuti_save(2, NULL, 'Il mondo… fuori traccia', 'Titolo IT', 'Sottotitolo IT', NULL, NULL, 'test695');
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_contenuti', 2, 'titolo_home', 'EN', 'Title EN', 2, 'test695')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo, obsoleto = false;
    DELETE FROM web_traduzioni WHERE entita = 'web_sito_contenuti' AND entita_id = 2 AND campo = 'sottotitolo_home' AND lingua = 'EN';
    v_j := fn_web_sito_home(2, 'EN');
    ASSERT v_j ? 'titolo' AND v_j ? 'sottotitolo' AND NOT v_j ? 'frase', 'chiavi: titolo e sottotitolo, non più frase';
    ASSERT v_j->>'titolo' = 'Title EN', 'titolo tradotto';
    ASSERT v_j->>'sottotitolo' = 'Sottotitolo IT', 'sottotitolo non tradotto → italiano';

    -- 4. una traduzione del sottotitolo avvisa la coda (tutto il sito), come gli altri testi
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_contenuti', 2, 'sottotitolo_home', 'DE', 'Untertitel', 2, 'test695');
    ASSERT (SELECT count(*) FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL AND oggetto = 'menu') = 1, 'coda avvisata';

    -- 5. permessi invariati: la home al pubblico, il salvataggio no
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT has_function_privilege('anon', 'fn_web_sito_home(integer, character varying)', 'EXECUTE'), 'anon legge la home';
        ASSERT NOT has_function_privilege('anon',
            'fn_web_sito_contenuti_save(integer, bigint, character varying, character varying, character varying, integer, character varying, character varying)', 'EXECUTE'),
            'anon non salva';
    END IF;
    CREATE ROLE test695_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test695_nessuno',
        'fn_web_sito_contenuti_save(integer, bigint, character varying, character varying, character varying, integer, character varying, character varying)', 'EXECUTE'),
        'il salvataggio non è eseguibile da chiunque';

    RAISE NOTICE 'Test 695: OK';
END $$;
ROLLBACK;
