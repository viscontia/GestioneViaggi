
-- 90_Optimize_MovClientiViaggi.sql
-- DESCRIZIONE: Aggiunta FK mancanti e rimozione indici ridondanti per mov_clienti_viaggi
-- DATA: 2026-01-15
-- AUTORE: Antigravity

DO $$
BEGIN
    -- 1. AGGIUNTA FOREIGN KEYS
    
    -- FK su cliente_id_fk
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_viaggi_cliente') THEN
        ALTER TABLE mov_clienti_viaggi
        ADD CONSTRAINT fk_mov_clienti_viaggi_cliente
        FOREIGN KEY (cliente_id_fk) REFERENCES ana_clienti(cliente_id)
        ON DELETE RESTRICT;
    END IF;

    -- FK su tipo_partecipante_id_fk
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_viaggi_tipo_part') THEN
        ALTER TABLE mov_clienti_viaggi
        ADD CONSTRAINT fk_mov_clienti_viaggi_tipo_part
        FOREIGN KEY (tipo_partecipante_id_fk) REFERENCES ana_tipo_partecipante(tipo_partecipante_id)
        ON DELETE RESTRICT;
    END IF;

    -- FK su cliente_pilota_id_fk
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_viaggi_pilota') THEN
        ALTER TABLE mov_clienti_viaggi
        ADD CONSTRAINT fk_mov_clienti_viaggi_pilota
        FOREIGN KEY (cliente_pilota_id_fk) REFERENCES ana_clienti(cliente_id)
        ON DELETE RESTRICT;
    END IF;

    -- 2. RIMOZIONE INDICI RIDONDANTI
    -- Nota: idx01 (viaggio_id_fk) ridondante con idx_mov_clienti_viaggi_viaggio
    -- Nota: idx02 (data_viaggio_id_fk) ridondante con idx_mov_clienti_viaggi_data
    -- Nota: idx03 (cliente_id_fk) ridondante con idx_mov_clienti_viaggi_cliente

    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'mov_clienti_viaggi_idx01') THEN
        DROP INDEX mov_clienti_viaggi_idx01;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'mov_clienti_viaggi_idx02') THEN
        DROP INDEX mov_clienti_viaggi_idx02;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'mov_clienti_viaggi_idx03') THEN
        DROP INDEX mov_clienti_viaggi_idx03;
    END IF;

END $$;
