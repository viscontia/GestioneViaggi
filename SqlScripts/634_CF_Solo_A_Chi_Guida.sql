-- ============================================================================
-- 634 — il codice fiscale si chiede a CHI GUIDA, non a tutti
--
-- Adriano, 2026-09-07: «Se pilota è obbligatorio perché la fattura verrà fatta a
-- lui. Chi è dichiarato come passeggero può anche non avere il CF obbligatorio.
-- Serve a chiedere meno dati all'iscrizione dei passeggeri, per rendere meno
-- pesante l'iscrizione stessa.»
--
-- ⚠️ IL 629 AVEVA MESSO LA REGOLA NEL POSTO SBAGLIATO, e lo si vede solo ora:
-- fn_ana_clienti_valida giudica la SCHEDA, e la scheda NON SA se quella persona
-- guidera'. Il ruolo esiste solo nell'iscrizione. Funzionava per coincidenza — il
-- sito crea schede nuove quasi sempre per il pilota — non perche' fosse giusta.
--
-- COSA CAMBIA:
--   • fn_ana_clienti_valida  -> non pretende piu' il codice fiscale. Se c'e',
--     fn_cf_verifica continua a controllarlo com'e' scritto.
--   • fn_mov_clienti_viaggi_valida -> lo pretende a chi ha un ruolo di GUIDA,
--     riconosciuto da tipo_partecipante_pilota (auto, moto, quad, enduro, mezzo
--     noleggiato, guida, guida in seconda) e non dall'ordine dei passi del sito.
--     Chi risiede all'estero resta escluso.
--
-- ⚠️ IL CASO CHE RENDEVA RISCHIOSA LA PROPOSTA — «e se un passeggero domani si
-- dichiara pilota?» — e' coperto senza scrivere nulla: fn_mov_clienti_viaggi_update
-- passa dalla STESSA guardia dell'insert. Verificato, non supposto.
--
-- QUANTO PESA: su PROD azienda 2 ci sono 110 guide e 75 passeggeri. A quattro
-- clienti su dieci si chiedeva un dato che non serviva.
--
-- ⚠️ Conseguenza per la segreteria: creando un cliente nel gestionale ora si puo'
-- salvare senza codice fiscale, e il rifiuto arriva quando lo si iscrive come
-- pilota. E' un rifiuto spostato piu' avanti, non tolto.
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_ana_clienti_valida(p_dati jsonb, p_cliente_id integer DEFAULT NULL::integer)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text)
 LANGUAGE plpgsql
 STABLE
