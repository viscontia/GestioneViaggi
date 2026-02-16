-- Script per inserire SOLO i tassi di cambio EUR -> EUR (ID 2 -> 2)
-- Senza BEGIN/COMMIT esplicito per gestire meglio gli errori singoli

INSERT INTO ana_tassi_cambio (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, created_by)
VALUES ('2026-01-15', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk) DO NOTHING;

INSERT INTO ana_tassi_cambio (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, created_by)
VALUES ('2026-01-20', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk) DO NOTHING;

INSERT INTO ana_tassi_cambio (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, created_by)
VALUES ('2026-02-10', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk) DO NOTHING;

INSERT INTO ana_tassi_cambio (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, created_by)
VALUES ('2026-03-05', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk) DO NOTHING;

INSERT INTO ana_tassi_cambio (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_valore, created_by)
VALUES ('2026-04-12', 2, 2, 1.0, 'dcba3981-ff43-4ea7-a241-d50fb62a778e')
ON CONFLICT (tasso_data_validita, tasso_valuta_da_fk, tasso_valuta_a_fk) DO NOTHING;
