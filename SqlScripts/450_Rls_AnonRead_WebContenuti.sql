-- Blocco 3 (Task 3.1) - Lettura pubblica anon sulle tabelle-contenuto web.
-- Principio: anon legge SOLO contenuti pubblicati; tutto il resto e' negato (nessun GRANT).
--
-- Deviazione di sicurezza rispetto all'esempio del piano (full-table GRANT):
-- i GRANT SELECT sono A LIVELLO DI COLONNA ed escludono SEMPRE created_by/updated_by
-- (contengono le email degli operatori del gestionale: non devono essere esposte al sito).
-- Su web_tour_mappa sono esclusi anche gpx_originale/gpx_filename/parametri_render
-- ("GPX mai al browser, nessun dato vettoriale esposto" - vincolo Blocco 9).
--
-- Le policy restano role-based pure (TO anon, niente auth.*): identiche su Postgres liscio e Supabase.

-- ---------------------------------------------------------------------------
-- CONTENUTI TOUR: solo pubblicati
-- ---------------------------------------------------------------------------
GRANT SELECT (web_tour_contenuti_id, viaggio_id_fk, sottotitolo, descrizione_html, difficolta,
              durata_testo, luoghi_visitati, info_pernottamento_html, info_pasti_html,
              info_equipaggiamento_html, altre_info_html, slug, meta_title, meta_description,
              stato_pubblicazione, ordine, data_pubblicazione, azienda_id, created, updated)
    ON web_tour_contenuti TO anon;
CREATE POLICY anon_read_pubblicati ON web_tour_contenuti
    FOR SELECT TO anon USING (stato_pubblicazione = 'pubblicato');

-- ---------------------------------------------------------------------------
-- CATEGORIE SPORT: pubbliche (lookup di navigazione)
-- ---------------------------------------------------------------------------
GRANT SELECT (web_categorie_sport_id, codice, etichetta, slug, ordine, azienda_id)
    ON web_categorie_sport TO anon;
CREATE POLICY anon_read_all ON web_categorie_sport FOR SELECT TO anon USING (true);

-- ---------------------------------------------------------------------------
-- ITINERARIO: solo se il tour e' pubblicato (evita leak di bozze)
-- ---------------------------------------------------------------------------
GRANT SELECT (web_tour_itinerario_id, viaggio_id_fk, giorno_numero, titolo_giornata, ordine, azienda_id)
    ON web_tour_itinerario TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_itinerario
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = web_tour_itinerario.viaggio_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- PASSAGGI ITINERARIO: gated via giornata -> tour pubblicato
-- ---------------------------------------------------------------------------
GRANT SELECT (web_tour_itinerario_passaggi_id, itinerario_id_fk, testo_html, immagine_url,
              immagine_storage_path, immagine_didascalia, ordine, azienda_id)
    ON web_tour_itinerario_passaggi TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_itinerario_passaggi
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_itinerario i
        JOIN web_tour_contenuti c ON c.viaggio_id_fk = i.viaggio_id_fk
        WHERE i.web_tour_itinerario_id = web_tour_itinerario_passaggi.itinerario_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- IMMAGINI: gated via tour pubblicato
-- ---------------------------------------------------------------------------
GRANT SELECT (web_tour_immagini_id, viaggio_id_fk, tipo, url, storage_path, alt_text, titolo,
              larghezza, altezza, mime, ordine, azienda_id)
    ON web_tour_immagini TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_immagini
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = web_tour_immagini.viaggio_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- MAPPA: gated via tour pubblicato; SOLO immagine statica + bbox + attribuzione.
-- Colonne GPX e parametri di render MAI esposte (dato vettoriale solo server).
-- ---------------------------------------------------------------------------
GRANT SELECT (web_tour_mappa_id, viaggio_id_fk, bbox_min_lat, bbox_min_lon, bbox_max_lat,
              bbox_max_lon, provider, stile, immagine_url, immagine_storage_path,
              data_generazione, azienda_id)
    ON web_tour_mappa TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_mappa
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = web_tour_mappa.viaggio_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- TRADUZIONI: USING(true) (DECISO nel design doc: niente gating dinamico sul campo
-- polimorfico entita; una traduzione isolata fuori contesto non e' un leak critico
-- e il sito parte sempre dalle entita' principali gia' filtrate).
-- ---------------------------------------------------------------------------
GRANT SELECT (web_traduzioni_id, entita, entita_id, campo, lingua, testo, tradotto_auto,
              revisionato, obsoleto, data_traduzione, azienda_id)
    ON web_traduzioni TO anon;
CREATE POLICY anon_read_all ON web_traduzioni FOR SELECT TO anon USING (true);

-- ---------------------------------------------------------------------------
-- BLOG (predisposizione): solo articoli pubblicati
-- ---------------------------------------------------------------------------
GRANT SELECT (web_blog_articoli_id, titolo, slug, sottotitolo, contenuto_html, immagine_url,
              stato_pubblicazione, data_pubblicazione, meta_title, meta_description, azienda_id)
    ON web_blog_articoli TO anon;
CREATE POLICY anon_read_pubblicati ON web_blog_articoli
    FOR SELECT TO anon USING (stato_pubblicazione = 'pubblicato');
