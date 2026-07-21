-- 487_WebTourImmagini_NomeFile.sql
-- Blocco 7 (Galleria) — aggiunge nome_file a web_tour_immagini per il dedup upload
-- (stesso nome file caricato due volte sullo stesso contenuto). Tabella non vuota in produzione:
-- colonna nullable, nessun backfill necessario (righe esistenti restano NULL, non partecipano al dedup).

BEGIN;

ALTER TABLE web_tour_immagini
    ADD COLUMN IF NOT EXISTS nome_file VARCHAR(255);

-- INSERT: nuovo parametro p_nome_file in coda (default NULL, backward-compatible sui valori)
DROP FUNCTION IF EXISTS fn_web_tour_immagini_insert(
    INTEGER, BIGINT, TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, VARCHAR, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_insert(
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_url TEXT,
    p_storage_path VARCHAR,
    p_tipo VARCHAR DEFAULT 'galleria',
    p_alt_text VARCHAR DEFAULT NULL,
    p_titolo VARCHAR DEFAULT NULL,
    p_larghezza INTEGER DEFAULT NULL,
    p_altezza INTEGER DEFAULT NULL,
    p_mime VARCHAR DEFAULT NULL,
    p_ordine INTEGER DEFAULT 0,
    p_nome_file VARCHAR DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_immagini(
        web_tour_contenuti_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, ordine, nome_file, azienda_id)
    VALUES (
        p_web_tour_contenuti_id_fk, p_tipo, p_url, p_storage_path, p_alt_text, p_titolo, p_larghezza, p_altezza, p_mime, p_ordine, p_nome_file, p_azienda_id)
    RETURNING web_tour_immagini_id INTO v_id;
    RETURN v_id;
END $$;

-- UPDATE: nuovo parametro p_nome_file in coda (default NULL)
DROP FUNCTION IF EXISTS fn_web_tour_immagini_update(
    BIGINT, INTEGER, BIGINT, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, VARCHAR, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_tipo VARCHAR,
    p_url TEXT,
    p_storage_path VARCHAR,
    p_alt_text VARCHAR,
    p_titolo VARCHAR,
    p_larghezza INTEGER,
    p_altezza INTEGER,
    p_mime VARCHAR,
    p_ordine INTEGER,
    p_nome_file VARCHAR DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini
       SET web_tour_contenuti_id_fk=p_web_tour_contenuti_id_fk, tipo=p_tipo, url=p_url, storage_path=p_storage_path,
           alt_text=p_alt_text, titolo=p_titolo, larghezza=p_larghezza, altezza=p_altezza, mime=p_mime, ordine=p_ordine,
           nome_file=p_nome_file
     WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

COMMIT;
