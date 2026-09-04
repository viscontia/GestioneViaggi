-- =============================================================================
-- 584 — Quando una partenza accetta iscrizioni, e quando si puo' dirla fatta
-- =============================================================================
--
-- Tre regole dettate il 2026-09-04, tutte con la stessa origine: il concetto di
-- «partenza aperta» era rimasto implicito, e ognuno se lo era ricostruito.
--
-- 1. NON SI ISCRIVE A UN VIAGGIO GIA' PARTITO. Lo script 583 aveva reso
--    prenotabili le partenze iniziate ma non ancora finite, ragionando che per
--    il database non erano «concluse». Sbagliato, e la ragione e' di mestiere:
--    «cosa fa il cliente, parte a meta' viaggio dei Pirenei da Roma per fare
--    cosa?». Il criterio giusto non e' «non e' finita» ma «non e' cominciata».
--
-- 2. NON SI MARCA FATTA UNA PARTENZA CHE NON E' PARTITA. La spunta «effettuato»
--    descrive un fatto avvenuto: prima del primo giorno non c'e' niente da
--    descrivere. Finora nulla lo impediva.
--
-- 3. NON ESISTONO PARTENZE ANNULLATE LOGICAMENTE. Una partenza o c'e' o non
--    c'e': se va tolta si cancella, ed e' possibile solo quando non ha iscritti
--    (lo garantiscono gia' le foreign key ON DELETE RESTRICT). Il vincolo sulla
--    colonna ammetteva un terzo valore 'P' che nessuno ha mai usato — 148 righe,
--    tutte 'Y' o 'N' — e che avrebbe potuto diventare proprio quello stato
--    intermedio che non si vuole.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Il concetto che mancava, e che ora ha un nome
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_partenza_iscrivibile(p_data_viaggio_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        -- Non e' ancora cominciata...
        d.data_viaggio_data_inizio > CURRENT_DATE
        -- ...e nessuno l'ha dichiarata fatta.
        AND COALESCE(d.data_viaggio_effettuato_sino, 'N') <> 'Y',
        FALSE)
    FROM ana_date_viaggi d
    WHERE d.data_viaggio_id = p_data_viaggio_id;
$$;

COMMENT ON FUNCTION fn_partenza_iscrivibile(INTEGER) IS
'Se a questa partenza ci si puo'' ancora iscrivere: non e'' cominciata e non e'' segnata
come effettuata. E'' la regola che decide sia cosa il sito PROPONE sia cosa il database
ACCETTA — una sola, cosi'' non possono allontanarsi. Diversa da fn_partenza_conclusa, che
dice se il viaggio e'' finito: a un viaggio in corso non ci si iscrive, ma concluso non e''.';


-- ---------------------------------------------------------------------------
-- 2. La spunta «effettuato» descrive un fatto, non una previsione
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_date_viaggi_effettuato_guardia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.data_viaggio_effettuato_sino = 'Y'
       AND NEW.data_viaggio_data_inizio > CURRENT_DATE THEN
        RAISE EXCEPTION
            'Non si può segnare come effettuata una partenza che deve ancora cominciare (parte il %). La spunta si mette dal primo giorno di viaggio in avanti.',
            to_char(NEW.data_viaggio_data_inizio, 'DD/MM/YYYY');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ana_date_viaggi_effettuato_guardia ON ana_date_viaggi;
CREATE TRIGGER ana_date_viaggi_effettuato_guardia
    BEFORE INSERT OR UPDATE OF data_viaggio_effettuato_sino, data_viaggio_data_inizio
    ON ana_date_viaggi
    FOR EACH ROW
    EXECUTE FUNCTION fn_ana_date_viaggi_effettuato_guardia();

COMMENT ON FUNCTION fn_ana_date_viaggi_effettuato_guardia() IS
'Impedisce di segnare «effettuata» una partenza non ancora cominciata. Serve un trigger e
non un CHECK: il confronto e'' con la data di oggi, e un CHECK ammette solo espressioni
immutabili.';


-- ---------------------------------------------------------------------------
-- 3. Niente terzo stato: o si e' fatta, o no
-- ---------------------------------------------------------------------------
-- Il 'P' non e' mai stato usato (148 righe, tutte Y o N). Lasciarlo aperto
-- significava tenere a disposizione proprio l'annullamento logico che non si vuole.
ALTER TABLE ana_date_viaggi DROP CONSTRAINT IF EXISTS chk_data_viaggio_effettuato_sino;
ALTER TABLE ana_date_viaggi ADD CONSTRAINT chk_data_viaggio_effettuato_sino
    CHECK (data_viaggio_effettuato_sino IN ('Y', 'N') OR data_viaggio_effettuato_sino IS NULL);


-- ---------------------------------------------------------------------------
-- 1. Chi decide le iscrizioni usa la nuova regola
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_wizard_get_viaggi_disponibili(p_azienda_id integer)
RETURNS TABLE(
    viaggio_id                 integer,
    viaggio_descrizione_breve  character varying,
    viaggio_descrizione_estesa text,
    viaggio_numero_giorni      integer,
    viaggio_numero_notti       integer,
    viaggio_link               character varying,
    nome_nazione               character varying
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        v.viaggio_id, v.viaggio_descrizione_breve, v.viaggio_descrizione_estesa,
        v.viaggio_numero_giorni, v.viaggio_numero_notti, v.viaggio_link,
        n.name::character varying
    FROM ana_viaggi v
    INNER JOIN ana_date_viaggi dv ON dv.viaggio_id_fk = v.viaggio_id
    LEFT JOIN eba_countries n     ON v.viaggio_nazione_fk = n.country_id
    WHERE v.azienda_id = p_azienda_id
      AND fn_partenza_iscrivibile(dv.data_viaggio_id)
    ORDER BY v.viaggio_descrizione_breve;
END;
$$;

COMMENT ON FUNCTION fn_wizard_get_viaggi_disponibili(integer) IS
'I viaggi che il sito puo'' proporre: quelli con almeno una partenza iscrivibile secondo
fn_partenza_iscrivibile — la stessa regola che decide se l''iscrizione viene accettata.';


-- ---------------------------------------------------------------------------
-- E la validazione dell'iscrizione: stessa regola, messaggio giusto
-- ---------------------------------------------------------------------------
-- Il rifiuto diceva sempre «questa partenza si e' conclusa». Per un viaggio in
-- corso sarebbe falso: non e' concluso, e' cominciato. Chi legge il messaggio
-- deve riconoscerci la propria situazione, altrimenti pensa a un guasto.
CREATE OR REPLACE FUNCTION fn_partenza_motivo_non_iscrivibile(p_data_viaggio_id INTEGER)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN d.data_viaggio_id IS NULL THEN NULL
        WHEN fn_partenza_iscrivibile(d.data_viaggio_id) THEN NULL
        WHEN COALESCE(d.data_viaggio_effettuato_sino,'N') = 'Y' THEN
            'Questa partenza risulta già effettuata: non si possono più aggiungere partecipanti.'
        WHEN d.data_viaggio_data_fine < CURRENT_DATE THEN
            format('Questa partenza si è conclusa il %s: non si possono più aggiungere partecipanti.',
                   to_char(d.data_viaggio_data_fine, 'DD/MM/YYYY'))
        ELSE
            format('Questa partenza è già iniziata il %s: non è più possibile iscriversi.',
                   to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY'))
    END
    FROM ana_date_viaggi d WHERE d.data_viaggio_id = p_data_viaggio_id;
$$;

COMMENT ON FUNCTION fn_partenza_motivo_non_iscrivibile(INTEGER) IS
'Perche'' a questa partenza non ci si puo'' iscrivere, con le parole giuste per il caso:
gia'' effettuata, conclusa, o cominciata. NULL se invece e'' iscrivibile.';


-- La validazione dell'iscrizione passa alla regola nuova. Si sostituisce solo il
-- primo blocco: il resto della funzione resta quello dello script 582.
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
END;
$$;
