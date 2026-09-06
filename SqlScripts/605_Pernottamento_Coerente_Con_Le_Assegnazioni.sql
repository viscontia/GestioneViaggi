-- =============================================================================
-- 605 — Cambiare o togliere un pernottamento non invalida ciò che è già assegnato
-- =============================================================================
--
-- Domanda emersa in collaudo il 2026-09-06, dopo la stessa dal lato dei tipi
-- (script 604): «e se ci sono già abbinamenti su clienti/viaggi? La domanda vale
-- per le modifiche e per le cancellazioni».
--
-- ⚠️ Le strade per invalidare la storia in silenzio erano **tre**, non una:
--
--   1. Togliere un genere dai generi ammessi da un pernottamento.
--      Misurato: togliere ALBERGO dal pernottamento «ALBERGO» renderebbe incoerenti
--      **414 assegnazioni**.
--
--   2. Cambiare il pernottamento DI UN VIAGGIO. Misurato: «4X4 - COAST TO COAST
--      2022» ha 37 assegnazioni che si invaliderebbero passando a SOLO CAMPI TENDATI.
--
--   3. Cancellare un pernottamento. ✅ Qui la protezione **c'era gia'**: il trigger
--      `ana_tipo_pernottamento_trg2` rifiuta e dice quanto e' collegato («57 viaggi,
--      121 date viaggi e 1417 prenotazioni»). ⚠️ Mancava pero' la **chiave esterna**
--      su `ana_viaggi.viaggio_tipo_pernottamento_fk` — ne' in sviluppo ne' su PROD:
--      l'integrita' dipendeva interamente da quel trigger, e un trigger si puo'
--      disattivare (lo abbiamo fatto noi stessi nello script 597). La si aggiunge
--      come rete sotto la rete. Orfani oggi: 0 in entrambi gli ambienti.
--
-- Il trigger `trg_alloggio_coerente` (602) non copre nulla di tutto questo: guarda
-- le assegnazioni quando le si scrive, non cio' che cambia sotto di loro.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. La chiave esterna che mancava
-- ---------------------------------------------------------------------------
-- ON DELETE RESTRICT: cancellare un pernottamento usato da un viaggio non deve
-- riuscire. Non c'e' una scelta sensata da fare al posto dell'operatore — mettere
-- NULL vorrebbe dire «viaggio senza pernottamento», che e' un'altra cosa.
ALTER TABLE ana_viaggi
    ADD CONSTRAINT fk_ana_viaggi_tipo_pernottamento
    FOREIGN KEY (viaggio_tipo_pernottamento_fk)
    REFERENCES ana_tipo_pernottamento(ana_tipo_pernottamento_id)
    ON DELETE RESTRICT;


-- ---------------------------------------------------------------------------
-- 2. Togliere un genere ammesso: solo se non invalida assegnazioni
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_set(
    p_pernottamento_id INTEGER, p_generi INTEGER[]
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_quanti  INTEGER;
    v_rotte   INTEGER;
    v_viaggi  TEXT;
BEGIN
    -- Che cosa resterebbe scoperto con i generi nuovi? Si guarda l'EFFETTO, non
    -- l'uso: se un genere si toglie e nessuno lo stava usando, e' innocuo — ed e'
    -- proprio il caso in cui serve poter correggere una configurazione sbagliata.
    SELECT count(*),
           string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
      INTO v_rotte, v_viaggi
    FROM mov_clienti_alloggi a
    JOIN ana_viaggi v          ON v.viaggio_id = a.viaggio_id_fk
    JOIN ana_tipo_alloggio t   ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE v.viaggio_tipo_pernottamento_fk = p_pernottamento_id
      -- «Nessuna sistemazione» vale sempre e non dipende dalla configurazione.
      AND g.genere_codice <> 'NESSUNA'
      AND NOT (t.genere_fk = ANY (COALESCE(p_generi, ARRAY[]::INTEGER[])));

    IF COALESCE(v_rotte, 0) > 0 THEN
        RAISE EXCEPTION
            'Con queste sistemazioni % assegnazioni già registrate resterebbero scoperte, su: %. Cambia prima quelle assegnazioni, oppure lascia le sistemazioni come sono.',
            v_rotte, left(v_viaggi, 200)
            USING ERRCODE = 'check_violation';
    END IF;

    DELETE FROM ana_tipo_pernottamento_generi WHERE pernottamento_fk = p_pernottamento_id;

    INSERT INTO ana_tipo_pernottamento_generi (pernottamento_fk, genere_fk)
    SELECT p_pernottamento_id, x FROM unnest(COALESCE(p_generi, ARRAY[]::INTEGER[])) x
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_quanti = ROW_COUNT;

    -- `con_albergo` resta una conseguenza, non una scelta (vedi script 601).
    UPDATE ana_tipo_pernottamento p
       SET ana_tipo_pernottamento_con_albergo =
           CASE WHEN EXISTS (
                    SELECT 1 FROM ana_tipo_pernottamento_generi pg
                    JOIN ana_alloggio_generi g ON g.genere_id = pg.genere_fk
                    WHERE pg.pernottamento_fk = p_pernottamento_id AND g.genere_codice = 'ALBERGO')
                THEN 'Y' ELSE 'N' END
     WHERE p.ana_tipo_pernottamento_id = p_pernottamento_id;

    RETURN v_quanti;
END;
$$;


-- ---------------------------------------------------------------------------
-- 3. Cambiare il pernottamento di un viaggio
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_guardia_pernottamento_viaggio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE v_rotte INTEGER; v_pern VARCHAR;
BEGIN
    IF NEW.viaggio_tipo_pernottamento_fk IS NOT DISTINCT FROM OLD.viaggio_tipo_pernottamento_fk THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_rotte
    FROM mov_clienti_alloggi a
    JOIN ana_tipo_alloggio t   ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE a.viaggio_id_fk = NEW.viaggio_id
      AND g.genere_codice <> 'NESSUNA'
      AND NOT EXISTS (
          SELECT 1 FROM ana_tipo_pernottamento_generi pg
          WHERE pg.pernottamento_fk = NEW.viaggio_tipo_pernottamento_fk
            AND pg.genere_fk = t.genere_fk);

    IF v_rotte > 0 THEN
        SELECT ana_tipo_pernottamento_descrizione INTO v_pern
        FROM ana_tipo_pernottamento WHERE ana_tipo_pernottamento_id = NEW.viaggio_tipo_pernottamento_fk;

        RAISE EXCEPTION
            'Con il pernottamento «%» % sistemazioni già assegnate su questo viaggio non sarebbero più ammesse. Vanno cambiate prima.',
            COALESCE(v_pern, 'scelto'), v_rotte
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pernottamento_viaggio ON ana_viaggi;
CREATE TRIGGER trg_pernottamento_viaggio
    BEFORE UPDATE OF viaggio_tipo_pernottamento_fk ON ana_viaggi
    FOR EACH ROW EXECUTE FUNCTION fn_guardia_pernottamento_viaggio();
