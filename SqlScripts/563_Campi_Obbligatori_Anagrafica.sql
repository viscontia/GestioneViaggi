-- =============================================================================
-- 563 — I campi obbligatori dell'anagrafica, una volta sola e per tutti
-- =============================================================================
--
-- Deciso il 2026-08-31. Il documento d'identita' serve a OGNI occupante della
-- stanza, non solo a chi guida: alla registrazione in albergo si presentano per
-- legge i documenti di tutti. Quindi l'obbligo non e' una regola di ruolo.
--
-- Prefisso e telefono restano invece per ruolo: al pilota servono per davvero,
-- e chi viaggia come passeggero puo' legittimamente non lasciare il proprio
-- numero. Sono percio' l'unica parte che dipende dal tipo di partecipante,
-- accanto all'email e ai dati del mezzo che gia' funzionavano cosi'.
--
-- Cosa cambia:
--   1. fn_ana_clienti_campi_mancanti — dice quali dati mancano, una volta sola.
--   2. fn_ana_clienti_valida         — li chiede a chi salva un'anagrafica.
--   3. fn_mov_clienti_viaggi_valida  — li chiede, bloccando, a chi iscrive.
--
-- Il punto 3 non e' un doppione del 2: intercetta i clienti storici, quelli che
-- nessuno ha piu' aperto da quando la regola non c'era, e che altrimenti
-- arriverebbero incompleti fino al check-in. Sul DB locale di prova erano 578 su
-- 742; il numero che conta e' quello di PROD, non ancora misurato.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Che cosa manca a questa anagrafica
-- -----------------------------------------------------------------------------
-- Una riga per ogni dato mancante: il codice serve al gestionale per illuminare
-- il campo giusto, l'etichetta per scrivere una frase leggibile. Chi la chiama
-- sceglie se farne N segnalazioni distinte (l'anagrafica) o una sola con
-- l'elenco (l'iscrizione).
--
-- Prende un JSONB e non un cliente_id perche' deve poter giudicare anche dati
-- non ancora salvati: e' lo stesso motivo per cui esiste fn_ana_clienti_valida.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_clienti_campi_mancanti(
    p_dati   JSONB,
    p_pilota BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(campo VARCHAR, etichetta TEXT)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Vuoto e assente sono la stessa cosa: ' ' non e' un indirizzo.
    IF COALESCE((p_dati->>'cliente_titolo_fk')::INTEGER, 0) = 0 THEN
        RETURN QUERY SELECT 'TITOLO'::VARCHAR, 'il titolo'::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_cognome', '')) = '' THEN
        RETURN QUERY SELECT 'COGNOME'::VARCHAR, 'il cognome'::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_nome', '')) = '' THEN
        RETURN QUERY SELECT 'NOME'::VARCHAR, 'il nome'::TEXT;
    END IF;

    IF (p_dati->>'cliente_data_nascita') IS NULL THEN
        RETURN QUERY SELECT 'DATA_NASCITA'::VARCHAR, 'la data di nascita'::TEXT;
    END IF;

    IF COALESCE((p_dati->>'cliente_comune_nascita_fk')::INTEGER, 0) = 0 THEN
        RETURN QUERY SELECT 'COMUNE_NASCITA'::VARCHAR, 'il comune di nascita'::TEXT;
    END IF;

    IF COALESCE((p_dati->>'cliente_comune_residenza_fk')::INTEGER, 0) = 0 THEN
        RETURN QUERY SELECT 'COMUNE_RESIDENZA'::VARCHAR, 'il comune di residenza'::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_indirizzo_residenza', '')) = '' THEN
        RETURN QUERY SELECT 'INDIRIZZO_RESIDENZA'::VARCHAR, 'l''indirizzo di residenza'::TEXT;
    END IF;

    -- Il documento: cinque dati, e servono tutti insieme. Un numero senza data
    -- di scadenza non si puo' trascrivere sulla schedina degli alloggiati.
    IF btrim(COALESCE(p_dati->>'cliente_tipodoc_identita', '')) = '' THEN
        RETURN QUERY SELECT 'DOC_TIPO'::VARCHAR, 'il tipo di documento'::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_documento_numero', '')) = '' THEN
        RETURN QUERY SELECT 'DOC_NUMERO'::VARCHAR, 'il numero del documento'::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_documento_rilasciato_da', '')) = '' THEN
        RETURN QUERY SELECT 'DOC_ENTE'::VARCHAR, 'l''ente che ha rilasciato il documento'::TEXT;
    END IF;

    IF (p_dati->>'cliente_documento_rilasciato_data') IS NULL THEN
        RETURN QUERY SELECT 'DOC_RILASCIO'::VARCHAR, 'la data di rilascio del documento'::TEXT;
    END IF;

    IF (p_dati->>'cliente_documento_rilasciato_scadenza') IS NULL THEN
        RETURN QUERY SELECT 'DOC_SCADENZA'::VARCHAR, 'la data di scadenza del documento'::TEXT;
    END IF;

    -- Solo per chi guida. Un passeggero che non lascia il proprio numero non
    -- sta nascondendo un dato: sta esercitando una scelta legittima.
    IF p_pilota THEN
        IF btrim(COALESCE(p_dati->>'cliente_preftelint', '')) = '' THEN
            RETURN QUERY SELECT 'PREFISSO'::VARCHAR, 'il prefisso internazionale'::TEXT;
        END IF;

        IF btrim(COALESCE(p_dati->>'cliente_telefono', '')) = '' THEN
            RETURN QUERY SELECT 'TELEFONO'::VARCHAR, 'il numero di telefono'::TEXT;
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_ana_clienti_campi_mancanti(JSONB, BOOLEAN) IS
'Elenca i dati obbligatori assenti da un''anagrafica. Una riga per campo: il codice per
illuminare il campo, l''etichetta per scrivere la frase. p_pilota aggiunge prefisso e
telefono, che servono solo a chi guida. Chiamata sia dal salvataggio dell''anagrafica sia
dall''iscrizione al viaggio: la definizione di "completa" e'' una sola.';


