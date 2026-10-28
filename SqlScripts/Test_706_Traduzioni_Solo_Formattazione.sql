-- ============================================================================
-- Test dello script 706. Transazione annullata: nessun dato resta.
-- Prima dello script deve FALLIRE (le funzioni non esistono).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_n    integer;
    v_j    jsonb;
    g1 bigint; q1 bigint;
BEGIN
    -- 1. la regola, sul solo testo (senza tabelle)
    -- da titoletto 3 a titoletto 2: il tipo del blocco passa alla traduzione, le parole tradotte restano
    ASSERT fn_html_riporta_formattazione('<h3>Il viaggio</h3><p>Testo</p>', '<h2>Il viaggio</h2><p>Testo</p>',
                                         '<h3>Die Reise</h3><p>Text</p>') = '<h2>Die Reise</h2><p>Text</p>', 'h3 → h2';
    -- la formattazione dentro la traduzione (corsivo su una parola) resta com'è
    ASSERT fn_html_riporta_formattazione('<h3>Il <em>viaggio</em></h3>', '<h2>Il <em>viaggio</em></h2>',
                                         '<h3>Die <em>Reise</em></h3>') = '<h2>Die <em>Reise</em></h2>', 'h3 → h2 col corsivo';
    -- allineamento (attributi del blocco)
    ASSERT fn_html_riporta_formattazione('<p>Testo</p>', '<p class="ql-align-justify">Testo</p>', '<p>Text</p>')
           = '<p class="ql-align-justify">Text</p>', 'allineamento';
    -- da paragrafi a elenco: gli elenchi (ul/ol) vengono dall'italiano nuovo
    ASSERT fn_html_riporta_formattazione('<p>Uno</p><p>Due</p>', '<ul><li>Uno</li><li>Due</li></ul>',
                                         '<p>Eins</p><p>Zwei</p>') = '<ul><li>Eins</li><li>Zwei</li></ul>', 'paragrafi → elenco';
    ASSERT fn_html_riporta_formattazione('<ul><li>Uno</li></ul><p>Tre</p>', '<ol><li>Uno</li></ol><p>Tre</p>',
                                         '<ul><li>Eins</li></ul><p>Drei</p>') = '<ol><li>Eins</li></ol><p>Drei</p>', 'puntato → numerato';
    -- grassetto su tutto il blocco: passa (e si toglie) anche nella traduzione
    ASSERT fn_html_riporta_formattazione('<p>Attenzione</p>', '<p><strong>Attenzione</strong></p>', '<p>Achtung</p>')
           = '<p><strong>Achtung</strong></p>', 'grassetto su tutto il blocco';
    ASSERT fn_html_riporta_formattazione('<p><strong>Attenzione</strong></p>', '<p>Attenzione</p>', '<p><strong>Achtung</strong></p>')
           = '<p>Achtung</p>', 'grassetto tolto da tutto il blocco';
    ASSERT fn_html_riporta_formattazione('<p><strong>Attenzione</strong></p>', '<p><strong><em>Attenzione</em></strong></p>',
                                         '<p><strong>Achtung</strong></p>') = '<p><strong><em>Achtung</em></strong></p>', 'corsivo aggiunto al grassetto';
    -- grassetto su alcune parole (decisione A di Adriano, 2026-10-28): la traduzione resta valida, com'era
    ASSERT fn_html_riporta_formattazione('<p>Serve il casco sempre</p>', '<p>Serve il <strong>casco</strong> sempre</p>',
                                         '<p>Helm immer nötig</p>') = '<p>Helm immer nötig</p>', 'grassetto su alcune parole';
    ASSERT fn_html_riporta_formattazione('<p><strong>A</strong> e <strong>B</strong></p>', '<p><em><strong>A</strong> e <strong>B</strong></em></p>',
                                         '<p><strong>A</strong> und <strong>B</strong></p>')
           = '<p><em><strong>A</strong> und <strong>B</strong></em></p>', 'involucro su due grassetti';
    ASSERT fn_html_riporta_formattazione('<p><strong>A</strong> e <strong>B</strong></p>', '<p>A e B</p>',
                                         '<p><strong>A</strong> und <strong>B</strong></p>')
           = '<p><strong>A</strong> und <strong>B</strong></p>', 'due grassetti tolti: non è tutto il blocco, la traduzione resta';
    -- riga vuota aggiunta: va anche nella traduzione
    ASSERT fn_html_riporta_formattazione('<p>A</p><p>B</p>', '<p>A</p><p><br></p><p>B</p>', '<p>Ah</p><p>Be</p>')
           = '<p>Ah</p><p><br></p><p>Be</p>', 'riga vuota aggiunta';
    ASSERT fn_html_riporta_formattazione('<p>A</p><p><br></p><p>B</p>', '<p>A</p><p>B</p>', '<p>Ah</p><p><br></p><p>Be</p>')
           = '<p>Ah</p><p>Be</p>', 'riga vuota tolta';
    -- testo semplice: spazi diversi non cambiano niente; da testo a paragrafo e ritorno
    ASSERT fn_html_riporta_formattazione('Ciao  mondo', 'Ciao mondo', 'Hallo Welt') = 'Hallo Welt', 'spazi';
    ASSERT fn_html_riporta_formattazione('Ciao', '<p>Ciao</p>', 'Hallo') = '<p>Hallo</p>', 'testo → paragrafo';
    ASSERT fn_html_riporta_formattazione('<p>Ciao</p>', 'Ciao', '<p>Hallo</p>') = 'Hallo', 'paragrafo → testo';
    -- niente di cambiato: la traduzione com'è
    ASSERT fn_html_riporta_formattazione('<p>A</p>', '<p>A</p>', '<p>X</p>') = '<p>X</p>', 'uguale';

    -- quando NON si può: si ritraduce (NULL)
    ASSERT fn_html_riporta_formattazione('<p>Serve il casco</p>', '<p>Serve sempre il casco</p>', '<p>Helm</p>') IS NULL, 'parola aggiunta';
    ASSERT fn_html_riporta_formattazione('<p>Ciao</p>', '<p>ciao</p>', '<p>Hallo</p>') IS NULL, 'maiuscola cambiata';
    ASSERT fn_html_riporta_formattazione('<p>A B</p><p>C</p>', '<p>A</p><p>B C</p>', '<p>X</p><p>Y</p>') IS NULL, 'parole spostate fra blocchi';
    ASSERT fn_html_riporta_formattazione('<p>AB</p>', '<p>A</p><p>B</p>', '<p>X</p>') IS NULL, 'paragrafo spezzato';
    -- stesso testo in tutto (gli spazi lo rendono identico), ma «B» passa al primo blocco
    ASSERT fn_html_riporta_formattazione('<p>A </p><p>B C</p>', '<p>A B</p><p> C</p>', '<p>X</p><p>Y</p>') IS NULL,
           'parola passata al blocco prima';
    ASSERT fn_html_riporta_formattazione('<h3>A</h3><p>B</p>', '<h2>A</h2><p>B</p>', '<h3>X Y</h3>') IS NULL,
           'traduzione con un numero di blocchi diverso';
    ASSERT fn_html_riporta_formattazione('<p>A</p>B', '<h2>A</h2>B', '<p>X</p>Y') IS NULL, 'parole fuori dai blocchi';
    ASSERT fn_html_riporta_formattazione('<h3>A</h3>', '<h2>A</h2>', '<h3>X</h3>Y') IS NULL, 'parole fuori dai blocchi nella traduzione';

    -- 2. le traduzioni di un campo (entità finta: la tabella delle traduzioni è polimorfica)
    DELETE FROM web_traduzioni WHERE entita = 'test706';
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, azienda_id, created_by)
    VALUES ('test706', 1, 'testo', 'DE', '<h3>Die Reise</h3><p>Text</p>',  true,  false, false, 2, 'test706'),
           ('test706', 1, 'testo', 'EN', '<h3>The trip</h3><p>Text</p>',   false, true,  false, 2, 'test706'),  -- rivista a mano
           ('test706', 1, 'testo', 'FR', '<h3>Le voyage et le texte</h3>', true,  false, false, 2, 'test706'),  -- un blocco solo
           ('test706', 1, 'testo', 'ES', '<h3>Viejo</h3>',                 true,  false, true,  2, 'test706'),  -- già da rifare
           ('test706', 2, 'testo', 'DE', '<h3>Andere</h3><p>X</p>',        true,  false, false, 2, 'test706'),  -- altro record
           ('test706', 1, 'altro', 'DE', '<h3>Anderes Feld</h3><p>X</p>',  true,  false, false, 2, 'test706');  -- altro campo

    -- solo formattazione: chi combacia la riceve e resta valida (anche la rivista a mano), chi no diventa da rifare
    v_n := fn_web_traduzioni_dopo_modifica(2, 'test706', 1, 'testo', '<h3>Il viaggio</h3><p>Testo</p>', '<h2>Il viaggio</h2><p>Testo</p>');
    ASSERT v_n = 1, 'da rifare: solo il francese, non ' || v_n;
    ASSERT (SELECT testo FROM web_traduzioni WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'DE')
           = '<h2>Die Reise</h2><p>Text</p>', 'tedesco riformattato';
    ASSERT (SELECT testo = '<h2>The trip</h2><p>Text</p>' AND revisionato AND NOT tradotto_auto AND NOT obsoleto FROM web_traduzioni
             WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'EN'), 'la revisione a mano resta';
    ASSERT (SELECT obsoleto AND testo = '<h3>Le voyage et le texte</h3>' FROM web_traduzioni
             WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'FR'), 'francese da rifare, testo intatto';
    ASSERT (SELECT testo = '<h3>Viejo</h3>' FROM web_traduzioni
             WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'ES'), 'quella già da rifare non si tocca';
    ASSERT (SELECT bool_and(testo LIKE '<h3>%' AND NOT obsoleto) FROM web_traduzioni
             WHERE entita = 'test706' AND (entita_id = 2 OR campo = 'altro')), 'altri record e altri campi intatti';

    -- un'altra azienda non tocca queste traduzioni
    v_n := fn_web_traduzioni_dopo_modifica(1, 'test706', 1, 'testo', '<h2>Il viaggio</h2><p>Testo</p>', '<h2>Altro</h2>');
    ASSERT v_n = 0 AND NOT (SELECT obsoleto FROM web_traduzioni WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'DE'),
           'altra azienda: nessun effetto';

    -- parole cambiate: tutto da rifare, come prima
    v_n := fn_web_traduzioni_dopo_modifica(2, 'test706', 1, 'testo', '<h2>Il viaggio</h2><p>Testo</p>', '<h2>Il viaggio</h2><p>Testo nuovo</p>');
    ASSERT v_n = 2, 'parole cambiate: tedesco e inglese da rifare, non ' || v_n;
    ASSERT (SELECT bool_and(obsoleto) FROM web_traduzioni WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo'), 'tutte da rifare';

    -- nessuna differenza: niente da fare
    UPDATE web_traduzioni SET obsoleto = false WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'DE';
    ASSERT fn_web_traduzioni_dopo_modifica(2, 'test706', 1, 'testo', '<p>A</p>', '<p>A</p>') = 0, 'nessuna differenza';
    ASSERT NOT (SELECT obsoleto FROM web_traduzioni WHERE entita = 'test706' AND entita_id = 1 AND campo = 'testo' AND lingua = 'DE'), 'resta valida';

    -- senza azienda: errore (la versione per le entità comuni è _global)
    BEGIN
        PERFORM fn_web_traduzioni_dopo_modifica(NULL, 'test706', 1, 'testo', '<p>A</p>', '<p>B</p>');
        RAISE EXCEPTION 'doveva fallire';
    EXCEPTION WHEN OTHERS THEN
        ASSERT SQLERRM <> 'doveva fallire', 'senza azienda deve fallire';
    END;

    -- entità comuni (descrizioni dei tipi di viaggio): qualunque azienda abbia tradotto
    UPDATE web_traduzioni SET azienda_id = (SELECT min(azienda_id) FROM ana_aziende WHERE azienda_id <> 2), obsoleto = false, testo = '<p>Fuoristrada</p>' WHERE entita = 'test706' AND entita_id = 2;
    v_n := fn_web_traduzioni_dopo_modifica_global('test706', 2, 'testo', '<p>Fuoristrada</p>', '<h2>Fuoristrada</h2>');
    ASSERT v_n = 0 AND (SELECT testo FROM web_traduzioni WHERE entita = 'test706' AND entita_id = 2) = '<h2>Fuoristrada</h2>', 'globale';
    DELETE FROM web_traduzioni WHERE entita = 'test706';

    -- 3. le FAQ: il salvataggio usa la stessa regola per la risposta (HTML) e per domanda e gruppo
    PERFORM fn_web_sito_faq_save(2, '[{"nome": "Gruppo", "domande": [{"domanda": "Domanda?", "risposta": "<h3>Titolo</h3><p>Risposta</p>", "attiva": true}]}]'::jsonb, 'test706');
    v_j := fn_web_sito_faq_list(2);
    g1 := (v_j->0->>'id')::bigint; q1 := (v_j->0->'domande'->0->>'id')::bigint;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_sito_faq', q1, 'risposta', 'DE', '<h3>Titel</h3><p>Antwort</p>', 2, 'test706'),
           ('web_sito_faq', q1, 'domanda', 'DE', 'Frage?', 2, 'test706'),
           ('web_sito_faq_gruppi', g1, 'nome', 'DE', 'Gruppe', 2, 'test706');
    PERFORM fn_web_sito_faq_save(2, format('[{"id": %s, "nome": "Gruppo", "domande": [{"id": %s, "domanda": "Domanda?", "risposta": "<h2>Titolo</h2><p>Risposta</p>", "attiva": true}]}]', g1, q1)::jsonb, 'test706');
    ASSERT fn_web_sito_faq(2, 'DE')->0->'domande'->0->>'risposta' = '<h2>Titel</h2><p>Antwort</p>',
           'FAQ: solo formattazione, tradotta col titoletto nuovo: ' || fn_web_sito_faq(2, 'DE')::text;
    PERFORM fn_web_sito_faq_save(2, format('[{"id": %s, "nome": "Gruppo nuovo", "domande": [{"id": %s, "domanda": "Domanda nuova?", "risposta": "<h2>Titolo</h2><p>Risposta nuova</p>", "attiva": true}]}]', g1, q1)::jsonb, 'test706');
    ASSERT (SELECT count(*) FROM web_traduzioni WHERE created_by = 'test706' AND obsoleto) = 3, 'FAQ: parole cambiate, tutto da rifare';

    -- 4. permessi: solo il gestionale (in PROD una funzione nuova nasce eseguibile da chiunque)
    ASSERT NOT EXISTS (
        SELECT 1 FROM pg_proc p
         WHERE p.proname IN ('fn_html_blocchi', 'fn_html_involucro', 'fn_html_riporta_formattazione',
                             'fn_web_traduzioni_dopo_modifica', 'fn_web_traduzioni_dopo_modifica_global',
                             'fn_web_traduzioni_dopo_modifica_tutte')
           AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0)
                OR has_function_privilege('anon', p.oid, 'EXECUTE'))), 'funzioni aperte al pubblico';

    RAISE NOTICE 'Test 706: tutto ok';
END $$;
ROLLBACK;
