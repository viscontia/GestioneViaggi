-- Funzioni CRUD per web_newsletter_soppressioni (Blocco 2 estensione web).
-- Blacklist/soppressioni email (bounce, reclami, opt-out globale) per azienda.
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation (uq_web_newsletter_soppressioni_email) propaga.

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_newsletter_soppressioni_insert(
    p_azienda_id INTEGER,
    p_email CITEXT,
    p_motivo VARCHAR,
    p_data TIMESTAMPTZ DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_soppressioni(email, motivo, data, azienda_id)
    VALUES (p_email, p_motivo, COALESCE(p_data, now()), p_azienda_id)
    RETURNING web_newsletter_soppressioni_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_newsletter_soppressioni_list(p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_soppressioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_soppressioni WHERE azienda_id = p_azienda_id ORDER BY email;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_newsletter_soppressioni_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_soppressioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_soppressioni WHERE web_newsletter_soppressioni_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_soppressioni_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_email CITEXT,
    p_motivo VARCHAR,
    p_data TIMESTAMPTZ)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_soppressioni
       SET email=p_email, motivo=p_motivo, data=p_data
     WHERE web_newsletter_soppressioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_soppressioni_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_newsletter_soppressioni WHERE web_newsletter_soppressioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
