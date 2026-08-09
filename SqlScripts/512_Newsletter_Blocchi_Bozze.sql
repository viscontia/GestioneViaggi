-- Newsletter a blocchi — Fase 1 (schema + CRUD + riordino + clonazione + bozze).
-- Design: "Estensione Progetto WEB/Documenti/2026-08-09-Newsletter_Blocchi_design.md"
--
-- La newsletter smette di essere una casella di testo dentro un template fisso e diventa una
-- sequenza di blocchi ordinati. Tabella e non JSONB perche' le traduzioni hanno bisogno di
-- identificatori stabili: web_traduzioni indirizza (entita, entita_id, campo, lingua) e un
-- indirizzamento per posizione si romperebbe al primo riordino dei blocchi.
--
-- Campi espliciti e non un JSONB "contenuto" per lo stesso motivo: 'campo' nelle traduzioni
-- deve essere un nome noto e stabile ('titolo', 'corpo_html', 'link_etichetta', ...).

-- ============================================================================
-- 1) web_newsletter_invii: bozze e modelli
-- ============================================================================

-- La riga nasce ora alla CREAZIONE della newsletter, non piu' al momento dell'invio:
-- stato 'bozza' era gia' ammesso dal CHECK e non lo scriveva nessuno.
-- corpo_html diventa l'ISTANTANEA di cio' che e' partito davvero, quindi e' NULL finche'
-- non si invia (prima era NOT NULL perche' si scriveva solo all'invio).
ALTER TABLE web_newsletter_invii ALTER COLUMN corpo_html DROP NOT NULL;

-- Un modello e' una newsletter riutilizzabile: non compare nello storico e si duplica
-- invece di inviarsi. L'oggetto fa da nome del modello (ed e' anche l'oggetto di partenza
-- delle newsletter che ne nascono).
ALTER TABLE web_newsletter_invii
    ADD COLUMN IF NOT EXISTS is_modello BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN web_newsletter_invii.is_modello IS
'true = struttura riutilizzabile con nome (l''oggetto fa da nome): esclusa dallo storico, si clona invece di inviarsi.';
COMMENT ON COLUMN web_newsletter_invii.corpo_html IS
'HTML renderizzato AL MOMENTO DELL''INVIO (istantanea di cio'' che e'' partito). NULL sulle bozze e sui modelli.';

-- ============================================================================
-- 2) Catalogo dei tipi di blocco
-- ============================================================================
-- Nessuna tabella: e' un catalogo di codice, non dati aziendali. Una function lo rende
-- interrogabile dalla UI (etichette, obbligatorieta', occorrenze massime) mantenendo
-- un'unica fonte di verita' lato DB.
--
-- obbligatorio = il blocco non si puo' eliminare e viene creato con la newsletter
-- max_occorrenze = NULL significa "quante se ne vuole"

CREATE OR REPLACE FUNCTION fn_web_newsletter_tipi_blocco()
RETURNS TABLE(tipo VARCHAR, etichetta VARCHAR, obbligatorio BOOLEAN, max_occorrenze INTEGER, ordine_catalogo INTEGER)
LANGUAGE sql IMMUTABLE AS $$
    SELECT * FROM (VALUES
        ('intestazione'::VARCHAR, 'Intestazione (logo)'::VARCHAR,  true,  1,    10),
        ('testata',               'Testata con immagine',          false, NULL, 20),
        ('testo',                 'Testo',                         false, NULL, 30),
        ('tour',                  'Riquadro tour',                 false, NULL, 40),
        ('immagine',              'Immagine',                      false, NULL, 50),
        ('pulsante',              'Pulsante',                      false, NULL, 60),
        ('separatore',            'Separatore',                    false, NULL, 70),
        ('footer',                'Footer societario',             true,  1,    80)
    ) AS t(tipo, etichetta, obbligatorio, max_occorrenze, ordine_catalogo);
$$;

-- ============================================================================
-- 3) web_newsletter_blocchi
-- ============================================================================

