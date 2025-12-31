-- Fix UNIQUE constraint on email - Scenario C
-- REQUISITO:
-- - Stessa azienda PUÒ usare stessa email per reparti diversi (es: CEO con più ruoli)
-- - Aziende diverse NON POSSONO usare la stessa email
--
-- SOLUZIONE: Trigger che verifica unicità email tra aziende diverse

-- Rimuovi constraint precedenti
ALTER TABLE ana_aziende_email DROP CONSTRAINT IF EXISTS uq_ana_aziende_email_global;
DROP INDEX IF EXISTS idx_email_global_unique;

-- Crea funzione trigger per verificare unicità email tra aziende
CREATE OR REPLACE FUNCTION fn_check_email_unique_across_companies()
RETURNS TRIGGER AS $$
BEGIN
    -- Verifica se l'email è già usata da un'altra azienda
    IF EXISTS (
        SELECT 1
        FROM ana_aziende_email
        WHERE LOWER(email) = LOWER(NEW.email)
        AND azienda_fk != NEW.azienda_fk
    ) THEN
        RAISE EXCEPTION 'Email % già utilizzata da un''altra azienda', NEW.email
            USING ERRCODE = '23505'; -- unique_violation
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger se esiste
DROP TRIGGER IF EXISTS trg_check_email_unique_across_companies ON ana_aziende_email;

-- Crea trigger BEFORE INSERT OR UPDATE
CREATE TRIGGER trg_check_email_unique_across_companies
    BEFORE INSERT OR UPDATE OF email, azienda_fk ON ana_aziende_email
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_email_unique_across_companies();

-- Commento
COMMENT ON FUNCTION fn_check_email_unique_across_companies() IS
'Garantisce che una email non possa essere usata da aziende diverse.
La stessa azienda può usare la stessa email per reparti diversi.';
