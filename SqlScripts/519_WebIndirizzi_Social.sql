-- I pulsanti social sono una categoria a parte e vanno resi in modo riconoscibile.
--
-- Un indirizzo della rubrica puo' dichiarare a QUALE social punta. Da li' il pulsante prende:
--   * il colore del marchio (sempre, non serve caricare nulla);
--   * l'icona, SE l'utente ne ha caricata una.
--
-- Perche' l'icona e' un file e non un carattere o un font: nelle email le icone devono essere
-- immagini con URL pubblico. I font di icone non vengono caricati, l'SVG non e' renderizzato da
-- Outlook, e le URI data: nemmeno. Non ci sono alternative.
--
-- L'icona sta sulla RIGA e non in una tabella di icone globali: cosi' si carica dalla stessa form
-- dove si scrive l'indirizzo, senza una seconda schermata da cercare. Se due righe puntano allo
-- stesso social e caricano la stessa icona e' una duplicazione minima e innocua.

ALTER TABLE web_indirizzi ADD COLUMN IF NOT EXISTS social               VARCHAR(20);
ALTER TABLE web_indirizzi ADD COLUMN IF NOT EXISTS icona_url            VARCHAR(500);
ALTER TABLE web_indirizzi ADD COLUMN IF NOT EXISTS icona_storage_path   VARCHAR(500);

ALTER TABLE web_indirizzi DROP CONSTRAINT IF EXISTS chk_web_indirizzi_social;
ALTER TABLE web_indirizzi
    ADD CONSTRAINT chk_web_indirizzi_social
    CHECK (social IS NULL OR social IN ('facebook','instagram','tiktok','youtube'));

COMMENT ON COLUMN web_indirizzi.social IS
'Social a cui punta l''indirizzo: da qui il pulsante prende colore del marchio e icona. NULL = collegamento normale.';
COMMENT ON COLUMN web_indirizzi.icona_url IS
'URL pubblico dell''icona (PNG/JPEG). Facoltativo: senza, il pulsante usa il solo colore del marchio.';

-- Il blocco COPIA social e icona al momento della scelta, come gia' fa con l'URL: una newsletter
-- inviata non deve cambiare aspetto se in rubrica si cambia icona o si cancella la riga.
ALTER TABLE web_newsletter_blocchi ADD COLUMN IF NOT EXISTS social     VARCHAR(20);
ALTER TABLE web_newsletter_blocchi ADD COLUMN IF NOT EXISTS icona_url  VARCHAR(500);

ALTER TABLE web_newsletter_blocchi DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_social;
ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_social
    CHECK (social IS NULL OR social IN ('facebook','instagram','tiktok','youtube'));

-- ============================================================================
-- CRUD rubrica: social e icona
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_web_indirizzi_insert(
    p_azienda_id  INTEGER,
    p_descrizione VARCHAR,
    p_url         VARCHAR,
    p_note        TEXT    DEFAULT NULL,
    p_ordine      INTEGER DEFAULT NULL,
    p_attivo      BOOLEAN DEFAULT true,
    p_social      VARCHAR DEFAULT NULL,
    p_icona_url   VARCHAR DEFAULT NULL,
    p_icona_path  VARCHAR DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_ordine INTEGER;
BEGIN
    IF p_ordine IS NULL THEN
        SELECT COALESCE(MAX(ordine), 0) + 10 INTO v_ordine FROM web_indirizzi WHERE azienda_id = p_azienda_id;
    ELSE
        v_ordine := p_ordine;
    END IF;

    INSERT INTO web_indirizzi(descrizione, url, note, ordine, attivo, azienda_id,
                              social, icona_url, icona_storage_path)
    VALUES (btrim(p_descrizione), btrim(p_url), p_note, v_ordine, COALESCE(p_attivo, true), p_azienda_id,
            NULLIF(btrim(COALESCE(p_social,'')), ''), p_icona_url, p_icona_path)
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
    p_attivo      BOOLEAN DEFAULT true,
    p_social      VARCHAR DEFAULT NULL,
    p_icona_url   VARCHAR DEFAULT NULL,
    p_icona_path  VARCHAR DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_indirizzi
       SET descrizione        = btrim(p_descrizione),
           url                = btrim(p_url),
           note               = p_note,
           ordine             = COALESCE(p_ordine, ordine),
           attivo             = COALESCE(p_attivo, attivo),
           social             = NULLIF(btrim(COALESCE(p_social,'')), ''),
           icona_url          = p_icona_url,
           icona_storage_path = p_icona_path
     WHERE web_indirizzi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
