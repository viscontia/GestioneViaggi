-- Funzioni CRUD per web_categorie_sport (template Blocco 2 dell'estensione web).
-- Convenzione condivisa da tutte le entita web:
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (isolamento multi-tenant);
--   * SECURITY INVOKER (default), niente SECURITY DEFINER;
--   * le colonne di audit (created/created_by/updated/updated_by) NON sono mai passate:
--     le valorizza il trigger trg_web_audit() dalla GUC my.app_user;
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_insert(
    p_azienda_id INTEGER, p_codice VARCHAR, p_etichetta VARCHAR, p_slug VARCHAR, p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_categorie_sport(codice, etichetta, slug, ordine, azienda_id)
    VALUES (p_codice, p_etichetta, p_slug, p_ordine, p_azienda_id)
    RETURNING web_categorie_sport_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_list(p_azienda_id INTEGER)
RETURNS SETOF web_categorie_sport LANGUAGE sql STABLE AS $$
    SELECT * FROM web_categorie_sport WHERE azienda_id = p_azienda_id ORDER BY ordine, etichetta;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_categorie_sport LANGUAGE sql STABLE AS $$
    SELECT * FROM web_categorie_sport WHERE web_categorie_sport_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_update(
    p_id BIGINT, p_azienda_id INTEGER, p_codice VARCHAR, p_etichetta VARCHAR, p_slug VARCHAR, p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_categorie_sport
       SET codice=p_codice, etichetta=p_etichetta, slug=p_slug, ordine=p_ordine
     WHERE web_categorie_sport_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_categorie_sport WHERE web_categorie_sport_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