-- -----------------------------------------------------------------------------
-- 2. L'anagrafica: una segnalazione per ogni campo
-- -----------------------------------------------------------------------------
-- Separate e non riunite in una frase sola perche' il gestionale le rimappa sul
-- campo (mappa CampoPerEsito in ClienteDialog): un elenco unico direbbe cosa
-- manca ma non dove.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_clienti_valida(
    p_dati       JSONB,
    p_cliente_id INTEGER DEFAULT NULL
)
RETURNS TABLE(gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_azienda   INTEGER := (p_dati->>'azienda_fk')::INTEGER;
    v_cognome   VARCHAR := p_dati->>'cliente_cognome';
    v_nome      VARCHAR := p_dati->>'cliente_nome';
    v_nascita   DATE    := (p_dati->>'cliente_data_nascita')::DATE;
    v_com_nasc  INTEGER := (p_dati->>'cliente_comune_nascita_fk')::INTEGER;
    v_cf        VARCHAR := p_dati->>'cliente_codicefiscale';
    v_titolo    INTEGER := (p_dati->>'cliente_titolo_fk')::INTEGER;
    v_sesso     CHAR;
    v_rilascio  DATE    := (p_dati->>'cliente_documento_rilasciato_data')::DATE;
    v_scadenza  DATE    := (p_dati->>'cliente_documento_rilasciato_scadenza')::DATE;
    v_email     TEXT    := btrim(COALESCE(p_dati->>'cliente_email',''));
    v_iban      TEXT    := btrim(COALESCE(p_dati->>'cliente_iban',''));
BEGIN
    SELECT t.titolo_persone_sesso INTO v_sesso
    FROM ana_titolo_persone t WHERE t.titolo_persone_cod = v_titolo;

    -- I dati che devono esserci. Prefisso e telefono no: qui non si sa in che
    -- ruolo viaggera' questa persona, e lo si scopre solo all'iscrizione.
    RETURN QUERY
    SELECT 'ERRORE'::VARCHAR,
           ('MANCA_' || m.campo)::VARCHAR,
           format('Manca %s.', m.etichetta)::TEXT
    FROM fn_ana_clienti_campi_mancanti(p_dati, FALSE) m;

    IF v_email <> '' AND v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'EMAIL_FORMATO'::VARCHAR,
               'L''indirizzo email non è scritto in modo valido.'::TEXT;
    END IF;

    IF v_iban <> '' AND (length(v_iban) NOT BETWEEN 15 AND 34 OR v_iban !~ '^[A-Za-z]{2}') THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'IBAN_FORMATO'::VARCHAR,
               'L''IBAN non è valido: servono da 15 a 34 caratteri e due lettere di paese iniziali.'::TEXT;
    END IF;

    IF btrim(COALESCE(v_cognome,'')) <> '' AND length(btrim(v_cognome)) < 2 THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'COGNOME_MINIMO'::VARCHAR,
               'Il cognome deve avere almeno 2 caratteri.'::TEXT;
    END IF;

    IF btrim(COALESCE(v_nome,'')) <> '' AND length(btrim(v_nome)) < 2 THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'NOME_MINIMO'::VARCHAR,
               'Il nome deve avere almeno 2 caratteri.'::TEXT;
    END IF;

    RETURN QUERY
    SELECT d.gravita, d.esito, d.messaggio
    FROM fn_ana_clienti_verifica_duplicato(v_azienda, v_cognome, v_nome, v_nascita,
                                           v_com_nasc, v_cf, p_cliente_id, NULLIF(v_email,'')) d;

    RETURN QUERY
    SELECT c.gravita, c.esito, c.messaggio
    FROM fn_cf_verifica(v_cf, v_cognome, v_nome, v_nascita, v_sesso, v_com_nasc) c
    WHERE c.gravita <> 'OK';

    IF v_rilascio IS NOT NULL AND v_rilascio > CURRENT_DATE THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'RILASCIO_FUTURO'::VARCHAR,
               'La data di rilascio del documento è nel futuro.'::TEXT;
    END IF;

    IF v_nascita IS NOT NULL AND v_nascita > CURRENT_DATE THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'NASCITA_FUTURA'::VARCHAR,
               'La data di nascita è nel futuro.'::TEXT;
    END IF;

    IF v_scadenza IS NOT NULL AND v_scadenza < CURRENT_DATE THEN
        RETURN QUERY SELECT 'AVVISO'::VARCHAR, 'DOCUMENTO_SCADUTO'::VARCHAR,
               format('Il documento risulta scaduto il %s.', to_char(v_scadenza,'DD/MM/YYYY'))::TEXT;
    END IF;

    IF btrim(COALESCE(p_dati->>'cliente_telefono','')) <> ''
       AND btrim(COALESCE(p_dati->>'cliente_preftelint','')) = '' THEN
        RETURN QUERY SELECT 'CONFERMA'::VARCHAR, 'PREFISSO_MANCANTE'::VARCHAR,
               'C''è un numero di telefono ma manca il prefisso internazionale.'::TEXT;
    END IF;

    -- L'avviso nome/sesso. Il sesso qui e' gia' quello derivato dal titolo, quindi
    -- funziona anche per il sito, che manda la chiave del titolo e non il sesso.
    IF fn_nome_sesso_avviso(v_nome, v_sesso) IS NOT NULL THEN
        RETURN QUERY SELECT 'AVVISO'::VARCHAR, 'NOME_SESSO'::VARCHAR,
               fn_nome_sesso_avviso(v_nome, v_sesso);
    END IF;
END;
$$;


-- -----------------------------------------------------------------------------
-- 3. L'iscrizione: qui non si passa
-- -----------------------------------------------------------------------------
-- Il cliente e' gia' salvato, quindi lo si rilegge e lo si giudica con la stessa
-- funzione del punto 1. Una segnalazione sola con l'elenco: qui non c'e' un
-- campo da illuminare, c'e' una scheda da riaprire.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_valida(
    p_dati     JSONB,
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
