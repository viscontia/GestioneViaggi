-- Allinea fn_web_tour_contenuti_clona alle mappe multiple e ai nuovi campi tradotti.
-- Segue gli script 493 (mappe multiple), 495/503 (campi traducibili), 497 (descrizione obbligatoria).
--
-- ⚠️ REGRESSIONE CORRETTA QUI: dal 497 la descrizione della mappa è NOT NULL, ma il clone — scritto
-- quando la mappa era una sola e senza descrizione — non la copiava. Risultato: **clonare un
-- contenuto con mappe falliva** con "null value in column descrizione". La clonazione è il modo
-- normale di riproporre un viaggio che si ripete, quindi era rotto proprio il percorso più usato.
--
-- Tre lacune sanate:
--   1. mappe: si copiano descrizione e gpx_bytes, e l'abbinamento alla giornata viene RIMAPPATO
--      sulla giornata clonata (copiarlo tale e quale punterebbe alla giornata di un'altra edizione,
--      cosa che la FK composita del 493 rifiuta);
--   2. traduzioni dei TITOLI DELLE GIORNATE (entità web_tour_itinerario, script 503);
--   3. traduzioni delle DESCRIZIONI DELLE MAPPE (entità web_tour_mappa, script 495).
--      Senza 2 e 3 il contenuto clonato nasceva con quei campi non tradotti e quindi NON
--      pubblicabile, costringendo a ritradurre testi identici all'originale.
--
-- Le traduzioni continuano a essere copiate conservando revisionato/obsoleto: il testo è lo stesso,
-- riportarle a "da revisionare" farebbe rifare un lavoro già fatto.
--
-- NOTA sui file su Storage: immagini e mappe clonate puntano agli STESSI oggetti dell'originale
-- (comportamento preesistente, non introdotto qui). Eliminando un media dall'edizione sorgente si
-- rompe anche quello della copia. Da valutare separatamente.

CREATE OR REPLACE FUNCTION fn_web_tour_contenuti_clona(
    p_contenuto_sorgente BIGINT,
    p_data_viaggio_dest  INTEGER,
    p_azienda_id         INTEGER)
RETURNS BIGINT LANGUAGE plpgsql AS $function$
DECLARE
    v_src        web_tour_contenuti%ROWTYPE;
    v_dest       ana_date_viaggi%ROWTYPE;
    v_nuovo_id   BIGINT;
    v_slug_base  VARCHAR;
    v_slug       VARCHAR;
    v_n          INTEGER := 1;
    v_giorno     RECORD;
    v_new_giorno BIGINT;
    v_passo      RECORD;
    v_new_passo  BIGINT;
    v_mappa      RECORD;
    v_new_mappa  BIGINT;
