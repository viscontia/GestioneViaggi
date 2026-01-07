-- Fix data migration using ana_viaggi_bak
-- 1. Restore data linkage for VRU
UPDATE ana_viaggi v
SET viaggio_tipo_avvicinamento_fk = (
        SELECT tipo_avvicinamento_id
        FROM ana_tipo_avvicinamento
        WHERE tipo_avvicinamento_descrizione = 'VEICOLO SU RUOTE'
    )
FROM ana_viaggi_bak b
WHERE v.viaggio_id = b.viaggio_id
    AND b.viaggio_tipo_avvicinamento = 'VRU';
-- 2. Restore data linkage for TRA
UPDATE ana_viaggi v
SET viaggio_tipo_avvicinamento_fk = (
        SELECT tipo_avvicinamento_id
        FROM ana_tipo_avvicinamento
        WHERE tipo_avvicinamento_descrizione = 'TRAGHETTO'
    )
FROM ana_viaggi_bak b
WHERE v.viaggio_id = b.viaggio_id
    AND b.viaggio_tipo_avvicinamento = 'TRA';
-- 3. Verify consistency
DO $$
DECLARE null_count INTEGER;
BEGIN
SELECT COUNT(*) INTO null_count
FROM ana_viaggi
WHERE viaggio_tipo_avvicinamento_fk IS NULL;
IF null_count > 0 THEN RAISE NOTICE 'Warning: % rows have NULL tipo_avvicinamento_fk',
null_count;
END IF;
END $$;