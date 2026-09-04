-- =============================================================================
-- 582 — Il giudizio sul documento si può chiedere PRIMA di iscriversi
-- =============================================================================
--
-- Segnalato il 2026-09-04 provando il test D7: «io bloccherei l'iscrizione prima
-- di arrivare alla conferma… inutile fare digitare un sacco di dati, magari anche
-- quelli del passeggero, per poi accorgersi che non si può partire».
--
-- Ha ragione, e oggi non è possibile: la severità del documento (ERRORE se il
-- viaggio è all'estero, AVVISO se è in Italia) è scritta DENTRO
-- fn_mov_clienti_viaggi_valida, che pretende un'iscrizione già composta — cliente,
-- ruolo, mezzo. Al secondo passo del wizard niente di tutto ciò esiste ancora, e
-- l'unico modo di sapere la risposta era arrivare in fondo e riceverne il rifiuto.
--
-- La regola viene quindi estratta in una funzione che risponde a una domanda più
-- piccola — «questa data di scadenza basta per questa partenza?» — e che si può
-- porre in qualunque momento. NON è una copia: fn_mov_clienti_viaggi_valida viene
-- riscritta per chiamarla, così la severità resta definita in un posto solo.
--
--   fn_documento_stato_per_viaggio      ← MANCANTE / SCADUTO / SCADE_DURANTE / VALIDO
--        └── fn_documento_esito_per_partenza   ← + la gravità, che dipende dalla meta
--                 ├── fn_mov_clienti_viaggi_valida   (al salvataggio, come prima)
--                 └── il sito, al secondo passo      (per non far compilare invano)
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_documento_esito_per_partenza(
    p_data_viaggio_id INTEGER,
    p_scadenza        DATE,
    p_nome            TEXT DEFAULT NULL
)
RETURNS TABLE(gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_inizio        DATE;
    v_fine          DATE;
    v_estero        BOOLEAN;
    v_doc_stato     VARCHAR;
    v_doc_messaggio TEXT;
BEGIN
    SELECT d.data_viaggio_data_inizio, d.data_viaggio_data_fine,
           -- Nazione non indicata = si assume estero: e' il caso piu' severo, e sui
           -- documenti di chi parte non si tira a indovinare.
           COALESCE(co.iso_alpha2, 'XX') <> 'IT'
      INTO v_inizio, v_fine, v_estero
    FROM ana_date_viaggi d
    JOIN ana_viaggi vg         ON vg.viaggio_id = d.viaggio_id_fk
    LEFT JOIN eba_countries co ON co.country_id = vg.viaggio_nazione_fk
    WHERE d.data_viaggio_id = p_data_viaggio_id;

    IF v_inizio IS NULL THEN
        RETURN;   -- partenza sconosciuta: non e' questa funzione a doverlo dire
    END IF;

    SELECT s.stato, s.messaggio INTO v_doc_stato, v_doc_messaggio
    FROM fn_documento_stato_per_viaggio(p_scadenza, v_inizio, v_fine) s;

    IF v_doc_stato = 'VALIDO' THEN
        RETURN;   -- nessun esito: non c'e' niente da dire
    END IF;

    RETURN QUERY SELECT
        -- All'estero e' un ERRORE: senza documento valido non si parte, e iscrivere
        -- qualcuno a un viaggio che non potra' fare non e' un servizio. In Italia e'
        -- un AVVISO: si parte, ma l'albergo puo' rifiutare la registrazione — i
        -- documenti di tutti gli occupanti si presentano per legge (script 563).
        CASE WHEN v_estero THEN 'ERRORE' ELSE 'AVVISO' END::VARCHAR,
        ('DOCUMENTO_' || v_doc_stato)::VARCHAR,
        format('%s %s%s',
               COALESCE(p_nome, 'Il cliente'),
               lower(left(v_doc_messaggio, 1)) || substr(v_doc_messaggio, 2),
               CASE WHEN v_estero
                    THEN ' Il viaggio è all''estero: senza documento valido non si parte.'
                    ELSE ' In albergo i documenti di tutti gli occupanti si presentano per legge.'
               END)::TEXT;
END;
$$;

COMMENT ON FUNCTION fn_documento_esito_per_partenza(INTEGER, DATE, TEXT) IS
'Se questa data di scadenza basta per questa partenza, e con quale gravità: ERRORE
all''estero, AVVISO in Italia. Nessuna riga = documento a posto. Si può chiedere PRIMA
di comporre l''iscrizione, quindi il sito la usa per fermare chi non potrebbe partire
senza fargli compilare tutto il resto.';


-- ---------------------------------------------------------------------------
-- La validazione dell'iscrizione ora la chiama, invece di riscriverla.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_valida(
    p_dati JSONB,
    p_modifica BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(gravita VARCHAR, esito VARCHAR, messaggio TEXT, riferimento INTEGER)
LANGUAGE plpgsql
STABLE
AS $$
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
BEGIN
    -- Partenza gia' conclusa: non si aggiungono partecipanti. Prima di tutto il
    -- resto, perche' se il viaggio e' finito non ha senso discutere del documento.
    IF NOT p_modifica AND fn_partenza_conclusa(v_data) THEN
        SELECT to_char(COALESCE(d.data_viaggio_data_fine, d.data_viaggio_data_inizio), 'DD/MM/YYYY')
          INTO v_mancanti
        FROM ana_date_viaggi d WHERE d.data_viaggio_id = v_data;

        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PARTENZA_CONCLUSA'::VARCHAR,
               format('Questa partenza si è conclusa il %s: non si possono più aggiungere partecipanti.',
                      COALESCE(v_mancanti, 'una data passata'))::TEXT, v_data;
        RETURN;
    END IF;

    v_mancanti := NULL;

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

    -- Il documento. La regola e la sua gravita' non sono piu' scritte qui: stanno in
    -- fn_documento_esito_per_partenza, che il sito interroga anche PRIMA di comporre
    -- l'iscrizione — per non far compilare tutto a chi poi non potrebbe partire.
    SELECT c.cliente_documento_rilasciato_scadenza INTO v_scadenza
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    RETURN QUERY
    SELECT e.gravita, e.esito, e.messaggio, v_cliente
    FROM fn_documento_esito_per_partenza(v_data, v_scadenza, v_nome) e;

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
$$;