BEGIN
    -- 1. Validazioni
    SELECT * INTO v_src FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_contenuto_sorgente AND azienda_id = p_azienda_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contenuto sorgente % non trovato per azienda %', p_contenuto_sorgente, p_azienda_id;
    END IF;

    SELECT * INTO v_dest FROM ana_date_viaggi
     WHERE data_viaggio_id = p_data_viaggio_dest AND azienda_id = p_azienda_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Data destinazione % non trovata', p_data_viaggio_dest;
    END IF;

    IF v_dest.viaggio_id_fk <> v_src.viaggio_id_fk THEN
        RAISE EXCEPTION 'La data destinazione appartiene a un altro viaggio: clone consentito solo sullo stesso viaggio';
    END IF;

    IF EXISTS (SELECT 1 FROM web_tour_contenuti
               WHERE data_viaggio_id_fk = p_data_viaggio_dest AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'La data destinazione ha gia'' un contenuto: usa modifica invece di clona';
    END IF;

    -- 2. Slug nuovo: slug sorgente + date dal-al; suffisso progressivo su collisione
    v_slug_base := v_src.slug || '_' || to_char(v_dest.data_viaggio_data_inizio, 'YYYY-MM-DD')
                             || '_' || to_char(v_dest.data_viaggio_data_fine, 'YYYY-MM-DD');
    v_slug := v_slug_base;
    WHILE EXISTS (SELECT 1 FROM web_tour_contenuti WHERE azienda_id = p_azienda_id AND slug = v_slug) LOOP
        v_n := v_n + 1;
        v_slug := v_slug_base || '_' || v_n;
    END LOOP;

    -- 3. Nuovo contenuto: sempre BOZZA e senza data di prima pubblicazione, così una copia non
    --    arriva mai online scavalcando i controlli di pubblicazione.
    INSERT INTO web_tour_contenuti(
        viaggio_id_fk, data_viaggio_id_fk, sottotitolo, descrizione_html, durata_testo, luoghi_visitati,
        info_pernottamento_html, info_pasti_html, info_equipaggiamento_html, altre_info_html,
        slug, meta_title, meta_description, stato_pubblicazione, ordine, data_pubblicazione, azienda_id)
    VALUES (
        v_src.viaggio_id_fk, p_data_viaggio_dest, v_src.sottotitolo, v_src.descrizione_html, v_src.durata_testo, v_src.luoghi_visitati,
        v_src.info_pernottamento_html, v_src.info_pasti_html, v_src.info_equipaggiamento_html, v_src.altre_info_html,
        v_slug, v_src.meta_title, v_src.meta_description, 'bozza', v_src.ordine, NULL, p_azienda_id)
    RETURNING web_tour_contenuti_id INTO v_nuovo_id;

    -- 4. Immagini
    INSERT INTO web_tour_immagini(web_tour_contenuti_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, nome_file, ordine, azienda_id)
    SELECT v_nuovo_id, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, nome_file, ordine, azienda_id
      FROM web_tour_immagini
     WHERE web_tour_contenuti_id_fk = p_contenuto_sorgente AND azienda_id = p_azienda_id;

    -- 5. Itinerario: giornate e passaggi, con le mappe old->new necessarie ai remap successivi.
    CREATE TEMP TABLE _clone_map_passi (old_id BIGINT, new_id BIGINT) ON COMMIT DROP;
    CREATE TEMP TABLE _clone_map_giornate (old_id BIGINT, new_id BIGINT) ON COMMIT DROP;
    CREATE TEMP TABLE _clone_map_mappe (old_id BIGINT, new_id BIGINT) ON COMMIT DROP;

    FOR v_giorno IN
        SELECT * FROM web_tour_itinerario
         WHERE web_tour_contenuti_id_fk = p_contenuto_sorgente AND azienda_id = p_azienda_id
         ORDER BY giorno_numero
    LOOP
        INSERT INTO web_tour_itinerario(web_tour_contenuti_id_fk, giorno_numero, titolo_giornata, ordine, azienda_id)
        VALUES (v_nuovo_id, v_giorno.giorno_numero, v_giorno.titolo_giornata, v_giorno.ordine, p_azienda_id)
        RETURNING web_tour_itinerario_id INTO v_new_giorno;

        INSERT INTO _clone_map_giornate(old_id, new_id) VALUES (v_giorno.web_tour_itinerario_id, v_new_giorno);

        FOR v_passo IN
            SELECT * FROM web_tour_itinerario_passaggi
             WHERE itinerario_id_fk = v_giorno.web_tour_itinerario_id AND azienda_id = p_azienda_id
             ORDER BY ordine
        LOOP
            INSERT INTO web_tour_itinerario_passaggi(itinerario_id_fk, testo_html, immagine_url, immagine_storage_path, immagine_didascalia, ordine, azienda_id)
            VALUES (v_new_giorno, v_passo.testo_html, v_passo.immagine_url, v_passo.immagine_storage_path, v_passo.immagine_didascalia, v_passo.ordine, p_azienda_id)
            RETURNING web_tour_itinerario_passaggi_id INTO v_new_passo;

            INSERT INTO _clone_map_passi(old_id, new_id) VALUES (v_passo.web_tour_itinerario_passaggi_id, v_new_passo);
        END LOOP;
    END LOOP;

    -- 6. Mappe (0..N dal 493): riga per riga, per rimappare l'abbinamento alla giornata clonata
    --    e per poter poi rimappare le traduzioni della descrizione.
    FOR v_mappa IN
        SELECT * FROM web_tour_mappa
         WHERE web_tour_contenuti_id_fk = p_contenuto_sorgente AND azienda_id = p_azienda_id
    LOOP
        INSERT INTO web_tour_mappa(web_tour_contenuti_id_fk, web_tour_itinerario_id_fk, descrizione,
            gpx_originale, gpx_filename, gpx_bytes, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
            provider, stile, parametri_render, immagine_url, immagine_storage_path, data_generazione, azienda_id)
        VALUES (v_nuovo_id,
            (SELECT g.new_id FROM _clone_map_giornate g WHERE g.old_id = v_mappa.web_tour_itinerario_id_fk),
            v_mappa.descrizione,
            v_mappa.gpx_originale, v_mappa.gpx_filename, v_mappa.gpx_bytes,
            v_mappa.bbox_min_lat, v_mappa.bbox_min_lon, v_mappa.bbox_max_lat, v_mappa.bbox_max_lon,
            v_mappa.provider, v_mappa.stile, v_mappa.parametri_render,
            v_mappa.immagine_url, v_mappa.immagine_storage_path, v_mappa.data_generazione, p_azienda_id)
        RETURNING web_tour_mappa_id INTO v_new_mappa;

        INSERT INTO _clone_map_mappe(old_id, new_id) VALUES (v_mappa.web_tour_mappa_id, v_new_mappa);
    END LOOP;

    -- 7. Traduzioni del contenuto (entita_id: sorgente -> nuovo)
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    SELECT 'web_tour_contenuti', v_nuovo_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id
      FROM web_traduzioni
     WHERE entita = 'web_tour_contenuti' AND entita_id = p_contenuto_sorgente AND azienda_id = p_azienda_id;

    -- 8. Traduzioni dei passi (remap)
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    SELECT 'web_tour_itinerario_passaggi', m.new_id, tr.campo, tr.lingua, tr.testo, tr.tradotto_auto, tr.revisionato, tr.obsoleto, tr.data_traduzione, tr.azienda_id
      FROM web_traduzioni tr
      JOIN _clone_map_passi m ON m.old_id = tr.entita_id
     WHERE tr.entita = 'web_tour_itinerario_passaggi' AND tr.azienda_id = p_azienda_id;

    -- 9. Traduzioni dei titoli delle giornate (remap) — script 503
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    SELECT 'web_tour_itinerario', m.new_id, tr.campo, tr.lingua, tr.testo, tr.tradotto_auto, tr.revisionato, tr.obsoleto, tr.data_traduzione, tr.azienda_id
      FROM web_traduzioni tr
      JOIN _clone_map_giornate m ON m.old_id = tr.entita_id
     WHERE tr.entita = 'web_tour_itinerario' AND tr.azienda_id = p_azienda_id;

    -- 10. Traduzioni delle descrizioni delle mappe (remap) — script 495
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id)
    SELECT 'web_tour_mappa', m.new_id, tr.campo, tr.lingua, tr.testo, tr.tradotto_auto, tr.revisionato, tr.obsoleto, tr.data_traduzione, tr.azienda_id
      FROM web_traduzioni tr
      JOIN _clone_map_mappe m ON m.old_id = tr.entita_id
     WHERE tr.entita = 'web_tour_mappa' AND tr.azienda_id = p_azienda_id;

    RETURN v_nuovo_id;
END $function$;

COMMENT ON FUNCTION fn_web_tour_contenuti_clona(BIGINT, INTEGER, INTEGER) IS
'Clona la scheda web di una edizione su un''altra data dello STESSO viaggio: editoriale, immagini, itinerario, mappe (con abbinamento giornata rimappato) e tutte le traduzioni, conservando revisionato/obsoleto. La copia nasce sempre in bozza. I file su Storage restano condivisi con l''originale.';
