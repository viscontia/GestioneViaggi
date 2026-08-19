-- Anche l'oggetto della newsletter e' un testo tradotto: se cambia, la sua traduzione non vale piu'.
--
-- Sintomo (collaudo del 2026-08-18, test 44.5-bis): riscrivendo l'oggetto di una newsletter gia'
-- tradotta, il riquadro Lingue non segnalava niente e i contatori restavano pieni.
--
-- Il danno vero non e' l'avviso mancante. `fn_web_newsletter_invii_update` faceva una UPDATE
-- secca dell'oggetto, quindi le traduzioni restavano marcate valide pur riferendosi al testo
-- precedente: alla spedizione i destinatari stranieri ricevevano l'oggetto VECCHIO tradotto,
-- mentre gli italiani ricevevano quello nuovo. Silenziosamente, e senza modo di accorgersene.
--
-- Osservato sulla newsletter 32: italiano cambiato in "TEST 18 Ago 2026 (notte piena)" alle 20:38,
-- traduzioni ferme a "TEST 18 August 2026 (night)" / "(Nacht)" / "(noche)" / "(nuit)" delle 20:12,
-- tutte con obsoleto = false.
--
-- I campi dei blocchi hanno gia' questo trattamento da `536_Obsolescenza_Prima_Della_Update.sql`
-- (`fn_web_newsletter_blocchi_update`, cinque campi, ognuno col suo confronto). L'oggetto era
-- rimasto fuori perche' vive su un'altra tabella e passa da un'altra funzione: stessa regola,
-- stesso ordine — si invalida cio' che c'era, poi si scrive.

CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_update(
    p_id BIGINT, p_azienda_id INTEGER, p_oggetto VARCHAR, p_corpo_html TEXT,
    p_stato VARCHAR, p_data_invio TIMESTAMPTZ, p_numero_destinatari INTEGER, p_canale VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_n           INTEGER;
    v_oggetto_old VARCHAR;
BEGIN
    -- PRIMA di scrivere: cio' che era tradotto sull'oggetto vecchio non vale piu'.
    SELECT oggetto INTO v_oggetto_old
      FROM web_newsletter_invii
     WHERE web_newsletter_invii_id = p_id AND azienda_id = p_azienda_id;

    -- IS DISTINCT FROM e non <>: fra NULL e un testo, l'operatore normale darebbe NULL e il
    -- confronto passerebbe per "non cambiato" proprio quando l'oggetto viene svuotato o riempito.
    IF v_oggetto_old IS DISTINCT FROM p_oggetto THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_invii', p_id, 'oggetto');
    END IF;

    -- Questa stessa funzione viene chiamata anche dal motore d'invio per aggiornare stato, data,
    -- destinatari e canale: li' l'oggetto e' identico a quello gia' a DB, il confronto non scatta
    -- e nessuna traduzione viene toccata a meta' spedizione.
    UPDATE web_newsletter_invii
       SET oggetto = p_oggetto, corpo_html = p_corpo_html, stato = p_stato, data_invio = p_data_invio,
           numero_destinatari = p_numero_destinatari, canale = p_canale
     WHERE web_newsletter_invii_id = p_id AND azienda_id = p_azienda_id;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $function$;

COMMENT ON FUNCTION fn_web_newsletter_invii_update(BIGINT, INTEGER, VARCHAR, TEXT, VARCHAR, TIMESTAMPTZ, INTEGER, VARCHAR)
IS 'Aggiorna una newsletter. Se l''oggetto cambia, marca obsolete le sue traduzioni prima di scrivere (script 537).';
