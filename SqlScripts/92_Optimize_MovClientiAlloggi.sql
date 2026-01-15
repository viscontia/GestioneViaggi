
-- 92_Optimize_MovClientiAlloggi.sql
-- DESCRIZIONE: Aggiunta FK e ottimizzazione indici per mov_clienti_alloggi
-- DATA: 2026-01-15
-- AUTORE: Antigravity

DO $$
BEGIN
    -- 1. AGGIUNTA FOREIGN KEYS
    -- Cliente 1
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl1') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl1 FOREIGN KEY (cliente_id1_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;
    -- Cliente 2
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl2') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl2 FOREIGN KEY (cliente_id2_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;
    -- Cliente 3
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl3') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl3 FOREIGN KEY (cliente_id3_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;
    -- Cliente 4
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl4') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl4 FOREIGN KEY (cliente_id4_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;
    -- Cliente 5
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl5') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl5 FOREIGN KEY (cliente_id5_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;
    -- Cliente 6
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_mov_clienti_alloggi_cl6') THEN
        ALTER TABLE mov_clienti_alloggi ADD CONSTRAINT fk_mov_clienti_alloggi_cl6 FOREIGN KEY (cliente_id6_fk) REFERENCES ana_clienti(cliente_id) ON DELETE RESTRICT;
    END IF;

    -- 2. OTTIMIZZAZIONE INDICI
    -- Rimuovi indice vecchio/non standard se esiste
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cliente1') THEN
        DROP INDEX idx_mov_clienti_alloggi_cliente1;
    END IF;

    -- Aggiungi indici standard per ogni FK (se non esistono)
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl1') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl1 ON mov_clienti_alloggi(cliente_id1_fk);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl2') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl2 ON mov_clienti_alloggi(cliente_id2_fk);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl3') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl3 ON mov_clienti_alloggi(cliente_id3_fk);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl4') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl4 ON mov_clienti_alloggi(cliente_id4_fk);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl5') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl5 ON mov_clienti_alloggi(cliente_id5_fk);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_mov_clienti_alloggi_cl6') THEN
        CREATE INDEX idx_mov_clienti_alloggi_cl6 ON mov_clienti_alloggi(cliente_id6_fk);
    END IF;

END $$;
