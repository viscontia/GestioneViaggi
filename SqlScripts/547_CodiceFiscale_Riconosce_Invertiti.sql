-- =============================================================================
-- 547 — Il codice fiscale riconosce nome e cognome invertiti
-- =============================================================================
-- La bonifica del 545 ha trovato TRE anagrafiche su 448 con nome e cognome
-- scambiati fra loro, e le ha riconosciute perche' il codice fiscale torna
-- esatto invertendo i due campi. E' un errore di digitazione comune — chi compila
-- in fretta parte dal campo sbagliato — e finora nessuno lo vedeva: le due
-- stringhe sono entrambe plausibili, e solo il codice fiscale sa qual e' quale.
--
-- Qui quella capacita' smette di essere un'indagine una tantum e diventa parte
-- del controllo: fn_cf_verifica, invece di dire genericamente "non corrisponde",
-- dice CHE COSA non va e come si aggiusta.
--
-- Nuovo esito: INVERTITI. Resta un errore (valido = FALSE), ma con una diagnosi
-- che si legge e si risolve in un gesto — si scambiano i due campi.
--
-- Sostituisce fn_cf_verifica del 544, gia' applicato: da qui in poi vale questa.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_cf_verifica(
    p_cf            VARCHAR,
    p_cognome       VARCHAR DEFAULT NULL,
    p_nome          VARCHAR DEFAULT NULL,
    p_data_nascita  DATE    DEFAULT NULL,
    p_sesso         CHAR    DEFAULT NULL,
    p_comune_id     INTEGER DEFAULT NULL
) RETURNS TABLE (valido BOOLEAN, esito VARCHAR, messaggio TEXT, cf_atteso VARCHAR)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cf         TEXT := upper(btrim(COALESCE(p_cf,'')));
    v_atteso     VARCHAR;
    v_invertito  VARCHAR;
BEGIN
    IF v_cf = '' THEN
        RETURN QUERY SELECT FALSE, 'MANCANTE'::VARCHAR, 'Il codice fiscale non è stato inserito.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF v_cf !~ '^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$' THEN
        RETURN QUERY SELECT FALSE, 'FORMA'::VARCHAR,
               'Il codice fiscale non ha una forma valida: servono 16 caratteri nel formato previsto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF substr(v_cf, 16, 1) <> fn_cf_carattere_controllo(substr(v_cf, 1, 15)) THEN
        RETURN QUERY SELECT FALSE, 'CARATTERE_CONTROLLO'::VARCHAR,
               'Il codice fiscale non supera il controllo dell''ultimo carattere: c''è un errore di digitazione.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF p_cognome IS NULL OR p_nome IS NULL OR p_data_nascita IS NULL
       OR p_sesso IS NULL OR p_comune_id IS NULL THEN
        RETURN QUERY SELECT TRUE, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido (non confrontato con l''anagrafica).'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    v_atteso := fn_cf_calcola(p_cognome, p_nome, p_data_nascita, p_sesso, p_comune_id);

    IF v_atteso IS NULL THEN
        RETURN QUERY SELECT TRUE, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido: l''anagrafica non basta per il confronto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF v_cf = v_atteso THEN
        RETURN QUERY SELECT TRUE, 'CORRISPONDE'::VARCHAR,
               'Codice fiscale corrispondente ai dati anagrafici.'::TEXT, v_atteso;
        RETURN;
    END IF;

    IF fn_cf_omocodia_a_base(v_cf) = fn_cf_omocodia_a_base(v_atteso) THEN
        RETURN QUERY SELECT TRUE, 'OMOCODIA'::VARCHAR,
               'Codice fiscale corrispondente, con sostituzioni per omocodia.'::TEXT, v_atteso;
        RETURN;
    END IF;

    -- Prima di dichiarare che non corrisponde: e se i due campi fossero scambiati?
    -- Il codice fiscale e' l'unico che sa quale delle due stringhe e' il cognome.
    v_invertito := fn_cf_calcola(p_nome, p_cognome, p_data_nascita, p_sesso, p_comune_id);
    IF v_invertito IS NOT NULL
       AND (v_cf = v_invertito OR fn_cf_omocodia_a_base(v_cf) = fn_cf_omocodia_a_base(v_invertito)) THEN
        RETURN QUERY SELECT FALSE, 'INVERTITI'::VARCHAR,
               format('Nome e cognome sembrano invertiti: il codice fiscale corrisponde leggendo «%s» come cognome e «%s» come nome.',
                      upper(btrim(p_nome)), upper(btrim(p_cognome)))::TEXT,
               v_atteso;
        RETURN;
    END IF;

    RETURN QUERY SELECT FALSE, 'NON_CORRISPONDE'::VARCHAR,
           format('Il codice fiscale non corrisponde ai dati anagrafici: da cognome, nome, data di nascita, sesso e comune risulterebbe %s.', v_atteso)::TEXT,
           v_atteso;
END;
$$;

COMMENT ON FUNCTION fn_cf_verifica(VARCHAR,VARCHAR,VARCHAR,DATE,CHAR,INTEGER) IS
'Verifica completa del codice fiscale. Esiti: MANCANTE, FORMA, CARATTERE_CONTROLLO, FORMA_OK, CORRISPONDE, OMOCODIA, INVERTITI (nome e cognome scambiati, SqlScripts/547), NON_CORRISPONDE. Unico punto di verita'' per gestionale e sito.';

COMMIT;
