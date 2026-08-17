-- Fase 4.4 — cio' che si rompe da solo quando l'invio diventa multilingua.
--
-- 1) ARCHIVIO. web_newsletter_invii.corpo_html e' una colonna sola e conserva un corpo solo.
--    Finche' si spediva in italiano bastava; con cinque lingue, di cio' che ha ricevuto il
--    destinatario tedesco non resta traccia. Una newsletter inviata e' la prova documentale di
--    cosa e' stato mandato e a chi: se il registro dice "DE" e l'archivio ha solo l'italiano, la
--    prova non c'e' piu'.
--
-- 2) CLONAZIONE. Clonare genera id di blocco NUOVI, e le traduzioni sono indirizzate per id: la
--    copia nasceva senza. Su un modello e' il caso peggiore — un modello "Auguri di Natale" ha lo
--    stesso testo ogni anno, e ritradurlo ogni volta significa ripagarlo ogni volta.

-- =====================================================================
-- 1) Archivio del corpo, per lingua
-- =====================================================================
CREATE TABLE IF NOT EXISTS web_newsletter_invii_corpi (
    web_newsletter_invii_corpi_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invio_id_fk  BIGINT      NOT NULL REFERENCES web_newsletter_invii(web_newsletter_invii_id) ON DELETE CASCADE,
    lingua       CHAR(2)     NOT NULL,
    corpo_html   TEXT        NOT NULL,
    oggetto      VARCHAR(255) NOT NULL,
    destinatari  INTEGER     NOT NULL DEFAULT 0,
    azienda_id   INTEGER     NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by   VARCHAR(50) NOT NULL DEFAULT current_user,
    created      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_web_newsletter_invii_corpi UNIQUE (invio_id_fk, lingua)
);

COMMENT ON TABLE web_newsletter_invii_corpi IS
'Cosa e'' stato spedito, per lingua. Una riga per ogni lingua effettivamente usata in un invio.';
COMMENT ON COLUMN web_newsletter_invii_corpi.destinatari IS
'Quanti destinatari hanno ricevuto questa versione.';

CREATE INDEX IF NOT EXISTS idx_web_newsletter_invii_corpi_invio ON web_newsletter_invii_corpi(invio_id_fk);

-- Si scrive una volta per lingua, a invio concluso. Il conflitto aggiorna invece di fallire:
-- un reinvio parziale non deve interrompersi sull'archivio.
CREATE OR REPLACE FUNCTION fn_web_newsletter_corpo_archivia(
    p_invio_id BIGINT, p_azienda_id INTEGER, p_lingua VARCHAR,
    p_oggetto VARCHAR, p_corpo TEXT, p_destinatari INTEGER)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_newsletter_invii_corpi(invio_id_fk, lingua, corpo_html, oggetto, destinatari, azienda_id)
    VALUES (p_invio_id, upper(p_lingua), p_corpo, p_oggetto, COALESCE(p_destinatari, 0), p_azienda_id)
    ON CONFLICT (invio_id_fk, lingua) DO UPDATE
        SET corpo_html = EXCLUDED.corpo_html,
            oggetto    = EXCLUDED.oggetto,
            destinatari = EXCLUDED.destinatari
    RETURNING web_newsletter_invii_corpi_id INTO v_id;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_corpi_list(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(lingua CHAR(2), oggetto VARCHAR, corpo_html TEXT, destinatari INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT c.lingua, c.oggetto, c.corpo_html, c.destinatari
      FROM web_newsletter_invii_corpi c
     WHERE c.invio_id_fk = p_invio_id AND c.azienda_id = p_azienda_id
     ORDER BY (c.lingua <> 'IT'), c.lingua;   -- l'italiano per primo: e' l'originale
$$;

-- =====================================================================
-- 2) La clonazione porta con sé le traduzioni
-- =====================================================================
-- I blocchi si copiano UNO ALLA VOLTA e non con un INSERT ... SELECT: serve sapere quale nuovo id
-- corrisponde a quale vecchio, e un inserimento massivo non lo restituisce. Venti blocchi non sono
-- un problema di prestazioni; perdere le traduzioni lo e'.
--
-- L'OGGETTO non si copia: la copia ne riceve uno nuovo, scritto dall'utente, e una traduzione
-- del vecchio sarebbe semplicemente sbagliata.
--
-- Si copia con INSERT diretto e non con fn_web_traduzioni_upsert perche' quella azzera
-- "revisionato": una traduzione riletta e approvata resterebbe approvata anche nella copia, che
-- ha esattamente lo stesso testo.
CREATE OR REPLACE FUNCTION fn_web_newsletter_clona(
    p_invio_id BIGINT, p_azienda_id INTEGER,
    p_nuovo_oggetto VARCHAR DEFAULT NULL, p_come_modello BOOLEAN DEFAULT false)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_nuovo BIGINT; v_oggetto VARCHAR;
    r RECORD; v_nuovo_blocco BIGINT;
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

    FOR r IN
        SELECT * FROM web_newsletter_blocchi
         WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
         ORDER BY ordine
    LOOP
        INSERT INTO web_newsletter_blocchi(
            invio_id_fk, tipo, ordine, layout, colonne, titolo, sottotitolo, corpo_html,
            immagine_url, immagine_storage_path, immagine_alt, link_url, link_etichetta,
            data_viaggio_id_fk, indirizzo_id_fk, social, icona_url, layout_pulsante,
            colore_titolo, colore_sottotitolo, azienda_id)
        VALUES (
            v_nuovo, r.tipo, r.ordine, r.layout, r.colonne, r.titolo, r.sottotitolo, r.corpo_html,
            r.immagine_url, r.immagine_storage_path, r.immagine_alt, r.link_url, r.link_etichetta,
            r.data_viaggio_id_fk, r.indirizzo_id_fk, r.social, r.icona_url, r.layout_pulsante,
            r.colore_titolo, r.colore_sottotitolo, r.azienda_id)
        RETURNING web_newsletter_blocchi_id INTO v_nuovo_blocco;

        -- Le traduzioni valide del blocco d'origine seguono la copia. Le obsolete no: sono gia'
        -- disallineate dall'italiano, copiarle porterebbe avanti un errore.
        INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo,
                                   tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id, created_by)
        SELECT 'web_newsletter_blocchi', v_nuovo_blocco, t.campo, t.lingua, t.testo,
               t.tradotto_auto, t.revisionato, FALSE, t.data_traduzione, t.azienda_id, current_user
          FROM web_traduzioni t
         WHERE t.entita = 'web_newsletter_blocchi'
           AND t.entita_id = r.web_newsletter_blocchi_id
           AND t.azienda_id = p_azienda_id
           AND NOT t.obsoleto
        ON CONFLICT (entita, entita_id, campo, lingua) DO NOTHING;
    END LOOP;

    RETURN v_nuovo;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT proname, count(*) AS v FROM pg_proc
              WHERE proname IN ('fn_web_newsletter_clona','fn_web_newsletter_corpo_archivia','fn_web_newsletter_corpi_list')
              GROUP BY proname
    LOOP
        RAISE NOTICE '% -> % versione/i', r.proname, r.v;
        IF r.v > 1 THEN RAISE EXCEPTION 'La function % ha % firme sovrapposte.', r.proname, r.v; END IF;
    END LOOP;
END $$;
