-- =============================================================================
-- 581 — Il rifiuto del consenso si registra, come la concessione
-- =============================================================================
--
-- Deciso il 2026-09-04, preparando la richiesta del consenso durante l'iscrizione
-- al viaggio: «a chi non ha mai risposto si chiede sempre, a chi ha rifiutato non
-- lo richiediamo piu' — essere insistenti non paga mai».
--
-- Per poterlo fare serve un dato che oggi non c'e'. Le tre colonne esistenti
-- registrano solo i CAMBI DI STATO (script 510), e un rifiuto non e' un cambio di
-- stato: `consenso_marketing` era gia' FALSE e resta FALSE, quindi
-- fn_ana_clienti_set_consenso esce senza scrivere niente. Il risultato e' che
-- FALSE significa due cose molto diverse:
--
--     «non gliel'ho mai chiesto»   e   «ha detto di no»
--
-- Sui dati reali: 737 clienti su 744 hanno FALSE, tutti senza data e senza fonte.
-- Senza distinguerli, la richiesta ricomparirebbe a ogni iscrizione anche a chi ha
-- gia' rifiutato: fastidioso per la persona e indifendibile davanti a un reclamo.
--
-- Si aggiunge quindi una colonna che dice QUANDO E' STATA POSTA LA DOMANDA,
-- indipendentemente dalla risposta. Le tre colonne esistenti non si toccano:
-- continuano a documentare il consenso e la sua eventuale revoca, che e' la prova
-- da conservare.
-- =============================================================================

ALTER TABLE ana_clienti
    ADD COLUMN IF NOT EXISTS consenso_marketing_chiesto_data  TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS consenso_marketing_chiesto_fonte VARCHAR(30) NULL;

COMMENT ON COLUMN ana_clienti.consenso_marketing_chiesto_data IS
'Quando e'' stata posta la domanda sul consenso, quale che sia stata la risposta.
NULL = non gliel''e'' mai stata posta. Serve a non richiederlo a chi ha gia'' detto no.';

COMMENT ON COLUMN ana_clienti.consenso_marketing_chiesto_fonte IS
'Dove e'' stata posta la domanda: iscrizione_web, gestionale, …';


-- ---------------------------------------------------------------------------
-- Se a questa persona il consenso va chiesto.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_consenso_da_chiedere(p_cliente_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        -- Non ce l'ha gia' dato...
        c.consenso_marketing = FALSE
        -- ...non gli e' mai stato chiesto...
        AND c.consenso_marketing_chiesto_data IS NULL
        -- ...e non ha mai espresso una volonta' in passato. Quest'ultima condizione
        -- copre chi il consenso lo aveva DATO e poi REVOCATO: per lui la colonna
        -- «chiesto» e' vuota, perche' la revoca e' avvenuta prima che esistesse, ma
        -- una risposta l'ha data eccome. Richiederglielo sarebbe il caso peggiore.
        AND c.consenso_marketing_data IS NULL,
        FALSE)
    FROM ana_clienti c
    WHERE c.cliente_id = p_cliente_id;
$$;

COMMENT ON FUNCTION fn_consenso_da_chiedere(INTEGER) IS
'Se il consenso marketing va chiesto a questo cliente: solo a chi non ha mai risposto.
Chi ha gia'' detto sì, chi ha detto no e chi ha revocato non vengono piu'' interpellati.
Regola unica per il gestionale e per il sito di iscrizione.';


-- ---------------------------------------------------------------------------
-- La risposta, qualunque sia.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_consenso_registra_risposta(
    p_cliente_id INTEGER,
    p_risposta   BOOLEAN,
    p_fonte      VARCHAR DEFAULT 'iscrizione_web'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_fonte VARCHAR := COALESCE(NULLIF(btrim(p_fonte), ''), 'iscrizione_web');
BEGIN
    -- La domanda risulta posta in ogni caso: e' proprio il no che va registrato,
    -- perche' e' il no che impedisce di richiederlo domani.
    UPDATE ana_clienti
       SET consenso_marketing_chiesto_data  = NOW(),
           consenso_marketing_chiesto_fonte = v_fonte
     WHERE cliente_id = p_cliente_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Il sì passa dalla funzione che c'era gia', che scrive data e fonte del
    -- consenso: quella resta la prova di quando e' stato concesso, e non va
    -- confusa con la data in cui e' stata posta la domanda.
    IF p_risposta THEN
        PERFORM fn_ana_clienti_set_consenso(p_cliente_id, TRUE, v_fonte);
    END IF;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION fn_consenso_registra_risposta(INTEGER, BOOLEAN, VARCHAR) IS
'Registra la risposta alla richiesta di consenso, sì o no che sia. Il no non cambia
lo stato del consenso ma segna che la domanda e'' stata posta, ed e'' cio'' che evita
di richiederlo a chi ha gia'' rifiutato.';
