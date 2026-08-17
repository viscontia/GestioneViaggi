-- Fase 4.2 — traduzione per campo dei blocchi di una newsletter.
--
-- Non serve una tabella nuova: web_traduzioni indirizza (entita, entita_id, campo, lingua) e regge
-- gia' i contenuti web. Le entita' che si aggiungono sono due:
--   'web_newsletter_blocchi' + id del blocco  -> titolo, sottotitolo, corpo_html,
--                                                link_etichetta, immagine_alt
--   'web_newsletter_invii'   + id dell'invio  -> oggetto
--
-- Quello che NON entra qui, e il motivo:
--   * il sottotitolo di un blocco TOUR e' il periodo ("Dal 2 al 7 maggio 2026"), GENERATO dalle
--     date della partenza. Archiviarne una traduzione significa fotografare un valore che
--     cambiera': cambiando partenza l'italiano si aggiorna e il tedesco resta indietro, in
--     silenzio. Va rigenerato per lingua (fase 4.3), non tradotto;
--   * i testi che mette il programma — disiscrizione, etichette di riserva — sono localizzati nel
--     codice (NewsletterTesti, fase 4.1): non hanno un originale scritto da qualcuno, quindi
--     nessuno deve rileggerli a ogni newsletter;
--   * tutto cio' che non e' prosa: colori, layout, indirizzi, id.

-- =====================================================================
-- 1) Le traduzioni di una newsletter, in una lettura sola
-- =====================================================================
-- Il rendering serve una mail per destinatario: interrogare campo per campo sarebbe una query per
-- ogni blocco per ogni destinatario. Qui si prende tutto in un colpo, per la lingua richiesta.
-- Le righe OBSOLETE non escono: una traduzione obsoleta e' peggio di nessuna traduzione, perche'
-- sembra giusta. Il chiamante ricade sull'italiano, che e' sempre allineato.
-- Il contesto di rendering si prepara UNA volta e serve destinatari di lingue diverse: la lettura
-- prende quindi tutte le lingue insieme (p_lingua NULL) e il chiamante sceglie riga per riga.
DROP FUNCTION IF EXISTS fn_web_newsletter_traduzioni(bigint, integer, character varying);

CREATE OR REPLACE FUNCTION fn_web_newsletter_traduzioni(
    p_invio_id BIGINT, p_azienda_id INTEGER, p_lingua VARCHAR DEFAULT NULL)
RETURNS TABLE(lingua CHAR(2), entita VARCHAR, entita_id BIGINT, campo VARCHAR, testo TEXT)
LANGUAGE sql STABLE AS $$
    SELECT t.lingua, t.entita, t.entita_id, t.campo, t.testo
      FROM web_traduzioni t
     WHERE t.azienda_id = p_azienda_id
       AND (p_lingua IS NULL OR t.lingua = upper(p_lingua))
       AND NOT t.obsoleto
       AND NULLIF(btrim(t.testo), '') IS NOT NULL
       AND (
             (t.entita = 'web_newsletter_invii' AND t.entita_id = p_invio_id)
          OR (t.entita = 'web_newsletter_blocchi' AND t.entita_id IN (
                 SELECT b.web_newsletter_blocchi_id FROM web_newsletter_blocchi b
                  WHERE b.invio_id_fk = p_invio_id AND b.azienda_id = p_azienda_id))
           );
$$;

COMMENT ON FUNCTION fn_web_newsletter_traduzioni(BIGINT, INTEGER, VARCHAR) IS
'Traduzioni valide (non obsolete) di una newsletter: oggetto e campi dei blocchi. p_lingua NULL = tutte.';

