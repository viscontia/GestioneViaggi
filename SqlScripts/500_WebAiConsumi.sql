-- Registro dei consumi Claude (traduzioni) + soglia di spesa per azienda.
--
-- Perché serve: la chiave Anthropic è precaricata con un importo e l'utente traduce senza vedere
-- quanto sta spendendo. L'API NON espone il credito residuo (nessun endpoint di saldo con la chiave
-- normale; l'Admin API riporta consumi e costi, non il residuo, e richiede una chiave di
-- organizzazione), quindi il consumo lo contiamo noi: ogni risposta Messages include già il blocco
-- "usage" con i token, che finora veniva scartato. Nessuna chiamata aggiuntiva, nessun credito bruciato.
--
-- ⚠️ Il costo qui registrato è una STIMA sui consumi passati da QUESTO gestionale: se la stessa
-- chiave viene usata altrove, quel consumo non compare.

CREATE TABLE IF NOT EXISTS web_ai_consumi (
    web_ai_consumo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id        INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    modello           VARCHAR(60)  NOT NULL,
    contesto          VARCHAR(200),           -- es. "Descrizione (EN)": per capire dove sono finiti i token
    input_tokens      INTEGER      NOT NULL DEFAULT 0,
    output_tokens     INTEGER      NOT NULL DEFAULT 0,
    -- Costo calcolato al momento della chiamata con i prezzi allora configurati: congelarlo qui
    -- mantiene corretto lo storico anche se i prezzi di listino cambiano.
    costo_stimato     NUMERIC(12,6) NOT NULL DEFAULT 0,
    valuta            VARCHAR(3)   NOT NULL DEFAULT 'USD',
    created_by        VARCHAR(50)  NOT NULL,
    created           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_web_ai_consumi_azienda_data ON web_ai_consumi (azienda_id, created DESC);

COMMENT ON TABLE web_ai_consumi IS
'Consumi Claude registrati dal gestionale (token e costo stimato per chiamata). Stima interna: non è il saldo Anthropic.';

-- Configurazione per azienda: soglia di spesa facoltativa.
-- Non si tiene traccia delle ricariche (decisione utente): senza importo dichiarato non esiste una
-- percentuale di credito, quindi l'allerta è su una soglia di spesa cumulata scelta dall'utente.
CREATE TABLE IF NOT EXISTS web_ai_config (
    azienda_id   INTEGER      PRIMARY KEY REFERENCES ana_aziende(azienda_id) ON DELETE CASCADE,
    soglia_spesa NUMERIC(10,2),          -- NULL = nessun avviso
    -- Da quando contare la spesa ai fini della soglia: si sposta a "adesso" quando si ricarica o si
    -- riarma l'avviso, così il conteggio riparte senza cancellare lo storico.
    conteggio_da TIMESTAMPTZ  NOT NULL DEFAULT now(),
    avvisato_il  TIMESTAMPTZ,            -- NULL = avviso non ancora inviato per il periodo corrente
    created_by   VARCHAR(50)  NOT NULL DEFAULT 'system',
    created      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by   VARCHAR(50),
    updated      TIMESTAMPTZ
);

COMMENT ON TABLE web_ai_config IS
'Soglia di spesa Claude per azienda. avvisato_il impedisce di rimandare la stessa email a ogni traduzione successiva.';

-- ---------------------------------------------------------------------------
-- Registrazione di una chiamata
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_ai_consumo_insert(
    p_azienda_id    INTEGER,
    p_modello       VARCHAR,
    p_contesto      VARCHAR,
    p_input_tokens  INTEGER,
    p_output_tokens INTEGER,
    p_costo         NUMERIC,
    p_valuta        VARCHAR DEFAULT 'USD')
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_ai_consumi(azienda_id, modello, contesto, input_tokens, output_tokens,
                               costo_stimato, valuta, created_by)
    VALUES (p_azienda_id, p_modello, p_contesto, COALESCE(p_input_tokens,0), COALESCE(p_output_tokens,0),
            COALESCE(p_costo,0), COALESCE(p_valuta,'USD'),
            COALESCE(current_setting('my.app_user', true), 'system'))
    RETURNING web_ai_consumo_id INTO v_id;
    RETURN v_id;
END $$;

-- ---------------------------------------------------------------------------
-- Riepilogo: totali dal periodo indicato (NULL = da sempre)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_ai_consumo_riepilogo(
    p_azienda_id INTEGER,
    p_da         TIMESTAMPTZ DEFAULT NULL)
RETURNS TABLE (
    n_chiamate     INTEGER,
    tot_input      BIGINT,
    tot_output     BIGINT,
    costo_totale   NUMERIC,
    valuta         VARCHAR,
    ultima_chiamata TIMESTAMPTZ)
LANGUAGE sql STABLE AS $$
    SELECT COUNT(*)::INTEGER,
           COALESCE(SUM(input_tokens), 0)::BIGINT,
           COALESCE(SUM(output_tokens), 0)::BIGINT,
           COALESCE(SUM(costo_stimato), 0)::NUMERIC,
           COALESCE(MAX(valuta), 'USD')::VARCHAR,
           MAX(created)
      FROM web_ai_consumi
     WHERE azienda_id = p_azienda_id
       AND (p_da IS NULL OR created >= p_da);
$$;

-- ---------------------------------------------------------------------------
-- Config: lettura e impostazione della soglia
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_ai_config_get(p_azienda_id INTEGER)
RETURNS TABLE (soglia_spesa NUMERIC, conteggio_da TIMESTAMPTZ, avvisato_il TIMESTAMPTZ)
LANGUAGE sql STABLE AS $$
    SELECT c.soglia_spesa, c.conteggio_da, c.avvisato_il
      FROM web_ai_config c WHERE c.azienda_id = p_azienda_id;
$$;

-- p_riparti = true azzera il conteggio (nuova ricarica): sposta conteggio_da a ora e riarma l'avviso.
CREATE OR REPLACE FUNCTION fn_web_ai_config_set(
    p_azienda_id INTEGER,
    p_soglia     NUMERIC,
    p_riparti    BOOLEAN DEFAULT FALSE)
RETURNS INTEGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO web_ai_config(azienda_id, soglia_spesa, conteggio_da, avvisato_il, created_by)
    VALUES (p_azienda_id, p_soglia, now(), NULL, COALESCE(current_setting('my.app_user', true), 'system'))
    ON CONFLICT (azienda_id) DO UPDATE
       SET soglia_spesa = EXCLUDED.soglia_spesa,
           conteggio_da = CASE WHEN p_riparti THEN now() ELSE web_ai_config.conteggio_da END,
           -- Cambiare la soglia o ripartire riarma l'avviso: altrimenti alzando il tetto non si
           -- verrebbe più avvisati al nuovo superamento.
           avvisato_il  = NULL,
           updated_by   = COALESCE(current_setting('my.app_user', true), 'system'),
           updated      = now();
    RETURN 1;
END $$;

-- ---------------------------------------------------------------------------
-- Soglia superata? Marca l'avviso nella stessa istruzione.
-- ---------------------------------------------------------------------------
-- Restituisce true UNA sola volta per periodo. Il controllo e la marcatura stanno nello stesso
-- UPDATE: se fossero due istruzioni, due traduzioni in sequenza potrebbero entrambe leggere
-- "non ancora avvisato" e far partire due email.
CREATE OR REPLACE FUNCTION fn_web_ai_soglia_da_avvisare(p_azienda_id INTEGER)
RETURNS TABLE (da_avvisare BOOLEAN, speso NUMERIC, soglia NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE v_speso NUMERIC; v_soglia NUMERIC; v_rows INTEGER;
BEGIN
    SELECT c.soglia_spesa,
           COALESCE((SELECT SUM(k.costo_stimato) FROM web_ai_consumi k
                      WHERE k.azienda_id = p_azienda_id AND k.created >= c.conteggio_da), 0)
      INTO v_soglia, v_speso
      FROM web_ai_config c
     WHERE c.azienda_id = p_azienda_id;

    IF v_soglia IS NULL OR v_soglia <= 0 THEN
        RETURN QUERY SELECT FALSE, COALESCE(v_speso, 0), v_soglia;   -- nessuna soglia impostata
        RETURN;
    END IF;

    UPDATE web_ai_config
       SET avvisato_il = now()
     WHERE azienda_id = p_azienda_id
       AND avvisato_il IS NULL
       AND v_speso >= v_soglia * 0.9;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    RETURN QUERY SELECT v_rows > 0, v_speso, v_soglia;
END $$;

COMMENT ON FUNCTION fn_web_ai_soglia_da_avvisare(INTEGER) IS
'true (una sola volta per periodo) quando la spesa raggiunge il 90% della soglia: controllo e marcatura nello stesso UPDATE per non generare email doppie.';

-- ---------------------------------------------------------------------------
-- Destinatario dell'avviso: email principale dell'azienda
-- ---------------------------------------------------------------------------
-- Preferisce l'indirizzo marcato principale; in mancanza prende il primo disponibile, così
-- l'avviso arriva comunque invece di perdersi perché nessuno ha spuntato "principale".
CREATE OR REPLACE FUNCTION fn_ana_aziende_email_principale(p_azienda_id INTEGER)
RETURNS VARCHAR LANGUAGE sql STABLE AS $$
    SELECT email FROM ana_aziende_email
     WHERE azienda_fk = p_azienda_id
     ORDER BY is_principale DESC, email_id
     LIMIT 1;
$$;