CREATE TABLE IF NOT EXISTS web_newsletter_blocchi (
    web_newsletter_blocchi_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invio_id_fk               BIGINT       NOT NULL,
    tipo                      VARCHAR(20)  NOT NULL,
    ordine                    INTEGER      NOT NULL DEFAULT 0,

    -- Disposizione: copre "posizione fisica uno rispetto all'altro" senza inventare tipi nuovi
    layout                    VARCHAR(10)  NOT NULL DEFAULT 'pieno',
    colonne                   SMALLINT     NOT NULL DEFAULT 1,

    -- Campi di contenuto (quali siano valorizzati dipende dal tipo; i traducibili sono
    -- titolo, sottotitolo, corpo_html, immagine_alt, link_etichetta)
    titolo                    VARCHAR(255),
    sottotitolo               VARCHAR(255),
    corpo_html                TEXT,
    immagine_url              VARCHAR(500),
    immagine_storage_path     VARCHAR(500),
    immagine_alt              VARCHAR(255),
    link_url                  VARCHAR(500),
    link_etichetta            VARCHAR(100),

    -- Solo per tipo='tour': l'edizione da cui si ricavano copertina, titolo e link
    data_viaggio_id_fk        INTEGER,

    azienda_id                INTEGER      NOT NULL,
    created_by                VARCHAR(50)  NOT NULL,
    created                   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by                VARCHAR(50),
    updated                   TIMESTAMPTZ,

    CONSTRAINT fk_web_newsletter_blocchi_invio
        FOREIGN KEY (invio_id_fk) REFERENCES web_newsletter_invii(web_newsletter_invii_id) ON DELETE CASCADE,
    CONSTRAINT fk_web_newsletter_blocchi_azienda
        FOREIGN KEY (azienda_id) REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    CONSTRAINT fk_web_newsletter_blocchi_data_viaggio
        FOREIGN KEY (data_viaggio_id_fk) REFERENCES ana_date_viaggi(data_viaggio_id) ON DELETE SET NULL,

    CONSTRAINT chk_web_newsletter_blocchi_tipo
        CHECK (tipo IN ('intestazione','testata','testo','tour','immagine','pulsante','separatore','footer')),
    CONSTRAINT chk_web_newsletter_blocchi_layout
        CHECK (layout IN ('sinistra','destra','pieno')),
    CONSTRAINT chk_web_newsletter_blocchi_colonne
        CHECK (colonne IN (1,2))
);

CREATE INDEX IF NOT EXISTS idx_web_newsletter_blocchi_invio   ON web_newsletter_blocchi(invio_id_fk, ordine);
CREATE INDEX IF NOT EXISTS idx_web_newsletter_blocchi_azienda ON web_newsletter_blocchi(azienda_id);

-- Intestazione e footer: uno solo per newsletter. Indici parziali perche' il vincolo
-- vale solo per quei due tipi.
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_newsletter_blocchi_intestazione
    ON web_newsletter_blocchi(invio_id_fk) WHERE tipo = 'intestazione';
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_newsletter_blocchi_footer
    ON web_newsletter_blocchi(invio_id_fk) WHERE tipo = 'footer';

DROP TRIGGER IF EXISTS trg_web_newsletter_blocchi_audit ON web_newsletter_blocchi;
CREATE TRIGGER trg_web_newsletter_blocchi_audit
    BEFORE INSERT OR UPDATE ON web_newsletter_blocchi
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();

COMMENT ON TABLE web_newsletter_blocchi IS
'Blocchi ordinati che compongono una newsletter (Fase 1 newsletter a blocchi). Intestazione e footer sono obbligatori e unici; gli altri liberi in numero e ordine.';

-- ============================================================================
-- 4) CRUD
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_list(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_blocchi
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_blocchi
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY ordine, web_newsletter_blocchi_id;
$$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_get(p_id BIGINT, p_azienda_id INTEGER)
RETURNS SETOF web_newsletter_blocchi
LANGUAGE sql STABLE AS $$
    SELECT * FROM web_newsletter_blocchi
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
$$;

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
    p_data_viaggio_id_fk    INTEGER      DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_id     BIGINT;
    v_max    INTEGER;
    v_conta  INTEGER;
    v_ordine INTEGER;
BEGIN
    -- La newsletter deve essere della stessa azienda: senza questo controllo si potrebbe
    -- appendere un blocco alla newsletter di un altro tenant passando l'id giusto.
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

    -- Ordine non passato: in coda, ma sempre PRIMA del footer, che deve restare ultimo.
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
        data_viaggio_id_fk, azienda_id)
    VALUES (
        p_invio_id_fk, p_tipo, v_ordine, COALESCE(p_layout,'pieno'), COALESCE(p_colonne,1::SMALLINT),
        p_titolo, p_sottotitolo, p_corpo_html,
        p_immagine_url, p_immagine_storage_path, p_immagine_alt, p_link_url, p_link_etichetta,
        p_data_viaggio_id_fk, p_azienda_id)
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
    p_data_viaggio_id_fk    INTEGER      DEFAULT NULL)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    -- Aggiornamento completo dei campi di contenuto: i NULL azzerano (un blocco a cui si
    -- toglie il sottotitolo deve restare senza). Tipo e ordine non si cambiano qui:
    -- il tipo e' immutabile, l'ordine passa dalla reorder.
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
           data_viaggio_id_fk    = p_data_viaggio_id_fk
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER; v_tipo VARCHAR; v_obbl BOOLEAN;
BEGIN
    SELECT tipo INTO v_tipo FROM web_newsletter_blocchi
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;

    IF v_tipo IS NULL THEN RETURN 0; END IF;

    SELECT obbligatorio INTO v_obbl FROM fn_web_newsletter_tipi_blocco() WHERE tipo = v_tipo;
    IF v_obbl THEN
        RAISE EXCEPTION 'Il blocco "%" e'' obbligatorio e non puo'' essere eliminato.', v_tipo;
    END IF;

    DELETE FROM web_newsletter_blocchi
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

