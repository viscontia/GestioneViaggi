-- ============================================================================
-- Test dello script 661: il sito completa una scheda esistente, non la riscrive
--
-- Gira tutto dentro una transazione che si annulla: non lascia modifiche.
-- Usa il cliente 3870 (azienda 2, scheda completa: indirizzo, telefono, codice
-- fiscale, documento, email); l'azienda 6 esiste e il 3870 non ci sta.
--
-- Per avere un campo VUOTO da riempire, il test svuota a mano un campo del 3870
-- e poi chiede alla funzione di completarlo. ⚠️ Si svuotano solo campi facoltativi
-- o che la scheda tollera vuoti: se fn_ana_clienti_valida rifiutasse la scheda per
-- un altro motivo, il test proverebbe la validazione, non il completamento. Per
-- questo la prima verifica e' che il 3870, cosi' com'e', la validazione la superi.
--
-- ⚠️ LA CHIAVE ESTERNA A ZERO NON SI PROVA QUI. Titolo, comune di residenza e
-- comune di nascita sono NOT NULL con un vincolo di chiave esterna verso tabelle
-- che non hanno la riga 0, e il vincolo non e' differibile: in ana_clienti uno
-- zero non puo' esistere. La funzione lo tratta comunque da vuoto, come fa
-- fn_ana_clienti_campi_mancanti, ma provarlo vorrebbe dire disattivare i vincoli.
--
-- ⚠️ La concorrenza (due completamenti insieme) non si prova in una sessione sola:
-- la garantisce il FOR UPDATE sulla riga, vedi lo script.
-- ============================================================================

BEGIN;
DO $$
DECLARE
    v_prima   RECORD;
    v_dopo    RECORD;
    v_scritti TEXT[];
    v_msg     TEXT;
    v_dettaglio TEXT;
    v_cf_vero TEXT;
    -- Ben formato, con il carattere di controllo giusto, ma nato il 20 invece
    -- che il 19: supera la forma e non corrisponde ai dati del 3870.
    v_cf_falso TEXT := 'VSCDRN59A20F952' || fn_cf_carattere_controllo('VSCDRN59A20F952');
