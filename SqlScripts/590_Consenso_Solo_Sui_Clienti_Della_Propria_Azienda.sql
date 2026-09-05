-- =============================================================================
-- 590 — Il consenso si può chiedere e registrare solo sui PROPRI clienti
-- =============================================================================
--
-- Trovato il 2026-09-05 rispondendo a una domanda dell'utente: «flask le anagrafiche
-- le legge per azienda?». Quasi sempre sì — le ricerche per email e per codice
-- fiscale ricevono `p_azienda_id` — ma le due funzioni del consenso no: prendono un
-- `cliente_id` e basta.
--
-- ⚠️ Il punto non e' teorico. I due endpoint del consenso leggono l'identificativo
-- DIRETTAMENTE dalla richiesta (`request.args` e il corpo JSON), quindi bastava
-- cambiare un numero per registrare un consenso — o un rifiuto — a nome di un
-- cliente qualsiasi, anche di un'altra azienda. Un consenso al marketing falsificato
-- e' esattamente cio' che il consenso dovrebbe dimostrare non sia successo.
--
-- Le funzioni ora vogliono sapere per conto di CHI si sta chiedendo, e su un cliente
-- che non e' suo non rispondono e non scrivono.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_consenso_da_chiedere(INTEGER);
CREATE OR REPLACE FUNCTION fn_consenso_da_chiedere(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    -- Si chiede a chi non ha mai risposto. Chi ha gia' detto no non lo si richiama:
    -- essere insistenti non paga mai. Un cliente di un'altra azienda non e'
    -- «nessuno da chiedere»: e' proprio una domanda che non spetta a noi.
    SELECT EXISTS (
        SELECT 1 FROM ana_clienti c
        WHERE c.cliente_id = p_cliente_id
          AND c.azienda_fk = p_azienda_id
          AND c.consenso_marketing_chiesto_data IS NULL
          AND COALESCE(c.consenso_marketing, FALSE) = FALSE
          AND nullif(btrim(c.cliente_email), '') IS NOT NULL
    );
$$;

COMMENT ON FUNCTION fn_consenso_da_chiedere(INTEGER, INTEGER) IS
'Se a questo cliente DI QUESTA AZIENDA va chiesto il consenso alla newsletter: solo a chi
non ha mai risposto e ha un indirizzo. Su un cliente di un''altra azienda risponde no.';


DROP FUNCTION IF EXISTS fn_consenso_registra_risposta(INTEGER, BOOLEAN, VARCHAR);
CREATE OR REPLACE FUNCTION fn_consenso_registra_risposta(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER,
    p_risposta   BOOLEAN,
    p_fonte      VARCHAR DEFAULT 'iscrizione_web'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE v_righe INTEGER;
BEGIN
    UPDATE ana_clienti SET
        -- La data della domanda si registra SEMPRE, quale che sia la risposta: e'
        -- quello che distingue «ha detto no» da «non gliel'ho mai chiesto», e che
        -- impedisce di richiederlo la prossima volta.
        consenso_marketing_chiesto_data  = now(),
        consenso_marketing_chiesto_fonte = p_fonte,
        consenso_marketing               = p_risposta,
        consenso_marketing_data          = CASE WHEN p_risposta THEN now()
                                                ELSE consenso_marketing_data END,
        consenso_marketing_fonte         = CASE WHEN p_risposta THEN p_fonte
                                                ELSE consenso_marketing_fonte END
    WHERE cliente_id = p_cliente_id
      AND azienda_fk = p_azienda_id;

    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe > 0;
END;
$$;

COMMENT ON FUNCTION fn_consenso_registra_risposta(INTEGER, INTEGER, BOOLEAN, VARCHAR) IS
'Registra la risposta al consenso — anche il NO — su un cliente DI QUESTA AZIENDA.
Restituisce FALSE se il cliente non e'' suo: senza il vincolo sull''azienda bastava
cambiare un numero nella richiesta per falsificare il consenso di chiunque.';
