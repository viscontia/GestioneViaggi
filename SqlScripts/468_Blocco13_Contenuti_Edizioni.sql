-- ========================================
-- Script: 468_Blocco13_Contenuti_Edizioni.sql
-- Blocco 13 — Fase A: web_tour_contenuti diventa figlio di (viaggio + data_viaggio).
-- Il contenuto NON e' piu' 1:1 col viaggio ma 1:1 con l'edizione (ana_date_viaggi).
-- difficolta rimossa (ora ana_viaggi.viaggio_difficolta, letta live dal web).
-- Migrazione a freddo: nessun contenuto web esistente.
-- ========================================

-- 1. Schema web_tour_contenuti
ALTER TABLE web_tour_contenuti
    ADD COLUMN IF NOT EXISTS data_viaggio_id_fk INTEGER;

-- FK verso l'edizione (ana_date_viaggi PK = data_viaggio_id INTEGER)
ALTER TABLE web_tour_contenuti DROP CONSTRAINT IF EXISTS fk_web_tour_contenuti_data_viaggio;
ALTER TABLE web_tour_contenuti ADD CONSTRAINT fk_web_tour_contenuti_data_viaggio
    FOREIGN KEY (data_viaggio_id_fk) REFERENCES ana_date_viaggi(data_viaggio_id);

-- La colonna e' obbligatoria (tabella vuota -> NOT NULL diretto)
ALTER TABLE web_tour_contenuti ALTER COLUMN data_viaggio_id_fk SET NOT NULL;

-- Togliere il vecchio 1:1 su viaggio (UNIQUE inline auto-nominato) e mettere il 1:1 su edizione
ALTER TABLE web_tour_contenuti DROP CONSTRAINT IF EXISTS web_tour_contenuti_viaggio_id_fk_key;
ALTER TABLE web_tour_contenuti DROP CONSTRAINT IF EXISTS uq_web_tour_contenuti_data_viaggio;
ALTER TABLE web_tour_contenuti ADD CONSTRAINT uq_web_tour_contenuti_data_viaggio UNIQUE (data_viaggio_id_fk);

-- Rimuovere difficolta (spostata in ana_viaggi.viaggio_difficolta)
ALTER TABLE web_tour_contenuti DROP CONSTRAINT IF EXISTS chk_web_tour_contenuti_difficolta;
ALTER TABLE web_tour_contenuti DROP COLUMN IF EXISTS difficolta;

-- 2. CRUD: insert/update cambiano firma (drop vecchia + ricrea)
DROP FUNCTION IF EXISTS fn_web_tour_contenuti_insert(
    INTEGER, INTEGER, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, TEXT, TEXT, TEXT, TEXT, TEXT,
    VARCHAR, VARCHAR, VARCHAR, INTEGER, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_insert(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_data_viaggio_id_fk INTEGER,
    p_slug VARCHAR,
    p_sottotitolo VARCHAR DEFAULT NULL,
    p_descrizione_html TEXT DEFAULT NULL,
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
        viaggio_id_fk, data_viaggio_id_fk, sottotitolo, descrizione_html, durata_testo, luoghi_visitati,
        info_pernottamento_html, info_pasti_html, info_equipaggiamento_html, altre_info_html,
        slug, meta_title, meta_description, stato_pubblicazione, ordine, data_pubblicazione, azienda_id)
    VALUES (
        p_viaggio_id_fk, p_data_viaggio_id_fk, p_sottotitolo, p_descrizione_html, p_durata_testo, p_luoghi_visitati,
        p_info_pernottamento_html, p_info_pasti_html, p_info_equipaggiamento_html, p_altre_info_html,
        p_slug, p_meta_title, p_meta_description, p_stato_pubblicazione, p_ordine, p_data_pubblicazione, p_azienda_id)
    RETURNING web_tour_contenuti_id INTO v_id;
    RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS fn_web_tour_contenuti_update(
    BIGINT, INTEGER, INTEGER, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, TEXT, TEXT, TEXT, TEXT, TEXT,
    VARCHAR, VARCHAR, VARCHAR, INTEGER, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_data_viaggio_id_fk INTEGER,
    p_slug VARCHAR,
    p_sottotitolo VARCHAR,
    p_descrizione_html TEXT,
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
       SET viaggio_id_fk=p_viaggio_id_fk, data_viaggio_id_fk=p_data_viaggio_id_fk,
           sottotitolo=p_sottotitolo, descrizione_html=p_descrizione_html,
           durata_testo=p_durata_testo, luoghi_visitati=p_luoghi_visitati,
           info_pernottamento_html=p_info_pernottamento_html, info_pasti_html=p_info_pasti_html,
           info_equipaggiamento_html=p_info_equipaggiamento_html, altre_info_html=p_altre_info_html,
           slug=p_slug, meta_title=p_meta_title, meta_description=p_meta_description,
           stato_pubblicazione=p_stato_pubblicazione, ordine=p_ordine, data_pubblicazione=p_data_pubblicazione
     WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- 3. GET per edizione (nuova relazione 1:1) — usata dalla UI al posto di get_by_viaggio
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_get_by_data_viaggio(p_data_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS SETOF web_tour_contenuti LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_contenuti
    WHERE data_viaggio_id_fk = p_data_viaggio_id AND azienda_id = p_azienda_id;
$$;

-- fn_web_tour_contenuti_get_by_viaggio: invariata come firma ma ora ritorna N righe
-- (una per edizione del viaggio) — i chiamanti non devono piu' trattarla come singola.

-- 4. Elenco edizioni di un viaggio per il SELETTORE EDIZIONE (Fase E):
--    ogni data del viaggio con stato contenuto (con/senza) ed effettuazione (Y/N).
CREATE OR REPLACE FUNCTION fn_web_edizioni_per_viaggio(p_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS TABLE (
    data_viaggio_id INTEGER,
    data_inizio DATE,
    data_fine DATE,
    effettuato_sino CHAR(1),
    web_tour_contenuti_id BIGINT,
    stato_pubblicazione VARCHAR
) LANGUAGE sql STABLE AS $$
    SELECT d.data_viaggio_id,
           d.data_viaggio_data_inizio,
           d.data_viaggio_data_fine,
           d.data_viaggio_effettuato_sino,
           c.web_tour_contenuti_id,
           c.stato_pubblicazione
      FROM ana_date_viaggi d
      LEFT JOIN web_tour_contenuti c
             ON c.data_viaggio_id_fk = d.data_viaggio_id AND c.azienda_id = p_azienda_id
     WHERE d.viaggio_id_fk = p_viaggio_id AND d.azienda_id = p_azienda_id
     ORDER BY d.data_viaggio_data_inizio DESC;
$$;
