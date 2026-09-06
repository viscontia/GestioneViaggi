-- =============================================================================
-- 606 — La guardia sui generi guarda TUTTI i riferimenti, non solo uno
-- =============================================================================
--
-- Osservazione dell'utente il 2026-09-06: «questi controlli di integrità
-- referenziale devono essere nel tuo DNA». Ha ragione, e verificando cosa avevo
-- lasciato scoperto e' saltato fuori subito.
--
-- `fn_ana_alloggio_generi_delete` contava solo i **tipi di sistemazione** che usano
-- il genere. Ma un genere e' riferito da DUE parti:
--
--     ana_tipo_alloggio.genere_fk              ← contato
--     ana_tipo_pernottamento_generi.genere_fk  ← ⚠️ non contato
--
-- ✅ Il dato non era in pericolo: la chiave esterna blocca comunque. ⚠️ Ma il
-- messaggio che arrivava all'operatore era quello grezzo di PostgreSQL —
-- «violates foreign key constraint ana_tipo_pernottamento_generi_genere_fk_fkey» —
-- che non dice cosa fare e non si puo' mostrare a nessuno.
--
-- Una guardia che protegge il dato ma non spiega il rifiuto ha fatto meta' lavoro:
-- l'operatore resta bloccato senza sapere dove guardare.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_alloggio_generi_delete(p_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_desc   VARCHAR;
    v_tipi   INTEGER;
    v_pern   INTEGER;
    v_elenco TEXT;
    v_motivi TEXT[] := ARRAY[]::TEXT[];
BEGIN
    SELECT genere_descrizione INTO v_desc FROM ana_alloggio_generi WHERE genere_id = p_id;
    IF v_desc IS NULL THEN
        RETURN 0;   -- gia' cancellato: non e' un errore
    END IF;

    SELECT count(*) INTO v_tipi FROM ana_tipo_alloggio WHERE genere_fk = p_id;
    IF v_tipi > 0 THEN
        v_motivi := array_append(v_motivi, v_tipi || ' tipi di sistemazione');
    END IF;

    SELECT count(*), string_agg(p.ana_tipo_pernottamento_descrizione, ', '
                                ORDER BY p.ana_tipo_pernottamento_descrizione)
      INTO v_pern, v_elenco
    FROM ana_tipo_pernottamento_generi pg
    JOIN ana_tipo_pernottamento p ON p.ana_tipo_pernottamento_id = pg.pernottamento_fk
    WHERE pg.genere_fk = p_id;
    IF COALESCE(v_pern, 0) > 0 THEN
        v_motivi := array_append(v_motivi,
            v_pern || ' tipi di pernottamento che lo ammettono (' || v_elenco || ')');
    END IF;

    IF array_length(v_motivi, 1) > 0 THEN
        -- ⚠️ I motivi si uniscono con « e », non con una virgola sostituita a
        -- posteriori: uno dei due contiene gia' un elenco fra parentesi, e la
        -- sostituzione dell'ultima virgola finiva li' dentro invece che fra i motivi.
        RAISE EXCEPTION 'Impossibile eliminare «%»: è usato da %.',
              v_desc, array_to_string(v_motivi, ' e ')
              USING ERRCODE = 'check_violation';
    END IF;

    DELETE FROM ana_alloggio_generi WHERE genere_id = p_id;
    RETURN 1;
END;
$$;

COMMENT ON FUNCTION fn_ana_alloggio_generi_delete(INTEGER) IS
'Elimina un genere solo se nessuno lo riferisce — ne'' i tipi di sistemazione ne'' i tipi di
pernottamento che lo ammettono. Il messaggio dice CHI lo usa: un rifiuto senza il motivo
lascia l''operatore bloccato senza sapere dove guardare.';
