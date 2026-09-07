-- =============================================================================
-- 624 — Blocco C: una regola sola per l'email, e via i ruderi della validazione
-- =============================================================================
--
-- ⚠️ **Correzione a due mie affermazioni**, che avevo scritto nel piano e che la
-- misura ha smentito:
--
--   1. «il sito accetta iscrizioni che il gestionale rifiuta» — FALSO. La catena e'
--      `fn_mov_clienti_viaggi_insert` → `_guardia` → `_valida`: la regola vale
--      identica per tutti e due. Quello che manca al sito e' CHIEDERE prima, per
--      dirlo alla persona invece di farla arrivare in fondo e poi rifiutarla;
--   2. «il codice fiscale e' scritto tre volte» — FALSO. E' gia' unificato: la
--      famiglia `fn_cf_*` a database fa il calcolo, il carattere di controllo e
--      l'omocodia; il C# fa solo il controllo di FORMA mentre si digita, e lo dice
--      nella sua intestazione; il componente JavaScript chiama `/api/validate-cf`,
--      che a sua volta chiama il database. Contare i file non e' misurare.
--
-- Quello che invece e' vero, e si corregge qui.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. «Indirizzo valido»: due definizioni, e diverse
-- ---------------------------------------------------------------------------
-- `fn_validate_email_format` diceva una cosa, e `fn_ana_clienti_valida` se la
-- riscriveva a modo suo, piu' permissiva. Sui 471 clienti in locale la differenza si
-- vede su UNO: `mailto:avvocatoelenaperini@gmail.com` — un collegamento incollato al
-- posto dell'indirizzo, che la permissiva lasciava passare.
--
-- ⚠️ Su PROD (azienda 2) tutti i 198 indirizzi passano la regola severa: adottarla
-- non blocca nessuno. Verificato in sola lettura il 2026-09-07.
--
-- Si tiene la funzione con un nome, e chi serve la chiama.
CREATE OR REPLACE FUNCTION fn_validate_email_format(p_email text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    RETURN p_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$;

COMMENT ON FUNCTION fn_validate_email_format(text) IS
'⛔️ **L''unica definizione di «indirizzo scritto bene»** per il gestionale e per il sito.
Non riscriverla altrove: fino al 2026-09-07 ce n''erano due, e non concordavano.
Non dice se la casella esiste — quello lo dice solo mandarci una mail.';


-- ---------------------------------------------------------------------------
-- 2. La validazione del cliente chiede a lei
-- ---------------------------------------------------------------------------
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


-- ---------------------------------------------------------------------------
-- 3. I ruderi: una validazione che finge di validare
-- ---------------------------------------------------------------------------
-- ⛔️ `validate_codice_fiscale` controllava solo la FORMA con un'espressione regolare,
-- e aveva dentro scritto:
--
--     -- TODO: Implementare algoritmo completo di controllo
--     -- Per ora validazione pattern
--
-- Niente carattere di controllo: un codice fiscale con l'ultima lettera sbagliata le
-- risultava buono. ⚠️ E' il tipo peggiore di funzione morta — non inerte, ma
-- **ingannevole**: chi la trovasse e la usasse crederebbe di aver controllato.
-- Accanto c'e' gia' la famiglia `fn_cf_*`, completa, che fa il calcolo vero.
--
-- `validate_fiscal_data` era l'unica a chiamarla, e non la chiama nessuno.
-- `validate_partita_iva` stessa storia.
-- ⚠️ Firme lette dal database: un DROP con la firma sbagliata non protesta.
DROP FUNCTION IF EXISTS validate_fiscal_data();
DROP FUNCTION IF EXISTS validate_codice_fiscale(text);
DROP FUNCTION IF EXISTS validate_partita_iva(text);
