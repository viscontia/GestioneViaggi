-- 470_Blocco13_WebTourImmagini_RiancoraContenuto.sql
-- Blocco 13 re-model (Fase B): ri-ancora web_tour_immagini dal VIAGGIO al CONTENUTO.
-- La colonna FK viaggio_id_fk INTEGER -> web_tour_contenuti_id_fk BIGINT NOT NULL
--   REFERENCES web_tour_contenuti(web_tour_contenuti_id) ON DELETE CASCADE.
-- Tabella figlia VUOTA: si usa DROP/ADD COLUMN NOT NULL liberamente.
-- Indici e funzioni che citavano viaggio_id_fk ricreati sulla nuova colonna.

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) Tabella: sostituzione colonna FK e ricostruzione indici
-- ----------------------------------------------------------------------------

-- La policy RLS anon dipende da viaggio_id_fk: la droppo (ricreata per-contenuto in Fase C)
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_immagini;

-- Indici che citavano viaggio_id_fk (li droppo prima del cambio colonna)
DROP INDEX IF EXISTS idx_web_tour_immagini_viaggio;
DROP INDEX IF EXISTS uq_web_tour_immagini_principale;
DROP INDEX IF EXISTS idx_web_tour_immagini_contenuto;

-- Cambio colonna FK (INTEGER viaggio -> BIGINT contenuto). Tabella vuota.
ALTER TABLE web_tour_immagini DROP COLUMN IF EXISTS viaggio_id_fk;
ALTER TABLE web_tour_immagini
    ADD COLUMN IF NOT EXISTS web_tour_contenuti_id_fk BIGINT NOT NULL
        REFERENCES web_tour_contenuti(web_tour_contenuti_id) ON DELETE CASCADE;

-- Ricreo gli indici sulla nuova colonna (rinominati _viaggio -> _contenuto)
CREATE INDEX idx_web_tour_immagini_contenuto
    ON web_tour_immagini (web_tour_contenuti_id_fk, tipo, ordine);
-- Regola: una sola immagine tipo='principale' per contenuto
CREATE UNIQUE INDEX uq_web_tour_immagini_principale
    ON web_tour_immagini (web_tour_contenuti_id_fk) WHERE tipo = 'principale';

-- ----------------------------------------------------------------------------
-- 2) Funzioni: DROP firma vecchia (cambia il TIPO del parametro) + CREATE
-- ----------------------------------------------------------------------------

-- INSERT -> ritorna il nuovo id
DROP FUNCTION IF EXISTS fn_web_tour_immagini_insert(
    INTEGER, INTEGER, TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, VARCHAR, INTEGER);
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
    p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_immagini(
        web_tour_contenuti_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, ordine, azienda_id)
    VALUES (
        p_web_tour_contenuti_id_fk, p_tipo, p_url, p_storage_path, p_alt_text, p_titolo, p_larghezza, p_altezza, p_mime, p_ordine, p_azienda_id)
    RETURNING web_tour_immagini_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per contenuto (scoped per azienda), ordinata per tipo e ordine
DROP FUNCTION IF EXISTS fn_web_tour_immagini_list(INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_list(p_web_tour_contenuti_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_immagini LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_immagini
     WHERE web_tour_contenuti_id_fk = p_web_tour_contenuti_id AND azienda_id = p_azienda_id
     ORDER BY tipo, ordine;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
DROP FUNCTION IF EXISTS fn_web_tour_immagini_update(
    BIGINT, INTEGER, INTEGER, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, VARCHAR, INTEGER);
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
    p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini
       SET web_tour_contenuti_id_fk=p_web_tour_contenuti_id_fk, tipo=p_tipo, url=p_url, storage_path=p_storage_path,
           alt_text=p_alt_text, titolo=p_titolo, larghezza=p_larghezza, altezza=p_altezza, mime=p_mime, ordine=p_ordine
     WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- REORDER atomico delle immagini di un contenuto (scoped per azienda+contenuto)
DROP FUNCTION IF EXISTS fn_web_tour_immagini_reorder(INTEGER, INTEGER, BIGINT[]);
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_reorder(
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini i
       SET ordine = x.nuovo_ordine::INTEGER
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE i.web_tour_immagini_id = x.id
       AND i.web_tour_contenuti_id_fk = p_web_tour_contenuti_id_fk
       AND i.azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- SET PRINCIPALE (copertina) del contenuto: due pass atomici (indice unique parziale non deferrable)
DROP FUNCTION IF EXISTS fn_web_tour_immagini_set_principale(BIGINT, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_set_principale(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini
       SET tipo = 'galleria'
     WHERE web_tour_contenuti_id_fk = p_web_tour_contenuti_id_fk AND azienda_id = p_azienda_id AND tipo = 'principale';

    UPDATE web_tour_immagini
       SET tipo = 'principale'
     WHERE web_tour_immagini_id = p_id AND web_tour_contenuti_id_fk = p_web_tour_contenuti_id_fk AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

COMMIT;
