-- Integrita' dei collegamenti fra newsletter e partenze.
--
-- Il vincolo su web_newsletter_blocchi.data_viaggio_id_fk e' ON DELETE SET NULL: il database, da
-- solo, non impedisce niente — azzererebbe l'aggancio in silenzio. Cio' che protegge davvero e'
-- sp_ana_date_viaggi_delete, che rifiuta di cancellare una partenza che abbia una scheda di
-- contenuti web. E siccome un blocco di newsletter puo' puntare a un tour SOLO se quel tour ha una
-- scheda web (il collegamento si costruisce da li'), la protezione c'e' — ma per proprieta'
-- transitiva, non per un controllo che sappia delle newsletter.
--
-- Il buco sta proprio li': la scheda web si puo' eliminare, e fn_web_tour_contenuti_delete non
-- guardava le newsletter. Eliminata la scheda, la partenza diventa cancellabile e l'aggancio del
-- blocco viene azzerato. Su una newsletter INVIATA il danno e' contenuto — titolo, immagine e
-- indirizzo sono copie dentro il blocco, quindi la mail resta leggibile e la prova documentale
-- regge. Su una BOZZA no: resta un collegamento a una pagina che non esiste piu', e siccome
-- l'aggancio ora e' NULL non lo intercetta ne' il riaggancio ne' la validazione, che guarda solo
-- se i blocchi sono vuoti. Si spedirebbe una newsletter con un link morto senza un solo avviso.
--
-- Due guardie:
--   1) non si elimina la scheda web se una newsletter IN BOZZA punta a quella partenza;
--   2) prima di spedire si verifica che i collegamenti ai tour siano ancora vivi — che copre
--      tutti i modi in cui un collegamento muore, non solo la cancellazione.

-- =====================================================================
-- 1) Eliminazione della scheda web: guardia sulle newsletter in bozza
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_n INTEGER;
    v_data_viaggio INTEGER;
    v_bozze TEXT;
