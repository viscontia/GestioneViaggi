-- Funzioni CRUD per web_tour_contenuti (Blocco 2 estensione web).
-- 1:1 con il viaggio: la UI carica per viaggio (fn_web_tour_contenuti_get_by_viaggio).
-- Convenzione condivisa (vedi 431_Create_FnWebCategorieSport_Crud.sql):
--   * ogni funzione prende p_azienda_id INTEGER ed e' scoped su di esso (multi-tenant);
--   * SECURITY INVOKER (default);
--   * colonne di audit (created/created_by/updated/updated_by) NON passate: le valorizza trg_web_audit();
--   * insert ritorna il nuovo id; update/delete ritornano il numero di righe (0/1);
--   * niente gestione di 23505: la unique violation propaga (DbErrorTranslator la traduce).

-- INSERT -> ritorna il nuovo id
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_insert(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_slug VARCHAR,
    p_sottotitolo VARCHAR DEFAULT NULL,
    p_descrizione_html TEXT DEFAULT NULL,
    p_difficolta VARCHAR DEFAULT NULL,
    p_durata_testo VARCHAR DEFAULT NULL,
    p_luoghi_visitati TEXT DEFAULT NULL,
    p_info_pernottamento_html TEXT DEFAULT NULL,
    p_info_pasti_html TEXT DEFAULT NULL,
    p_info_equipaggiamento_html TEXT DEFAULT NULL,
    p_altre_info_html TEXT DEFAULT NULL,
    p_meta_title VARCHAR DEFAULT NULL,
    p_meta_description VARCHAR DEFAULT NULL,
    p_stato_pubblicazione VARCHAR DEFAULT 'bozza',
    p_ordine INTEGER DEFAULT 0,
    p_data_pubblicazione TIMESTAMPTZ DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_contenuti(
        viaggio_id_fk, sottotitolo, descrizione_html, difficolta, durata_testo, luoghi_visitati,
        info_pernottamento_html, info_pasti_html, info_equipaggiamento_html, altre_info_html,
        slug, meta_title, meta_description, stato_pubblicazione, ordine, data_pubblicazione, azienda_id)
    VALUES (
        p_viaggio_id_fk, p_sottotitolo, p_descrizione_html, p_difficolta, p_durata_testo, p_luoghi_visitati,
        p_info_pernottamento_html, p_info_pasti_html, p_info_equipaggiamento_html, p_altre_info_html,
        p_slug, p_meta_title, p_meta_description, p_stato_pubblicazione, p_ordine, p_data_pubblicazione, p_azienda_id)
    RETURNING web_tour_contenuti_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per azienda
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_list(p_azienda_id INTEGER)
RETURNS SETOF web_tour_contenuti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_contenuti WHERE azienda_id = p_azienda_id ORDER BY ordine, sottotitolo;
$$;

-- GET singolo (scoped per azienda)
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_contenuti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_contenuti WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
$$;

-- GET per viaggio (1:1): la UI carica il contenuto del viaggio
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_get_by_viaggio(p_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS SETOF web_tour_contenuti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_contenuti WHERE viaggio_id_fk = p_viaggio_id AND azienda_id = p_azienda_id;
$$;

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_slug VARCHAR,
    p_sottotitolo VARCHAR,
    p_descrizione_html TEXT,
    p_difficolta VARCHAR,
    p_durata_testo VARCHAR,
    p_luoghi_visitati TEXT,
    p_info_pernottamento_html TEXT,
    p_info_pasti_html TEXT,
    p_info_equipaggiamento_html TEXT,
    p_altre_info_html TEXT,
    p_meta_title VARCHAR,
    p_meta_description VARCHAR,
    p_stato_pubblicazione VARCHAR,
    p_ordine INTEGER,
    p_data_pubblicazione TIMESTAMPTZ)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_contenuti
       SET viaggio_id_fk=p_viaggio_id_fk, sottotitolo=p_sottotitolo, descrizione_html=p_descrizione_html,
           difficolta=p_difficolta, durata_testo=p_durata_testo, luoghi_visitati=p_luoghi_visitati,
           info_pernottamento_html=p_info_pernottamento_html, info_pasti_html=p_info_pasti_html,
           info_equipaggiamento_html=p_info_equipaggiamento_html, altre_info_html=p_altre_info_html,
           slug=p_slug, meta_title=p_meta_title, meta_description=p_meta_description,
           stato_pubblicazione=p_stato_pubblicazione, ordine=p_ordine, data_pubblicazione=p_data_pubblicazione
     WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE (scoped per azienda) -> ritorna righe eliminate (0/1)
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    DELETE FROM web_tour_contenuti WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
