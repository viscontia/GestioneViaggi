-- ============================================================================
-- 475_Cifratura_Segreti_Pgcrypto.sql
-- Hardening pre-release: cifratura REALE dei segreti con pgcrypto (pgp_sym_*).
-- Sostituisce i campi "_enc" finti (jsonb {"value":plaintext}) e ana_aziende.claude_api_key
-- in chiaro. La master key arriva dall'app (env GV_SECRET_KEY) come parametro p_master.
-- Migrazione a freddo: i valori attuali sono FINTI -> azzerati (USING NULL); vanno re-inseriti
-- dalle form dopo il rilascio. Esclusi: Geoapify (deciso), sys_redis_endpoints (infra).
-- ============================================================================

-- pgcrypto (già installato; idempotente)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1) Colonne _enc: jsonb -> bytea (valori finti azzerati). Tabelle vuote/finte.
-- ----------------------------------------------------------------------------
-- password_enc è NOT NULL: la password può ora essere assente (config senza pwd) -> drop NOT NULL
ALTER TABLE ana_aziende_smtp ALTER COLUMN password_enc DROP NOT NULL;
ALTER TABLE ana_aziende_smtp ALTER COLUMN inbound_password_enc DROP NOT NULL;
ALTER TABLE ana_aziende_esp  ALTER COLUMN api_key_enc DROP NOT NULL;
ALTER TABLE ana_aziende_smtp ALTER COLUMN password_enc TYPE bytea USING NULL;
ALTER TABLE ana_aziende_smtp ALTER COLUMN inbound_password_enc TYPE bytea USING NULL;
ALTER TABLE ana_aziende_esp  ALTER COLUMN api_key_enc TYPE bytea USING NULL;
ALTER TABLE web_pagamenti_config ALTER COLUMN stripe_secret_key_enc TYPE bytea USING NULL;
ALTER TABLE web_pagamenti_config ALTER COLUMN stripe_webhook_secret_enc TYPE bytea USING NULL;

-- Claude: da text in chiaro -> bytea cifrata
ALTER TABLE ana_aziende ADD COLUMN IF NOT EXISTS claude_api_key_enc bytea;

-- ----------------------------------------------------------------------------
-- 2) Claude get/set: cifrati con master key (rimpiazza 463)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ana_aziende_get_claude_key(INTEGER);
DROP FUNCTION IF EXISTS fn_ana_aziende_set_claude_key(INTEGER, TEXT);
ALTER TABLE ana_aziende DROP COLUMN IF EXISTS claude_api_key;

CREATE OR REPLACE FUNCTION fn_ana_aziende_get_claude_key(p_azienda_id INTEGER, p_master TEXT)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN claude_api_key_enc IS NOT NULL
                THEN pgp_sym_decrypt(claude_api_key_enc, p_master)
           END
      FROM ana_aziende WHERE azienda_id = p_azienda_id;
$$;

CREATE OR REPLACE FUNCTION fn_ana_aziende_set_claude_key(p_azienda_id INTEGER, p_key TEXT, p_master TEXT)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_aziende
       SET claude_api_key_enc = CASE WHEN NULLIF(btrim(p_key), '') IS NULL THEN NULL
                                     ELSE pgp_sym_encrypt(btrim(p_key), p_master) END
     WHERE azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- ----------------------------------------------------------------------------
-- 3) SMTP: lettura config con decifratura password (aggiunge p_master)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_get_smtp_config_for_email(integer);

CREATE OR REPLACE FUNCTION fn_get_smtp_config_for_email(p_azienda_id integer, p_master text)
RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'smtp_id', s.smtp_id,
        'host', s.host,
        'port', s.port,
        'username', s.username,
        'password', CASE WHEN s.password_enc IS NOT NULL THEN pgp_sym_decrypt(s.password_enc, p_master) END,
        'use_tls', s.use_tls,
        'use_starttls', s.use_starttls,
        'security_method', s.security_method,
        'from_name', s.from_name,
        'from_email', s.from_email
    )
    INTO v_result
    FROM ana_aziende_smtp s
    WHERE s.azienda_fk = p_azienda_id
      AND s.is_active = TRUE
      AND s.status = 'active'
      AND s.config_type = 'outbound'
    ORDER BY s.priority ASC
    LIMIT 1;
    RETURN v_result;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4) ESP: insert/update ricevono la key IN CHIARO + master e cifrano (era JSONB pre-cifrata).
--    Aggiunta get_key che decifra. Nessun consumer C# ancora: pronto per il wiring ESP.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_insert(INTEGER, VARCHAR, JSONB, VARCHAR, VARCHAR, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_update(BIGINT, INTEGER, VARCHAR, JSONB, VARCHAR, VARCHAR, VARCHAR, BOOLEAN);

CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_insert(
    p_azienda_id INTEGER, p_provider VARCHAR, p_api_key TEXT, p_master TEXT,
    p_sender_email VARCHAR DEFAULT NULL, p_sender_name VARCHAR DEFAULT NULL,
    p_sender_domain VARCHAR DEFAULT NULL, p_attivo BOOLEAN DEFAULT false)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO ana_aziende_esp(provider, api_key_enc, sender_email, sender_name, sender_domain, attivo, azienda_id)
    VALUES (p_provider, pgp_sym_encrypt(p_api_key, p_master), p_sender_email, p_sender_name, p_sender_domain, p_attivo, p_azienda_id)
    RETURNING ana_aziende_esp_id INTO v_id;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_update(
    p_id BIGINT, p_azienda_id INTEGER, p_provider VARCHAR, p_api_key TEXT, p_master TEXT,
    p_sender_email VARCHAR, p_sender_name VARCHAR, p_sender_domain VARCHAR, p_attivo BOOLEAN)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_aziende_esp
       SET provider=p_provider, api_key_enc=pgp_sym_encrypt(p_api_key, p_master), sender_email=p_sender_email,
           sender_name=p_sender_name, sender_domain=p_sender_domain, attivo=p_attivo
     WHERE ana_aziende_esp_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION fn_ana_aziende_esp_get_key(p_azienda_id INTEGER, p_master TEXT)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN api_key_enc IS NOT NULL THEN pgp_sym_decrypt(api_key_enc, p_master) END
      FROM ana_aziende_esp WHERE azienda_id = p_azienda_id;
$$;
