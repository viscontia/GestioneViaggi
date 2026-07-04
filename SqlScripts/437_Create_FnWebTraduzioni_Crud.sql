-- Funzioni CRUD per web_traduzioni (Blocco 2 estensione web).
-- Traduzioni multilingua di campi di altre entita (entita + entita_id + campo + lingua).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation (uq_web_traduzioni) propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_traduzioni_insert(
    p_azienda_id INTEGER,
    p_entita VARCHAR,
    p_entita_id BIGINT,
    p_campo VARCHAR,
    p_lingua VARCHAR,
    p_testo TEXT,
    p_tradotto_auto BOOLEAN DEFAULT true,
    p_revisionato BOOLEAN DEFAULT false,
    p_obsoleto BOOLEAN DEFAULT false,
    p_data_traduzione TIMESTAMPTZ DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_traduzioni(
        entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    VALUES (
        p_entita, p_entita_id, p_campo, p_lingua, p_testo, p_tradotto_auto, p_revisionato, p_obsoleto, p_data_traduzione, p_azienda_id)
    RETURNING web_traduzioni_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_traduzioni_list(p_azienda_id INTEGER)
RETURNS SETOF web_traduzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_traduzioni WHERE azienda_id = p_azienda_id ORDER BY entita, entita_id, campo, lingua;
$$;

-- LIST per record sorgente: tutte le lingue/campi di una entita+entita_id
CREATE OR REPLACE FUNCTION fn_web_traduzioni_list_by_entita(p_entita VARCHAR, p_entita_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_traduzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_traduzioni
     WHERE entita = p_entita AND entita_id = p_entita_id AND azienda_id = p_azienda_id
     ORDER BY campo, lingua;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_traduzioni_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_traduzioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_traduzioni WHERE web_traduzioni_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_traduzioni_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_entita VARCHAR,
    p_entita_id BIGINT,
    p_campo VARCHAR,
    p_lingua VARCHAR,
    p_testo TEXT,
    p_tradotto_auto BOOLEAN,
    p_revisionato BOOLEAN,
    p_obsoleto BOOLEAN,
    p_data_traduzione TIMESTAMPTZ)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_traduzioni
       SET entita=p_entita, entita_id=p_entita_id, campo=p_campo, lingua=p_lingua, testo=p_testo,
           tradotto_auto=p_tradotto_auto, revisionato=p_revisionato, obsoleto=p_obsoleto,
           data_traduzione=p_data_traduzione
     WHERE web_traduzioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_traduzioni_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_traduzioni WHERE web_traduzioni_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