BEGIN
    SELECT * INTO v_prima FROM ana_clienti WHERE cliente_id = 3870;

    -- 0. il 3870 cosi' com'e' supera la validazione: se no i casi sotto non provano nulla
    ASSERT NOT EXISTS (SELECT 1 FROM fn_ana_clienti_valida(
                           (SELECT to_jsonb(c) FROM ana_clienti c WHERE c.cliente_id = 3870), 3870)
                        WHERE gravita IN ('ERRORE', 'CONFERMA')),
           'il 3870 non supera piu'' fn_ana_clienti_valida: scegliere un''altra scheda';
    v_cf_vero := fn_cf_calcola(v_prima.cliente_cognome, v_prima.cliente_nome, v_prima.cliente_data_nascita,
                               v_prima.cliente_sesso, v_prima.cliente_comune_nascita_fk);
    ASSERT v_cf_vero = v_prima.cliente_codicefiscale, 'il codice fiscale del 3870 non torna con i suoi dati';

    -- 1. un campo PIENO non si sovrascrive
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_indirizzo_residenza', 'VIA FALSA 1',
               'cliente_telefono', '000'));
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_scritti IS NULL, 'ha scritto su campi pieni: ' || array_to_string(v_scritti, ',');
    ASSERT v_dopo.cliente_indirizzo_residenza = v_prima.cliente_indirizzo_residenza, 'indirizzo sovrascritto';
    ASSERT v_dopo.cliente_telefono = v_prima.cliente_telefono, 'telefono sovrascritto';

    -- 2. un campo VUOTO si riempie, e viene restituito con la sua etichetta.
    --    Nella stessa chiamata un campo pieno: passa solo quello vuoto.
    UPDATE ana_clienti SET cliente_intolleranza = NULL WHERE cliente_id = 3870;
    SELECT array_agg(etichetta) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_intolleranza', 'NESSUNA',
               'cliente_telefono', '000'));
    ASSERT v_scritti = ARRAY['le allergie o intolleranze'],
           'campo vuoto non riempito: ' || COALESCE(array_to_string(v_scritti, ','), 'nulla');
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_dopo.cliente_intolleranza = 'NESSUNA', 'valore non scritto';
    ASSERT v_dopo.cliente_telefono = v_prima.cliente_telefono, 'telefono sovrascritto insieme al completamento';

    -- 3. email e consenso non passano mai di qui
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_email', 'altro@example.invalid',
               'consenso_marketing', true,
               'consenso_marketing_fonte', 'SITO_ISCRIZIONE'));
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_scritti IS NULL, 'email o consenso scritti dal completamento';
    ASSERT v_dopo.cliente_email = v_prima.cliente_email, 'email scritta dal completamento';
    ASSERT NOT v_dopo.consenso_marketing, 'consenso acceso dal completamento';

    -- 4. cliente di un'altra azienda: rifiutato con il messaggio di «non trovato».
    --    Si controlla il messaggio: un raise_exception qualsiasi (per esempio una
    --    regola di validazione) non deve bastare a far passare il caso.
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 6, jsonb_build_object('cliente_intolleranza', 'X'));
        ASSERT false, 'azienda sbagliata accettata';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg = 'Cliente non trovato.', 'azienda sbagliata: messaggio inatteso: ' || v_msg;
    END;

    -- 5. una chiave che non e' una colonna, e una colonna che il modulo non manda
    --    (note, IBAN, lingua, controparte, audit): ignorate, senza errore.
    --    Note e IBAN del 3870 sono vuoti: se passassero, si vedrebbe.
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'colonna_inventata', 'X',
               'cliente_note', 'NOTA DAL SITO',
               'cliente_iban', 'IT60X0542811101000000123456',
               'controparte_fk', 1,
               'cliente_lingua', 'IT',
               'created_by', 'sito',
               'azienda_fk', 6,
               'cliente_id', 1));
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_scritti IS NULL, 'scritte colonne fuori dal modulo: ' || array_to_string(v_scritti, ',');
    ASSERT COALESCE(v_dopo.cliente_note, '') = COALESCE(v_prima.cliente_note, ''), 'note scritte';
    ASSERT COALESCE(v_dopo.cliente_iban, '') = COALESCE(v_prima.cliente_iban, ''), 'IBAN scritto';
    ASSERT v_dopo.controparte_fk IS NOT DISTINCT FROM v_prima.controparte_fk, 'controparte scritta';
    ASSERT v_dopo.cliente_lingua = v_prima.cliente_lingua, 'lingua scritta';
    ASSERT v_dopo.azienda_fk = 2, 'azienda cambiata';

    -- 6. un valore vuoto non riempie un campo vuoto e non svuota un campo pieno;
    --    un oggetto o una lista al posto di un testo si saltano
    UPDATE ana_clienti SET cliente_intolleranza = NULL WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_intolleranza', '   ',
               'cliente_telefono', '',
               'cliente_indirizzo_residenza', NULL));
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_scritti IS NULL, 'un valore vuoto e'' stato scritto: ' || array_to_string(v_scritti, ',');
    ASSERT v_dopo.cliente_intolleranza IS NULL, 'campo vuoto «riempito» di spazi';
    ASSERT v_dopo.cliente_telefono = v_prima.cliente_telefono, 'telefono svuotato';
    ASSERT v_dopo.cliente_indirizzo_residenza = v_prima.cliente_indirizzo_residenza, 'indirizzo svuotato';
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, '{"cliente_intolleranza": {"a": 1}}'::jsonb);
    ASSERT v_scritti IS NULL, 'un oggetto e'' stato scritto come intolleranza';
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, '{"cliente_intolleranza": ["PESCE"]}'::jsonb);
    ASSERT v_scritti IS NULL, 'una lista e'' stata scritta come intolleranza';
    ASSERT (SELECT cliente_intolleranza FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'intolleranza scritta da un oggetto o da una lista';

    -- 7. anche uno spazio in archivio e' vuoto: ' ' non e' un indirizzo
    UPDATE ana_clienti SET cliente_indirizzo_residenza = ' ' WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_indirizzo_residenza', 'VIA ROMA 10'));
    ASSERT v_scritti = ARRAY['cliente_indirizzo_residenza'], 'indirizzo di soli spazi non completato';
    ASSERT (SELECT cliente_indirizzo_residenza FROM ana_clienti WHERE cliente_id = 3870) = 'VIA ROMA 10',
           'indirizzo non scritto';

    -- 8. la validazione e' quella di fn_ana_clienti_valida: una data di rilascio
    --    futura su un campo vuoto si rifiuta, con un messaggio, e non si scrive
    UPDATE ana_clienti SET cliente_documento_rilasciato_data = NULL WHERE cliente_id = 3870;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object(
                    'cliente_documento_rilasciato_data', (CURRENT_DATE + 30)::TEXT));
        ASSERT false, 'data di rilascio futura accettata';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg = 'La data di rilascio del documento è nel futuro.',
               'validazione: messaggio inatteso: ' || v_msg;
    END;
    ASSERT (SELECT cliente_documento_rilasciato_data FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'data di rilascio futura scritta';

    -- 9. un valore malformato su un campo vuoto: un messaggio unico, non l'errore di Postgres
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object(
                    'cliente_documento_rilasciato_data', 'abc'));
        ASSERT false, 'data «abc» accettata';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg = 'Uno dei dati inviati non è nel formato atteso.',
               'data malformata: messaggio inatteso: ' || v_msg;
    END;
    UPDATE ana_clienti SET cliente_documento_rilasciato_data = v_prima.cliente_documento_rilasciato_data
     WHERE cliente_id = 3870;

    -- 10. ⛔️ codice fiscale falso su una scheda senza codice fiscale ma con i dati
    --     di nascita: rifiutato, e il messaggio NON rivela il codice fiscale che
    --     risulterebbe dai dati in archivio (ne' alcun altro codice fiscale)
    UPDATE ana_clienti SET cliente_codicefiscale = NULL WHERE cliente_id = 3870;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_codicefiscale', v_cf_falso));
        ASSERT false, 'codice fiscale falso accettato';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT position(v_cf_vero IN v_msg) = 0, 'il messaggio rivela il codice fiscale della scheda: ' || v_msg;
        ASSERT v_msg !~ '[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]',
               'il messaggio contiene un codice fiscale: ' || v_msg;
        ASSERT v_msg = 'Il codice fiscale non corrisponde ai dati della scheda.',
               'codice fiscale falso: messaggio inatteso: ' || v_msg;
    END;
    ASSERT (SELECT cliente_codicefiscale FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'codice fiscale falso scritto';

    -- 11. codice fiscale che non si puo' confermare: saltato, senza errore.
    --     a) comune di nascita senza codice catastale (nato all'estero): FORMA_OK.
    --        E' il caso che prova la regola: la scheda e' completa, e senza la
    --        regola la validazione lascerebbe passare il codice.
    UPDATE ana_clienti
       SET cliente_comune_nascita_fk = (SELECT min(comune_id) FROM ana_geo_comuni
                                         WHERE btrim(COALESCE(comune_codfisc, '')) = '')
     WHERE cliente_id = 3870;
    ASSERT (SELECT cliente_comune_nascita_fk FROM ana_clienti WHERE cliente_id = 3870) IS NOT NULL,
           'in locale non c''e'' un comune senza codice catastale: il caso 11a non prova nulla';
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_codicefiscale', v_cf_vero));
    ASSERT v_scritti IS NULL, 'codice fiscale non confermabile (nato all''estero) scritto';
    ASSERT (SELECT cliente_codicefiscale FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'codice fiscale non confermabile in archivio';
    UPDATE ana_clienti SET cliente_comune_nascita_fk = v_prima.cliente_comune_nascita_fk WHERE cliente_id = 3870;
    --     b) manca la data di nascita: anche qui FORMA_OK, saltato
    UPDATE ana_clienti SET cliente_data_nascita = NULL WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_codicefiscale', v_cf_vero));
    ASSERT v_scritti IS NULL, 'codice fiscale non confermato scritto';
    ASSERT (SELECT cliente_codicefiscale FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'codice fiscale non confermato in archivio';

    -- 12. data di nascita da sola: nessun codice fiscale la conferma, si salta
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT));
    ASSERT v_scritti IS NULL, 'data di nascita scritta senza codice fiscale che la confermi';
    ASSERT (SELECT cliente_data_nascita FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'data di nascita non confermata in archivio';

    -- 13. data di nascita e codice fiscale incoerenti, tutti e due vuoti in archivio:
    --     non si scrive nessuno dei due
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT,
               'cliente_codicefiscale', v_cf_falso));
    ASSERT v_scritti IS NULL, 'scritti data e codice fiscale incoerenti: ' || array_to_string(v_scritti, ',');

    -- 14. codice fiscale e data di nascita tutti e due vuoti in archivio: anche se
    --     coerenti tra loro non si scrive nessuno dei due, e senza errore. Il
    --     codice fiscale si calcola da dati pubblici (cognome, nome, sesso, comune,
    --     gia' in scheda) piu' la data: una coppia inventata si conferma da sola.
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', '1990-05-05',
               'cliente_codicefiscale', fn_cf_calcola(v_prima.cliente_cognome, v_prima.cliente_nome,
                                                      '1990-05-05', v_prima.cliente_sesso,
                                                      v_prima.cliente_comune_nascita_fk)));
    ASSERT v_scritti IS NULL, 'scritta una coppia data e codice fiscale inventata: ' || array_to_string(v_scritti, ',');
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_dopo.cliente_data_nascita IS NULL AND v_dopo.cliente_codicefiscale IS NULL,
           'data o codice fiscale scritti con tutti e due vuoti in archivio';

    -- 14-bis. data di nascita in archivio, codice fiscale vuoto: passa il codice vero
    UPDATE ana_clienti SET cliente_data_nascita = v_prima.cliente_data_nascita WHERE cliente_id = 3870;
    SELECT array_agg(etichetta) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_codicefiscale', lower(v_cf_vero)));
    ASSERT v_scritti = ARRAY['il codice fiscale'],
           'codice fiscale vero non scritto: ' || COALESCE(array_to_string(v_scritti, ','), 'nulla');
    ASSERT (SELECT cliente_codicefiscale FROM ana_clienti WHERE cliente_id = 3870) = v_cf_vero,
           'codice fiscale non scritto';

    -- 15. data di nascita vuota, codice fiscale gia' in archivio: la conferma quel
    --     codice, se arriva anche nel modulo; senza, si salta
    UPDATE ana_clienti SET cliente_data_nascita = NULL, cliente_codicefiscale = v_prima.cliente_codicefiscale
     WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT));
    ASSERT v_scritti IS NULL, 'data di nascita scritta senza il codice fiscale nel modulo';
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT,
               'cliente_codicefiscale', v_cf_vero));
    ASSERT v_scritti = ARRAY['cliente_data_nascita'],
           'data di nascita confermata dal codice in archivio non scritta: ' || COALESCE(array_to_string(v_scritti, ','), 'nulla');

    -- 15-bis. ⛔️ un vincolo di tabella che la validazione non guarda prima: una data
    --     di rilascio anteriore alla nascita. L'errore di Postgres porterebbe nel
    --     DETAIL la riga intera della scheda; esce invece un testo senza valori.
    UPDATE ana_clienti SET cliente_documento_rilasciato_data = NULL WHERE cliente_id = 3870;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object(
                    'cliente_documento_rilasciato_data', '1900-01-01'));
        ASSERT false, 'data di rilascio anteriore alla nascita accettata';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_dettaglio = PG_EXCEPTION_DETAIL;
        ASSERT v_msg = 'Alcune date non sono coerenti tra loro.', 'vincolo sulle date: messaggio inatteso: ' || v_msg;
        ASSERT position(v_cf_vero IN v_msg || COALESCE(v_dettaglio, '')) = 0
           AND position(v_prima.cliente_data_nascita::TEXT IN v_msg || COALESCE(v_dettaglio, '')) = 0,
               'vincolo sulle date: l''errore rivela i dati della scheda';
        ASSERT COALESCE(v_dettaglio, '') = '', 'vincolo sulle date: l''errore ha un dettaglio: ' || v_dettaglio;
    END;
    UPDATE ana_clienti SET cliente_documento_rilasciato_data = v_prima.cliente_documento_rilasciato_data
     WHERE cliente_id = 3870;

    -- 15-ter. ⛔️ l'indice unico su cognome + nome + data di nascita (senza comune,
    --     quindi fn_ana_clienti_valida non lo vede come doppione): un omonimo nato
    --     lo stesso giorno in un altro comune. Anche qui un testo senza valori.
    UPDATE ana_clienti SET cliente_data_nascita = NULL WHERE cliente_id = 3870;
    INSERT INTO ana_clienti (cliente_id, cliente_titolo_fk, cliente_cognome, cliente_nome, cliente_sesso,
                             cliente_comune_residenza_fk, cliente_comune_nascita_fk, cliente_data_nascita,
                             azienda_fk)
    SELECT (SELECT max(cliente_id) + 1 FROM ana_clienti), v_prima.cliente_titolo_fk,
           v_prima.cliente_cognome, v_prima.cliente_nome, v_prima.cliente_sesso,
           v_prima.cliente_comune_residenza_fk,
           (SELECT min(comune_id) FROM ana_geo_comuni WHERE comune_id <> v_prima.cliente_comune_nascita_fk),
           v_prima.cliente_data_nascita, 2;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object(
                    'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT,
                    'cliente_codicefiscale', v_cf_vero));
        ASSERT false, 'omonimo nato lo stesso giorno accettato';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_dettaglio = PG_EXCEPTION_DETAIL;
        ASSERT v_msg = 'Questi dati risultano già su un''altra scheda: usa il codice per modificare la scheda.',
               'indice unico: messaggio inatteso: ' || v_msg;
        ASSERT COALESCE(v_dettaglio, '') = '', 'indice unico: l''errore ha un dettaglio: ' || v_dettaglio;
    END;
    -- L'omonimo resta fino al ROLLBACK: i casi che seguono non guardano la data di nascita.

    -- 16. senza email in archivio non c'e' avviso, quindi non si completa niente:
    --     stesso messaggio del cliente che non esiste
    UPDATE ana_clienti SET cliente_email = NULL, cliente_intolleranza = NULL WHERE cliente_id = 3870;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_intolleranza', 'NESSUNA'));
        ASSERT false, 'completamento accettato su una scheda senza email';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg = 'Cliente non trovato.', 'scheda senza email: messaggio inatteso: ' || v_msg;
    END;
    ASSERT (SELECT cliente_intolleranza FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'scheda senza email completata';

    -- 17. anon (e authenticated, dove esiste) non le puo' chiamare (script 659)
    ASSERT NOT has_function_privilege('anon', 'fn_web_cliente_completa(integer,integer,jsonb)', 'EXECUTE'),
           'anon puo'' completare le schede';
    ASSERT NOT has_function_privilege('anon', 'fn_web_cliente_completa_esito_cf(jsonb)', 'EXECUTE'),
           'anon puo'' interrogare l''esito del codice fiscale';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        ASSERT NOT has_function_privilege('authenticated', 'fn_web_cliente_completa(integer,integer,jsonb)', 'EXECUTE'),
               'authenticated puo'' completare le schede';
        ASSERT NOT has_function_privilege('authenticated', 'fn_web_cliente_completa_esito_cf(jsonb)', 'EXECUTE'),
               'authenticated puo'' interrogare l''esito del codice fiscale';
    END IF;

    RAISE NOTICE 'Test 661: tutto OK';
END $$;
ROLLBACK;