-- Riordino: stesso schema di fn_web_tour_itinerario_reorder (array di id nell'ordine voluto).
CREATE OR REPLACE FUNCTION fn_web_newsletter_blocchi_reorder(
    p_azienda_id INTEGER, p_invio_id_fk BIGINT, p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_blocchi b
       SET ordine = x.nuovo_ordine::INTEGER * 10
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE b.web_newsletter_blocchi_id = x.id
       AND b.invio_id_fk = p_invio_id_fk
       AND b.azienda_id  = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    -- Intestazione sempre prima, footer sempre ultimo: non dipendono da cosa ha
    -- trascinato l'utente.
    UPDATE web_newsletter_blocchi SET ordine = 0
     WHERE invio_id_fk = p_invio_id_fk AND azienda_id = p_azienda_id AND tipo = 'intestazione';
    UPDATE web_newsletter_blocchi SET ordine = 999999
     WHERE invio_id_fk = p_invio_id_fk AND azienda_id = p_azienda_id AND tipo = 'footer';

    RETURN v_n;
END $$;

-- ============================================================================
-- 5) Creazione di una bozza (con i blocchi obbligatori gia' dentro)
-- ============================================================================
-- I blocchi obbligatori si creano qui, non lato C#: cosi' l'invariante "ogni newsletter ha
-- intestazione e footer" vale anche per le newsletter create da altri percorsi (clonazione).

CREATE OR REPLACE FUNCTION fn_web_newsletter_crea_bozza(
    p_azienda_id INTEGER,
    p_oggetto    VARCHAR,
    p_is_modello BOOLEAN DEFAULT false)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_invii(oggetto, corpo_html, stato, azienda_id, is_modello)
    VALUES (p_oggetto, NULL, 'bozza', p_azienda_id, COALESCE(p_is_modello, false))
    RETURNING web_newsletter_invii_id INTO v_id;

    INSERT INTO web_newsletter_blocchi(invio_id_fk, tipo, ordine, azienda_id)
    VALUES (v_id, 'intestazione', 0,      p_azienda_id),
           (v_id, 'footer',       999999, p_azienda_id);

    RETURN v_id;
END $$;

-- ============================================================================
-- 6) Clonazione
-- ============================================================================
-- Con l'importazione da Drupal esclusa, la clonazione non e' un comodo: e' il meccanismo
-- con cui si costruisce il patrimonio di newsletter. Clona SEMPRE in bozza, anche se la
-- sorgente e' gia' stata inviata o e' un modello.

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

    -- corpo_html della sorgente NON si copia: e' l'istantanea di cio' che e' stato inviato,
    -- non un contenuto modificabile. La copia riparte dai blocchi.
    INSERT INTO web_newsletter_blocchi(
        invio_id_fk, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
        immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
        data_viaggio_id_fk, azienda_id)
    SELECT v_nuovo, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
           immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
           data_viaggio_id_fk, azienda_id
      FROM web_newsletter_blocchi
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY ordine;

    RETURN v_nuovo;
END $$;

-- ============================================================================
-- 7) Elenco newsletter (bozze / inviate / modelli separati)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_web_newsletter_elenco(
    p_azienda_id INTEGER,
    p_modelli    BOOLEAN DEFAULT false)
RETURNS TABLE(
    web_newsletter_invii_id BIGINT,
    oggetto                 VARCHAR,
    stato                   VARCHAR,
    data_invio              TIMESTAMPTZ,
    numero_destinatari      INTEGER,
    canale                  VARCHAR,
    is_modello              BOOLEAN,
    n_blocchi               INTEGER,
    created                 TIMESTAMPTZ)
LANGUAGE sql STABLE AS $$
    SELECT i.web_newsletter_invii_id, i.oggetto, i.stato, i.data_invio,
           i.numero_destinatari, i.canale, i.is_modello,
           (SELECT count(*)::INTEGER FROM web_newsletter_blocchi b WHERE b.invio_id_fk = i.web_newsletter_invii_id),
           i.created
      FROM web_newsletter_invii i
     WHERE i.azienda_id = p_azienda_id
       AND i.is_modello = COALESCE(p_modelli, false)
     ORDER BY COALESCE(i.data_invio, i.created) DESC;
$$;
