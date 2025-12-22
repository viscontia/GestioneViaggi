-- Script per allineare la sequenza IDENTITY al valore massimo esistente
-- Questo garantisce che il prossimo INSERT generi un ID univoco (MAX + 1)

SELECT setval(
    pg_get_serial_sequence('ana_tipo_mezzi', 'ana_tipo_mezzo_id'), 
    COALESCE((SELECT MAX(ana_tipo_mezzo_id) FROM ana_tipo_mezzi), 0)
);
