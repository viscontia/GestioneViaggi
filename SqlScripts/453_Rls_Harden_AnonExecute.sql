-- Blocco 3 (Task 3.5) - Hardening EXECUTE: chiude l'ereditarieta' da PUBLIC.
--
-- Problema: ogni funzione Postgres nasce con EXECUTE a PUBLIC; anon (membro implicito
-- di PUBLIC) erediterebbe l'EXECUTE su TUTTE le funzioni, incluse le SECURITY DEFINER
-- di auth/gestione utenti che girano da owner-superuser e bypassano le RLS.
--
-- Impatto verificato prima del deploy (vincolo del piano):
--   * il gestionale si connette SEMPRE come postgres (superuser, dev e prod) -> non impattato;
--   * i ruoli app_tenant_user/app_tenant_admin/app_readonly/app_superadmin non sono usati
--     da nessuna connection string del progetto (solo predisposizione) -> nessuna dipendenza
--     dall'EXECUTE ereditato da PUBLIC;
--   * admin_viaggi e' superuser -> non impattato.
-- ⚠️ Al deploy su Supabase riverificare: la REVOKE da PUBLIC tocca anche i ruoli
--    managed authenticated/service_role (service_role ha comunque BYPASSRLS;
--    per authenticated concedere EXECUTE esplicito solo se/quando servira').

-- 1) Nessuna routine eseguibile da PUBLIC (quindi da anon) per default.
--    ROUTINES e non FUNCTIONS: copre anche le PROCEDURE (le sp_app_* di gestione
--    utenti/ruoli resterebbero altrimenti CALLabili da anon).
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;

-- 2) Le routine FUTURE create da postgres nascono senza EXECUTE a PUBLIC
--    (altrimenti ogni nuovo deploy riaprirebbe il buco).
--    (in ALTER DEFAULT PRIVILEGES la parola FUNCTIONS copre anche le procedure)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- 3) Difesa in profondita': nessuna creazione oggetti da PUBLIC nello schema.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 4) Ri-concessione ESPLICITA delle sole funzioni di lettura pubblica del sito
--    (SECURITY INVOKER: attraverso di esse valgono le RLS degli script 450-452).
GRANT EXECUTE ON FUNCTION fn_web_tour_pubblicati(INTEGER, CHAR) TO anon;
GRANT EXECUTE ON FUNCTION fn_web_prezzo_da(INTEGER) TO anon;
