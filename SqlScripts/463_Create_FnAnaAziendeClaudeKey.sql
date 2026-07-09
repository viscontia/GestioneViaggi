-- Blocco 10: get/set della chiave Claude per-azienda (ana_aziende.claude_api_key).
-- Editabile dal tab Traduzioni (dall'admin dell'azienda). In chiaro per ora → cifrare pre-rilascio.

CREATE OR REPLACE FUNCTION fn_ana_aziende_get_claude_key(p_azienda_id INTEGER)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT claude_api_key FROM ana_aziende WHERE azienda_id = p_azienda_id;
$$;

CREATE OR REPLACE FUNCTION fn_ana_aziende_set_claude_key(p_azienda_id INTEGER, p_key TEXT)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_aziende
       SET claude_api_key = NULLIF(btrim(p_key), '')
     WHERE azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
