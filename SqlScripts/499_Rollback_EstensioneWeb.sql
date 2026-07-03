-- ROLLBACK completo dello schema Estensione Web (Blocchi 0-1, script 406-429).
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

-- 3) Funzione audit condivisa
DROP FUNCTION IF EXISTS trg_web_audit();

-- 4) Ruolo pubblico (revoca i grant residui, poi drop)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
        REVOKE USAGE ON SCHEMA public FROM anon;
        DROP ROLE anon;
    END IF;
END $$;
