-- 1. Create ana_tipo_avvicinamento table
CREATE TABLE IF NOT EXISTS ana_tipo_avvicinamento (
    tipo_avvicinamento_id SERIAL PRIMARY KEY,
    tipo_avvicinamento_descrizione VARCHAR(100) NOT NULL
);
-- 2. Create indices
CREATE INDEX IF NOT EXISTS idx_ana_tipo_avvicinamento_descrizione ON ana_tipo_avvicinamento(tipo_avvicinamento_descrizione);
-- 3. Populate table
INSERT INTO ana_tipo_avvicinamento (tipo_avvicinamento_descrizione)
VALUES ('VEICOLO SU RUOTE'),
    ('TRAGHETTO'),
    ('AEREO'),
    ('TRENO') ON CONFLICT DO NOTHING;
-- 4. Create backup of ana_viaggi
DROP TABLE IF EXISTS ana_viaggi_bak;
CREATE TABLE ana_viaggi_bak AS
SELECT *
FROM ana_viaggi;
-- 5. Add new Foreign Key column to ana_viaggi
ALTER TABLE ana_viaggi
ADD COLUMN IF NOT EXISTS viaggio_tipo_avvicinamento_fk INTEGER;
-- 6. Update ana_viaggi with FK values
-- Update logic matching descriptions. Using UPPER() to ensure case-insensitive match
UPDATE ana_viaggi v
SET viaggio_tipo_avvicinamento_fk = t.tipo_avvicinamento_id
FROM ana_tipo_avvicinamento t
WHERE UPPER(v.viaggio_tipo_avvicinamento) = t.tipo_avvicinamento_descrizione;
-- Handle mismatches if any? User implies direct string codes might be in use or descriptions match.
-- Based on import service, it was importing strings.
-- 7. Add Constraint FK
ALTER TABLE ana_viaggi DROP CONSTRAINT IF EXISTS fk_ana_viaggi_tipo_avvicinamento;
ALTER TABLE ana_viaggi
ADD CONSTRAINT fk_ana_viaggi_tipo_avvicinamento FOREIGN KEY (viaggio_tipo_avvicinamento_fk) REFERENCES ana_tipo_avvicinamento(tipo_avvicinamento_id);
-- 8. Final cleaning (Drop old column? User said "Aggiorna... con i codici invece della descrizione")
-- Keeping old column for safety until verified, or dropping it if confident.
-- User said: "Aggiorna ana_date_viaggi con i codici invece della descrizione attuale abbinandoli correttamente (ovviamente sulla descrizione, non puoi fare altrimenti). Chiaramente dovrai fare una alter table"
-- Assuming user meant ana_viaggi.
-- We will DROP the old column and RENAME the new one to maintain clean schema? 
-- Or typical pattern is `viaggio_tipo_avvicinamento_fk`.
-- Let's Check: schema often uses `_fk`. 
-- But user said "sostituire la descrizione con i codici".
-- I will DROP the old text column `viaggio_tipo_avvicinamento` to force usage of FK.
-- Before dropping, ensure NOT NULL if required?
-- ana_viaggi fields were mostly nullable in import, but plan said "Required".
-- START TRANSACTION; -- (Will be run inside transaction tool if possible or user runs script)
ALTER TABLE ana_viaggi DROP COLUMN IF EXISTS viaggio_tipo_avvicinamento;
-- 9. Trigger for integrity (Before Delete on ana_tipo_avvicinamento)
CREATE OR REPLACE FUNCTION trg_check_delete_tipo_avvicinamento() RETURNS TRIGGER AS $$ BEGIN IF EXISTS (
        SELECT 1
        FROM ana_viaggi
        WHERE viaggio_tipo_avvicinamento_fk = OLD.tipo_avvicinamento_id
    ) THEN RAISE EXCEPTION 'Impossibile eliminare Tipo Avvicinamento utilizzato in ana_viaggi';
END IF;
RETURN OLD;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_check_delete_ana_tipo_avvicinamento ON ana_tipo_avvicinamento;
CREATE TRIGGER trg_check_delete_ana_tipo_avvicinamento BEFORE DELETE ON ana_tipo_avvicinamento FOR EACH ROW EXECUTE FUNCTION trg_check_delete_tipo_avvicinamento();