-- Funzioni CRUD per web_newsletter_invii (Blocco 2 estensione web).
-- Campagne/invii di newsletter (testata: oggetto, corpo, stato, canale).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_insert(
    p_azienda_id INTEGER,
    p_oggetto VARCHAR,
    p_corpo_html TEXT,
    p_stato VARCHAR DEFAULT 'bozza',
    p_data_invio TIMESTAMPTZ DEFAULT NULL,
    p_numero_destinatari INTEGER DEFAULT NULL,
    p_canale VARCHAR DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_invii(oggetto, corpo_html, stato, data_invio, numero_destinatari, canale, azienda_id)
    VALUES (p_oggetto, p_corpo_html, p_stato, p_data_invio, p_numero_destinatari, p_canale, p_azienda_id)
    RETURNING web_newsletter_invii_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda (piu' recenti prima)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_list(p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_invii LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_invii WHERE azienda_id = p_azienda_id ORDER BY created DESC;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_invii LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_invii WHERE web_newsletter_invii_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_oggetto VARCHAR,
    p_corpo_html TEXT,
    p_stato VARCHAR,
    p_data_invio TIMESTAMPTZ,
    p_numero_destinatari INTEGER,
    p_canale VARCHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_invii
       SET oggetto=p_oggetto, corpo_html=p_corpo_html, stato=p_stato, data_invio=p_data_invio,
           numero_destinatari=p_numero_destinatari, canale=p_canale
     WHERE web_newsletter_invii_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_newsletter_invii WHERE web_newsletter_invii_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
