-- =============================================================================
-- 607 — Scoprire assegnazioni si può, ma dichiarandolo
-- =============================================================================
--
-- Difetto trovato in collaudo il 2026-09-06, prova C7. La guardia dello script 605
-- rifiutava di togliere i generi ammessi da un pernottamento quando cio' lasciava
-- scoperte assegnazioni gia' registrate. Corretto in linea di principio, ma:
--
--   1. l'operatore spunta un genere su «NESSUNO» → le 17 assegnazioni storiche di
--      quel pernottamento (righe vecchie dell'azienda 6) diventano coerenti;
--   2. l'operatore toglie la spunta per tornare com'era → **rifiutato**.
--
-- ⚠️ Una porta a senso unico: si puo' entrare in uno stato ma non tornare indietro,
-- nemmeno subito, nemmeno per annullare la propria modifica. Non e' protezione,
-- e' una trappola — e nasce dal fatto che quei dati erano gia' sporchi PRIMA.
--
-- La correzione non e' togliere il controllo: e' renderlo **dichiarabile**. E' lo
-- stesso schema gia' usato per l'anagrafica clienti (`fn_ana_clienti_guardia` con
-- `p_conferme_accettate`): il rifiuto diventa una domanda, e chi sa cosa sta
-- facendo risponde. Cio' che conta e' che non succeda **di nascosto**.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_set(
    p_pernottamento_id INTEGER,
    p_generi           INTEGER[],
    p_conferma         BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_quanti  INTEGER;
    v_rotte   INTEGER;
    v_viaggi  TEXT;
BEGIN
    SELECT count(*),
           string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
      INTO v_rotte, v_viaggi
    FROM mov_clienti_alloggi a
    JOIN ana_viaggi v          ON v.viaggio_id = a.viaggio_id_fk
    JOIN ana_tipo_alloggio t   ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE v.viaggio_tipo_pernottamento_fk = p_pernottamento_id
      AND g.genere_codice <> 'NESSUNA'
      AND NOT (t.genere_fk = ANY (COALESCE(p_generi, ARRAY[]::INTEGER[])));

    -- Si segnala, e si procede solo se l'operatore lo ha dichiarato.
    IF COALESCE(v_rotte, 0) > 0 AND NOT COALESCE(p_conferma, FALSE) THEN
        RAISE EXCEPTION
            'Con queste sistemazioni % assegnazioni già registrate resterebbero scoperte, su: %.',
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

-- La firma vecchia a due parametri non deve restare: chi la chiamasse otterrebbe il
-- comportamento senza conferma senza saperlo.
DROP FUNCTION IF EXISTS fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[]);

COMMENT ON FUNCTION fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[], BOOLEAN) IS
'Imposta i generi ammessi da un pernottamento. ⚠️ Se la scelta lascia scoperte assegnazioni
gia'' registrate lo dice e si ferma; con `p_conferma` procede. Il punto non e'' impedirlo —
a volte i dati sono gia'' sporchi e bisogna poter tornare indietro — ma che non succeda di
nascosto.';
