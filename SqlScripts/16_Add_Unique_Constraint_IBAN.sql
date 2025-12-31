-- Add UNIQUE constraint on IBAN in ana_aziende_banche
-- Prevent duplicate IBAN across all companies

-- Prima verifica se esistono duplicati (opzionale, per debug)
-- SELECT iban, COUNT(*)
-- FROM ana_aziende_banche
-- GROUP BY iban
-- HAVING COUNT(*) > 1;

-- Rimuovi l'indice non-unique esistente
DROP INDEX IF EXISTS idx_banche_iban;

-- Crea constraint UNIQUE su IBAN
ALTER TABLE ana_aziende_banche
ADD CONSTRAINT uq_ana_aziende_banche_iban UNIQUE (iban);

-- Ricrea l'indice come UNIQUE (già coperto dal constraint, ma esplicito)
CREATE UNIQUE INDEX idx_banche_iban_unique ON ana_aziende_banche(iban);

-- Commento
COMMENT ON CONSTRAINT uq_ana_aziende_banche_iban ON ana_aziende_banche
IS 'Garantisce unicità IBAN a livello globale - un IBAN non può essere associato a più aziende';
