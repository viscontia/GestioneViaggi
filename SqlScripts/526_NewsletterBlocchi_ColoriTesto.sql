-- Colore di titolo e sottotitolo dei blocchi.
--
-- Erano due costanti del renderer: il titolo blu (#2171A5) e il sottotitolo grigio (#888888).
-- Una scelta mia, mai richiesta, che l'utente non poteva cambiare: nel riquadro informativo il
-- titolo restava blu anche dove serviva altro. Il testo del corpo il colore ce l'ha gia' —
-- lo mette l'editor dentro l'HTML — ma titolo e sottotitolo sono campi di testo semplice e il
-- loro colore lo decideva solo il codice.
--
-- NULL = colore predefinito, cioe' esattamente l'aspetto di oggi: i blocchi gia' composti non
-- cambiano. Il formato e' vincolato a #RRGGBB perche' quel valore finisce dentro un attributo
-- style di una mail: un valore inventato non darebbe errore, darebbe testo nero senza spiegazione.
--
-- Le firme precedenti vengono rimosse esplicitamente: CREATE OR REPLACE non sostituisce una
-- function quando cambia il numero di parametri (vedi script 524 e 525).

ALTER TABLE web_newsletter_blocchi ADD COLUMN IF NOT EXISTS colore_titolo VARCHAR(7);
ALTER TABLE web_newsletter_blocchi ADD COLUMN IF NOT EXISTS colore_sottotitolo VARCHAR(7);

ALTER TABLE web_newsletter_blocchi DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_colore_titolo;
ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_colore_titolo
    CHECK (colore_titolo IS NULL OR colore_titolo ~ '^#[0-9A-Fa-f]{6}$');

ALTER TABLE web_newsletter_blocchi DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_colore_sottotitolo;
ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_colore_sottotitolo
    CHECK (colore_sottotitolo IS NULL OR colore_sottotitolo ~ '^#[0-9A-Fa-f]{6}$');

COMMENT ON COLUMN web_newsletter_blocchi.colore_titolo IS
'Colore del titolo in #RRGGBB. NULL = colore predefinito del modello grafico.';
COMMENT ON COLUMN web_newsletter_blocchi.colore_sottotitolo IS
'Colore del sottotitolo in #RRGGBB. NULL = colore predefinito del modello grafico.';

DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_insert(
    integer, bigint, character varying, integer, character varying, smallint,
    character varying, character varying, text, character varying, character varying,
    character varying, character varying, character varying, integer, bigint,
    character varying, character varying, character varying);

DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_update(
    bigint, integer, character varying, smallint, character varying, character varying,
    text, character varying, character varying, character varying, character varying,
    character varying, integer, bigint, character varying, character varying,
    character varying);

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_insert(
    p_azienda_id INTEGER, p_invio_id_fk BIGINT, p_tipo VARCHAR,
    p_ordine INTEGER DEFAULT NULL, p_layout VARCHAR DEFAULT 'pieno', p_colonne SMALLINT DEFAULT 1,
    p_titolo VARCHAR DEFAULT NULL, p_sottotitolo VARCHAR DEFAULT NULL, p_corpo_html TEXT DEFAULT NULL,
    p_immagine_url VARCHAR DEFAULT NULL, p_immagine_storage_path VARCHAR DEFAULT NULL,
    p_immagine_alt VARCHAR DEFAULT NULL, p_link_url VARCHAR DEFAULT NULL,
    p_link_etichetta VARCHAR DEFAULT NULL, p_data_viaggio_id_fk INTEGER DEFAULT NULL,
    p_indirizzo_id_fk BIGINT DEFAULT NULL, p_social VARCHAR DEFAULT NULL,
    p_icona_url VARCHAR DEFAULT NULL, p_layout_pulsante VARCHAR DEFAULT NULL,
    p_colore_titolo VARCHAR DEFAULT NULL, p_colore_sottotitolo VARCHAR DEFAULT NULL)
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
        data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, layout_pulsante,
        colore_titolo, colore_sottotitolo, azienda_id)
    VALUES (
        p_invio_id_fk, p_tipo, v_ordine, COALESCE(p_layout,'pieno'), COALESCE(p_colonne,1::SMALLINT),
        p_titolo, p_sottotitolo, p_corpo_html,
        p_immagine_url, p_immagine_storage_path, p_immagine_alt, p_link_url, p_link_etichetta,
        p_data_viaggio_id_fk, p_indirizzo_id_fk,
        NULLIF(btrim(COALESCE(p_social,'')), ''), p_icona_url,
        NULLIF(btrim(COALESCE(p_layout_pulsante,'')), ''),
        NULLIF(btrim(COALESCE(p_colore_titolo,'')), ''),
        NULLIF(btrim(COALESCE(p_colore_sottotitolo,'')), ''),
        p_azienda_id)
    RETURNING web_newsletter_blocchi_id INTO v_id;

    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_update(
    p_id BIGINT, p_azienda_id INTEGER, p_layout VARCHAR DEFAULT NULL, p_colonne SMALLINT DEFAULT NULL,
    p_titolo VARCHAR DEFAULT NULL, p_sottotitolo VARCHAR DEFAULT NULL, p_corpo_html TEXT DEFAULT NULL,
    p_immagine_url VARCHAR DEFAULT NULL, p_immagine_storage_path VARCHAR DEFAULT NULL,
    p_immagine_alt VARCHAR DEFAULT NULL, p_link_url VARCHAR DEFAULT NULL,
    p_link_etichetta VARCHAR DEFAULT NULL, p_data_viaggio_id_fk INTEGER DEFAULT NULL,
    p_indirizzo_id_fk BIGINT DEFAULT NULL, p_social VARCHAR DEFAULT NULL,
    p_icona_url VARCHAR DEFAULT NULL, p_layout_pulsante VARCHAR DEFAULT NULL,
    p_colore_titolo VARCHAR DEFAULT NULL, p_colore_sottotitolo VARCHAR DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_blocchi
       SET layout = COALESCE(p_layout, layout), colonne = COALESCE(p_colonne, colonne),
           titolo = p_titolo, sottotitolo = p_sottotitolo, corpo_html = p_corpo_html,
           immagine_url = p_immagine_url, immagine_storage_path = p_immagine_storage_path,
           immagine_alt = p_immagine_alt, link_url = p_link_url, link_etichetta = p_link_etichetta,
           data_viaggio_id_fk = p_data_viaggio_id_fk, indirizzo_id_fk = p_indirizzo_id_fk,
           social = NULLIF(btrim(COALESCE(p_social,'')), ''), icona_url = p_icona_url,
           layout_pulsante = NULLIF(btrim(COALESCE(p_layout_pulsante,'')), ''),
           colore_titolo = NULLIF(btrim(COALESCE(p_colore_titolo,'')), ''),
           colore_sottotitolo = NULLIF(btrim(COALESCE(p_colore_sottotitolo,'')), '')
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- La clonazione porta con se' anche i colori: una copia che tornasse ai colori predefiniti
-- costringerebbe a rifare a mano la scelta su ogni blocco.
CREATE OR REPLACE FUNCTION fn_web_newsletter_clona(
    p_invio_id BIGINT, p_azienda_id INTEGER,
    p_nuovo_oggetto VARCHAR DEFAULT NULL, p_come_modello BOOLEAN DEFAULT false)
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
        data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, layout_pulsante,
        colore_titolo, colore_sottotitolo, azienda_id)
    SELECT v_nuovo, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
           immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
           data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, layout_pulsante,
           colore_titolo, colore_sottotitolo, azienda_id
      FROM web_newsletter_blocchi
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY ordine;

    RETURN v_nuovo;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT proname, count(*) AS versioni FROM pg_proc
         WHERE proname IN ('fn_web_newsletter_blocchi_insert','fn_web_newsletter_blocchi_update')
         GROUP BY proname
    LOOP
        RAISE NOTICE '% -> % versione/i', r.proname, r.versioni;
        IF r.versioni > 1 THEN
            RAISE EXCEPTION 'La function % ha % firme sovrapposte: le chiamate parziali diventano ambigue.',
                            r.proname, r.versioni;
        END IF;
    END LOOP;
END $$;
