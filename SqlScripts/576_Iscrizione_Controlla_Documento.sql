-- =============================================================================
-- 576 — All'iscrizione si guarda anche il documento
-- =============================================================================
--
-- Terzo e ultimo chiamante di fn_documento_stato_per_viaggio (script 575).
--
-- La gravita' dipende dalla destinazione, deciso il 2026-09-02: all'ESTERO e' un
-- ERRORE, perche' senza documento valido non si parte e iscrivere qualcuno a un
-- viaggio che non potra' fare non e' un servizio. In ITALIA e' un AVVISO: si parte
-- lo stesso, ma l'albergo puo' rifiutare la registrazione.
--
-- ⚠️ Questo controllo NON basta da solo, ed e' importante saperlo: ci si iscrive
-- mesi prima, e un documento valido a giugno puo' essere scaduto a ottobre. Serve
-- anche il controllo sulla PARTENZA — lista partecipanti e stampe — che guarda la
-- situazione del giorno in cui lo si chiede.
-- =============================================================================

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
    v_inizio        DATE;
    v_fine          DATE;
    v_estero        BOOLEAN;
    v_scadenza      DATE;
    v_doc_stato     VARCHAR;
    v_doc_messaggio TEXT;
    v_scheda   JSONB;
    v_mancanti TEXT;
BEGIN
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

    -- L'anagrafica dev'essere completa PRIMA della partenza, non dopo: in albergo
    -- i documenti di tutti gli occupanti si presentano per legge. Questo controllo
    -- esiste per i clienti storici, quelli che nessuno ha piu' aperto da quando la
    -- regola non c'era: il salvataggio dell'anagrafica non li ha mai attraversati.
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

    -- Il documento deve arrivare valido alla FINE del viaggio, non solo a oggi.
    -- All'estero e' un ERRORE: senza documento valido non si parte, e iscrivere
    -- qualcuno a un viaggio che non potra' fare non e' un servizio. In Italia e' un
    -- AVVISO: si parte, ma l'albergo puo' rifiutare la registrazione — i documenti di
    -- tutti gli occupanti si presentano per legge (script 563).
    --
    -- La regola non e' qui: e' in fn_documento_stato_per_viaggio, la stessa che usano
    -- la lista dei partecipanti e le stampe.
    SELECT d.data_viaggio_data_inizio, d.data_viaggio_data_fine,
           COALESCE(co.iso_alpha2, 'XX') <> 'IT'
      INTO v_inizio, v_fine, v_estero
    FROM ana_date_viaggi d
    JOIN ana_viaggi vg        ON vg.viaggio_id = d.viaggio_id_fk
    LEFT JOIN eba_countries co ON co.country_id = vg.viaggio_nazione_fk
    WHERE d.data_viaggio_id = v_data;

    IF v_inizio IS NOT NULL THEN
        SELECT c.cliente_documento_rilasciato_scadenza INTO v_scadenza
        FROM ana_clienti c WHERE c.cliente_id = v_cliente;

        SELECT s.stato, s.messaggio INTO v_doc_stato, v_doc_messaggio
        FROM fn_documento_stato_per_viaggio(v_scadenza, v_inizio, v_fine) s;

        IF v_doc_stato <> 'VALIDO' THEN
            RETURN QUERY SELECT
                   CASE WHEN v_estero THEN 'ERRORE' ELSE 'AVVISO' END::VARCHAR,
                   ('DOCUMENTO_' || v_doc_stato)::VARCHAR,
                   format('%s %s%s',
                          COALESCE(v_nome, 'Il cliente'),
                          lower(left(v_doc_messaggio, 1)) || substr(v_doc_messaggio, 2),
                          CASE WHEN v_estero
                               THEN ' Il viaggio è all''estero: senza documento valido non si parte.'
                               ELSE ' In albergo i documenti di tutti gli occupanti si presentano per legge.'
                          END)::TEXT,
                   v_cliente;
        END IF;
    END IF;

    -- Il mezzo, se il ruolo lo richiede. La segnalazione dice QUALE dato manca:
    -- "dati del mezzo mancanti" costringerebbe a indovinare.
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
                          -- "la marca, il modello e la targa" si legge; con tre virgole no.
                          regexp_replace(array_to_string(v_manca, ', '), ', ([^,]+)$', ' e \1'))::TEXT,
                   v_cliente;
        END IF;
    END IF;
END;
$function$;
