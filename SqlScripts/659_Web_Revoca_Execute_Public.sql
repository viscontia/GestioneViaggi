-- ============================================================================
-- Nessuna funzione nostra eseguibile da PUBLIC (quindi da anon) — di nuovo
--
-- STORIA. Lo script 453 aveva già chiuso il problema: REVOKE EXECUTE da PUBLIC
-- su tutte le routine di `public`, più un ALTER DEFAULT PRIVILEGES perché le
-- funzioni FUTURE nascessero chiuse. ⚠️ Quel secondo pezzo NON HA MAI FUNZIONATO:
-- era scritto `... IN SCHEMA public REVOKE ... FROM PUBLIC`, e in PostgreSQL i
-- privilegi di default per schema possono solo AGGIUNGERE a quelli globali, mai
-- togliere (è scritto nella documentazione di ALTER DEFAULT PRIVILEGES). Il
-- comando è accettato senza errori e non fa nulla. Così ogni funzione nata dopo
-- il 453 ha ricevuto EXECUTE a PUBLIC, come vuole il comportamento standard.
-- Qui la revoca si fa a livello GLOBALE, cioè senza `IN SCHEMA`: l'unica forma
-- che toglie davvero il permesso di default.
--
-- MISURATO il 2026-09-25, uguale in PROD e in locale (che è una copia di PROD):
--   * 552 funzioni in `public`: 474 nostre (owner `postgres`), 78 delle estensioni;
--   * 187 delle nostre eseguibili da PUBLIC, fra cui funzioni di scrittura e
--     `fn_web_destinatari_newsletter`, che restituisce email di clienti;
--   * nessun privilegio di default su `public` per `postgres`.
--
-- ⭐️ OGGI NON ESPONE DATI: `anon` non ha permessi su nessuna tabella, quindi le
-- funzioni SECURITY INVOKER chiamate da anon falliscono con «permission denied».
-- Ma è una protezione che vive per caso: basta un GRANT su una tabella dato
-- domani per sbaglio e diventano tutte raggiungibili. È la regola dello script 655
-- («nessuna funzione di scrittura raggiungibile da anon») che non è rispettata.
--
-- CHI NON NE RISENTE, verificato prima di scrivere:
--   * il gestionale e il sito Flask si connettono come `postgres`, che è il
--     PROPRIETARIO delle funzioni: il proprietario esegue sempre, a prescindere
--     da PUBLIC. ⚠️ In PROD `postgres` NON è superuser (rolsuper = false): per
--     questo conta che sia il proprietario;
--   * nessuno dei due fa SET ROLE: impostano solo `my.app_user`;
--   * nessuna policy RLS chiama funzioni; nessuna Edge Function;
--   * i trigger non richiedono EXECUTE per scattare.
--
-- COSA NON SI TOCCA:
--   * i permessi ESPLICITI già dati apposta (script 453, 479, 481, 655): le
--     letture pubbliche restano concesse ad anon/authenticated, la coda di
--     rigenerazione a service_role;
--   * le funzioni delle estensioni (owner `supabase_admin`): non sono nostre.
--
-- ⚠️ REGOLA, da qui in avanti: una funzione che il sito pubblico chiama nasce
-- chiusa e riceve un GRANT EXECUTE esplicito ad anon (vedi script 655).
--
-- ✅ Applicato in locale e a PROD il 2026-09-25: 187 funzioni chiuse, anon esegue
--    le sole 8 concesse apposta, una funzione nuova nasce chiusa; gestionale e
--    Flask (postgres, proprietario) continuano a chiamare tutto.
-- ============================================================================

BEGIN;

-- 1) Le funzioni nostre ancora eseguibili da PUBLIC: si chiudono.
DO $$
DECLARE
    r RECORD;
    n INTEGER := 0;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS firma
          FROM pg_proc p
          JOIN pg_namespace ns ON ns.oid = p.pronamespace
         WHERE ns.nspname = 'public'
           AND p.proowner = 'postgres'::regrole
           AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
           AND (p.proacl IS NULL
                OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a
                            WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'))
    LOOP
        EXECUTE format('REVOKE EXECUTE ON %s %s FROM PUBLIC',
                       CASE WHEN (SELECT prokind FROM pg_proc WHERE oid = r.firma::oid) = 'p'
                            THEN 'PROCEDURE' ELSE 'FUNCTION' END,
                       r.firma);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'Routine chiuse a PUBLIC: %', n;
END $$;

-- 2) Le funzioni FUTURE create da postgres nascono chiuse.
--    ⛔️ SENZA `IN SCHEMA`: la forma per schema non può togliere (vedi sopra).
--    Vale per le funzioni che postgres crea in qualunque schema; negli schemi di
--    Supabase (storage, graphql…) restano in vigore i GRANT per schema che
--    Supabase stesso ha definito, perché quelli aggiungono.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;

-- ============================================================================
-- Verifica
--
-- 1. Nessuna funzione nostra aperta a PUBLIC (atteso: 0)
SELECT COUNT(*) AS aperte_a_public
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public' AND p.proowner = 'postgres'::regrole
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
   AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0));

-- 2. Le sole funzioni nostre che anon può eseguire (attese: le 8 concesse apposta)
SELECT p.proname
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
 WHERE ns.nspname = 'public' AND p.proowner = 'postgres'::regrole
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
   AND has_function_privilege('anon', p.oid, 'EXECUTE')
 ORDER BY 1;

-- 3. Il privilegio di default globale (atteso: una riga, postgres, senza PUBLIC)
SELECT pg_get_userbyid(defaclrole) AS ruolo, defaclacl
  FROM pg_default_acl d
 WHERE d.defaclnamespace = 0 AND d.defaclobjtype = 'f';

-- 3-bis. La prova vera: una funzione appena creata NON è eseguibile da anon
--      (atteso: false)
--      CREATE FUNCTION fn_prova_659() RETURNS int LANGUAGE sql AS 'SELECT 1';
--      SELECT has_function_privilege('anon', 'fn_prova_659()', 'EXECUTE');
--      DROP FUNCTION fn_prova_659();

-- 4. A mano, come anon:
--      SET ROLE anon;
--      SELECT COUNT(*) FROM fn_web_tour_pubblicati(2, 'IT');            -- atteso: risponde
--      SELECT * FROM fn_web_destinatari_newsletter(2, 1);               -- atteso: permission denied for function
--      RESET ROLE;
-- ============================================================================
