-- =============================================================================
-- 601 — Le letture e le scritture di generi, tipi di alloggio e associazioni
-- =============================================================================
--
-- Servono al gestionale per le pagine nuove. ⚠️ `TipoAlloggioService.cs` aveva la
-- SQL scritta dentro il C# — contro la regola del progetto («tutta la SQL vive in
-- funzioni PostgreSQL») — e aggiungendo il genere quella query andava comunque
-- toccata: si coglie l'occasione per portarla dove sta il resto.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- I generi
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_alloggio_generi_get_all(p_solo_attivi BOOLEAN DEFAULT FALSE)
RETURNS TABLE(genere_id INTEGER, codice VARCHAR, descrizione VARCHAR, ordine SMALLINT, attivo BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT g.genere_id, g.genere_codice, g.genere_descrizione, g.genere_ordine, g.genere_attivo
    FROM ana_alloggio_generi g
    WHERE NOT p_solo_attivi OR g.genere_attivo
    ORDER BY g.genere_ordine, g.genere_descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_ana_alloggio_generi_upsert(
    p_id INTEGER, p_codice VARCHAR, p_descrizione VARCHAR,
    p_ordine SMALLINT, p_attivo BOOLEAN
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER;
BEGIN
    IF btrim(COALESCE(p_codice,'')) = '' THEN
        RAISE EXCEPTION 'Il codice del genere è obbligatorio: è con quello che il programma lo riconosce.';
    END IF;

    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_alloggio_generi (genere_codice, genere_descrizione, genere_ordine, genere_attivo)
        VALUES (upper(btrim(p_codice)), p_descrizione, COALESCE(p_ordine, 99), COALESCE(p_attivo, TRUE))
        RETURNING genere_id INTO v_id;
    ELSE
        UPDATE ana_alloggio_generi
           SET genere_codice = upper(btrim(p_codice)), genere_descrizione = p_descrizione,
               genere_ordine = COALESCE(p_ordine, 99), genere_attivo = COALESCE(p_attivo, TRUE)
         WHERE genere_id = p_id
        RETURNING genere_id INTO v_id;
    END IF;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_alloggio_generi_delete(p_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_tipi INTEGER; v_desc VARCHAR;
BEGIN
    SELECT count(*) INTO v_tipi FROM ana_tipo_alloggio WHERE genere_fk = p_id;
    IF v_tipi > 0 THEN
        SELECT genere_descrizione INTO v_desc FROM ana_alloggio_generi WHERE genere_id = p_id;
        RAISE EXCEPTION 'Impossibile eliminare «%»: è il genere di % tipi di sistemazione.',
                        COALESCE(v_desc, p_id::TEXT), v_tipi;
    END IF;
    DELETE FROM ana_alloggio_generi WHERE genere_id = p_id;
    RETURN 1;
END;
$$;

COMMENT ON FUNCTION fn_ana_alloggio_generi_delete(INTEGER) IS
'Elimina un genere solo se nessun tipo di sistemazione lo usa. Il messaggio dice quanti sono:
«impossibile eliminare» senza il numero costringerebbe a cercarli a mano.';


-- ---------------------------------------------------------------------------
-- I tipi di alloggio, ora col genere
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_get_all()
RETURNS TABLE(
    tipo_alloggio_id INTEGER, tipo_alloggio_descrizione VARCHAR,
    tipo_alloggio_numero_occupanti INTEGER, tipo_alloggio_supplemento VARCHAR,
    genere_fk INTEGER, genere_descrizione VARCHAR, genere_codice VARCHAR
)
LANGUAGE sql STABLE AS $$
    SELECT t.tipo_alloggio_id, t.tipo_alloggio_descrizione, t.tipo_alloggio_numero_occupanti,
           t.tipo_alloggio_supplemento, t.genere_fk, g.genere_descrizione, g.genere_codice
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    ORDER BY g.genere_ordine, t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_upsert(
    p_id INTEGER, p_descrizione VARCHAR, p_numero_occupanti INTEGER,
    p_supplemento VARCHAR, p_genere_fk INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER;
BEGIN
    IF COALESCE(p_genere_fk, 0) = 0 THEN
        RAISE EXCEPTION 'Il genere è obbligatorio: senza, non si può sapere su quali viaggi questa sistemazione è ammessa.';
    END IF;

    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_tipo_alloggio
            (tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento, genere_fk)
        VALUES (p_descrizione, p_numero_occupanti, COALESCE(p_supplemento,'N'), p_genere_fk)
        RETURNING tipo_alloggio_id INTO v_id;
    ELSE
        UPDATE ana_tipo_alloggio
           SET tipo_alloggio_descrizione = p_descrizione,
               tipo_alloggio_numero_occupanti = p_numero_occupanti,
               tipo_alloggio_supplemento = COALESCE(p_supplemento,'N'),
               genere_fk = p_genere_fk
         WHERE tipo_alloggio_id = p_id
        RETURNING tipo_alloggio_id INTO v_id;
    END IF;
    RETURN v_id;
END;
$$;


-- ---------------------------------------------------------------------------
-- I generi ammessi da un pernottamento
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_get(p_pernottamento_id INTEGER)
RETURNS TABLE(genere_id INTEGER, codice VARCHAR, descrizione VARCHAR, ammesso BOOLEAN)
LANGUAGE sql STABLE AS $$
    -- Tutti i generi, con la spunta su quelli ammessi: la scheda mostra le scelte
    -- possibili, non solo quelle gia' fatte.
    SELECT g.genere_id, g.genere_codice, g.genere_descrizione,
           EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                   WHERE pg.pernottamento_fk = p_pernottamento_id AND pg.genere_fk = g.genere_id)
    FROM ana_alloggio_generi g
    WHERE g.genere_attivo
      -- NESSUNA non si configura: vale sempre, su qualunque viaggio.
      AND g.genere_codice <> 'NESSUNA'
    ORDER BY g.genere_ordine, g.genere_descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_ana_tipo_pernottamento_generi_set(
    p_pernottamento_id INTEGER, p_generi INTEGER[]
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_quanti INTEGER;
BEGIN
    DELETE FROM ana_tipo_pernottamento_generi WHERE pernottamento_fk = p_pernottamento_id;

    INSERT INTO ana_tipo_pernottamento_generi (pernottamento_fk, genere_fk)
    SELECT p_pernottamento_id, x FROM unnest(COALESCE(p_generi, ARRAY[]::INTEGER[])) x
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_quanti = ROW_COUNT;
    RETURN v_quanti;
END;
$$;

COMMENT ON FUNCTION fn_ana_tipo_pernottamento_generi_set(INTEGER, INTEGER[]) IS
'Imposta i generi ammessi da un pernottamento, sostituendo quelli precedenti. Un elenco
vuoto e'' legittimo: e'' il pernottamento «NESSUNO», dove non c''e'' niente da comporre.';
