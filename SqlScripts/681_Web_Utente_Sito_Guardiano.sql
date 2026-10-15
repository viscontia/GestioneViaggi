-- ============================================================================
-- 681 — Un utente del database che sa solo leggere la posta del guardiano
--
-- Il guardiano del sito (Tappa 2, Task 14-bis) avvisa via mail quando il
-- database non risponde: proprio allora non può leggere la configurazione
-- SMTP. Per questo, quando il database funziona, ne tiene una copia protetta
-- sul server (deciso da Adriano il 2026-10-15: copia automatica dal database,
-- utente dedicato).
--
-- La configurazione SMTP la legge fn_get_smtp_config_for_email (la stessa del
-- gestionale e del sito iscrizioni), che è SECURITY INVOKER e decifra con la
-- chiave dei segreti (GV_SECRET_KEY). Qui una funzione «porta» SECURITY
-- DEFINER la apre al solo utente sito_guardiano, che non ha nessun altro
-- permesso: niente tabelle, niente coda. Senza la chiave dei segreti la
-- password non si legge comunque.
--
-- ⚠️ search_path con extensions: pgcrypto (pgp_sym_decrypt) sta nello schema
-- extensions, sia in locale sia in PROD (verificato il 2026-10-15). Con il
-- solo public la decifratura fallirebbe.
--
-- ⛔️ Il ruolo nasce NOLOGIN e senza password: login e password si danno a mano
-- (ALTER ROLE ... LOGIN PASSWORD) e la password vive solo nel .env del server.
--
-- Rigiocabile.
-- ============================================================================
BEGIN;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_guardiano') THEN
        CREATE ROLE sito_guardiano NOLOGIN;
    END IF;
END $$;

-- Senza USAGE sullo schema il ruolo non «vede» le funzioni per nome (679).
GRANT USAGE ON SCHEMA public TO sito_guardiano;

CREATE OR REPLACE FUNCTION fn_web_guardiano_smtp(p_azienda_id integer, p_master text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, extensions, pg_temp
AS $$
    SELECT fn_get_smtp_config_for_email(p_azienda_id, p_master);
$$;

REVOKE EXECUTE ON FUNCTION fn_web_guardiano_smtp(integer, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_web_guardiano_smtp(integer, text) TO sito_guardiano;

COMMIT;

-- ============================================================================
-- Verifica: Test_681_Web_Utente_Sito_Guardiano.sql
-- ============================================================================
