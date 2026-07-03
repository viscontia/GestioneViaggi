-- Funzioni CRUD per web_tour_itinerario (Blocco 2 estensione web).
-- N giornate per viaggio: la list e' scoped per viaggio (fn_web_tour_itinerario_list).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default); colonne di audit valorizzate da trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_insert(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_giorno_numero INTEGER,
    p_titolo_giornata VARCHAR,
    p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_itinerario(viaggio_id_fk, giorno_numero, titolo_giornata, ordine, azienda_id)
    VALUES (p_viaggio_id_fk, p_giorno_numero, p_titolo_giornata, p_ordine, p_azienda_id)
    RETURNING web_tour_itinerario_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per viaggio (scoped per azienda), ordinata per giorno e ordine
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_list(p_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS SETOF web_tour_itinerario LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_itinerario
     WHERE viaggio_id_fk = p_viaggio_id AND azienda_id = p_azienda_id
     ORDER BY giorno_numero, ordine;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_itinerario LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_itinerario WHERE web_tour_itinerario_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_giorno_numero INTEGER,
    p_titolo_giornata VARCHAR,
    p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario
       SET viaggio_id_fk=p_viaggio_id_fk, giorno_numero=p_giorno_numero,
           titolo_giornata=p_titolo_giornata, ordine=p_ordine
     WHERE web_tour_itinerario_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tour_itinerario WHERE web_tour_itinerario_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
