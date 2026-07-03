-- Funzioni CRUD per web_tour_immagini (Blocco 2 estensione web).
-- N immagini per viaggio: la list e' scoped per viaggio (fn_web_tour_immagini_list).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default); colonne di audit valorizzate da trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_insert(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
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
        viaggio_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, ordine, azienda_id)
    VALUES (
        p_viaggio_id_fk, p_tipo, p_url, p_storage_path, p_alt_text, p_titolo, p_larghezza, p_altezza, p_mime, p_ordine, p_azienda_id)
    RETURNING web_tour_immagini_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per viaggio (scoped per azienda), ordinata per tipo e ordine
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_list(p_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS SETOF web_tour_immagini LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_immagini
     WHERE viaggio_id_fk = p_viaggio_id AND azienda_id = p_azienda_id
     ORDER BY tipo, ordine;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_immagini LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_immagini WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
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
       SET viaggio_id_fk=p_viaggio_id_fk, tipo=p_tipo, url=p_url, storage_path=p_storage_path,
           alt_text=p_alt_text, titolo=p_titolo, larghezza=p_larghezza, altezza=p_altezza, mime=p_mime, ordine=p_ordine
     WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tour_immagini WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
