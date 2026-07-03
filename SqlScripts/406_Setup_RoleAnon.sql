-- Ruolo di sola lettura per il traffico pubblico del sito (equivalente locale dell'anon Supabase).
-- NON login, NON superuser: subisce le RLS. I GRANT SELECT specifici sono negli script delle tabelle web.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA public TO anon;
