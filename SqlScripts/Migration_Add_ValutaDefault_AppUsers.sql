-- =============================================
-- Migration: Aggiunta valuta di default per utenti
-- Data: 2026-02-07
-- Descrizione: Aggiunge un campo FK alla tabella app_users
--              per memorizzare la valuta di default dell'utente
-- =============================================

-- STEP 1: Aggiungere la colonna valuta_default_id
ALTER TABLE app_users
ADD COLUMN valuta_default_id INTEGER;

-- STEP 2: Aggiungere il commento alla colonna
COMMENT ON COLUMN app_users.valuta_default_id IS 'Valuta di default per l''utente';

-- STEP 3: Impostare la valuta base (EUR) come default per tutti gli utenti esistenti
UPDATE app_users
SET valuta_default_id = (SELECT valuta_id FROM ana_valute WHERE valuta_is_base = true)
WHERE valuta_default_id IS NULL;

-- STEP 4: Aggiungere il vincolo di FK
ALTER TABLE app_users
ADD CONSTRAINT fk_app_users_valuta_default
FOREIGN KEY (valuta_default_id)
REFERENCES ana_valute(valuta_id)
ON DELETE RESTRICT;

-- STEP 5: Creare un indice per migliorare le performance nelle join
CREATE INDEX idx_app_users_valuta_default ON app_users(valuta_default_id);

-- =============================================
-- ROLLBACK (da eseguire solo se necessario)
-- =============================================
-- DROP INDEX IF EXISTS idx_app_users_valuta_default;
-- ALTER TABLE app_users DROP CONSTRAINT IF EXISTS fk_app_users_valuta_default;
-- ALTER TABLE app_users DROP COLUMN IF EXISTS valuta_default_id;
