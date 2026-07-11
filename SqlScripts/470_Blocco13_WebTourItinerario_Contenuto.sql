-- ============================================================================
-- Blocco 13 re-model: ri-ancoraggio web_tour_itinerario da VIAGGIO a CONTENUTO
-- Le giornate dell'itinerario pendono ora da web_tour_contenuti (figlio di
-- viaggio+data_viaggio), non piu' direttamente da ana_viaggi.
-- Tabella VUOTA: DROP/ADD COLUMN diretti. I passaggi (web_tour_itinerario_passaggi)
-- NON sono toccati: pendono da itinerario_id_fk.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Tabella: viaggio_id_fk INTEGER -> web_tour_contenuti_id_fk BIGINT
--    (drop della colonna rimuove anche la unique che la citava)
-- ---------------------------------------------------------------------------
-- Le policy RLS anon (itinerario + passaggi che joina i.viaggio_id_fk) dipendono
-- da viaggio_id_fk: le droppo (ricreate per-contenuto in Fase C).
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_itinerario;
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_itinerario_passaggi;

ALTER TABLE web_tour_itinerario DROP CONSTRAINT IF EXISTS uq_web_tour_itinerario_giorno;
ALTER TABLE web_tour_itinerario DROP COLUMN IF EXISTS viaggio_id_fk;

ALTER TABLE web_tour_itinerario
    ADD COLUMN IF NOT EXISTS web_tour_contenuti_id_fk BIGINT NOT NULL
        REFERENCES web_tour_contenuti(web_tour_contenuti_id) ON DELETE CASCADE;

-- Ricrea la unique sulla nuova colonna, MANTENENDO DEFERRABLE INITIALLY DEFERRED
-- (serve al reorder: swap di giorno_numero in un singolo statement).
ALTER TABLE web_tour_itinerario DROP CONSTRAINT IF EXISTS uq_web_tour_itinerario_giorno;
ALTER TABLE web_tour_itinerario ADD CONSTRAINT uq_web_tour_itinerario_giorno
    UNIQUE (web_tour_contenuti_id_fk, giorno_numero) DEFERRABLE INITIALLY DEFERRED;

-- idx_web_tour_itinerario_azienda invariato (su azienda_id): nessuna azione.

-- ---------------------------------------------------------------------------
-- 2) Funzioni CRUD/reorder: il parametro che portava l'id del viaggio diventa
--    l'id del contenuto (INTEGER -> BIGINT). Cambia il TIPO del parametro:
--    DROP della firma vecchia esatta prima del CREATE OR REPLACE (evita overload).
-- ---------------------------------------------------------------------------

-- INSERT -> ritorna il nuovo id
DROP FUNCTION IF EXISTS fn_web_tour_itinerario_insert(INTEGER, INTEGER, INTEGER, VARCHAR, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_insert(
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_giorno_numero INTEGER,
    p_titolo_giornata VARCHAR,
    p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_tour_itinerario(web_tour_contenuti_id_fk, giorno_numero, titolo_giornata, ordine, azienda_id)
    VALUES (p_web_tour_contenuti_id_fk, p_giorno_numero, p_titolo_giornata, p_ordine, p_azienda_id)
    RETURNING web_tour_itinerario_id INTO v_id;
    RETURN v_id;
END $$;

-- LIST per contenuto (scoped per azienda), ordinata per giorno e ordine
DROP FUNCTION IF EXISTS fn_web_tour_itinerario_list(INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_list(p_web_tour_contenuti_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_tour_itinerario LANGUAGE sql STABLE AS $$
    SELECT * FROM web_tour_itinerario
     WHERE web_tour_contenuti_id_fk = p_web_tour_contenuti_id AND azienda_id = p_azienda_id
     ORDER BY giorno_numero, ordine;
$$;

-- GET singolo: NON cambia (firma p_id BIGINT, p_azienda_id INTEGER) -> non toccata.

-- UPDATE (scoped per azienda) -> ritorna righe modificate (0/1)
DROP FUNCTION IF EXISTS fn_web_tour_itinerario_update(BIGINT, INTEGER, INTEGER, INTEGER, VARCHAR, INTEGER);
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_update(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_giorno_numero INTEGER,
    p_titolo_giornata VARCHAR,
    p_ordine INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario
       SET web_tour_contenuti_id_fk=p_web_tour_contenuti_id_fk, giorno_numero=p_giorno_numero,
           titolo_giornata=p_titolo_giornata, ordine=p_ordine
     WHERE web_tour_itinerario_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- DELETE: NON cambia (firma p_id BIGINT, p_azienda_id INTEGER) -> non toccata.

-- REORDER atomico delle giornate di un contenuto (scoped per azienda + contenuto)
DROP FUNCTION IF EXISTS fn_web_tour_itinerario_reorder(INTEGER, INTEGER, BIGINT[]);
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_reorder(
    p_azienda_id INTEGER,
    p_web_tour_contenuti_id_fk BIGINT,
    p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario g
       SET giorno_numero = x.nuovo_ordine::INTEGER,
           ordine        = x.nuovo_ordine::INTEGER
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE g.web_tour_itinerario_id = x.id
       AND g.web_tour_contenuti_id_fk = p_web_tour_contenuti_id_fk
       AND g.azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

COMMIT;
