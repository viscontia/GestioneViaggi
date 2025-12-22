-- Popolamento iniziale di ana_tipo_mezzi per soddisfare i vincoli di integrità
-- I valori sono inferiti dai dati esistenti in ana_mezzi_modelli

INSERT INTO ana_tipo_mezzi (ana_tipo_mezzo_id, ana_tipo_mezzo_descrizione)
VALUES 
    (2, 'MOTO ADVENTURE'),
    (3, 'MOTO ENDURO'),
    (4, 'FUORISTRADA 4X4'),
    (5, 'SUV / CROSSOVER'),
    (7, 'MOTO STRADALE'),
    (21, 'VEICOLO GENERICO')
ON CONFLICT (ana_tipo_mezzo_id) DO NOTHING;

-- Aggiornamento della sequenza per evitare conflitti futuri
SELECT setval(pg_get_serial_sequence('ana_tipo_mezzi', 'ana_tipo_mezzo_id'), (SELECT MAX(ana_tipo_mezzo_id) FROM ana_tipo_mezzi));
