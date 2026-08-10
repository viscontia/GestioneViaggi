-- Rubrica degli indirizzi web dell'azienda ("Tabelle web → Indirizzi web").
--
-- Nasce dal collaudo newsletter: per i pulsanti servono URL, ma chiederli all'utente al momento
-- del bisogno non funziona. Le destinazioni predefinite (home, pagina di un tour) coprono i casi
-- comuni e non gli altri: il sito attuale, quello nuovo che verra', pagine gia' esistenti,
-- collegamenti esterni (social, form, mappe). Sono indirizzi che l'azienda conosce una volta e
-- riusa sempre, quindi vanno scritti una volta sola in una tabella sua.
--
-- Il caso che rende utile la tabella: quando il sito nuovo sara' pronto, gli indirizzi cambiano
-- tutti insieme. Con la rubrica si correggono qui e le prossime newsletter sono a posto; senza,
-- andrebbero ricordati a memoria uno per uno.
--
-- Per-azienda, come tutto il resto tranne i lookup dichiarati globali.

CREATE TABLE IF NOT EXISTS web_indirizzi (
    web_indirizzi_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descrizione      VARCHAR(150) NOT NULL,
    url              VARCHAR(500) NOT NULL,
    note             TEXT,
    ordine           INTEGER      NOT NULL DEFAULT 0,
    attivo           BOOLEAN      NOT NULL DEFAULT true,
    azienda_id       INTEGER      NOT NULL,
    created_by       VARCHAR(50)  NOT NULL,
    created          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by       VARCHAR(50),
    updated          TIMESTAMPTZ,

    CONSTRAINT fk_web_indirizzi_azienda
        FOREIGN KEY (azienda_id) REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,

    -- La descrizione e' cio' che l'utente sceglie in tendina: due voci uguali sarebbero
    -- indistinguibili nel momento in cui servono.
    CONSTRAINT uq_web_indirizzi_descrizione UNIQUE (azienda_id, descrizione),

    CONSTRAINT chk_web_indirizzi_descrizione CHECK (length(btrim(descrizione)) >= 2),
    CONSTRAINT chk_web_indirizzi_url CHECK (btrim(url) ~* '^https?://.+')
);

CREATE INDEX IF NOT EXISTS idx_web_indirizzi_azienda ON web_indirizzi(azienda_id, ordine);

DROP TRIGGER IF EXISTS trg_web_indirizzi_audit ON web_indirizzi;
CREATE TRIGGER trg_web_indirizzi_audit
    BEFORE INSERT OR UPDATE ON web_indirizzi
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();

COMMENT ON TABLE web_indirizzi IS
'Rubrica per-azienda degli indirizzi web riutilizzabili (sito attuale, sito nuovo, pagine, link esterni). Usata dai pulsanti della newsletter.';
COMMENT ON COLUMN web_indirizzi.descrizione IS
'Nome con cui l''utente lo riconosce in tendina ("Home sito", "Pagina contatti", "Facebook").';

-- ============================================================================
-- CRUD
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_web_indirizzi_list(p_azienda_id INTEGER, p_solo_attivi BOOLEAN DEFAULT false)
RETURNS SETOF web_indirizzi
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_indirizzi
     WHERE azienda_id = p_azienda_id
       AND (NOT COALESCE(p_solo_attivi, false) OR attivo)
     ORDER BY ordine, descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_web_indirizzi_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_indirizzi
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_indirizzi WHERE web_indirizzi_id = p_id AND azienda_id = p_azienda_id;
$$;

CREATE OR REPLACE FUNCTION fn_web_indirizzi_insert(
    p_azienda_id  INTEGER,
    p_descrizione VARCHAR,
    p_url         VARCHAR,
    p_note        TEXT    DEFAULT NULL,
    p_ordine      INTEGER DEFAULT NULL,
    p_attivo      BOOLEAN DEFAULT true)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_ordine INTEGER;
BEGIN
    IF p_ordine IS NULL THEN
        SELECT COALESCE(MAX(ordine), 0) + 10 INTO v_ordine FROM web_indirizzi WHERE azienda_id = p_azienda_id;
    ELSE
        v_ordine := p_ordine;
    END IF;

    INSERT INTO web_indirizzi(descrizione, url, note, ordine, attivo, azienda_id)
    VALUES (btrim(p_descrizione), btrim(p_url), p_note, v_ordine, COALESCE(p_attivo, true), p_azienda_id)
    RETURNING web_indirizzi_id INTO v_id;

    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_indirizzi_update(
    p_id          BIGINT,
    p_azienda_id  INTEGER,
    p_descrizione VARCHAR,
    p_url         VARCHAR,
    p_note        TEXT    DEFAULT NULL,
    p_ordine      INTEGER DEFAULT NULL,
    p_attivo      BOOLEAN DEFAULT true)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_indirizzi
       SET descrizione = btrim(p_descrizione),
           url         = btrim(p_url),
           note        = p_note,
           ordine      = COALESCE(p_ordine, ordine),
           attivo      = COALESCE(p_attivo, attivo)
     WHERE web_indirizzi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION fn_web_indirizzi_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    -- Nessun vincolo verso i blocchi newsletter: il pulsante conserva l'URL scelto, non un
    -- riferimento. Cancellare un indirizzo dalla rubrica non deve rompere le newsletter gia'
    -- composte - il collegamento resta quello che era al momento della scelta.
    DELETE FROM web_indirizzi WHERE web_indirizzi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
