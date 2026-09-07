-- ============================================================================
-- 629 — Il codice fiscale diventa obbligatorio per i NUOVI residenti in Italia
--
-- Adriano, 2026-09-07: «SFT sta diventando un Tour Operator VERO (non sotto altri
-- TO come ora) quindi dovrà fare la fattura ad ogni singolo cliente e senza CF non
-- la può fare. Obbligatoria questa strada, da implementare assolutamente ovunque
-- prima del go-live.»
--
-- DOVE STA LA REGOLA. Qui dentro, in fn_ana_clienti_valida, che e' l'unica
-- validazione che il gestionale e il sito chiamano ENTRAMBI: scritta una volta,
-- vale ovunque. Non serve toccare nessuna delle due applicazioni perche' il
-- controllo scatti — semmai per anticiparlo all'utente con un asterisco.
--
-- LE DUE ESCLUSIONI, ed entrambe contano:
--   • solo le schede NUOVE (p_cliente_id IS NULL). Su PROD ci sono 44 clienti
--     residenti in Italia senza codice fiscale, e 42 di loro HANNO GIA' VIAGGIATO:
--     applicare la regola anche a loro renderebbe non risalvabili delle schede
--     valide, che e' esattamente il difetto di §2.9. Restano in pace.
--   • chi risiede ALL'ESTERO: il codice fiscale italiano non ce l'ha. Il
--     discriminante e' ana_geo_comuni.comune_estero = 'Y' (in az.2 sono 3 clienti,
--     2 dei quali senza codice fiscale).
--
-- ⚠️ NON e' un controllo di forma: se il codice fiscale c'e', a verificarlo resta
-- fn_cf_verifica, che era gia' li' sopra. Questo aggiunge solo «deve esserci».
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

    -- ⚠️ Il codice fiscale e' OBBLIGATORIO per chi si iscrive ORA e risiede in Italia.
    -- Deciso da Adriano il 2026-09-07: SFT sta diventando tour operator in proprio e
    -- dovra' fatturare a ogni singolo cliente — senza codice fiscale la fattura non
    -- si emette. Non e' una regola formale, e' un requisito fiscale.
    --
    -- Vale SOLO sulle schede nuove (p_cliente_id IS NULL). I clienti che ci sono gia'
    -- senza codice fiscale — 44 su PROD al 2026-09-07, di cui 42 hanno gia' viaggiato —
    -- restano modificabili come prima: bloccarli renderebbe non risalvabili delle
    -- schede valide, che e' il difetto gia' visto con i campi obbligatori (§2.9).
    --
    -- Chi risiede all'estero e' escluso: il codice fiscale italiano non ce l'ha.
    -- Il discriminante e' ana_geo_comuni.comune_estero ('Y' = fuori dall'Italia).
    IF p_cliente_id IS NULL AND btrim(COALESCE(v_cf, '')) = '' AND v_com_res IS NOT NULL THEN
        SELECT (g.comune_estero = 'Y') INTO v_estero
        FROM ana_geo_comuni g WHERE g.comune_id = v_com_res;

        IF COALESCE(v_estero, FALSE) = FALSE THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'MANCA_CF_RESIDENTE_ITALIA'::VARCHAR,
                   ('Il codice fiscale è obbligatorio per chi risiede in Italia: '
                    || 'serve per emettere la fattura.')::TEXT;
        END IF;
    END IF;

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

COMMIT;
