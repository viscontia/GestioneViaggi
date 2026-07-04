-- Funzioni CRUD per web_newsletter_iscritti (Blocco 2 estensione web).
-- Iscritti alla newsletter con doppio opt-in / disiscrizione via token.
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione (tranne _by_token, vedi sotto) prende p_azienda_id INTEGER ed e' scoped su di esso;
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation (uq_web_newsletter_iscritti_email) propaga.
-- SPECIALE:
--   * token_disiscrizione e' NOT NULL e NON e' un parametro: l'insert lo GENERA internamente con
--     encode(gen_random_bytes(24),'hex') (48 char hex, estensione pgcrypto). E' immutabile: la update NON lo tocca.

-- INSERT -> ritorna il nuovo id. token_disiscrizione generato internamente.
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_insert(
    p_azienda_id INTEGER,
    p_email CITEXT,
    p_nome VARCHAR DEFAULT NULL,
    p_cognome VARCHAR DEFAULT NULL,
    p_lingua VARCHAR DEFAULT 'IT',
    p_consenso BOOLEAN DEFAULT true,
    p_consenso_data TIMESTAMPTZ DEFAULT NULL,
    p_consenso_fonte VARCHAR DEFAULT NULL,
    p_stato VARCHAR DEFAULT 'attivo',
    p_cliente_fk INTEGER DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_iscritti(
        email, nome, cognome, lingua, consenso, consenso_data, consenso_fonte, stato,
        token_disiscrizione, cliente_fk, azienda_id)
    VALUES (
        p_email, p_nome, p_cognome, p_lingua, p_consenso, p_consenso_data, p_consenso_fonte, p_stato,
        encode(gen_random_bytes(24), 'hex'), p_cliente_fk, p_azienda_id)
    RETURNING web_newsletter_iscritti_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_list(p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_iscritti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_iscritti WHERE azienda_id = p_azienda_id ORDER BY email;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_iscritti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_iscritti WHERE web_newsletter_iscritti_id = p_id AND azienda_id = p_azienda_id;
$$;

-- GET per token di disiscrizione (flusso pubblico unsubscribe).
-- NON e' azienda-scoped: il link pubblico di disiscrizione ha solo il token, che e' un segreto
-- casuale a 48 caratteri hex (di fatto identificatore globale). Accettabile per questo caso d'uso.
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_by_token(p_token VARCHAR)
RETURNS SETOF web_newsletter_iscritti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_iscritti WHERE token_disiscrizione = p_token;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1). NON tocca token_disiscrizione (immutabile).
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_email CITEXT,
    p_nome VARCHAR,
    p_cognome VARCHAR,
    p_lingua VARCHAR,
    p_consenso BOOLEAN,
    p_consenso_data TIMESTAMPTZ,
    p_consenso_fonte VARCHAR,
    p_stato VARCHAR,
    p_cliente_fk INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_iscritti
       SET email=p_email, nome=p_nome, cognome=p_cognome, lingua=p_lingua, consenso=p_consenso,
           consenso_data=p_consenso_data, consenso_fonte=p_consenso_fonte, stato=p_stato, cliente_fk=p_cliente_fk
     WHERE web_newsletter_iscritti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_newsletter_iscritti_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_newsletter_iscritti WHERE web_newsletter_iscritti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
