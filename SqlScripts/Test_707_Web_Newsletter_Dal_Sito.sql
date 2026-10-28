-- ============================================================================
-- Test dello script 707. Transazione annullata: nessun dato resta.
-- Prima dello script deve FALLIRE (le funzioni non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_az2  integer := 2;
    v_az   integer := (SELECT min(azienda_id) FROM ana_aziende WHERE azienda_id <> 2);   -- un'altra azienda
    c1 text; c2 text; c3 text;
    v_id   bigint;
    v_n    integer;
    v_seg  text;
    f      text;
BEGIN
    DELETE FROM web_newsletter_richieste;   -- il test non dipende dalle richieste vere
    DELETE FROM web_newsletter_iscritti WHERE email ILIKE '%@prova707.test';
    DELETE FROM web_newsletter_soppressioni WHERE email ILIKE '%@prova707.test';

    -- 1. richiesta nuova: un codice; iscritto in attesa, SENZA consenso, che non riceve niente
    c1 := fn_web_newsletter_richiedi(v_az2, '  Anna@Prova707.test ', 'de', 'imp-a');
    ASSERT c1 ~ '^[0-9a-f]{64}$', 'codice: ' || coalesce(c1, 'NULL');
    ASSERT (SELECT stato = 'in_attesa' AND NOT consenso AND lingua = 'DE' AND conferma_lingua = 'DE'
              AND conferma_impronta <> c1 AND conferma_scadenza BETWEEN now() + interval '47 hours' AND now() + interval '49 hours'
              FROM web_newsletter_iscritti WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'),
           'in attesa, codice non in chiaro, scadenza 48 ore';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_destinatari_newsletter(v_az2, NULL) d WHERE d.email = 'anna@prova707.test'),
           'in attesa: non riceve la newsletter';

    -- 2. conferma: attivo con consenso, fonte e data; lingua della pagina; codice usabile una volta (poi «confermato» di nuovo)
    ASSERT fn_web_newsletter_conferma(v_az, c1) = 'sconosciuto', 'codice di un''altra azienda';
    ASSERT fn_web_newsletter_conferma(v_az2, c1) = 'confermato', 'conferma';
    ASSERT (SELECT stato = 'attivo' AND consenso AND lingua = 'DE' AND consenso_fonte = 'sito, doppio consenso'
              AND consenso_data > now() - interval '1 minute' FROM web_newsletter_iscritti
             WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'), 'attivo con consenso';
    ASSERT EXISTS (SELECT 1 FROM fn_web_destinatari_newsletter(v_az2, NULL) d WHERE d.email = 'anna@prova707.test'), 'ora riceve';
    ASSERT fn_web_newsletter_conferma(v_az2, c1) = 'confermato', 'secondo clic sullo stesso codice: già confermato';
    ASSERT fn_web_newsletter_conferma(v_az2, 'abc') = 'sconosciuto', 'codice malformato';
    ASSERT fn_web_newsletter_conferma(v_az2, NULL) = 'sconosciuto', 'senza codice';

    -- 3. già attivo: nessuna mail (risposta uguale per il visitatore), resta attivo
    ASSERT fn_web_newsletter_richiedi(v_az2, 'anna@prova707.test', 'it', 'imp-b') IS NULL, 'già attivo: niente mail';
    ASSERT (SELECT stato FROM web_newsletter_iscritti WHERE azienda_id = v_az2 AND email = 'anna@prova707.test') = 'attivo',
           'una richiesta non rimette in attesa un iscritto attivo';

    -- 4. codice scaduto
    c2 := fn_web_newsletter_richiedi(v_az2, 'bruno@prova707.test', 'it', 'imp-c');
    UPDATE web_newsletter_iscritti SET conferma_scadenza = now() - interval '1 minute' WHERE email = 'bruno@prova707.test';
    ASSERT fn_web_newsletter_conferma(v_az2, c2) = 'scaduto', 'scaduto';
    ASSERT (SELECT stato FROM web_newsletter_iscritti WHERE email = 'bruno@prova707.test') = 'in_attesa', 'scaduto: resta in attesa';

    -- 5. limiti: 3 richieste all'ora per visitatore; per indirizzo una mail ogni 10 minuti
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c1@prova707.test', 'it', 'imp-d') IS NOT NULL, 'visitatore, 1';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c2@prova707.test', 'it', 'imp-d') IS NOT NULL, 'visitatore, 2';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c3@prova707.test', 'it', 'imp-d') IS NOT NULL, 'visitatore, 3';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c4@prova707.test', 'it', 'imp-d') IS NULL, 'visitatore, 4: fermo';
    ASSERT NOT EXISTS (SELECT 1 FROM web_newsletter_iscritti WHERE email = 'c4@prova707.test'), 'fermo: nessun iscritto creato';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c1@prova707.test', 'it', 'imp-e') IS NULL, 'stesso indirizzo dopo 1 minuto: niente mail';
    -- per indirizzo: al massimo 3 mail al giorno (da visitatori diversi, a distanza)
    UPDATE web_newsletter_richieste SET creata = creata - interval '11 minutes' WHERE email = 'c1@prova707.test';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c1@prova707.test', 'it', 'imp-f') IS NOT NULL, 'indirizzo, 2ª mail dopo 11 minuti';
    UPDATE web_newsletter_richieste SET creata = creata - interval '11 minutes' WHERE email = 'c1@prova707.test';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c1@prova707.test', 'it', 'imp-g') IS NOT NULL, 'indirizzo, 3ª mail';
    UPDATE web_newsletter_richieste SET creata = creata - interval '11 minutes' WHERE email = 'c1@prova707.test';
    ASSERT fn_web_newsletter_richiedi(v_az2, 'c1@prova707.test', 'it', 'imp-h') IS NULL, 'indirizzo, 4ª mail nello stesso giorno: ferma';
    -- un'altra azienda ha i suoi conti
    ASSERT fn_web_newsletter_richiedi(v_az, 'c1@prova707.test', 'it', 'imp-z') IS NOT NULL, 'altra azienda: conti separati';

    -- 6. dati non validi: errore
    FOREACH f IN ARRAY ARRAY['non-email', 'a@b', repeat('x', 250) || '@prova707.test', ''] LOOP
        BEGIN
            PERFORM fn_web_newsletter_richiedi(v_az2, f, 'it', 'imp-x');
            RAISE EXCEPTION 'doveva fallire';
        EXCEPTION WHEN OTHERS THEN
            ASSERT SQLERRM <> 'doveva fallire', 'email non valida accettata: ' || f;
        END;
    END LOOP;
    BEGIN
        PERFORM fn_web_newsletter_richiedi(v_az2, 'ok@prova707.test', 'xx', 'imp-x');
        RAISE EXCEPTION 'doveva fallire';
    EXCEPTION WHEN OTHERS THEN
        ASSERT SQLERRM <> 'doveva fallire', 'lingua non valida accettata';
    END;

    -- 7. disiscrizione: firma col segreto dell'azienda (come il gestionale: HMAC-SHA256 dell'indirizzo minuscolo)
    v_seg := (SELECT segreto_disiscrizione FROM ana_aziende WHERE azienda_id = v_az2);
    ASSERT v_seg ~ '^[0-9a-f]{64}$', 'segreto della disiscrizione';
    ASSERT v_seg <> (SELECT segreto_disiscrizione FROM ana_aziende WHERE azienda_id = v_az), 'segreto diverso per azienda';
    ASSERT fn_web_newsletter_disiscrivi(v_az2, 'anna@prova707.test', 'sbagliata') = 'firma', 'firma sbagliata';
    ASSERT fn_web_newsletter_disiscrivi(v_az2, 'anna@prova707.test',
             encode(extensions.hmac('bruno@prova707.test', v_seg, 'sha256'), 'hex')) = 'firma', 'firma di un altro indirizzo';
    ASSERT fn_web_newsletter_disiscrivi(v_az, 'anna@prova707.test',
             encode(extensions.hmac('anna@prova707.test', v_seg, 'sha256'), 'hex')) = 'firma', 'firma di un''altra azienda';
    ASSERT (SELECT stato FROM web_newsletter_iscritti WHERE azienda_id = v_az2 AND email = 'anna@prova707.test') = 'attivo',
           'firme sbagliate: nessun effetto';
    ASSERT fn_web_newsletter_disiscrivi(v_az2, 'ANNA@prova707.test',
             upper(encode(extensions.hmac('anna@prova707.test', v_seg, 'sha256'), 'hex'))) = 'disiscritto', 'disiscrizione';
    ASSERT (SELECT stato = 'disiscritto' AND NOT consenso FROM web_newsletter_iscritti
             WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'), 'iscritto disiscritto';
    ASSERT EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'),
           'soppressione creata (ferma anche un cliente con consenso)';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_destinatari_newsletter(v_az2, NULL) d WHERE d.email = 'anna@prova707.test'), 'non riceve più';
    ASSERT fn_web_newsletter_disiscrivi(v_az2, 'anna@prova707.test',
             encode(extensions.hmac('anna@prova707.test', v_seg, 'sha256'), 'hex')) = 'disiscritto', 'seconda volta: nessun errore';
    -- un indirizzo che non è fra gli iscritti (es. un cliente): basta la soppressione
    ASSERT fn_web_newsletter_disiscrivi(v_az2, 'cliente@prova707.test',
             encode(extensions.hmac('cliente@prova707.test', v_seg, 'sha256'), 'hex')) = 'disiscritto', 'non iscritto';
    ASSERT EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'cliente@prova707.test'), 'soppresso';

    -- 8. riiscrizione di un soppresso (Adriano, 2026-10-28): la mail parte; senza conferma resta soppresso; confermando torna attivo
    UPDATE web_newsletter_richieste SET creata = creata - interval '1 hour' WHERE email = 'anna@prova707.test';  -- la mail del punto 1 è di un'ora fa
    c3 := fn_web_newsletter_richiedi(v_az2, 'anna@prova707.test', 'fr', 'imp-i');
    ASSERT c3 IS NOT NULL, 'soppresso che si riiscrive: la mail parte';
    ASSERT (SELECT stato FROM web_newsletter_iscritti WHERE email = 'anna@prova707.test' AND azienda_id = v_az2) = 'disiscritto',
           'prima della conferma resta disiscritto';
    ASSERT EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'),
           'prima della conferma resta soppresso';
    ASSERT fn_web_newsletter_conferma(v_az2, c3) = 'confermato', 'riconferma';
    ASSERT NOT EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'anna@prova707.test'),
           'confermando, la soppressione si toglie';
    ASSERT (SELECT stato = 'attivo' AND consenso AND lingua = 'FR' FROM web_newsletter_iscritti
             WHERE email = 'anna@prova707.test' AND azienda_id = v_az2), 'di nuovo attivo';
    -- un soppresso che non è fra gli iscritti (es. dal vecchio sito) si riiscrive: nasce in attesa, la soppressione resta fino alla conferma
    c3 := fn_web_newsletter_richiedi(v_az2, 'cliente@prova707.test', 'it', 'imp-j');
    ASSERT c3 IS NOT NULL AND EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'cliente@prova707.test'),
           'soppresso non iscritto';
    ASSERT fn_web_newsletter_conferma(v_az2, c3) = 'confermato', 'soppresso non iscritto, conferma';
    ASSERT NOT EXISTS (SELECT 1 FROM web_newsletter_soppressioni WHERE azienda_id = v_az2 AND email = 'cliente@prova707.test'),
           'soppresso non iscritto, confermato: soppressione tolta';

    -- 9. pulizia: le richieste in attesa scadute da più di un giorno spariscono (non hanno mai dato il consenso);
    --    un disiscritto con una richiesta scaduta resta (è storia)
    UPDATE web_newsletter_iscritti SET conferma_scadenza = now() - interval '2 days' WHERE email IN ('bruno@prova707.test');
    c3 := fn_web_newsletter_richiedi(v_az2, 'dora@prova707.test', 'it', 'imp-k');
    ASSERT NOT EXISTS (SELECT 1 FROM web_newsletter_iscritti WHERE email = 'bruno@prova707.test'), 'in attesa scaduta: cancellata';

    -- 10. la regola che lasciava ad anon inserire iscritti attivi non c'è più; tabella delle richieste chiusa
    ASSERT NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'web_newsletter_iscritti' AND policyname = 'anon_insert_iscrizione'),
           'regola anon_insert_iscrizione ancora presente';
    ASSERT (SELECT relrowsecurity FROM pg_class WHERE relname = 'web_newsletter_richieste'), 'RLS spente sulle richieste';

    -- 11. permessi: le tre funzioni solo a sito_posta (e al proprietario); nessuna tabella a sito_posta
    ASSERT NOT EXISTS (
        SELECT 1 FROM pg_proc p
         WHERE p.proname IN ('fn_web_newsletter_richiedi', 'fn_web_newsletter_conferma', 'fn_web_newsletter_disiscrivi')
           AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0)
                OR has_function_privilege('anon', p.oid, 'EXECUTE')
                OR NOT has_function_privilege('sito_posta', p.oid, 'EXECUTE')
                OR NOT p.prosecdef)), 'permessi delle funzioni';
    ASSERT (SELECT count(*) FROM pg_proc p WHERE p.proname IN ('fn_web_newsletter_richiedi', 'fn_web_newsletter_conferma',
                                                              'fn_web_newsletter_disiscrivi')) = 3, 'una sola versione per funzione';
    ASSERT NOT has_table_privilege('sito_posta', 'web_newsletter_iscritti', 'SELECT')
       AND NOT has_table_privilege('sito_posta', 'web_newsletter_richieste', 'SELECT')
       AND NOT has_table_privilege('anon', 'web_newsletter_richieste', 'SELECT')
       AND NOT has_column_privilege('anon', 'ana_aziende', 'segreto_disiscrizione', 'SELECT'), 'tabelle chiuse';

    RAISE NOTICE 'Test 707: tutto ok';
END $$;
ROLLBACK;
