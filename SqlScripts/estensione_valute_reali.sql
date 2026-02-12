-- Inserimento Nuove Valute
INSERT INTO ana_valute (valuta_codice_iso, valuta_descrizione, valuta_simbolo, valuta_is_base, valuta_attiva, valuta_decimali, created_by)
VALUES 
('BGN', 'Lev Bulgaro', 'лв', false, true, 2, 'mirania008@gmail.com'),
('CZK', 'Corona Ceca', 'Kč', false, true, 2, 'mirania008@gmail.com'),
('DKK', 'Corona Danese', 'kr', false, true, 2, 'mirania008@gmail.com'),
('HUF', 'Fiorino Ungherese', 'Ft', false, true, 2, 'mirania008@gmail.com'),
('ISK', 'Corona Islandese', 'kr', false, true, 0, 'mirania008@gmail.com'),
('NOK', 'Corona Norvegese', 'kr', false, true, 2, 'mirania008@gmail.com'),
('PLN', 'Zloty Polacco', 'zł', false, true, 2, 'mirania008@gmail.com'),
('RON', 'Leu Rumeno', 'lei', false, true, 2, 'mirania008@gmail.com'),
('SEK', 'Corona Svedese', 'kr', false, true, 2, 'mirania008@gmail.com'),
('MKD', 'Denaro Macedone', 'ден', false, true, 2, 'mirania008@gmail.com'),
('RSD', 'Dinaro Serbo', 'дин.', false, true, 2, 'mirania008@gmail.com'),
('TRY', 'Lira Turca', '₺', false, true, 2, 'mirania008@gmail.com'),
('UAH', 'Grivnia Ucraina', '₴', false, true, 2, 'mirania008@gmail.com'),
('MAD', 'Dirham Marocchino', 'د.م.', false, true, 2, 'mirania008@gmail.com'),
('TND', 'Dinaro Tunisino', 'د.t', false, true, 3, 'mirania008@gmail.com'),
('DZD', 'Dinaro Algerino', 'د.ج', false, true, 2, 'mirania008@gmail.com'),
('LYD', 'Dinaro Libico', 'ل.د', false, true, 3, 'mirania008@gmail.com'),
('EGP', 'Sterlina Egiziana', 'E£', false, true, 2, 'mirania008@gmail.com')
ON CONFLICT (valuta_codice_iso) DO NOTHING;

-- Inserimento Tassi di Cambio Reali (EUR base)
-- Utilizziamo INSERT ... ON CONFLICT per evitare duplicati se lo script viene rieseguito

-- Frankfurter Rates
INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, tasso_data_validita, tasso_fonte, created_by)
SELECT eur.valuta_id, tar.valuta_id, rates.valore, '2026-02-12', 'MANUAL_REAL', 'mirania008@gmail.com'
FROM ana_valute eur, ana_valute tar, (VALUES 
    ('AUD', 1.6678), ('CAD', 1.6128), ('CHF', 0.9142), ('CNY', 8.1944), 
    ('CZK', 24.245), ('DKK', 7.4712), ('GBP', 0.8711), ('HUF', 379.88), 
    ('ISK', 145.2), ('JPY', 182.52), ('NOK', 11.2535), ('PLN', 4.2158), 
    ('RON', 5.0928), ('SEK', 10.567), ('TRY', 51.829), ('USD', 1.1874), 
    ('ZAR', 18.874), ('BGN', 1.95583), ('MAD', 10.85530), ('TND', 3.4258), 
    ('DZD', 153.8094), ('LYD', 7.4811), ('EGP', 55.5681), ('MKD', 61.646), 
    ('RSD', 117.354), ('UAH', 50.9035), ('ALL', 96.445)
) AS rates(iso, valore)
WHERE eur.valuta_codice_iso = 'EUR' AND tar.valuta_codice_iso = rates.iso
ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;