BEGIN
    -- La scheda esiste ed è di questa azienda? Se no, si esce senza toccare nulla: le DELETE sulle
    -- figlie che seguono non sono scopate per azienda, quindi il controllo va fatto prima.
    SELECT data_viaggio_id_fk INTO v_data_viaggio
      FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Newsletter ancora da spedire che puntano a questa partenza: eliminando la scheda
    -- resterebbero con un collegamento morto e nessuno se ne accorgerebbe. Le gia' inviate non
    -- fermano niente: sono congelate e non si rompono.
    IF v_data_viaggio IS NOT NULL THEN
        SELECT string_agg(DISTINCT format('«%s»', i.oggetto), ', ')
          INTO v_bozze
          FROM web_newsletter_blocchi b
          JOIN web_newsletter_invii i ON i.web_newsletter_invii_id = b.invio_id_fk
         WHERE b.data_viaggio_id_fk = v_data_viaggio
           AND b.azienda_id = p_azienda_id
           AND i.stato = 'bozza';

        IF v_bozze IS NOT NULL THEN
            RAISE EXCEPTION
                'Impossibile eliminare la scheda web: le newsletter % non ancora spedite puntano a questa partenza. Togli o riaggancia quei blocchi, poi riprova.',
                v_bozze
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 1) Traduzioni delle figlie e della scheda. Prima delle DELETE, finché gli id sono ancora leggibili.
    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_itinerario_passaggi'
       AND t.entita_id IN (SELECT p.web_tour_itinerario_passaggi_id
                             FROM web_tour_itinerario_passaggi p
                             JOIN web_tour_itinerario i ON i.web_tour_itinerario_id = p.itinerario_id_fk
                            WHERE i.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_itinerario'
       AND t.entita_id IN (SELECT i.web_tour_itinerario_id FROM web_tour_itinerario i
                            WHERE i.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_mappa'
       AND t.entita_id IN (SELECT m.web_tour_mappa_id FROM web_tour_mappa m
                            WHERE m.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_contenuti' AND t.entita_id = p_id;

    -- 2) Mappe per prime: vedi nota (2) in testa.
    DELETE FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = p_id;

    -- 3) La scheda. Giornate, passaggi e immagini seguono per CASCADE.
    DELETE FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN v_n;
END $$;

-- =====================================================================
-- 2) Collegamenti ai tour ancora vivi: verifica prima di spedire
-- =====================================================================
-- Restituisce una riga per ogni blocco il cui collegamento a un tour non porta piu' da nessuna
-- parte. Vuoto = si puo' spedire.
--
-- Si guarda in DUE modi, perche' i blocchi non sono tutti uguali:
--   - per AGGANCIO (data_viaggio_id_fk), che e' il legame vero;
--   - per INDIRIZZO, cercando lo slug dentro link_url, che e' l'unico modo di intercettare i
--     blocchi il cui aggancio e' stato azzerato dalla cancellazione della partenza — cioe'
--     esattamente i casi piu' pericolosi, che nessun altro controllo vede.
CREATE OR REPLACE FUNCTION fn_web_newsletter_collegamenti_da_verificare(
    p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(ordine INTEGER, tipo VARCHAR, descrizione TEXT, motivo TEXT)
LANGUAGE sql STABLE AS $$
    WITH blocchi AS (
        SELECT b.ordine, b.tipo, b.data_viaggio_id_fk, b.link_url,
               COALESCE(NULLIF(btrim(b.titolo), ''),
                        NULLIF(btrim(b.link_etichetta), ''),
                        'senza titolo') AS descrizione,
               -- Lo slug e' l'ULTIMO segmento, perche' i collegamenti che generiamo noi hanno
               -- la forma {sito}/tour/{slug} e finiscono li'. Prendere il primo segmento dopo
               -- /tour/ farebbe passare per slug un pezzo di percorso di un indirizzo scritto a
               -- mano — es. /it/tour/fuoristrada/autunno-gallura darebbe "fuoristrada" — e la
               -- verifica direbbe "tour inesistente" su un indirizzo che non abbiamo composto noi
               -- e su cui non possiamo pronunciarci. Un controllo che grida al lupo viene ignorato.
               substring(b.link_url from '/tour/([^/?#]+)/?$') AS slug
          FROM web_newsletter_blocchi b
         WHERE b.invio_id_fk = p_invio_id AND b.azienda_id = p_azienda_id
    )
    -- a) Blocchi ancora agganciati: la scheda della partenza c'e' ancora? Ed e' pubblicata?
    SELECT x.ordine, x.tipo::VARCHAR, x.descrizione,
           CASE WHEN c.web_tour_contenuti_id IS NULL
                THEN 'la scheda web di quel tour non esiste più: il collegamento non porta da nessuna parte'
                ELSE 'la scheda web di quel tour non è pubblicata: il collegamento non funzionerà'
           END
      FROM blocchi x
      LEFT JOIN web_tour_contenuti c
             ON c.data_viaggio_id_fk = x.data_viaggio_id_fk AND c.azienda_id = p_azienda_id
     WHERE x.data_viaggio_id_fk IS NOT NULL
       AND (c.web_tour_contenuti_id IS NULL OR c.stato_pubblicazione <> 'pubblicato')

    UNION ALL

    -- b) Blocchi con l'indirizzo di un tour ma senza aggancio: o sono stati composti prima che
    --    l'aggancio venisse registrato, o la partenza e' stata cancellata e la FK azzerata.
    SELECT x.ordine, x.tipo::VARCHAR, x.descrizione,
           CASE WHEN c.web_tour_contenuti_id IS NULL
                THEN 'punta a un tour che non esiste più sul sito'
                ELSE 'la scheda web di quel tour non è pubblicata: il collegamento non funzionerà'
           END
      FROM blocchi x
      LEFT JOIN web_tour_contenuti c
             ON c.slug = x.slug AND c.azienda_id = p_azienda_id
     WHERE x.data_viaggio_id_fk IS NULL
       AND x.slug IS NOT NULL
       AND (c.web_tour_contenuti_id IS NULL OR c.stato_pubblicazione <> 'pubblicato')

    ORDER BY 1;
$$;

COMMENT ON FUNCTION fn_web_newsletter_collegamenti_da_verificare(BIGINT, INTEGER) IS
'Blocchi il cui collegamento a un tour non porta più da nessuna parte. Vuoto = si può spedire.';
