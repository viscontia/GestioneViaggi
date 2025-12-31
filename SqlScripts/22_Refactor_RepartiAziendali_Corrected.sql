-- =============================================================================
-- Script: 22_Refactor_RepartiAziendali_Corrected.sql
-- Descrizione: Rimozione campi ridondanti da reparti_aziendali
--              - email_reparto (già gestita in ana_aziende_email.email)
--              - created_at, updated_at (non necessari per tabella di decodifica)
--              MANTIENE: telefono_reparto (non esiste in ana_aziende_email)
--              Aggiunta FK per manager_contatto_fk
-- Data: 2025-01-01
-- =============================================================================

BEGIN;

-- 1. Verifica che non ci siano dati in email_reparto
DO $$
DECLARE
    email_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO email_count FROM reparti_aziendali WHERE email_reparto IS NOT NULL;

    IF email_count > 0 THEN
        RAISE WARNING 'ATTENZIONE: Trovate % email_reparto non nulle. Questi dati verranno persi.', email_count;
        RAISE WARNING 'Se necessario, migrare i dati in ana_aziende_email prima di procedere.';
    END IF;
END $$;

-- 2. Rimuovi il constraint di check su email_reparto
ALTER TABLE reparti_aziendali DROP CONSTRAINT IF EXISTS check_email_reparto;

-- 3. Rimuovi il trigger di aggiornamento timestamp
DROP TRIGGER IF EXISTS update_reparti_aziendali_modtime ON reparti_aziendali;

-- 4. Rimuovi SOLO le colonne ridondanti (MANTIENE telefono_reparto)
ALTER TABLE reparti_aziendali
    DROP COLUMN IF EXISTS email_reparto,
    DROP COLUMN IF EXISTS created_at,
    DROP COLUMN IF EXISTS updated_at;

-- 5. Aggiungi FK per manager_contatto_fk se non esiste
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_reparti_manager_contatto'
    ) THEN
        ALTER TABLE reparti_aziendali
            ADD CONSTRAINT fk_reparti_manager_contatto
            FOREIGN KEY (manager_contatto_fk)
            REFERENCES ana_aziende_contatti(contatto_id)
            ON DELETE SET NULL;

        RAISE NOTICE 'FK fk_reparti_manager_contatto aggiunta con successo';
    ELSE
        RAISE NOTICE 'FK fk_reparti_manager_contatto già esistente';
    END IF;
END $$;

-- 6. Verifica finale della struttura
\d reparti_aziendali

COMMIT;

-- =============================================================================
-- Struttura finale reparti_aziendali:
-- - reparto_id (PK)
-- - azienda_fk (FK -> ana_aziende)
-- - nome_reparto
-- - descrizione
-- - telefono_reparto (MANTENUTO - non esiste in ana_aziende_email)
-- - manager_contatto_fk (FK -> ana_aziende_contatti)
-- - is_active
-- =============================================================================
