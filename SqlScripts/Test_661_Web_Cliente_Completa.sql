-- ============================================================================
-- Test dello script 661: il sito completa una scheda esistente, non la riscrive
--
-- Gira tutto dentro una transazione che si annulla: non lascia modifiche.
-- Usa il cliente 3870 (azienda 2, scheda completa: indirizzo, telefono, codice
-- fiscale, documento); l'azienda 6 esiste e il 3870 non ci sta.
--
-- Per avere un campo VUOTO da riempire, il test svuota a mano un campo del 3870
-- e poi chiede alla funzione di completarlo. ⚠️ Si svuotano solo campi facoltativi
-- o che la scheda tollera vuoti: se fn_ana_clienti_update rifiutasse la scheda per
-- un altro motivo, il test proverebbe la validazione, non il completamento.
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
BEGIN
    SELECT * INTO v_prima FROM ana_clienti WHERE cliente_id = 3870;

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

    -- 3. email e consenso non passano mai di qui, nemmeno se oggi fossero vuoti
    UPDATE ana_clienti SET cliente_email = NULL WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_email', 'altro@example.invalid',
               'consenso_marketing', true,
               'consenso_marketing_fonte', 'SITO_ISCRIZIONE'));
    SELECT * INTO v_dopo FROM ana_clienti WHERE cliente_id = 3870;
    ASSERT v_scritti IS NULL, 'email o consenso scritti dal completamento';
    ASSERT v_dopo.cliente_email IS NULL, 'email scritta dal completamento';
    ASSERT NOT v_dopo.consenso_marketing, 'consenso acceso dal completamento';
    UPDATE ana_clienti SET cliente_email = v_prima.cliente_email WHERE cliente_id = 3870;

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

    -- 6. un valore vuoto non riempie un campo vuoto e non svuota un campo pieno
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

    -- 7. anche uno spazio in archivio e' vuoto: ' ' non e' un indirizzo
    UPDATE ana_clienti SET cliente_indirizzo_residenza = ' ' WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object('cliente_indirizzo_residenza', 'VIA ROMA 10'));
    ASSERT v_scritti = ARRAY['cliente_indirizzo_residenza'], 'indirizzo di soli spazi non completato';
    ASSERT (SELECT cliente_indirizzo_residenza FROM ana_clienti WHERE cliente_id = 3870) = 'VIA ROMA 10',
           'indirizzo non scritto';

    -- 8. la validazione e' quella di fn_ana_clienti_update: una data di rilascio
    --    futura su un campo vuoto si rifiuta, con il suo messaggio, e non si scrive
    UPDATE ana_clienti SET cliente_documento_rilasciato_data = NULL WHERE cliente_id = 3870;
    BEGIN
        PERFORM fn_web_cliente_completa(3870, 2, jsonb_build_object(
                    'cliente_documento_rilasciato_data', (CURRENT_DATE + 30)::TEXT));
        ASSERT false, 'data di rilascio futura accettata';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
        ASSERT v_msg LIKE '%La data di rilascio del documento è nel futuro.%',
               'validazione: messaggio inatteso: ' || v_msg;
    END;
    ASSERT (SELECT cliente_documento_rilasciato_data FROM ana_clienti WHERE cliente_id = 3870) IS NULL,
           'data di rilascio futura scritta';

    -- 9. riempire una data di nascita VUOTA non e' cambiarla (script 594): passa
    --    senza conferme anche se la scheda non ha codice fiscale
    UPDATE ana_clienti SET cliente_codicefiscale = NULL, cliente_data_nascita = NULL,
                           cliente_documento_rilasciato_data = v_prima.cliente_documento_rilasciato_data
     WHERE cliente_id = 3870;
    SELECT array_agg(campo) INTO v_scritti
      FROM fn_web_cliente_completa(3870, 2, jsonb_build_object(
               'cliente_data_nascita', v_prima.cliente_data_nascita::TEXT));
    ASSERT v_scritti = ARRAY['cliente_data_nascita'], 'data di nascita vuota non completata';
    ASSERT (SELECT cliente_data_nascita FROM ana_clienti WHERE cliente_id = 3870) = v_prima.cliente_data_nascita,
           'data di nascita non scritta';

    -- 10. anon non la puo' chiamare (script 659)
    ASSERT NOT has_function_privilege('anon', 'fn_web_cliente_completa(integer,integer,jsonb)', 'EXECUTE'),
           'anon puo'' completare le schede';

    RAISE NOTICE 'Test 661: tutto OK';
END $$;
ROLLBACK;