AS $function$
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
    v_com_res   INTEGER := (p_dati->>'cliente_comune_residenza_fk')::INTEGER;
    v_estero    BOOLEAN;
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

    -- Il consenso alla newsletter senza un indirizzo a cui scrivere non e' un
    -- consenso: e' una riga che non servira' mai a nessuno, e che al primo invio
    -- risultera' semplicemente non raggiungibile. Si chiede l'email prima.
    IF COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE) AND v_email = '' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'CONSENSO_SENZA_EMAIL'::VARCHAR,
               'Il consenso alla newsletter richiede un indirizzo email: senza, non c''è nulla a cui inviare.'::TEXT;
    END IF;

    -- ⚠️ La regola dell'indirizzo sta in fn_validate_email_format, non qui: era
    -- scritta in due posti con DUE espressioni diverse, e non concordavano.
    IF v_email <> '' AND NOT fn_validate_email_format(v_email) THEN
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

    -- ⚠️ IL CODICE FISCALE NON SI PRETENDE QUI. Ci stava dal 629 (stesso giorno),
    -- ma era il posto sbagliato: questa funzione giudica la SCHEDA, e la scheda
    -- NON SA se quella persona guidera'. Il ruolo esiste solo nell'iscrizione.
    -- Funzionava per coincidenza — il sito crea schede nuove quasi sempre per il
    -- pilota — non perche' la regola fosse al posto giusto.
    --
    -- Adriano, 2026-09-07: la fattura si emette a chi guida, quindi il codice
    -- fiscale serve a LUI. Ai passeggeri si chiede un dato che non servira', e
    -- ogni campo in piu' e' gente che abbandona l'iscrizione a meta'.
    -- Sono 75 passeggeri su PROD contro 110 guide: quattro clienti su dieci.
    --
    -- La regola e' passata in fn_mov_clienti_viaggi_valida, dove il ruolo si
    -- conosce. ⚠️ E chi si iscrive oggi da passeggero e domani da pilota viene
    -- fermato allora: fn_mov_clienti_viaggi_update passa dalla stessa guardia
    -- dell'insert — verificato, non supposto.
    --
    -- Se il codice fiscale c'e', fn_cf_verifica qui sopra continua a controllarlo.

    -- ⚠️ Data e luogo di nascita identificano la persona: si cambiano insieme al
    -- codice fiscale, che li conferma, oppure non si cambiano. Se il codice fiscale
    -- c'e', fn_cf_verifica qui sopra ha gia' detto se torna; se non c'e', non
    -- arbitra nessuno — ed e' li' che si poteva spostare la data di nascita di una
    -- cliente senza che uscisse un solo rilievo.
    IF p_cliente_id IS NOT NULL
       AND btrim(COALESCE(v_cf, '')) = ''
       AND fn_ana_clienti_nascita_modificata(p_cliente_id, p_dati) THEN
        RETURN QUERY SELECT 'CONFERMA'::VARCHAR, 'NASCITA_SENZA_CF'::VARCHAR,
               ('Stai cambiando la data o il comune di nascita di una scheda che non ha '
                || 'codice fiscale. Senza di quello niente conferma il dato nuovo: '
                || 'inserisci il codice fiscale, oppure conferma che la modifica è voluta.')::TEXT;
    END IF;

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
$function$;

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
    v_nascita  DATE;
    v_cf_cli   TEXT;
    v_res_estero BOOLEAN;
    v_eta      INTEGER;
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

    SELECT c.cliente_email, c.cliente_cognome || ' ' || c.cliente_nome, c.cliente_data_nascita
      INTO v_email, v_nome, v_nascita
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    -- Chi guida deve essere raggiungibile: e' a lui che vanno convocazione,
    -- variazioni di programma e istruzioni.
    IF COALESCE(v_pilota, FALSE) AND btrim(COALESCE(v_email, '')) = '' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_EMAIL'::VARCHAR,
               format('%s viene iscritto come pilota ma non ha un indirizzo email in anagrafica.',
                      COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
    END IF;

    -- ⚠️ Chi guida dev'essere maggiorenne. Adriano, 2026-09-07: «un minorenne non
    -- può avere il ruolo di pilota». Vale per TUTTI i ruoli che guidano — auto,
    -- moto, quad, enduro e le guide — riconosciuti da ana_tipo_partecipante.
    -- tipo_partecipante_pilota, non da un elenco di codici scritto qui: i ruoli
    -- cambiano, la colonna resta.
    --
    -- ⚠️ L'età si conta ALLA PARTENZA, non oggi: chi compie 18 anni prima del
    -- viaggio può guidarlo, e rifiutarlo sarebbe sbagliato. Trovato collaudando il
    -- sito il 2026-09-07: una cliente di 14 anni veniva accettata come pilota
    -- senza un rilievo.
    --
    -- Nessuna iscrizione esistente ne è toccata: misurato, zero piloti minorenni
    -- alla partenza, né su partenze future né su quelle passate.
    -- ⚠️ Il codice fiscale serve a CHI GUIDA, perche' e' a lui che si emette la
    -- fattura (Adriano, 2026-09-07). Ai passeggeri non si chiede: alleggerisce
    -- l'iscrizione, che e' il momento in cui la gente rinuncia.
    --
    -- Il ruolo si riconosce da tipo_partecipante_pilota, non dall'ordine in cui il
    -- sito chiede le email: cosi' copre moto, quad, enduro e le guide, e regge se
    -- domani l'interfaccia cambia.
    --
    -- Chi risiede all'estero e' escluso: il codice fiscale italiano non ce l'ha.
    IF COALESCE(v_pilota, FALSE) THEN
        SELECT btrim(COALESCE(c.cliente_codicefiscale, '')),
               COALESCE((g.comune_estero = 'Y'), FALSE)
          INTO v_cf_cli, v_res_estero
          FROM ana_clienti c
          LEFT JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
         WHERE c.cliente_id = v_cliente;

        IF v_cf_cli = '' AND NOT v_res_estero THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_CF'::VARCHAR,
                   format('%s viene iscritto come pilota ma non ha il codice fiscale: '
                          || 'serve per emettere la fattura a chi guida.',
                          COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
        END IF;
    END IF;

    IF COALESCE(v_pilota, FALSE) AND v_nascita IS NOT NULL THEN
        SELECT EXTRACT(YEAR FROM age(dv.data_viaggio_data_inizio, v_nascita))::INTEGER
          INTO v_eta
          FROM ana_date_viaggi dv WHERE dv.data_viaggio_id = v_data;

        IF v_eta IS NOT NULL AND v_eta < 18 THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_MINORENNE'::VARCHAR,
                   format('%s alla partenza avrà %s anni: chi guida deve essere maggiorenne. '
                          || 'Può viaggiare come passeggero.',
                          COALESCE(v_nome, 'Il cliente'), v_eta)::TEXT, v_cliente;
        END IF;
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
