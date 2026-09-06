-- =============================================================================
-- 608 — La domanda arriva solo se il cambio PEGGIORA le cose
-- =============================================================================
--
-- Segnalato in collaudo il 2026-09-06, prova C9: «non è rifiutato come dovrebbe,
-- ma mi propone di farlo».
--
-- Lo script 607 aveva trasformato il rifiuto in una domanda per uscire dalla porta
-- a senso unico della prova C7. ⚠️ Ma cosi' la domanda arriva **sempre allo stesso
-- modo**, e i due casi non sono affatto uguali:
--
--   C7 — si toglie un genere da «NESSUNO»: le 17 assegnazioni che restano scoperte
--        **erano gia' incoerenti prima**. Non si rompe niente, si torna com'era.
--        Chiedere e' rumore, e per giunta confonde.
--
--   C9 — si toglie ALBERGO dal pernottamento «ALBERGO»: le 414 assegnazioni che
--        restano scoperte sono **valide adesso**. Qui si rompe davvero.
--
-- La funzione non distingueva: contava tutto cio' che sarebbe restato scoperto,
-- compreso cio' che era gia' scoperto in partenza. Un controllo che grida anche
-- quando non succede niente insegna a rispondere «procedi» senza leggere — e il
-- giorno in cui il numero conta davvero, nessuno lo guarda.
--
-- Ora si confronta con lo stato ATTUALE: si chiede solo per le assegnazioni che
-- **oggi sono coerenti e smetterebbero di esserlo**.
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
      -- Oggi e' coerente…
      AND EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                  WHERE pg.pernottamento_fk = p_pernottamento_id
                    AND pg.genere_fk = t.genere_fk)
      -- …e con la scelta nuova non lo sarebbe piu'.
      AND NOT (t.genere_fk = ANY (COALESCE(p_generi, ARRAY[]::INTEGER[])));

    IF COALESCE(v_rotte, 0) > 0 AND NOT COALESCE(p_conferma, FALSE) THEN
        RAISE EXCEPTION
            'Con queste sistemazioni % assegnazioni oggi valide non lo sarebbero più, su: %.',
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

COMMENT ON FUNCTION fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[], BOOLEAN) IS
'Imposta i generi ammessi da un pernottamento. ⚠️ Chiede conferma solo se il cambio
PEGGIORA: assegnazioni oggi valide che smetterebbero di esserlo. Cio'' che era gia''
incoerente non fa scattare la domanda — un controllo che grida quando non succede niente
insegna a rispondere senza leggere.';


-- ---------------------------------------------------------------------------
-- Stessa correzione dove vale lo stesso ragionamento
-- ---------------------------------------------------------------------------
-- Il cambio di genere di un TIPO (script 604) aveva lo stesso difetto: contava
-- anche le assegnazioni gia' incoerenti.
CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_upsert(
    p_id INTEGER, p_descrizione VARCHAR, p_numero_occupanti INTEGER,
    p_supplemento VARCHAR, p_genere_fk INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_id           INTEGER;
    v_genere_prima INTEGER;
    v_quante       INTEGER;
    v_viaggi       TEXT;
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

    IF v_genere_prima IS DISTINCT FROM p_genere_fk THEN
        SELECT count(*),
               string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
          INTO v_quante, v_viaggi
        FROM mov_clienti_alloggi a
        JOIN ana_viaggi v ON v.viaggio_id = a.viaggio_id_fk
        WHERE a.tipo_alloggio_id_fk = p_id
          -- Oggi valida…
          AND EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                      WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                        AND pg.genere_fk = v_genere_prima)
          -- …e col genere nuovo non piu'.
          AND NOT EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                          WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                            AND pg.genere_fk = p_genere_fk);

        IF COALESCE(v_quante, 0) > 0 THEN
            RAISE EXCEPTION
                'Con questo genere % assegnazioni oggi valide non lo sarebbero più, su: %. Cambia prima le sistemazioni previste da quei viaggi, oppure lascia il genere com''è.',
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
