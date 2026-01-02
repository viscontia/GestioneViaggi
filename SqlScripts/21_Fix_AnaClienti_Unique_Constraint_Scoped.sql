-- Fix Unique Constraint on ana_clienti to be Tenant-Scoped
-- The previous constraint ana_clienti_idx06 (on cognome, nome, data_nascita, cf) was GLOBAL.
-- We must drop it and recreate it including azienda_fk to allow the same person in different companies.
-- 1. Drop the existing global index/constraint
DROP INDEX IF EXISTS ana_clienti_idx06;
-- Attempt to drop constraint by name if it exists as a constraint (Postgres sometimes names backend index same as constraint)
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_idx06;
-- 2. Create the new Scoped Unique Index
-- Includes azienda_fk to ensure uniqueness is only enforced WITHIN the same company
CREATE UNIQUE INDEX ana_clienti_idx06_scoped ON ana_clienti (
    azienda_fk,
    UPPER(cliente_cognome),
    UPPER(cliente_nome),
    cliente_data_nascita,
    UPPER(cliente_codicefiscale)
);
-- 3. Update comment
COMMENT ON INDEX ana_clienti_idx06_scoped IS 'Ensures uniqueness of client anagraphic data within a specific company (Tenant Scoped)';