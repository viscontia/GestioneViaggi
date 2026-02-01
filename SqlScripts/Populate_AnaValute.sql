-- =============================================
-- 3. Dati iniziali valute
-- =============================================
INSERT INTO ana_valute (valuta_codice_iso, valuta_descrizione, valuta_simbolo, valuta_is_base, valuta_decimali, created_by) VALUES
('EUR', 'Euro', '€', TRUE, 2, 'System'),                  -- Valuta base
('USD', 'Dollaro Statunitense', '$', FALSE, 2, 'System'),
('GBP', 'Sterlina Britannica', '£', FALSE, 2, 'System'),
('JPY', 'Yen Giapponese', '¥', FALSE, 0, 'System'),       -- 0 Decimali
('CAD', 'Dollaro Canadese', 'C$', FALSE, 2, 'System'),
('AUD', 'Dollaro Australiano', 'A$', FALSE, 2, 'System'),
('CHF', 'Franco Svizzero', 'CHF', FALSE, 2, 'System'),
('CNY', 'Renminbi Cinese', '¥', FALSE, 2, 'System'),
('ZAR', 'Rand Sudafricano', 'R', FALSE, 2, 'System'),
('BWP', 'Pula Botswana', 'P', FALSE, 2, 'System'),
('NAD', 'Dollaro Namibiano', 'N$', FALSE, 2, 'System'),
('ZMW', 'Kwacha Zambia', 'ZK', FALSE, 2, 'System'),
('MZN', 'Metical Mozambico', 'MT', FALSE, 2, 'System'),
('TZS', 'Scellino Tanzaniano', 'TSh', FALSE, 2, 'System'),
('KES', 'Scellino Keniota', 'KSh', FALSE, 2, 'System')
ON CONFLICT (valuta_codice_iso) DO NOTHING;
