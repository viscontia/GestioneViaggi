-- Legame fra il pulsante di un blocco e la rubrica indirizzi (web_indirizzi, script 517).
--
-- IL PROBLEMA. Finora il blocco conservava solo l'URL come stringa copiata. Questo protegge
-- l'archivio - una newsletter gia' spedita non deve cambiare retroattivamente se si corregge un
-- indirizzo in rubrica - ma tradisce il caso d'uso che ha motivato la rubrica stessa: al
-- passaggio al sito nuovo, bozze e soprattutto MODELLI resterebbero con gli indirizzi vecchi.
-- E i modelli sono il meccanismo con cui si costruisce il patrimonio di newsletter, avendo
-- escluso l'importazione da Drupal.
--
-- LA SOLUZIONE. Riferimento e copia CONVIVONO:
--   * indirizzo_id_fk = da dove viene il collegamento (NULL se scritto a mano o dedotto dal tour);
--   * link_url        = l'URL effettivo.
-- Finche' la newsletter e' bozza o modello, il rendering risolve il collegamento DALLA RUBRICA:
-- si corregge in un posto solo e tutte le bozze si allineano. Al momento dell'invio l'URL viene
-- congelato in link_url, e da li' in poi la newsletter inviata e' immutabile.
--
-- ON DELETE SET NULL e non RESTRICT: cancellando una voce di rubrica il blocco perde il legame
-- ma TIENE l'ultimo URL noto. Non si rompe e non diventa vuoto.

ALTER TABLE web_newsletter_blocchi
    ADD COLUMN IF NOT EXISTS indirizzo_id_fk BIGINT NULL;

ALTER TABLE web_newsletter_blocchi
    DROP CONSTRAINT IF EXISTS fk_web_newsletter_blocchi_indirizzo;

ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT fk_web_newsletter_blocchi_indirizzo
    FOREIGN KEY (indirizzo_id_fk) REFERENCES web_indirizzi(web_indirizzi_id) ON DELETE SET NULL;

COMMENT ON COLUMN web_newsletter_blocchi.indirizzo_id_fk IS
'Voce di rubrica da cui viene il collegamento. NULL = URL scritto a mano o dedotto dal tour. Su bozze e modelli il rendering risolve da qui; all''invio l''URL viene congelato in link_url.';

-- ============================================================================
-- CRUD: il riferimento entra in insert e update (in coda, parametri con default)
-- ============================================================================

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
    p_indirizzo_id_fk       BIGINT       DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_id     BIGINT;
    v_max    INTEGER;
    v_conta  INTEGER;
    v_ordine INTEGER;
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
          FROM web_newsletter_blocchi
         WHERE invio_id_fk = p_invio_id_fk AND tipo <> 'footer';
    ELSE
        v_ordine := p_ordine;
    END IF;

    INSERT INTO web_newsletter_blocchi(
        invio_id_fk, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
        immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
        data_viaggio_id_fk, indirizzo_id_fk, azienda_id)
    VALUES (
        p_invio_id_fk, p_tipo, v_ordine, COALESCE(p_layout,'pieno'), COALESCE(p_colonne,1::SMALLINT),
        p_titolo, p_sottotitolo, p_corpo_html,
        p_immagine_url, p_immagine_storage_path, p_immagine_alt, p_link_url, p_link_etichetta,
        p_data_viaggio_id_fk, p_indirizzo_id_fk, p_azienda_id)
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
    p_indirizzo_id_fk       BIGINT       DEFAULT NULL)
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
           indirizzo_id_fk       = p_indirizzo_id_fk
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- ============================================================================
-- Clonazione: il riferimento si porta dietro
-- ============================================================================
-- Senza questo, un modello clonato perderebbe proprio il legame che lo tiene aggiornato,
-- cioe' l'unica ragione per cui il riferimento esiste.

CREATE OR REPLACE FUNCTION fn_web_newsletter_clona(
    p_invio_id     BIGINT,
    p_azienda_id   INTEGER,
    p_nuovo_oggetto VARCHAR DEFAULT NULL,
    p_come_modello BOOLEAN DEFAULT false)
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
        data_viaggio_id_fk, indirizzo_id_fk, azienda_id)
    SELECT v_nuovo, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
           immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
           data_viaggio_id_fk, indirizzo_id_fk, azienda_id
      FROM web_newsletter_blocchi
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY ordine;

    RETURN v_nuovo;
END $$;

-- ============================================================================
-- Congelamento all'invio
-- ============================================================================
-- Scrive nei blocchi l'URL corrente della rubrica. Da chiamare PRIMA di comporre l'HTML
-- dell'invio: da quel momento la newsletter e' un documento storico e non deve piu' cambiare
-- se qualcuno corregge la rubrica.

CREATE OR REPLACE FUNCTION fn_web_newsletter_congela_indirizzi(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_blocchi b
       SET link_url = i.url
      FROM web_indirizzi i
     WHERE b.indirizzo_id_fk = i.web_indirizzi_id
       AND b.invio_id_fk = p_invio_id
       AND b.azienda_id  = p_azienda_id
       AND b.link_url IS DISTINCT FROM i.url;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
