-- Add UNIQUE constraint on (azienda_fk, email, reparto_fk)
-- REQUISITO FINALE:
-- - Stessa email può essere usata per reparti diversi nella stessa azienda (OK)
-- - Stessa email NON può essere duplicata nello stesso reparto della stessa azienda (NO)
-- - Email non può essere usata da aziende diverse (già gestito dal trigger)
--
-- Esempio:
-- pippo@gmail.com - Azienda A - Reparto Tecnico    ✅ OK
-- pippo@gmail.com - Azienda A - Reparto Commerciale ✅ OK (stessa email, reparto diverso)
-- pippo@gmail.com - Azienda A - Reparto Tecnico    ❌ NO (duplicato!)
-- pippo@gmail.com - Azienda B - Reparto Marketing  ❌ NO (trigger lo blocca)

-- Crea constraint UNIQUE su (azienda_fk, email, reparto_fk)
ALTER TABLE ana_aziende_email
ADD CONSTRAINT uq_ana_aziende_email_reparto UNIQUE (azienda_fk, email, reparto_fk);

-- Crea indice per ottimizzare le query
CREATE UNIQUE INDEX idx_email_reparto_per_azienda ON ana_aziende_email(azienda_fk, LOWER(email), reparto_fk);

-- Commento
COMMENT ON CONSTRAINT uq_ana_aziende_email_reparto ON ana_aziende_email
IS 'Impedisce duplicati della stessa email nello stesso reparto della stessa azienda. Permette la stessa email in reparti diversi.';
