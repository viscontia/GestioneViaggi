-- L'obsolescenza va marcata PRIMA della UPDATE, non dopo.
--
-- Sintomo: un riquadro tour appena creato risultava non tradotto, pur avendo le quattro
-- traduzioni ereditate dalla scheda del tour. Erano tutte marcate obsolete.
--
-- La causa e' l'ordine delle operazioni dentro fn_web_newsletter_blocchi_update:
--
--   1. si legge il valore precedente (su un blocco appena creato: corpo vuoto)
--   2. si esegue la UPDATE, che scrive testo e aggancio alla partenza
--   3. al termine dell'istruzione scatta il trigger AFTER UPDATE, che EREDITA le traduzioni
--      della scheda del tour e le scrive valide
--   4. subito dopo, il blocco di obsolescenza confronta vecchio e nuovo, vede che il testo e'
--      cambiato (da vuoto a pieno) e marca obsolete... proprio le quattro appena ereditate.
--
-- Il passo 4 e' giusto in se': se l'italiano cambia, la traduzione precedente non vale piu'.
-- Sbagliato e' che venga dopo il passo 3, perche' quelle traduzioni non sono "precedenti": sono
-- state prodotte dallo stesso aggiornamento, sul testo nuovo.
--
-- Invertendo, ogni passo torna a fare cio' che deve: si invalida cio' che c'era, si scrive, e
-- l'ereditarieta' — che avviene per ultima — ne mette di nuove e valide.

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
DECLARE v_n INTEGER; v_old RECORD;
BEGIN
    SELECT titolo, sottotitolo, corpo_html, link_etichetta, immagine_alt
      INTO v_old
      FROM web_newsletter_blocchi
     WHERE web_newsletter_blocchi_id = p_id AND azienda_id = p_azienda_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- PRIMA di scrivere: cio' che era tradotto sul testo vecchio non vale piu'.
    -- IS DISTINCT FROM e non <>: fra NULL e un testo, l'operatore normale darebbe NULL e il
    -- confronto passerebbe per "non cambiato" proprio quando un campo viene svuotato o riempito.
    IF v_old.titolo IS DISTINCT FROM p_titolo THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_blocchi', p_id, 'titolo');
    END IF;
    IF v_old.sottotitolo IS DISTINCT FROM p_sottotitolo THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_blocchi', p_id, 'sottotitolo');
    END IF;
    IF v_old.corpo_html IS DISTINCT FROM p_corpo_html THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_blocchi', p_id, 'corpo_html');
    END IF;
    IF v_old.link_etichetta IS DISTINCT FROM p_link_etichetta THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_blocchi', p_id, 'link_etichetta');
    END IF;
    IF v_old.immagine_alt IS DISTINCT FROM p_immagine_alt THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_blocchi', p_id, 'immagine_alt');
    END IF;

    -- DOPO: la scrittura. Al termine dell'istruzione scatta il trigger di ereditarieta', che per
    -- un riquadro tour rimette le traduzioni della scheda — valide, perche' riferite al testo
    -- appena scritto.
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

-- Rimette a posto i blocchi gia' salvati con l'ordine sbagliato: dove il testo del riquadro e'
-- ancora quello della scheda, l'ereditarieta' si puo' semplicemente rifare.
DO $$
DECLARE r RECORD; v_tot INTEGER := 0; v_n INTEGER;
BEGIN
    FOR r IN
        SELECT b.web_newsletter_blocchi_id AS id, b.azienda_id
          FROM web_newsletter_blocchi b
         WHERE b.tipo = 'tour' AND b.data_viaggio_id_fk IS NOT NULL
    LOOP
        v_n := fn_web_newsletter_blocco_eredita_traduzioni(r.id, r.azienda_id);
        v_tot := v_tot + COALESCE(v_n, 0);
    END LOOP;
    RAISE NOTICE 'Ereditarieta'' rifatta: % traduzioni rimesse valide.', v_tot;
END $$;
