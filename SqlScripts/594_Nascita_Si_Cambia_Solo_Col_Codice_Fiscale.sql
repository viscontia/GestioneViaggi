-- =============================================================================
-- 594 — Data e luogo di nascita si cambiano solo insieme al codice fiscale
-- =============================================================================
--
-- Domanda dell'utente, 2026-09-05: se sul sito una persona digita dati diversi da
-- quelli in anagrafica, che si fa?
--
-- La sua risposta distingue, e la distinzione e' giusta:
--
--   «Non e' un sito istituzionale. Se l'utente scrive un indirizzo diverso, saprà
--    quello che fa. E comunque per posta tradizionale Antonio non manda nulla, non
--    e' uno spedizioniere: l'indirizzo non e' determinante per un tour operator.
--    Molto piu' delicate data e luogo di nascita. Quelle possono cambiare solo
--    insieme al codice fiscale, che vince su tutto: o cambiano insieme, oppure non
--    si cambiano parzialmente.»
--
-- Recapiti, indirizzo e documento restano quindi come sono: chi si iscrive e' la
-- fonte piu' aggiornata, e sovrascrivere e' corretto.
--
-- ⚠️ Data e luogo di nascita no: identificano la persona. Con il codice fiscale il
-- controllo c'e' gia' — `fn_cf_verifica` confronta cognome, nome, data, sesso e
-- comune, e rifiuta se non tornano (verificato: ERRORE/CARATTERE_CONTROLLO). Ma
-- SENZA codice fiscale non arbitra nessuno: provato, si puo' spostare la data di
-- nascita di una cliente a piacere e non esce un solo rilievo. E sono proprio le
-- schede senza codice fiscale quelle piu' esposte, perche' sono le stesse che il
-- sito riconosce per nome e data di nascita (difetto 91).
--
-- Gravita' CONFERMA e non ERRORE: in segreteria una data di nascita sbagliata va
-- pur corretta — COLOMBO ROBERTA ne ha due che differiscono di cinque giorni — ma
-- deve essere una scelta dichiarata, non un effetto collaterale.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_clienti_nascita_modificata(
    p_cliente_id INTEGER,
    p_dati       JSONB
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM ana_clienti c
        WHERE c.cliente_id = p_cliente_id
          AND (
            -- Solo un valore che c'era e cambia. Riempire un campo vuoto e'
            -- completare una scheda, non riscrivere l'identita' di qualcuno:
            -- e' esattamente cio' che serve per le schede lasciate a meta'.
            (c.cliente_data_nascita IS NOT NULL
             AND (p_dati->>'cliente_data_nascita') IS NOT NULL
             AND (p_dati->>'cliente_data_nascita')::DATE <> c.cliente_data_nascita)
            OR
            (c.cliente_comune_nascita_fk IS NOT NULL
             AND (p_dati->>'cliente_comune_nascita_fk') IS NOT NULL
             AND (p_dati->>'cliente_comune_nascita_fk')::INTEGER <> c.cliente_comune_nascita_fk)
          )
    );
$$;

COMMENT ON FUNCTION fn_ana_clienti_nascita_modificata(INTEGER, JSONB) IS
'Se questi dati cambiano la data o il comune di nascita gia'' registrati. Riempire un
campo vuoto non conta: quella e'' una scheda che si completa, non un''identita'' che si
riscrive.';


-- ---------------------------------------------------------------------------
-- La validazione: una riga in più, e nient'altro
-- ---------------------------------------------------------------------------
-- ⚠️ La funzione qui sotto è la definizione ATTUALE con dentro il solo blocco
-- nuovo. Riscrivendola a memoria avevo cambiato senza accorgermene due cose che
-- non c'entravano: la gravità del prefisso mancante (da CONFERMA a ERRORE) e la
-- forma dell'avviso nome/sesso. Un `CREATE OR REPLACE` non avvisa di nulla:
-- sostituisce e basta.

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
$function$
