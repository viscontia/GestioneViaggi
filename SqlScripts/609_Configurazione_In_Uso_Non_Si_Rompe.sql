-- =============================================================================
-- 609 — Una configurazione in uso non si rompe, e «NESSUNO» non si tocca
-- =============================================================================
--
-- Due decisioni dell'utente il 2026-09-06, in collaudo.
--
-- 1. ⛔️ **Niente conferma: si rifiuta.** «La B perché la A è molto pericolosa».
--    Un solo clic su «Procedi» poteva scoprire 414 assegnazioni valide. Chi vuole
--    cambiare la configurazione sistema prima le assegnazioni, poi la cambia.
--    ⚠️ Supera gli script 607 e 608, che avevano introdotto la conferma per uscire
--    dalla trappola della prova C7 — trappola che il punto 2 elimina alla radice.
--
-- 2. **«NESSUNO» è una configurazione di sistema.** «Credo sia inutile e fuorviante
--    far spuntare casistiche che tanto non possono avere un'applicazione»: un
--    pernottamento che significa «non si dorme da nessuna parte» non puo' ammettere
--    generi di sistemazione. Spuntarli era proprio il gesto che ha creato la
--    trappola di C7, rendendo valide 17 righe storiche incoerenti.
--
-- ⚠️ **Come si riconosce «NESSUNO».** NON dalla descrizione: e' il difetto tolto
-- quattro volte fra il 5 e il 6 settembre — basta che qualcuno rinomini la riga e
-- il blocco sparisce in silenzio. Si aggiunge una colonna, che e' un dato.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Il segno che una riga e' di sistema
-- ---------------------------------------------------------------------------
ALTER TABLE ana_tipo_pernottamento
    ADD COLUMN IF NOT EXISTS ana_tipo_pernottamento_di_sistema BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN ana_tipo_pernottamento.ana_tipo_pernottamento_di_sistema IS
'La riga ha un significato per il programma e non si configura: «NESSUNO» vuol dire che il
viaggio non prevede pernottamento, quindi non puo'' ammettere generi di sistemazione.
⚠️ E'' una colonna e non un confronto sulla descrizione: rinominare la riga non deve poter
far sparire il blocco.';

-- Si riconosce UNA volta, qui, dai dati di oggi: da domani e' un dato.
UPDATE ana_tipo_pernottamento
   SET ana_tipo_pernottamento_di_sistema = TRUE
 WHERE upper(btrim(ana_tipo_pernottamento_descrizione)) = 'NESSUNO';

-- Una riga di sistema non ammette generi: si toglie cio' che c'e'.
DELETE FROM ana_tipo_pernottamento_generi pg
 USING ana_tipo_pernottamento p
 WHERE p.ana_tipo_pernottamento_id = pg.pernottamento_fk
   AND p.ana_tipo_pernottamento_di_sistema;

UPDATE ana_tipo_pernottamento
   SET ana_tipo_pernottamento_con_albergo = 'N'
 WHERE ana_tipo_pernottamento_di_sistema;


-- ---------------------------------------------------------------------------
-- 2. La scrittura: rifiuta, e non tocca le righe di sistema
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[], BOOLEAN);

CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_set(
    p_pernottamento_id INTEGER,
    p_generi           INTEGER[]
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_quanti    INTEGER;
    v_rotte     INTEGER;
    v_viaggi    TEXT;
    v_sistema   BOOLEAN;
    v_desc      VARCHAR;
BEGIN
    SELECT ana_tipo_pernottamento_di_sistema, ana_tipo_pernottamento_descrizione
      INTO v_sistema, v_desc
    FROM ana_tipo_pernottamento WHERE ana_tipo_pernottamento_id = p_pernottamento_id;

    IF COALESCE(v_sistema, FALSE) THEN
        IF array_length(COALESCE(p_generi, ARRAY[]::INTEGER[]), 1) IS NULL THEN
            RETURN 0;   -- nessun genere su una riga di sistema: e' gia' cosi', niente da fare
        END IF;
        RAISE EXCEPTION
            '«%» è una configurazione di sistema: significa che il viaggio non prevede pernottamento, quindi non può ammettere sistemazioni.',
            v_desc USING ERRCODE = 'check_violation';
    END IF;

    -- Le assegnazioni oggi valide che smetterebbero di esserlo. Non si chiede: si
    -- rifiuta, dicendo quante sono e cosa fare prima.
    SELECT count(*),
           string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
      INTO v_rotte, v_viaggi
    FROM mov_clienti_alloggi a
    JOIN ana_viaggi v          ON v.viaggio_id = a.viaggio_id_fk
    JOIN ana_tipo_alloggio t   ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE v.viaggio_tipo_pernottamento_fk = p_pernottamento_id
      AND g.genere_codice <> 'NESSUNA'
      AND EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                  WHERE pg.pernottamento_fk = p_pernottamento_id AND pg.genere_fk = t.genere_fk)
      AND NOT (t.genere_fk = ANY (COALESCE(p_generi, ARRAY[]::INTEGER[])));

    IF COALESCE(v_rotte, 0) > 0 THEN
        RAISE EXCEPTION
            'Non si può: % assegnazioni oggi valide non lo sarebbero più, su: %. Vanno cambiate prima quelle assegnazioni.',
            v_rotte, left(v_viaggi, 200)
            USING ERRCODE = 'check_violation';
    END IF;

    DELETE FROM ana_tipo_pernottamento_generi WHERE pernottamento_fk = p_pernottamento_id;

    INSERT INTO ana_tipo_pernottamento_generi (pernottamento_fk, genere_fk)
    SELECT p_pernottamento_id, x FROM unnest(COALESCE(p_generi, ARRAY[]::INTEGER[])) x
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_quanti = ROW_COUNT;

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

