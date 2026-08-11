-- Libreria immagini dell'azienda: icone e immagini generiche non legate ad alcun viaggio.
--
-- Nasce da un limite reale: il picker della newsletter pescava dalle sole gallerie dei tour, e
-- caricare li' anche le icone (euro, fuoristrada, "aperte le iscrizioni") avrebbe mescolato due
-- cose diverse — le foto di UN viaggio e il materiale grafico dell'azienda — rendendo la scelta
-- via via piu' difficile man mano che l'archivio cresce.
--
-- I file vivono sotto il prefisso "libreria/{azienda}/" su Storage, separato da quello dei tour.
-- Un bucket distinto avrebbe richiesto una nuova configurazione e nuove policy: la separazione
-- che serve qui e' logica, e il prefisso la garantisce.

CREATE TABLE IF NOT EXISTS web_immagini_libreria (
    web_immagini_libreria_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descrizione   VARCHAR(150) NOT NULL,
    url           VARCHAR(500) NOT NULL,
    storage_path  VARCHAR(500) NOT NULL,
    mime          VARCHAR(50),
    larghezza     INTEGER,
    altezza       INTEGER,
    ordine        INTEGER      NOT NULL DEFAULT 0,
    azienda_id    INTEGER      NOT NULL,
    created_by    VARCHAR(50)  NOT NULL,
    created       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by    VARCHAR(50),
    updated       TIMESTAMPTZ,

    CONSTRAINT fk_web_immagini_libreria_azienda
        FOREIGN KEY (azienda_id) REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    CONSTRAINT uq_web_immagini_libreria_path UNIQUE (storage_path),
    CONSTRAINT chk_web_immagini_libreria_descrizione CHECK (length(btrim(descrizione)) >= 2)
);

CREATE INDEX IF NOT EXISTS idx_web_immagini_libreria_azienda ON web_immagini_libreria(azienda_id, ordine);

DROP TRIGGER IF EXISTS trg_web_immagini_libreria_audit ON web_immagini_libreria;
CREATE TRIGGER trg_web_immagini_libreria_audit
    BEFORE INSERT OR UPDATE ON web_immagini_libreria
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();

COMMENT ON TABLE web_immagini_libreria IS
'Icone e immagini generiche per-azienda, non legate a un viaggio. Usate dai blocchi della newsletter.';

-- ============================================================================
-- CRUD
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_web_immagini_libreria_list(p_azienda_id INTEGER)
RETURNS SETOF web_immagini_libreria
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_immagini_libreria
     WHERE azienda_id = p_azienda_id
     ORDER BY ordine, descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_web_immagini_libreria_insert(
    p_azienda_id   INTEGER,
    p_descrizione  VARCHAR,
    p_url          VARCHAR,
    p_storage_path VARCHAR,
    p_mime         VARCHAR DEFAULT NULL,
    p_larghezza    INTEGER DEFAULT NULL,
    p_altezza      INTEGER DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_ordine INTEGER;
BEGIN
    SELECT COALESCE(MAX(ordine), 0) + 10 INTO v_ordine
      FROM web_immagini_libreria WHERE azienda_id = p_azienda_id;

    INSERT INTO web_immagini_libreria(descrizione, url, storage_path, mime, larghezza, altezza, ordine, azienda_id)
    VALUES (btrim(p_descrizione), p_url, p_storage_path, p_mime, p_larghezza, p_altezza, v_ordine, p_azienda_id)
    RETURNING web_immagini_libreria_id INTO v_id;

    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_immagini_libreria_rinomina(
    p_id BIGINT, p_azienda_id INTEGER, p_descrizione VARCHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_immagini_libreria SET descrizione = btrim(p_descrizione)
     WHERE web_immagini_libreria_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- ============================================================================
-- Integrita' verso le newsletter
-- ============================================================================
-- I blocchi COPIANO url e storage_path, non li referenziano: e' voluto, perche' una newsletter
-- inviata non deve cambiare aspetto. Ma il FILE su Storage e' uno solo: cancellarlo lascerebbe
-- immagini rotte nelle bozze e — peggio — nell'archivio di cio' che e' gia' stato spedito.
-- Da qui il controllo d'uso, sullo stesso schema di fn_web_immagini_in_uso (script 488).

CREATE OR REPLACE FUNCTION fn_web_immagini_libreria_in_uso(p_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(oggetto VARCHAR, stato VARCHAR, blocchi INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT i.oggetto, i.stato, count(*)::INTEGER
      FROM web_newsletter_blocchi b
      JOIN web_newsletter_invii   i ON i.web_newsletter_invii_id = b.invio_id_fk
      JOIN web_immagini_libreria  l ON l.web_immagini_libreria_id = p_id
     WHERE b.azienda_id = p_azienda_id
       AND b.immagine_storage_path = l.storage_path
     GROUP BY i.oggetto, i.stato
     ORDER BY i.stato, i.oggetto;
$$;

CREATE OR REPLACE FUNCTION fn_web_immagini_libreria_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER; v_usi INTEGER;
BEGIN
    SELECT COALESCE(sum(blocchi), 0) INTO v_usi
      FROM fn_web_immagini_libreria_in_uso(p_id, p_azienda_id);

    IF v_usi > 0 THEN
        RAISE EXCEPTION 'Immagine usata in % blocchi di newsletter: rimuovila prima da quelle newsletter.', v_usi;
    END IF;

    DELETE FROM web_immagini_libreria
     WHERE web_immagini_libreria_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
