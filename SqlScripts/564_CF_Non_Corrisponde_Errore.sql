-- =============================================================================
-- 564 — Il codice fiscale che non corrisponde e' un errore, non una domanda
-- =============================================================================
--
-- Deciso il 2026-08-31, durante i test del gruppo C. Finora fn_cf_verifica
-- rispondeva CONFERMA quando il codice non tornava con i dati anagrafici, per
-- non lasciare senza via d'uscita chi ha in mano un documento vero. In pratica
-- pero' quella domanda si puo' rispondere "si'" per stanchezza, e nasce una
-- scheda in cui codice e dati si contraddicono — senza che nessuno sappia piu'
-- quale dei due fosse quello buono.
--
-- Resta CONFERMA il solo caso in cui si sa cosa e' successo: **nomi invertiti**.
-- Li' il codice e' emesso davvero cosi', la correzione e' nota (scambiare i due
-- campi) e l'operatore la puo' accettare con cognizione.
--
-- Non toccati: forma e carattere di controllo (gia' ERRORE), codice mancante e
-- nato all'estero (nessun confronto possibile, gia' OK).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_cf_verifica(p_cf character varying, p_cognome character varying DEFAULT NULL::character varying, p_nome character varying DEFAULT NULL::character varying, p_data_nascita date DEFAULT NULL::date, p_sesso character DEFAULT NULL::bpchar, p_comune_id integer DEFAULT NULL::integer)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text, cf_atteso character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_cf         TEXT := upper(btrim(COALESCE(p_cf,'')));
    v_atteso     VARCHAR;
    v_invertito  VARCHAR;
BEGIN
    -- Il codice fiscale in se' non e' obbligatorio: se manca, non c'e' nulla da
    -- verificare. Se debba esserci o no lo decide un'altra regola.
    IF v_cf = '' THEN
        RETURN QUERY SELECT 'OK'::VARCHAR, 'MANCANTE'::VARCHAR,
               'Nessun codice fiscale da verificare.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    -- Un codice malformato non puo' essere un codice emesso: e' un refuso.
    IF v_cf !~ '^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'FORMA'::VARCHAR,
               'Il codice fiscale non ha una forma valida: servono 16 caratteri nel formato previsto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF substr(v_cf, 16, 1) <> fn_cf_carattere_controllo(substr(v_cf, 1, 15)) THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'CARATTERE_CONTROLLO'::VARCHAR,
               'Il codice fiscale non supera il controllo dell''ultimo carattere: c''è un errore di digitazione.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF p_cognome IS NULL OR p_nome IS NULL OR p_data_nascita IS NULL
       OR p_sesso IS NULL OR p_comune_id IS NULL THEN
        RETURN QUERY SELECT 'OK'::VARCHAR, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido (non confrontato con l''anagrafica).'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    v_atteso := fn_cf_calcola(p_cognome, p_nome, p_data_nascita, p_sesso, p_comune_id);

    -- Comune senza codice catastale (chi e' nato all'estero): il confronto non si
    -- puo' fare, e non e' colpa di chi compila.
    IF v_atteso IS NULL THEN
        RETURN QUERY SELECT 'OK'::VARCHAR, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido: l''anagrafica non basta per il confronto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF v_cf = v_atteso THEN
        RETURN QUERY SELECT 'OK'::VARCHAR, 'CORRISPONDE'::VARCHAR,
               'Codice fiscale corrispondente ai dati anagrafici.'::TEXT, v_atteso;
        RETURN;
    END IF;

    IF fn_cf_omocodia_a_base(v_cf) = fn_cf_omocodia_a_base(v_atteso) THEN
        RETURN QUERY SELECT 'OK'::VARCHAR, 'OMOCODIA'::VARCHAR,
               'Codice fiscale corrispondente, con sostituzioni per omocodia.'::TEXT, v_atteso;
        RETURN;
    END IF;

    -- Prima di dire che non corrisponde: e se i due campi fossero scambiati?
    v_invertito := fn_cf_calcola(p_nome, p_cognome, p_data_nascita, p_sesso, p_comune_id);
    IF v_invertito IS NOT NULL
       AND (v_cf = v_invertito OR fn_cf_omocodia_a_base(v_cf) = fn_cf_omocodia_a_base(v_invertito)) THEN
        RETURN QUERY SELECT 'CONFERMA'::VARCHAR, 'INVERTITI'::VARCHAR,
               format('Nome e cognome sembrano invertiti: il codice fiscale corrisponde leggendo «%s» come cognome e «%s» come nome. Vuoi scambiarli?',
                      upper(btrim(p_nome)), upper(btrim(p_cognome)))::TEXT,
               v_atteso;
        RETURN;
    END IF;

    -- Non corrisponde, e non e' il caso dei nomi invertiti (gestito sopra, che resta
    -- una CONFERMA perche' quel codice esiste davvero). Qui e' ERRORE, deciso il
    -- 2026-08-31: se il codice non torna con i dati, uno dei due e' sbagliato, e la
    -- risposta e' correggerlo — non registrare comunque una coppia incoerente che poi
    -- nessuno sapra' piu' quale dei due fosse buono.
    RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'NON_CORRISPONDE'::VARCHAR,
           format('Il codice fiscale non corrisponde ai dati anagrafici: da cognome, nome, data di nascita, sesso e comune risulterebbe %s. Controlla i dati prima di proseguire.', v_atteso)::TEXT,
           v_atteso;
END;
$function$
