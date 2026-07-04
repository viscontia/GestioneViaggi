-- ROLLBACK completo dello schema Estensione Web (Blocchi 0-3, script 406-453).
-- Uso: solo per annullare l'intera estensione in locale. Idempotente (IF EXISTS).
-- NON eseguire in produzione senza backup.

-- 1) Reverse degli ALTER su tabelle esistenti
ALTER TABLE ana_aziende     DROP COLUMN IF EXISTS token_iscrizione;
ALTER TABLE ana_clienti     DROP COLUMN IF EXISTS consenso_marketing;
ALTER TABLE ana_clienti     DROP COLUMN IF EXISTS consenso_marketing_data;
ALTER TABLE ana_clienti     DROP COLUMN IF EXISTS consenso_marketing_fonte;
ALTER TABLE ana_clienti     DROP COLUMN IF EXISTS controparte_fk;
ALTER TABLE ana_tipo_viaggi DROP COLUMN IF EXISTS web_categoria_fk;

-- 2) DROP delle nuove tabelle (CASCADE gestisce FK/trigger). Ordine inverso di dipendenza per chiarezza.
DROP TABLE IF EXISTS web_blog_articoli                CASCADE;
DROP TABLE IF EXISTS web_pagamenti_reminder_log       CASCADE;
DROP TABLE IF EXISTS web_pagamenti_transazioni        CASCADE;
DROP TABLE IF EXISTS web_pagamenti_reminder_regole    CASCADE;
DROP TABLE IF EXISTS web_pagamenti_regole             CASCADE;
DROP TABLE IF EXISTS web_pagamenti_config             CASCADE;
DROP TABLE IF EXISTS ana_aziende_esp                  CASCADE;
DROP TABLE IF EXISTS web_aziende_funzioni             CASCADE;
DROP TABLE IF EXISTS web_newsletter_soppressioni      CASCADE;
DROP TABLE IF EXISTS web_newsletter_invii_destinatari CASCADE;
DROP TABLE IF EXISTS web_newsletter_invii             CASCADE;
DROP TABLE IF EXISTS web_newsletter_iscritti          CASCADE;
DROP TABLE IF EXISTS web_traduzioni                   CASCADE;
DROP TABLE IF EXISTS web_tour_mappa                   CASCADE;
DROP TABLE IF EXISTS web_tour_immagini                CASCADE;
DROP TABLE IF EXISTS web_tour_itinerario_passaggi     CASCADE;
DROP TABLE IF EXISTS web_tour_itinerario              CASCADE;
DROP TABLE IF EXISTS web_tour_contenuti               CASCADE;
DROP TABLE IF EXISTS web_categorie_sport              CASCADE;

-- 3) Funzioni dell'estensione web non eliminate dal CASCADE delle tabelle
--    (le funzioni SETOF <tabella> cadono col DROP TABLE; quelle che ritornano
--    scalari o TABLE(...) - insert/update/delete/servizio - vanno rimosse a mano).
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT p.oid::regprocedure AS firma
               FROM pg_proc p
              WHERE p.pronamespace = 'public'::regnamespace
                AND (p.proname LIKE 'fn\_web\_%'
                     OR p.proname LIKE 'fn\_ana\_aziende\_esp\_%')
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %s', r.firma);
    END LOOP;
END $$;

-- Funzione audit condivisa
DROP FUNCTION IF EXISTS trg_web_audit();

-- 3b) Revert RLS Blocco 3 sulle tabelle legacy (le policy sulle tabelle web cadono col DROP TABLE)
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON ana_viaggi;
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON ana_date_viaggi;

-- 3c) Revert hardening EXECUTE (script 453): ripristina i default Postgres
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
GRANT CREATE ON SCHEMA public TO PUBLIC;

-- 4) Ruolo pubblico: DROP OWNED revoca TUTTI i privilegi concessi ad anon
--    (grant di colonna sulle ana_* inclusi; senza, il DROP ROLE fallirebbe), poi drop.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
        DROP OWNED BY anon;
        REVOKE USAGE ON SCHEMA public FROM anon;
        DROP ROLE anon;
    END IF;
END $$;
