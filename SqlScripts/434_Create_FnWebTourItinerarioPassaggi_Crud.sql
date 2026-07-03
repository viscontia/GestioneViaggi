-- Funzioni CRUD per web_tour_itinerario_passaggi (Blocco 2 estensione web).
-- N passaggi per giornata: la list e' scoped per itinerario (fn_web_tour_itinerario_passaggi_list).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default); colonne di audit valorizzate da trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_insert(
    p_azienda_id INTEGER,
    p_itinerario_id_fk BIGINT,
    p_testo_html TEXT,
    p_immagine_url TEXT DEFAULT NULL,
    p_immagine_storage_path VARCHAR DEFAULT NULL,
    p_immagine_didascalia VARCHAR DEFAULT NULL,
    p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_itinerario_passaggi(
        itinerario_id_fk, testo_html, immagine_url, immagine_storage_path, immagine_didascalia, ordine, azienda_id)
    VALUES (
        p_itinerario_id_fk, p_testo_html, p_immagine_url, p_immagine_storage_path, p_immagine_didascalia, p_ordine, p_azienda_id)
    RETURNING web_tour_itinerario_passaggi_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per itinerario (scoped per azienda), ordinata per ordine
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_list(p_itinerario_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_itinerario_passaggi LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_itinerario_passaggi
     WHERE itinerario_id_fk = p_itinerario_id AND azienda_id = p_azienda_id
     ORDER BY ordine;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_itinerario_passaggi LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_itinerario_passaggi WHERE web_tour_itinerario_passaggi_id = p_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_itinerario_id_fk BIGINT,
    p_testo_html TEXT,
    p_immagine_url TEXT,
    p_immagine_storage_path VARCHAR,
    p_immagine_didascalia VARCHAR,
    p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario_passaggi
       SET itinerario_id_fk=p_itinerario_id_fk, testo_html=p_testo_html, immagine_url=p_immagine_url,
           immagine_storage_path=p_immagine_storage_path, immagine_didascalia=p_immagine_didascalia, ordine=p_ordine
     WHERE web_tour_itinerario_passaggi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tour_itinerario_passaggi WHERE web_tour_itinerario_passaggi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
