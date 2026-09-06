-- =============================================================================
-- 604 — Il genere di un tipo non si cambia se invalida le assegnazioni fatte
-- =============================================================================
--
-- Domanda emersa in collaudo il 2026-09-06: «si può modificare il genere anche se
-- ci sono abbinamenti già fatti di clienti che hanno usato questa combinazione?»
--
-- ⚠️ Oggi sì, e non dovrebbe. Misurato: cambiando il genere di CAMERA MATRIMONIALE
-- da ALBERGO a TENDA, **219 assegnazioni esistenti** diventerebbero di colpo
-- incoerenti — tutte su viaggi che le tende non le prevedono. Nessun errore, nessun
-- avviso: il trigger `trg_alloggio_coerente` guarda gli inserimenti e le modifiche
-- delle assegnazioni, non i tipi. Le righe storiche resterebbero lì, sbagliate, e
-- si scoprirebbero una alla volta il giorno in cui qualcuno le tocca.
--
-- -----------------------------------------------------------------------------
-- LA REGOLA: non «se è usato», ma «se lo rende incoerente»
-- -----------------------------------------------------------------------------
-- Vietare il cambio a ogni tipo gia' usato sarebbe piu' semplice e sbagliato:
-- impedirebbe di **correggere una classificazione errata**, che e' proprio il caso
-- in cui serve. Se qualcuno ha messo una tenda fra le camere d'albergo, quel
-- genere va potuto sistemare.
--
-- Si guarda quindi l'effetto: il genere nuovo e' ammesso da TUTTI i viaggi su cui
-- quel tipo e' gia' assegnato? Se si', il cambio e' innocuo. Se no, si rifiuta
-- dicendo **quante** assegnazioni e su **quali viaggi** — perche' «non si puo'»
-- senza il perche' costringe a cercare a mano.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_upsert(
    p_id INTEGER, p_descrizione VARCHAR, p_numero_occupanti INTEGER,
    p_supplemento VARCHAR, p_genere_fk INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_id            INTEGER;
    v_genere_prima  INTEGER;
    v_quante        INTEGER;
    v_viaggi        TEXT;
BEGIN
    IF COALESCE(p_genere_fk, 0) = 0 THEN
        RAISE EXCEPTION 'Il genere è obbligatorio: senza, non si può sapere su quali viaggi questa sistemazione è ammessa.';
    END IF;

    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_tipo_alloggio
            (tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento, genere_fk)
        VALUES (upper(btrim(p_descrizione)), p_numero_occupanti, COALESCE(p_supplemento,'N'), p_genere_fk)
        RETURNING tipo_alloggio_id INTO v_id;
        RETURN v_id;
    END IF;

    SELECT genere_fk INTO v_genere_prima FROM ana_tipo_alloggio WHERE tipo_alloggio_id = p_id;

    -- Il genere cambia: si guarda che cosa succederebbe alle assegnazioni esistenti.
    IF v_genere_prima IS DISTINCT FROM p_genere_fk THEN
        SELECT count(*),
               string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
          INTO v_quante, v_viaggi
        FROM mov_clienti_alloggi a
        JOIN ana_viaggi v ON v.viaggio_id = a.viaggio_id_fk
        WHERE a.tipo_alloggio_id_fk = p_id
          AND NOT EXISTS (
              SELECT 1 FROM ana_tipo_pernottamento_generi pg
              WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                AND pg.genere_fk = p_genere_fk);

        IF COALESCE(v_quante, 0) > 0 THEN
            RAISE EXCEPTION
                'Con questo genere % assegnazioni già registrate diventerebbero incoerenti, su: %. Cambia prima le sistemazioni previste da quei viaggi, oppure lascia il genere com''è.',
                v_quante, left(v_viaggi, 200)
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    UPDATE ana_tipo_alloggio
       SET tipo_alloggio_descrizione = upper(btrim(p_descrizione)),
           tipo_alloggio_numero_occupanti = p_numero_occupanti,
           tipo_alloggio_supplemento = COALESCE(p_supplemento,'N'),
           genere_fk = p_genere_fk
     WHERE tipo_alloggio_id = p_id
    RETURNING tipo_alloggio_id INTO v_id;
    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_ana_tipo_alloggio_upsert(INTEGER, VARCHAR, INTEGER, VARCHAR, INTEGER) IS
'Salva un tipo di sistemazione. ⚠️ Rifiuta il cambio di genere che renderebbe incoerenti
assegnazioni gia'' registrate, dicendo quante e su quali viaggi. Non vieta il cambio su un
tipo «usato» — quello impedirebbe di correggere una classificazione sbagliata, che e''
proprio il caso in cui serve.';
