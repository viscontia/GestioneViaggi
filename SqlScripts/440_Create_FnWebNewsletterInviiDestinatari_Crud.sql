-- Funzioni CRUD per web_newsletter_invii_destinatari (Blocco 2 estensione web).
-- Righe destinatario di un invio newsletter (1 invio : N destinatari).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1).
-- La list e' per invio (fn_web_newsletter_invii_destinatari_list(p_invio_id, p_azienda_id)).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_destinatari_insert(
    p_azienda_id INTEGER,
    p_invio_id_fk BIGINT,
    p_email CITEXT,
    p_lingua VARCHAR DEFAULT NULL,
    p_stato_consegna VARCHAR DEFAULT NULL,
    p_data TIMESTAMPTZ DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_invii_destinatari(invio_id_fk, email, lingua, stato_consegna, data, azienda_id)
    VALUES (p_invio_id_fk, p_email, p_lingua, p_stato_consegna, p_data, p_azienda_id)
    RETURNING web_newsletter_invii_destinatari_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per invio (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_destinatari_list(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_invii_destinatari LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_invii_destinatari
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY email;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_destinatari_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_invii_destinatari LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_invii_destinatari
     WHERE web_newsletter_invii_destinatari_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_destinatari_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_invio_id_fk BIGINT,
    p_email CITEXT,
    p_lingua VARCHAR,
    p_stato_consegna VARCHAR,
    p_data TIMESTAMPTZ)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_invii_destinatari
       SET invio_id_fk=p_invio_id_fk, email=p_email, lingua=p_lingua, stato_consegna=p_stato_consegna, data=p_data
     WHERE web_newsletter_invii_destinatari_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_invii_destinatari_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_newsletter_invii_destinatari
     WHERE web_newsletter_invii_destinatari_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
