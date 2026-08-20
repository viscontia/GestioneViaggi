-- =============================================================================
-- 548 — Le verifiche dicono anche QUANTO e' grave
-- =============================================================================
-- Finora fn_cf_verifica restituiva "valido si'/no". Ma fra il valido e il non
-- valido c'e' una terza cosa, e il progetto la conosce gia': DateValidator.
-- MotivoDaConfermare, nato col bug delle date, "non vieta ma chiede conferma".
--
-- Il caso che lo rende necessario: nome e cognome invertiti. La diagnosi e'
-- quasi certa — che un codice fiscale sbagliato corrisponda per caso
-- all'anagrafica scambiata e' praticamente impossibile — ma la conclusione no:
-- i codici fiscali emessi con i campi invertiti ESISTONO, soprattutto per gli
-- stranieri, dove l'ordine nome/cognome del documento d'origine e' rovesciato.
-- Bloccare renderebbe quella persona non registrabile per sempre.
--
-- Da qui un vocabolario unico, che vale per il gestionale E per il sito:
--
--   OK       — nulla da dire
--   AVVISO   — si segnala, si prosegue senza chiedere niente
--   CONFERMA — si chiede "vuoi davvero?", e si puo' proseguire
--   ERRORE   — non si salva
--
-- Scriverlo qui, e non in ciascun client, e' il punto: la politica "questo
-- blocca, quello chiede conferma" deve essere una sola, altrimenti torna a
-- sparpagliarsi. E' esattamente cio' che stiamo smontando.
-- =============================================================================

BEGIN;

-- Il tipo restituito cambia (si aggiunge la gravita'), e CREATE OR REPLACE non
-- puo' farlo: serve eliminare prima. E' sicuro perche' nessuno la chiama ancora —
-- il gestionale e il sito passeranno alle funzioni canoniche con le fasi 3 e 5.
DROP FUNCTION IF EXISTS fn_cf_verifica(VARCHAR,VARCHAR,VARCHAR,DATE,CHAR,INTEGER);

CREATE OR REPLACE FUNCTION fn_cf_verifica(
    p_cf            VARCHAR,
    p_cognome       VARCHAR DEFAULT NULL,
    p_nome          VARCHAR DEFAULT NULL,
    p_data_nascita  DATE    DEFAULT NULL,
    p_sesso         CHAR    DEFAULT NULL,
    p_comune_id     INTEGER DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT, cf_atteso VARCHAR)
LANGUAGE plpgsql STABLE AS $$
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

    -- Non corrisponde e non sappiamo perche'. CONFERMA e non ERRORE: senza
    -- conoscere la correzione, un blocco lascerebbe l'operatore con un codice
    -- preso da un documento vero e nessun modo di registrarlo.
    RETURN QUERY SELECT 'CONFERMA'::VARCHAR, 'NON_CORRISPONDE'::VARCHAR,
           format('Il codice fiscale non corrisponde ai dati anagrafici: da cognome, nome, data di nascita, sesso e comune risulterebbe %s. Controlla i dati prima di proseguire.', v_atteso)::TEXT,
           v_atteso;
END;
$$;

COMMENT ON FUNCTION fn_cf_verifica(VARCHAR,VARCHAR,VARCHAR,DATE,CHAR,INTEGER) IS
'Verifica del codice fiscale con GRAVITA'' (OK/AVVISO/CONFERMA/ERRORE, SqlScripts/548). Esiti: MANCANTE, FORMA, CARATTERE_CONTROLLO, FORMA_OK, CORRISPONDE, OMOCODIA, INVERTITI, NON_CORRISPONDE. Unico punto di verita'' per gestionale e sito.';

COMMIT;
