-- =============================================================================
-- 555 — Verificare il codice fiscale partendo da un cliente
-- =============================================================================
-- fn_cf_verifica vuole l'anagrafica campo per campo. Va bene quando i dati sono
-- in mano a chi chiama (una form aperta), ma non quando si parte da un cliente
-- gia' a database: il sito di iscrizione faceva 70 righe di orchestrazione in
-- Python — leggere il cliente, estrarre cognome nome data sesso e codice
-- catastale, calcolare il CF atteso, confrontare, gestire l'omocodia — per
-- arrivare dove questa funzione arriva in una chiamata.
--
-- Con p_cliente_id nullo resta la sola verifica di forma: e' il caso del cliente
-- nuovo, che l'anagrafica non ce l'ha ancora.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_cf_verifica_cliente(
    p_cf         VARCHAR,
    p_cliente_id INTEGER DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT, cf_atteso VARCHAR)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cognome VARCHAR; v_nome VARCHAR; v_nascita DATE; v_sesso CHAR; v_comune INTEGER;
BEGIN
    IF p_cliente_id IS NOT NULL THEN
        SELECT c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
               c.cliente_sesso, c.cliente_comune_nascita_fk
          INTO v_cognome, v_nome, v_nascita, v_sesso, v_comune
        FROM ana_clienti c WHERE c.cliente_id = p_cliente_id;
    END IF;

    RETURN QUERY SELECT * FROM fn_cf_verifica(p_cf, v_cognome, v_nome, v_nascita, v_sesso, v_comune);
END;
$$;

COMMENT ON FUNCTION fn_cf_verifica_cliente(VARCHAR,INTEGER) IS
'Verifica del codice fiscale partendo da un cliente gia'' a database. Con p_cliente_id nullo resta la sola verifica di forma.';

COMMIT;
