-- =============================================
-- Migration: Rendere valuta_default_id obbligatorio
-- Data: 2026-02-07
-- Descrizione: Modifica la colonna valuta_default_id per renderla NOT NULL
--              Tutti gli utenti devono avere una valuta di default
-- =============================================

-- STEP 1: Verificare che tutti gli utenti abbiano una valuta_default_id
-- Se ci sono record NULL, impostarli sulla valuta base (EUR)
UPDATE app_users
SET valuta_default_id = (SELECT valuta_id FROM ana_valute WHERE valuta_is_base = true)
WHERE valuta_default_id IS NULL;

-- STEP 2: Rendere la colonna NOT NULL
ALTER TABLE app_users
ALTER COLUMN valuta_default_id SET NOT NULL;

-- STEP 3: Aggiornare il commento
COMMENT ON COLUMN app_users.valuta_default_id IS 'Valuta di default per l''utente (obbligatorio)';

-- =============================================
-- ROLLBACK (da eseguire solo se necessario)
-- =============================================
-- ALTER TABLE app_users ALTER COLUMN valuta_default_id DROP NOT NULL;
