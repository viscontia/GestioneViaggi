-- ============================================================================
-- 631 — la regola «puo' partire?» vale anche per il gestionale
--
-- Adriano, 2026-09-07: «SI va collegata anche a MAUI, assolutamente: regole
-- uniche e centralizzate».
--
-- ⚠️ NON e' stata collegata scrivendo una chiamata nel C#. Sarebbe stata la
-- seconda copia della stessa regola, e una delle due sarebbe rimasta indietro —
-- e' il difetto che questo progetto ha passato giorni a togliere.
--
-- E' stata messa dove passano ENTRAMBI: fn_mov_clienti_viaggi_valida, che la
-- guardia interroga e che fn_mov_clienti_viaggi_insert chiama sempre. Il
-- gestionale (AddParticipantAsync) e il sito (finalizzazione) arrivano tutti e
-- due li'. Da oggi nessuna delle due strade puo' iscrivere chi non puo' partire,
-- nemmeno per errore.
--
-- Il sito continua a fermarsi PRIMA, al passo 2, con un messaggio che invita a
-- completare la scheda: questo non lo sostituisce, e' la rete sotto.
--
-- ⚠️ Non tocca le iscrizioni gia' registrate: vale su cio' che si scrive adesso.
-- I 42 clienti senza codice fiscale che hanno gia' viaggiato restano come sono.
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_mov_clienti_viaggi_valida(p_dati jsonb, p_modifica boolean DEFAULT false)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text, riferimento integer)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_viaggio  INTEGER := (p_dati->>'viaggio_id_fk')::INTEGER;
    v_data     INTEGER := (p_dati->>'data_viaggio_id_fk')::INTEGER;
    v_cliente  INTEGER := (p_dati->>'cliente_id_fk')::INTEGER;
    v_tipo     INTEGER := (p_dati->>'tipo_partecipante_id_fk')::INTEGER;
    v_pilota   BOOLEAN;
    v_mezzo_ob BOOLEAN;
    v_ruolo    VARCHAR;
    v_email    VARCHAR;
    v_nome     TEXT;
    v_manca    TEXT[] := ARRAY[]::TEXT[];
    v_scadenza DATE;
    v_scheda   JSONB;
    v_mancanti TEXT;
    v_motivo   TEXT;
