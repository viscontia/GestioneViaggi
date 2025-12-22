-- Aggiunta Foreign Key su ana_mezzi_modelli verso ana_tipo_mezzi
-- Questo sostituisce la necessità del trigger TRG2 di Oracle per impedire la cancellazione
-- di un tipo mezzo se utilizzato da un modello.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_mezzi_modelli_tipo' 
        AND table_name = 'ana_mezzi_modelli'
    ) THEN
        ALTER TABLE ana_mezzi_modelli
        ADD CONSTRAINT fk_mezzi_modelli_tipo
        FOREIGN KEY (mezzo_modello_tipo_fk)
        REFERENCES ana_tipo_mezzi (ana_tipo_mezzo_id)
        ON DELETE RESTRICT;
    END IF;
END $$;
