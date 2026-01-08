-- Add FK for mov_clienti_viaggi
ALTER TABLE mov_clienti_viaggi
ADD CONSTRAINT fk_mov_clienti_viaggi_viaggio FOREIGN KEY (viaggio_id_fk) REFERENCES ana_viaggi(viaggio_id) ON DELETE RESTRICT;
-- Add FK for mov_clienti_alloggi
ALTER TABLE mov_clienti_alloggi
ADD CONSTRAINT fk_mov_clienti_alloggi_viaggio FOREIGN KEY (viaggio_id_fk) REFERENCES ana_viaggi(viaggio_id) ON DELETE RESTRICT;