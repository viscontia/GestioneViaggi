-- Fix sequence for ana_mezzi_modelli table
DO $$
BEGIN
    -- 1. Create the sequence if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'ana_mezzi_modelli_seq') THEN
        CREATE SEQUENCE ana_mezzi_modelli_seq;
    END IF;

    -- 2. Set the default value for the id column to use the sequence
    ALTER TABLE ana_mezzi_modelli 
    ALTER COLUMN mezzo_modello_id SET DEFAULT nextval('ana_mezzi_modelli_seq');

    -- 3. Sync the sequence with the current max id
    PERFORM setval('ana_mezzi_modelli_seq', COALESCE((SELECT MAX(mezzo_modello_id) FROM ana_mezzi_modelli), 0) + 1, false);
END $$;
