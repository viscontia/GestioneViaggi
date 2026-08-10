-- I blocchi trasportano social e icona (segue lo script 519).
--
-- Copiati sul blocco e non risolti dalla rubrica al rendering, per la stessa ragione dell'URL:
-- una newsletter gia' inviata non deve cambiare aspetto se in rubrica si sostituisce l'icona o si
-- cancella la riga. Il legame indirizzo_id_fk resta per l'aggiornamento delle bozze.

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_insert(
    p_azienda_id            INTEGER,
    p_invio_id_fk           BIGINT,
    p_tipo                  VARCHAR,
    p_ordine                INTEGER      DEFAULT NULL,
    p_layout                VARCHAR      DEFAULT 'pieno',
    p_colonne               SMALLINT     DEFAULT 1,
    p_titolo                VARCHAR      DEFAULT NULL,
    p_sottotitolo           VARCHAR      DEFAULT NULL,
    p_corpo_html            TEXT         DEFAULT NULL,
    p_immagine_url          VARCHAR      DEFAULT NULL,
    p_immagine_storage_path VARCHAR      DEFAULT NULL,
    p_immagine_alt          VARCHAR      DEFAULT NULL,
    p_link_url              VARCHAR      DEFAULT NULL,
    p_link_etichetta        VARCHAR      DEFAULT NULL,
    p_data_viaggio_id_fk    INTEGER      DEFAULT NULL,
    p_indirizzo_id_fk       BIGINT       DEFAULT NULL,
    p_social                VARCHAR      DEFAULT NULL,
    p_icona_url             VARCHAR      DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_max INTEGER; v_conta INTEGER; v_ordine INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM web_newsletter_invii
                    WHERE web_newsletter_invii_id = p_invio_id_fk AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'Newsletter non trovata per questa azienda.';
    END IF;

    SELECT max_occorrenze INTO v_max FROM fn_web_newsletter_tipi_blocco() WHERE tipo = p_tipo;
    IF v_max IS NOT NULL THEN
        SELECT count(*) INTO v_conta FROM web_newsletter_blocchi
         WHERE invio_id_fk = p_invio_id_fk AND tipo = p_tipo;
        IF v_conta >= v_max THEN
            RAISE EXCEPTION 'Il blocco "%" puo'' comparire al massimo % volta/e in una newsletter.', p_tipo, v_max;
        END IF;
    END IF;

    IF p_ordine IS NULL THEN
        SELECT COALESCE(MAX(ordine), 0) + 10 INTO v_ordine
          FROM web_newsletter_blocchi WHERE invio_id_fk = p_invio_id_fk AND tipo <> 'footer';
    ELSE
        v_ordine := p_ordine;
    END IF;

    INSERT INTO web_newsletter_blocchi(
        invio_id_fk, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
        immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
        data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, azienda_id)
    VALUES (
        p_invio_id_fk, p_tipo, v_ordine, COALESCE(p_layout,'pieno'), COALESCE(p_colonne,1::SMALLINT),
        p_titolo, p_sottotitolo, p_corpo_html,
        p_immagine_url, p_immagine_storage_path, p_immagine_alt, p_link_url, p_link_etichetta,
        p_data_viaggio_id_fk, p_indirizzo_id_fk,
        NULLIF(btrim(COALESCE(p_social,'')), ''), p_icona_url, p_azienda_id)
    RETURNING web_newsletter_blocchi_id INTO v_id;

    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_update(
    p_id                    BIGINT,
    p_azienda_id            INTEGER,
    p_layout                VARCHAR      DEFAULT NULL,
    p_colonne               SMALLINT     DEFAULT NULL,
    p_titolo                VARCHAR      DEFAULT NULL,
    p_sottotitolo           VARCHAR      DEFAULT NULL,
    p_corpo_html            TEXT         DEFAULT NULL,
    p_immagine_url          VARCHAR      DEFAULT NULL,
    p_immagine_storage_path VARCHAR      DEFAULT NULL,
    p_immagine_alt          VARCHAR      DEFAULT NULL,
    p_link_url              VARCHAR      DEFAULT NULL,
    p_link_etichetta        VARCHAR      DEFAULT NULL,
    p_data_viaggio_id_fk    INTEGER      DEFAULT NULL,
    p_indirizzo_id_fk       BIGINT       DEFAULT NULL,
    p_social                VARCHAR      DEFAULT NULL,
    p_icona_url             VARCHAR      DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_blocchi
       SET layout                = COALESCE(p_layout, layout),
           colonne               = COALESCE(p_colonne, colonne),
           titolo                = p_titolo,
           sottotitolo           = p_sottotitolo,
           corpo_html            = p_corpo_html,
           immagine_url          = p_immagine_url,
           immagine_storage_path = p_immagine_storage_path,
           immagine_alt          = p_immagine_alt,
           link_url              = p_link_url,
           link_etichetta        = p_link_etichetta,
           data_viaggio_id_fk    = p_data_viaggio_id_fk,
           indirizzo_id_fk       = p_indirizzo_id_fk,
           social                = NULLIF(btrim(COALESCE(p_social,'')), ''),
           icona_url             = p_icona_url
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- Clonazione: social e icona seguono il blocco.
CREATE OR REPLACE FUNCTION fn_web_newsletter_clona(
    p_invio_id      BIGINT,
    p_azienda_id    INTEGER,
    p_nuovo_oggetto VARCHAR DEFAULT NULL,
    p_come_modello  BOOLEAN DEFAULT false)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_nuovo BIGINT; v_oggetto VARCHAR;
BEGIN
    SELECT oggetto INTO v_oggetto FROM web_newsletter_invii
     WHERE web_newsletter_invii_id = p_invio_id AND azienda_id = p_azienda_id;
    IF v_oggetto IS NULL THEN
        RAISE EXCEPTION 'Newsletter da clonare non trovata per questa azienda.';
    END IF;

    INSERT INTO web_newsletter_invii(oggetto, corpo_html, stato, azienda_id, is_modello)
    VALUES (COALESCE(NULLIF(btrim(p_nuovo_oggetto), ''), v_oggetto || ' (copia)'),
            NULL, 'bozza', p_azienda_id, COALESCE(p_come_modello, false))
    RETURNING web_newsletter_invii_id INTO v_nuovo;

    INSERT INTO web_newsletter_blocchi(
        invio_id_fk, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
        immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
        data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, azienda_id)
    SELECT v_nuovo, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
           immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
           data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, azienda_id
      FROM web_newsletter_blocchi
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY ordine;

    RETURN v_nuovo;
END $$;
