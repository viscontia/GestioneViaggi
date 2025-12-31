-- Fix UNIQUE constraint on email in ana_aziende_email
-- CORREZIONE: Email deve essere unica GLOBALMENTE (non per azienda)
-- La stessa azienda PUÒ usare la stessa email per reparti diversi
-- Aziende diverse NON POSSONO usare la stessa email

-- Rimuovi il constraint errato (per azienda)
ALTER TABLE ana_aziende_email DROP CONSTRAINT IF EXISTS uq_ana_aziende_email_azienda_email;
DROP INDEX IF EXISTS idx_aziende_email_unique_per_azienda;

-- Crea constraint UNIQUE GLOBALE su email
ALTER TABLE ana_aziende_email
ADD CONSTRAINT uq_ana_aziende_email_global UNIQUE (email);

-- Crea indice case-insensitive per ottimizzare le query
CREATE UNIQUE INDEX idx_email_global_unique ON ana_aziende_email(LOWER(email));

-- Commento
COMMENT ON CONSTRAINT uq_ana_aziende_email_global ON ana_aziende_email
IS 'Garantisce unicità email a livello globale - una email appartiene ad una sola azienda. La stessa azienda può usare la stessa email per reparti diversi.';
