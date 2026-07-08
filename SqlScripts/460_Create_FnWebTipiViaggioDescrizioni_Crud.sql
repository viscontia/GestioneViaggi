-- Funzioni CRUD per web_tipi_viaggio_descrizioni (Blocco 8, ex web_categorie_sport).
-- Tabella GLOBALE (niente azienda_id): le funzioni NON sono scopate per azienda.
-- Convenzione: SECURITY INVOKER; audit via trg_web_tipi_viaggio_descrizioni_audit;
-- insert ritorna il nuovo id; update/delete ritornano righe (0/1); unique(slug) propaga (tradotto da DbErrorTranslator).

-- Drop delle vecchie funzioni per-azienda (fn_web_categorie_sport_*): la tabella è stata rinominata/snellita.
DROP FUNCTION IF EXISTS fn_web_categorie_sport_insert(integer, varchar, varchar, varchar, integer);
DROP FUNCTION IF EXISTS fn_web_categorie_sport_get(bigint, integer);
DROP FUNCTION IF EXISTS fn_web_categorie_sport_update(bigint, integer, varchar, varchar, varchar, integer);
DROP FUNCTION IF EXISTS fn_web_categorie_sport_delete(bigint, integer);
DROP FUNCTION IF EXISTS fn_web_categorie_sport_list(integer);

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tipi_viaggio_descrizioni_insert(
    p_descrizione_web VARCHAR,
    p_slug VARCHAR,
    p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tipi_viaggio_descrizioni(descrizione_web, slug, ordine)
    VALUES (p_descrizione_web, p_slug, p_ordine)
    RETURNING web_tipi_viaggio_descrizioni_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST (globale), ordinata per ordine poi descrizione
CREATE OR REPLACE FUNCTION fn_web_tipi_viaggio_descrizioni_list()
RETURNS SETOF web_tipi_viaggio_descrizioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tipi_viaggio_descrizioni ORDER BY ordine, descrizione_web;
$$;

-- GET singolo
CREATE OR REPLACE FUNCTION fn_web_tipi_viaggio_descrizioni_get(p_id BIGINT)
RETURNS SETOF web_tipi_viaggio_descrizioni LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tipi_viaggio_descrizioni WHERE web_tipi_viaggio_descrizioni_id = p_id;
$$;

-- UPDATE -> righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tipi_viaggio_descrizioni_update(
    p_id BIGINT,
    p_descrizione_web VARCHAR,
    p_slug VARCHAR,
    p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tipi_viaggio_descrizioni
       SET descrizione_web = p_descrizione_web, slug = p_slug, ordine = p_ordine
     WHERE web_tipi_viaggio_descrizioni_id = p_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE -> righe eliminate (0/1). La FK ana_tipo_viaggi.descrizione_web_fk è ON DELETE SET NULL.
CREATE OR REPLACE FUNCTION fn_web_tipi_viaggio_descrizioni_delete(p_id BIGINT)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tipi_viaggio_descrizioni WHERE web_tipi_viaggio_descrizioni_id = p_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
