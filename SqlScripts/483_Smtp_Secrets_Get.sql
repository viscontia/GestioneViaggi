-- Recupera outbound + inbound password DECIFRATE per una config SMTP (pgcrypto).
-- Sostituisce la lettura inline rotta password_enc->>'value' (JSONB su colonna bytea).
CREATE OR REPLACE FUNCTION fn_ana_aziende_smtp_secrets_get(
    p_smtp_id  uuid,
    p_master   text
)
RETURNS TABLE (password text, inbound_password text)
LANGUAGE sql
AS $$
    SELECT
        CASE WHEN password_enc         IS NULL THEN NULL ELSE pgp_sym_decrypt(password_enc,         p_master) END,
        CASE WHEN inbound_password_enc IS NULL THEN NULL ELSE pgp_sym_decrypt(inbound_password_enc, p_master) END
    FROM ana_aziende_smtp
    WHERE smtp_id = p_smtp_id;
$$;
