-- Blocco 10 (traduzioni Claude API): colonna chiave per-azienda + upsert traduzione + marca obsolete.

-- 1) Chiave API Claude/Anthropic per-azienda (in chiaro per ora → cifrare pre-rilascio con SMTP/ESP).
ALTER TABLE ana_aziende ADD COLUMN IF NOT EXISTS claude_api_key TEXT;

-- 2) Upsert di una traduzione per (entita, entita_id, campo, lingua) — usato dal "Traduci".
--    Ri-tradurre resetta i flag: tradotto_auto=true, revisionato=false, obsoleto=false, data=now.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_upsert(
    p_azienda_id INTEGER,
    p_entita VARCHAR,
    p_entita_id BIGINT,
    p_campo VARCHAR,
    p_lingua VARCHAR,
    p_testo TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo,
                               tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    VALUES (p_entita, p_entita_id, p_campo, p_lingua, p_testo,
            TRUE, FALSE, FALSE, now(), p_azienda_id)
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE
       SET testo = EXCLUDED.testo,
           tradotto_auto = TRUE,
           revisionato = FALSE,
           obsoleto = FALSE,
           data_traduzione = now(),
           azienda_id = EXCLUDED.azienda_id
    RETURNING web_traduzioni_id INTO v_id;
    RETURN v_id;
END $$;

-- 3) Marca obsolete tutte le traduzioni (ogni lingua) di un campo sorgente quando l'IT cambia.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_marca_obsolete(
    p_azienda_id INTEGER,
    p_entita VARCHAR,
    p_entita_id BIGINT,
    p_campo VARCHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_traduzioni
       SET obsoleto = TRUE
     WHERE entita = p_entita AND entita_id = p_entita_id
       AND campo = p_campo AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
