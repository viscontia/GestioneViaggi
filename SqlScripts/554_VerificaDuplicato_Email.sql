-- =============================================================================
-- 554 — L'email ripetuta entra fra i riscontri, come AVVISO
-- =============================================================================
-- Il 2026-08-20 si era deciso che l'email condivisa NON e' un vincolo: le tre
-- coppie trovate su PROD erano marito e moglie con una casella sola, e vietarlo
-- avrebbe costretto a inventare indirizzi finti. Ma la verifica non la faceva
-- nessuno: fn_ana_clienti_verifica_duplicato guardava solo codice fiscale e
-- anagrafica.
--
-- Intanto il dialog dei clienti continuava a dire "Mail gia' presente in
-- Anagrafica Clienti: impossibile proseguire" — cioe' BLOCCAVA, mentre la regola
-- decisa dice di avvisare. Due software, due risposte alla stessa domanda: e'
-- esattamente cio' che si sta smontando.
--
-- Qui l'email entra come quarto livello, con gravita' AVVISO.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_clienti_verifica_duplicato(
    p_azienda_id          INTEGER,
    p_cognome             VARCHAR,
    p_nome                VARCHAR,
    p_data_nascita        DATE    DEFAULT NULL,
    p_comune_nascita_id   INTEGER DEFAULT NULL,
    p_cf                  VARCHAR DEFAULT NULL,
    p_escludi_cliente_id  INTEGER DEFAULT NULL,
    p_email               VARCHAR DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT, cliente_id INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.gravita, r.esito, r.messaggio, r.cliente_id FROM (
    WITH candidati AS (
        SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
               c.cliente_comune_nascita_fk, upper(btrim(c.cliente_codicefiscale)) AS cf,
               lower(btrim(c.cliente_email)) AS email
        FROM ana_clienti c
        WHERE c.azienda_fk = p_azienda_id
          AND (p_escludi_cliente_id IS NULL OR c.cliente_id <> p_escludi_cliente_id)
    )
    SELECT 'ERRORE'::VARCHAR, 'STESSO_CF'::VARCHAR,
           format('Il codice fiscale è già registrato su un altro cliente: %s %s.',
                  k.cliente_cognome, k.cliente_nome)::TEXT, k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_cf,'')) <> '' AND k.cf = upper(btrim(p_cf))

    UNION ALL
    SELECT 'ERRORE'::VARCHAR, 'STESSA_ANAGRAFICA'::VARCHAR,
           format('Esiste già un cliente con gli stessi dati anagrafici: %s %s, nato il %s.',
                  k.cliente_cognome, k.cliente_nome, to_char(k.cliente_data_nascita, 'DD/MM/YYYY'))::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
      AND k.cliente_data_nascita = p_data_nascita
      AND k.cliente_comune_nascita_fk = p_comune_nascita_id
      AND upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))

    UNION ALL
    SELECT 'AVVISO'::VARCHAR, 'OMONIMO'::VARCHAR,
           format('Esiste già un cliente che si chiama %s %s%s. Controlla che non sia la stessa persona.',
                  k.cliente_cognome, k.cliente_nome,
                  CASE WHEN k.cliente_data_nascita IS NOT NULL
                       THEN ', nato il ' || to_char(k.cliente_data_nascita, 'DD/MM/YYYY') ELSE '' END)::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
      AND NOT (p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
               AND k.cliente_data_nascita = p_data_nascita
               AND k.cliente_comune_nascita_fk = p_comune_nascita_id)

    UNION ALL
    -- 4. Stessa email. AVVISO e non vincolo: condividere la casella e' prassi
    --    legittima — marito e moglie, o chi non lascia il proprio indirizzo e usa
    --    quello del compagno di viaggio. Serve a intercettare la scheda duplicata
    --    per errore, non a vietare la coppia.
    SELECT 'AVVISO'::VARCHAR, 'STESSA_EMAIL'::VARCHAR,
           format('Questo indirizzo email è già usato da %s %s. Verifica che non sia la stessa persona.',
                  k.cliente_cognome, k.cliente_nome)::TEXT, k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_email,'')) <> ''
      AND k.email = lower(btrim(p_email))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
    ) AS r(gravita, esito, messaggio, cliente_id)
    ORDER BY CASE WHEN r.gravita = 'ERRORE' THEN 1 ELSE 2 END, r.cliente_id;
$$;

-- La validazione dei clienti passa anche l'email.
CREATE OR REPLACE FUNCTION fn_ana_clienti_valida(
    p_dati       JSONB,
    p_cliente_id INTEGER DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql STABLE AS $$
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
END;
$$;

COMMIT;