BEGIN
    -- Partenza non piu' aperta alle iscrizioni. Prima di tutto il resto: se non ci
    -- si puo' iscrivere, discutere del documento non ha senso.
    IF NOT p_modifica THEN
        v_motivo := fn_partenza_motivo_non_iscrivibile(v_data);
        IF v_motivo IS NOT NULL THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PARTENZA_NON_ISCRIVIBILE'::VARCHAR,
                   v_motivo, v_data;
            RETURN;
        END IF;
    END IF;

    IF NOT p_modifica AND EXISTS (
        SELECT 1 FROM mov_clienti_viaggi
        WHERE viaggio_id_fk = v_viaggio AND data_viaggio_id_fk = v_data
          AND cliente_id_fk = v_cliente) THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'GIA_ISCRITTO'::VARCHAR,
               'Questo cliente è già iscritto a questo viaggio in questa data.'::TEXT, v_cliente;
    END IF;

    SELECT tp.tipo_partecipante_pilota,
           tp.tipo_partecipante_dati_mezzo_obb = 'Y',
           tp.tipo_partecipante_descrizione
      INTO v_pilota, v_mezzo_ob, v_ruolo
    FROM ana_tipo_partecipante tp WHERE tp.tipo_partecipante_id = v_tipo;

    SELECT c.cliente_email, c.cliente_cognome || ' ' || c.cliente_nome INTO v_email, v_nome
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    -- Chi guida deve essere raggiungibile: e' a lui che vanno convocazione,
    -- variazioni di programma e istruzioni.
    IF COALESCE(v_pilota, FALSE) AND btrim(COALESCE(v_email, '')) = '' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_EMAIL'::VARCHAR,
               format('%s viene iscritto come pilota ma non ha un indirizzo email in anagrafica.',
                      COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
    END IF;

    -- L'anagrafica dev'essere completa PRIMA della partenza: in albergo i documenti
    -- di tutti gli occupanti si presentano per legge (script 563).
    SELECT to_jsonb(c) INTO v_scheda FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    IF v_scheda IS NOT NULL THEN
        SELECT regexp_replace(string_agg(m.etichetta, ', ' ORDER BY m.campo), ', ([^,]+)$', ' e \1')
          INTO v_mancanti
        FROM fn_ana_clienti_campi_mancanti(v_scheda, COALESCE(v_pilota, FALSE)) m;

        IF v_mancanti IS NOT NULL THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'ANAGRAFICA_INCOMPLETA'::VARCHAR,
                   format('L''anagrafica di %s non è completa: manca %s. Va completata prima dell''iscrizione.',
                          COALESCE(v_nome, 'questo cliente'), v_mancanti)::TEXT,
                   v_cliente;
        END IF;
    END IF;

    -- Il documento: regola e gravita' in fn_documento_esito_per_partenza (582), che
    -- il sito interroga anche PRIMA di comporre l'iscrizione.
    SELECT c.cliente_documento_rilasciato_scadenza INTO v_scadenza
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    RETURN QUERY
    SELECT e.gravita, e.esito, e.messaggio, v_cliente
    FROM fn_documento_esito_per_partenza(v_data, v_scadenza, v_nome) e;

    -- Il mezzo, se il ruolo lo richiede. La segnalazione dice QUALE dato manca.
    IF COALESCE(v_mezzo_ob, FALSE) THEN
        IF (p_dati->>'ana_mezzi_id_fk') IS NULL THEN
            v_manca := array_append(v_manca, 'la marca');
        END IF;
        IF (p_dati->>'mezzo_modello_id_fk') IS NULL THEN
            v_manca := array_append(v_manca, 'il modello');
        END IF;
        IF btrim(COALESCE(p_dati->>'mov_cliente_viaggio_targa_mezzo','')) = '' THEN
            v_manca := array_append(v_manca, 'la targa');
        END IF;

        IF array_length(v_manca, 1) > 0 THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'MEZZO_INCOMPLETO'::VARCHAR,
                   format('Per il ruolo «%s» i dati del mezzo sono obbligatori: manca %s.',
                          COALESCE(v_ruolo, 'selezionato'),
                          regexp_replace(array_to_string(v_manca, ', '), ', ([^,]+)$', ' e \1'))::TEXT,
                   v_cliente;
        END IF;
    END IF;

    -- ⚠️ Questa persona puo' PARTIRE? Domanda diversa da tutte quelle qui sopra,
    -- che riguardano l'iscrizione (ruolo, mezzo, posti, documento). Qui si guarda
    -- la scheda anagrafica di chi viaggia: senza codice fiscale, a chi risiede in
    -- Italia non si puo' emettere la fattura.
    --
    -- Sta QUI e non nel codice delle applicazioni perche' e' l'unico punto da cui
    -- passano entrambe: il gestionale con AddParticipantAsync e il sito con la
    -- finalizzazione chiamano tutti e due fn_mov_clienti_viaggi_insert, che chiama
    -- la guardia, che chiama questa. Collegarla nei due programmi avrebbe voluto
    -- dire due copie — e una delle due sarebbe rimasta indietro.
    --
    -- ⚠️ Non tocca le iscrizioni GIA' esistenti: vale su cio' che si scrive adesso.
    IF v_cliente IS NOT NULL THEN
        RETURN QUERY
        SELECT i.gravita, i.esito, i.messaggio, v_cliente
        FROM ana_clienti c
        CROSS JOIN LATERAL fn_cliente_iscrivibile(c.cliente_id, c.azienda_fk) i
        WHERE c.cliente_id = v_cliente;
    END IF;

END;
$function$;

COMMIT;