COMMENT ON FUNCTION fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[]) IS
'Imposta i generi ammessi da un pernottamento. ⛔️ **Rifiuta** — non chiede — se il cambio
renderebbe non valide assegnazioni oggi valide: un clic non deve poter rompere la storia.
⚠️ Le righe di sistema («NESSUNO») non ammettono generi e non si configurano.';


-- ---------------------------------------------------------------------------
-- 3. La lettura: dice anche se la riga e' di sistema
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ana_tipo_pernottamento_generi_get(INTEGER);

CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_get(p_pernottamento_id INTEGER)
RETURNS TABLE(genere_id INTEGER, codice VARCHAR, descrizione VARCHAR, ammesso BOOLEAN, di_sistema BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT g.genere_id, g.genere_codice, g.genere_descrizione,
           EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                   WHERE pg.pernottamento_fk = p_pernottamento_id AND pg.genere_fk = g.genere_id),
           COALESCE((SELECT p.ana_tipo_pernottamento_di_sistema FROM ana_tipo_pernottamento p
                     WHERE p.ana_tipo_pernottamento_id = p_pernottamento_id), FALSE)
    FROM ana_alloggio_generi g
    WHERE g.genere_attivo AND g.genere_codice <> 'NESSUNA'
    ORDER BY g.genere_ordine, g.genere_descrizione;
$$;


-- ---------------------------------------------------------------------------
-- 4. Il divieto vero: una riga di sistema non si rinomina e non si cancella
-- ---------------------------------------------------------------------------
-- ⚠️ Nasconderne i pulsanti nella scheda non e' un controllo: e' un suggerimento.
-- Il sito, un import, un altro operatore o una query non passano da quella scheda.
-- La regola sta qui, dove nessuno la puo' aggirare.
CREATE OR REPLACE FUNCTION trg_pernottamento_di_sistema()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.ana_tipo_pernottamento_di_sistema THEN
            RAISE EXCEPTION
                '«%» è una configurazione di sistema e non si può cancellare: è il valore che indica «il viaggio non prevede pernottamento».',
                OLD.ana_tipo_pernottamento_descrizione USING ERRCODE = 'check_violation';
        END IF;
        RETURN OLD;
    END IF;

    IF OLD.ana_tipo_pernottamento_di_sistema
       AND NEW.ana_tipo_pernottamento_descrizione IS DISTINCT FROM OLD.ana_tipo_pernottamento_descrizione THEN
        RAISE EXCEPTION
            '«%» è una configurazione di sistema e non si può rinominare.',
            OLD.ana_tipo_pernottamento_descrizione USING ERRCODE = 'check_violation';
    END IF;

    -- Nessuno puo' promuovere o declassare una riga a «di sistema» dai dati.
    IF NEW.ana_tipo_pernottamento_di_sistema IS DISTINCT FROM OLD.ana_tipo_pernottamento_di_sistema THEN
        RAISE EXCEPTION 'Non si può cambiare la natura di sistema di una tipologia di pernottamento.'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pernottamento_di_sistema ON ana_tipo_pernottamento;
CREATE TRIGGER trg_pernottamento_di_sistema
    BEFORE UPDATE OR DELETE ON ana_tipo_pernottamento
    FOR EACH ROW EXECUTE FUNCTION trg_pernottamento_di_sistema();