-- =====================================================================
-- 2) Quanto e' tradotta, lingua per lingua
-- =====================================================================
-- Serve a due cose: mostrare lo stato mentre si compone, e avvisare prima di spedire quanti
-- destinatari riceverebbero l'italiano. Conta i campi TRADUCIBILI davvero compilati: un titolo
-- vuoto non e' una traduzione mancante, e contarlo farebbe apparire incompleta una newsletter
-- completa.
CREATE OR REPLACE FUNCTION fn_web_newsletter_traduzioni_stato(
    p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(lingua CHAR(2), traducibili INTEGER, tradotti INTEGER, obsoleti INTEGER, mancanti INTEGER)
LANGUAGE sql STABLE AS $$
    WITH campi AS (
        -- L'oggetto della newsletter
        SELECT 'web_newsletter_invii'::VARCHAR AS entita,
               i.web_newsletter_invii_id       AS entita_id,
               'oggetto'::VARCHAR              AS campo
          FROM web_newsletter_invii i
         WHERE i.web_newsletter_invii_id = p_invio_id AND i.azienda_id = p_azienda_id
           AND NULLIF(btrim(i.oggetto), '') IS NOT NULL

        UNION ALL
        -- I campi dei blocchi, uno per riga, saltando i vuoti
        SELECT 'web_newsletter_blocchi', b.web_newsletter_blocchi_id, c.campo
          FROM web_newsletter_blocchi b
          CROSS JOIN LATERAL (VALUES
                ('titolo',         b.titolo),
                -- il periodo di un riquadro tour e' generato: non e' materia di traduzione
                ('sottotitolo',    CASE WHEN b.tipo = 'tour' THEN NULL ELSE b.sottotitolo END),
                ('corpo_html',     b.corpo_html),
                ('link_etichetta', b.link_etichetta),
                ('immagine_alt',   b.immagine_alt)
          ) AS c(campo, valore)
         WHERE b.invio_id_fk = p_invio_id AND b.azienda_id = p_azienda_id
           AND NULLIF(btrim(c.valore), '') IS NOT NULL
    ),
    lingue AS (SELECT unnest(ARRAY['EN','DE','ES','FR'])::CHAR(2) AS lingua)
    SELECT l.lingua,
           count(*)::INTEGER                                                        AS traducibili,
           count(t.web_traduzioni_id) FILTER (WHERE NOT t.obsoleto)::INTEGER        AS tradotti,
           count(t.web_traduzioni_id) FILTER (WHERE t.obsoleto)::INTEGER            AS obsoleti,
           (count(*) - count(t.web_traduzioni_id))::INTEGER                         AS mancanti
      FROM lingue l
      CROSS JOIN campi c
      LEFT JOIN web_traduzioni t
             ON t.entita = c.entita AND t.entita_id = c.entita_id
            AND t.campo = c.campo   AND t.lingua = l.lingua
            AND t.azienda_id = p_azienda_id
            AND NULLIF(btrim(t.testo), '') IS NOT NULL
     GROUP BY l.lingua
     ORDER BY l.lingua;
$$;

COMMENT ON FUNCTION fn_web_newsletter_traduzioni_stato(BIGINT, INTEGER) IS
'Copertura delle traduzioni di una newsletter per lingua: traducibili, tradotti, obsoleti, mancanti.';

-- =====================================================================
-- 3) Modificare un blocco rende obsolete le sue traduzioni
-- =====================================================================
-- E' il punto in cui il meccanismo si romperebbe da solo. Corretto l'italiano, la traduzione
-- tedesca resta quella di prima e continua a partire: in italiano il testo e' giusto, quindi
-- nessuno se ne accorge. Si marca obsoleto SOLO il campo che e' cambiato davvero — marcare tutto
-- costringerebbe a ritradurre l'intera newsletter per una virgola.
--
-- Sta dentro la function di aggiornamento, non nel programma, perche' e' l'unico modo di non
-- poterselo dimenticare: chiunque aggiorni un blocco passa di qui. La firma non cambia.
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

    -- IS DISTINCT FROM e non <>: fra NULL e un testo, l'operatore normale darebbe NULL e il
    -- confronto passerebbe per "non cambiato" proprio quando un campo viene svuotato o riempito.
    IF v_n > 0 THEN
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
    END IF;

    RETURN v_n;
END $$;

-- =====================================================================
-- 4) Cambiare l'oggetto rende obsoleta la sua traduzione
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_web_newsletter_set_oggetto(
    p_invio_id BIGINT, p_azienda_id INTEGER, p_oggetto VARCHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER; v_old VARCHAR;
BEGIN
    SELECT oggetto INTO v_old FROM web_newsletter_invii
     WHERE web_newsletter_invii_id = p_invio_id AND azienda_id = p_azienda_id;

    IF NOT FOUND THEN RETURN 0; END IF;

    IF EXISTS (SELECT 1 FROM web_newsletter_invii
                WHERE web_newsletter_invii_id = p_invio_id AND stato <> 'bozza') THEN
        RAISE EXCEPTION 'Una newsletter già spedita non si modifica.';
    END IF;

    UPDATE web_newsletter_invii SET oggetto = p_oggetto
     WHERE web_newsletter_invii_id = p_invio_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    IF v_n > 0 AND v_old IS DISTINCT FROM p_oggetto THEN
        PERFORM fn_web_traduzioni_marca_obsolete(p_azienda_id, 'web_newsletter_invii', p_invio_id, 'oggetto');
    END IF;

    RETURN v_n;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT proname, count(*) AS v FROM pg_proc
              WHERE proname IN ('fn_web_newsletter_blocchi_update','fn_web_newsletter_traduzioni',
                                'fn_web_newsletter_traduzioni_stato','fn_web_newsletter_set_oggetto')
              GROUP BY proname
    LOOP
        RAISE NOTICE '% -> % versione/i', r.proname, r.v;
        IF r.v > 1 THEN RAISE EXCEPTION 'La function % ha % firme sovrapposte.', r.proname, r.v; END IF;
    END LOOP;
END $$;
