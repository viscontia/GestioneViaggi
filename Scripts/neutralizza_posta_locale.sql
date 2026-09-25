-- ============================================================================
-- Neutralizza la posta nel DB LOCALE dopo una copia di PROD.
--
-- ⛔️ SOLO LOCALE. Non è uno script di SqlScripts/ e non va mai applicato a PROD:
--    si rifiuta di girare se trova i ruoli di Supabase.
--
-- Perché: il gestionale non ha dirottamento della posta, e una copia di PROD porta
-- in locale clienti, fornitori e iscritti newsletter veri.
--
-- Cosa fa: ogni indirizzo di un DESTINATARIO diventa
--     visconti.adriano+<codice>@gmail.com   oppure   mirania008+<codice>@gmail.com
-- Il <codice> è ricavato dall'indirizzo originale (md5), quindi:
--   * lo stesso indirizzo dà lo stesso risultato in tutte le tabelle
--     (iscritti ↔ clienti ↔ soppressioni restano collegati);
--   * indirizzi diversi restano diversi (i vincoli di unicità reggono);
--   * Gmail consegna tutto alle due caselle, e il <codice> dice di chi era.
--
-- Cosa NON tocca, di proposito:
--   * ana_aziende_smtp (from/bounce): il mittente deve restare quello autenticato;
--   * app_users e tabelle password_*: sono gli accessi al gestionale;
--   * storici degli invii (web_newsletter_invii_destinatari, web_pagamenti_reminder_log):
--     sono il registro di cosa è già partito, non destinatari futuri.
--
-- Uso:  docker exec -i postgres_db psql -U postgres -d gestione_viaggi -v ON_ERROR_STOP=1 < Scripts/neutralizza_posta_locale.sql
-- ============================================================================

BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('supabase_admin', 'authenticator')) THEN
        RAISE EXCEPTION 'Questo è un database Supabase: lo script gira solo in locale.';
    END IF;
END $$;

CREATE FUNCTION pg_temp.finta_email(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p IS NULL OR btrim(p) = '' THEN p
        WHEN lower(btrim(p)) LIKE '%+%@gmail.com'
             AND split_part(lower(btrim(p)), '+', 1) IN ('visconti.adriano', 'mirania008') THEN p  -- già neutralizzato
        ELSE (CASE WHEN get_byte(decode(md5(lower(btrim(p))), 'hex'), 0) % 2 = 0
                   THEN 'visconti.adriano' ELSE 'mirania008' END)
             || '+' || left(md5(lower(btrim(p))), 10) || '@gmail.com'
    END
$$;

-- Niente trigger durante la riscrittura: cambia solo l'indirizzo, e non deve
-- scattare nessuna validazione o notifica sulle righe storiche.
SET LOCAL session_replication_role = replica;

UPDATE ana_clienti               SET cliente_email = pg_temp.finta_email(cliente_email) WHERE cliente_email IS DISTINCT FROM pg_temp.finta_email(cliente_email);
UPDATE web_newsletter_iscritti   SET email = pg_temp.finta_email(email::text)           WHERE email::text IS DISTINCT FROM pg_temp.finta_email(email::text);
UPDATE web_newsletter_soppressioni SET email = pg_temp.finta_email(email::text)         WHERE email::text IS DISTINCT FROM pg_temp.finta_email(email::text);
UPDATE ana_controparti           SET email = pg_temp.finta_email(email)                 WHERE email IS DISTINCT FROM pg_temp.finta_email(email);
UPDATE ana_aziende_contatti      SET email = pg_temp.finta_email(email)                 WHERE email IS DISTINCT FROM pg_temp.finta_email(email);
UPDATE ana_aziende_sedi          SET email = pg_temp.finta_email(email)                 WHERE email IS DISTINCT FROM pg_temp.finta_email(email);
UPDATE ana_aziende_email         SET email = pg_temp.finta_email(email)                 WHERE email IS DISTINCT FROM pg_temp.finta_email(email);

-- Verifica: nessun destinatario fuori dalle due caselle.
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM (
        SELECT cliente_email e FROM ana_clienti
        UNION ALL SELECT email::text FROM web_newsletter_iscritti
        UNION ALL SELECT email::text FROM web_newsletter_soppressioni
        UNION ALL SELECT email FROM ana_controparti
        UNION ALL SELECT email FROM ana_aziende_contatti
        UNION ALL SELECT email FROM ana_aziende_sedi
        UNION ALL SELECT email FROM ana_aziende_email
    ) x
    WHERE e IS NOT NULL AND btrim(e) <> ''
      AND lower(e) !~ '^(visconti\.adriano|mirania008)\+[0-9a-f]{10}@gmail\.com$';
    IF n > 0 THEN
        RAISE EXCEPTION 'Restano % indirizzi veri: annullo.', n;
    END IF;
END $$;

COMMIT;
