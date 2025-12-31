-- Add UNIQUE constraint on (azienda_fk, email) in ana_aziende_email
-- Prevent duplicate email within the same company (but different companies can have same email)

-- Verifica se esistono duplicati (opzionale, per debug)
-- SELECT azienda_fk, email, COUNT(*)
-- FROM ana_aziende_email
-- GROUP BY azienda_fk, email
-- HAVING COUNT(*) > 1;

-- Crea constraint UNIQUE su (azienda_fk, email)
-- Questo permette la stessa email in aziende diverse, ma non nella stessa azienda
ALTER TABLE ana_aziende_email
ADD CONSTRAINT uq_ana_aziende_email_azienda_email UNIQUE (azienda_fk, email);

-- Crea indice per ottimizzare le query
CREATE UNIQUE INDEX idx_aziende_email_unique_per_azienda ON ana_aziende_email(azienda_fk, LOWER(email));

-- Commento
COMMENT ON CONSTRAINT uq_ana_aziende_email_azienda_email ON ana_aziende_email
IS 'Garantisce unicità email per azienda - la stessa email non può essere usata più volte nella stessa azienda';
