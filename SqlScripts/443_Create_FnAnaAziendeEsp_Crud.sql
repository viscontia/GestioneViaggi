-- Funzioni CRUD per ana_aziende_esp (Blocco 2 estensione web - Task 2.2).
-- Convenzione template 431. La tabella e' 1:1 con ana_aziende (UNIQUE azienda_id):
-- oltre a get per id c'e' get_by_azienda (stesso pattern di fn_web_tour_contenuti_get_by_viaggio).
-- p_api_key_enc JSONB: la API key arriva GIA' cifrata dall'app (pattern password_enc di ana_aziende_smtp).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_insert(
    p_azienda_id INTEGER, p_provider VARCHAR, p_api_key_enc JSONB,
    p_sender_email VARCHAR DEFAULT NULL, p_sender_name VARCHAR DEFAULT NULL,
    p_sender_domain VARCHAR DEFAULT NULL, p_attivo BOOLEAN DEFAULT false)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO ana_aziende_esp(provider, api_key_enc, sender_email, sender_name, sender_domain, attivo, azienda_id)
    VALUES (p_provider, p_api_key_enc, p_sender_email, p_sender_name, p_sender_domain, p_attivo, p_azienda_id)
    RETURNING ana_aziende_esp_id INTO v_id;
    RETURN v_id;
END $$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF ana_aziende_esp LANGUAGE sql STABLE AS $$
    SELECT * FROM ana_aziende_esp WHERE ana_aziende_esp_id = p_id AND azienda_id = p_azienda_id;
$$;

-- GET per azienda (relazione 1:1 -> 0/1 righe)
CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_get_by_azienda(p_azienda_id INTEGER)
RETURNS SETOF ana_aziende_esp LANGUAGE sql STABLE AS $$
    SELECT * FROM ana_aziende_esp WHERE azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_update(
    p_id BIGINT, p_azienda_id INTEGER, p_provider VARCHAR, p_api_key_enc JSONB,
    p_sender_email VARCHAR, p_sender_name VARCHAR, p_sender_domain VARCHAR, p_attivo BOOLEAN)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_aziende_esp
       SET provider=p_provider, api_key_enc=p_api_key_enc, sender_email=p_sender_email,
           sender_name=p_sender_name, sender_domain=p_sender_domain, attivo=p_attivo
     WHERE ana_aziende_esp_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM ana_aziende_esp WHERE ana_aziende_esp_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
