-- Funzioni CRUD per web_aziende_funzioni (Blocco 2 estensione web - Task 2.2).
-- Convenzione template 431 (web_categorie_sport):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (isolamento multi-tenant);
--   * SECURITY INVOKER (default), niente SECURITY DEFINER;
--   * le colonne di audit (created/created_by/updated/updated_by) NON sono mai passate:
--     le valorizza il trigger trg_web_audit() dalla GUC my.app_user;
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_insert(
    p_azienda_id INTEGER, p_funzione VARCHAR, p_attiva BOOLEAN DEFAULT false, p_parametri JSONB DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_aziende_funzioni(funzione, attiva, parametri, azienda_id)
    VALUES (p_funzione, p_attiva, p_parametri, p_azienda_id)
    RETURNING web_aziende_funzioni_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_list(p_azienda_id INTEGER)
RETURNS SETOF web_aziende_funzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_aziende_funzioni WHERE azienda_id = p_azienda_id ORDER BY funzione;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_aziende_funzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_aziende_funzioni WHERE web_aziende_funzioni_id = p_id AND azienda_id = p_azienda_id;
$$;

-- GET per chiave logica (azienda, funzione) -- lookup tipico del toggle di configurazione
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_get_by_funzione(p_azienda_id INTEGER, p_funzione VARCHAR)
RETURNS SETOF web_aziende_funzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_aziende_funzioni WHERE azienda_id = p_azienda_id AND funzione = p_funzione;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_update(
    p_id BIGINT, p_azienda_id INTEGER, p_funzione VARCHAR, p_attiva BOOLEAN, p_parametri JSONB)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_aziende_funzioni
       SET funzione=p_funzione, attiva=p_attiva, parametri=p_parametri
     WHERE web_aziende_funzioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_aziende_funzioni_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_aziende_funzioni WHERE web_aziende_funzioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
