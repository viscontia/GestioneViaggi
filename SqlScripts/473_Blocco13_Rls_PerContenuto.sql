-- ============================================================================
-- Blocco 13 — Fase C: RLS anon ricablata sul CONTENUTO (per-edizione).
-- Le figlie sono gated via web_tour_contenuti_id_fk (era viaggio_id_fk).
-- GRANT colonnari aggiornati (contenuti: -difficolta +data_viaggio_id_fk;
-- ana_viaggi: +viaggio_difficolta; figlie: viaggio_id_fk->web_tour_contenuti_id_fk).
-- ana_date_viaggi: policy stretta alla sola data pubblicata.
-- Ricrea le policy 'anon_read_if_tour_pubblicato' droppate in Fase B.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- CONTENUTI: GRANT aggiornato (-difficolta, +data_viaggio_id_fk). Policy stato invariata.
-- ---------------------------------------------------------------------------
REVOKE SELECT ON web_tour_contenuti FROM anon;
GRANT SELECT (web_tour_contenuti_id, viaggio_id_fk, data_viaggio_id_fk, sottotitolo, descrizione_html,
              durata_testo, luoghi_visitati, info_pernottamento_html, info_pasti_html,
              info_equipaggiamento_html, altre_info_html, slug, meta_title, meta_description,
              stato_pubblicazione, ordine, data_pubblicazione, azienda_id, created, updated)
    ON web_tour_contenuti TO anon;

-- ---------------------------------------------------------------------------
-- ITINERARIO: gated via contenuto pubblicato
-- ---------------------------------------------------------------------------
REVOKE SELECT ON web_tour_itinerario FROM anon;
GRANT SELECT (web_tour_itinerario_id, web_tour_contenuti_id_fk, giorno_numero, titolo_giornata, ordine, azienda_id)
    ON web_tour_itinerario TO anon;
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_itinerario;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_itinerario
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.web_tour_contenuti_id = web_tour_itinerario.web_tour_contenuti_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- PASSAGGI: gated via giornata -> contenuto pubblicato
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_itinerario_passaggi;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_itinerario_passaggi
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_itinerario i
        JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = i.web_tour_contenuti_id_fk
        WHERE i.web_tour_itinerario_id = web_tour_itinerario_passaggi.itinerario_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- IMMAGINI: gated via contenuto pubblicato
-- ---------------------------------------------------------------------------
REVOKE SELECT ON web_tour_immagini FROM anon;
GRANT SELECT (web_tour_immagini_id, web_tour_contenuti_id_fk, tipo, url, storage_path, alt_text, titolo,
              larghezza, altezza, mime, ordine, azienda_id)
    ON web_tour_immagini TO anon;
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_immagini;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_immagini
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.web_tour_contenuti_id = web_tour_immagini.web_tour_contenuti_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- MAPPA: gated via contenuto pubblicato (GPX/parametri restano esclusi)
-- ---------------------------------------------------------------------------
REVOKE SELECT ON web_tour_mappa FROM anon;
GRANT SELECT (web_tour_mappa_id, web_tour_contenuti_id_fk, bbox_min_lat, bbox_min_lon, bbox_max_lat,
              bbox_max_lon, provider, stile, immagine_url, immagine_storage_path,
              data_generazione, azienda_id)
    ON web_tour_mappa TO anon;
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON web_tour_mappa;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_mappa
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.web_tour_contenuti_id = web_tour_mappa.web_tour_contenuti_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- ANA_VIAGGI: GRANT +viaggio_difficolta (serve al sito). Policy invariata
-- (contenuti mantiene viaggio_id_fk: EXISTS resta valido con N contenuti/viaggio).
-- ---------------------------------------------------------------------------
REVOKE SELECT ON ana_viaggi FROM anon;
GRANT SELECT (viaggio_id, viaggio_descrizione_breve, viaggio_descrizione_estesa,
              viaggio_numero_giorni, viaggio_numero_notti, viaggio_num_km, viaggio_difficolta,
              viaggio_pasti_al_sacco, viaggio_tipo_viaggio_fk, viaggio_nazione_fk, azienda_id)
    ON ana_viaggi TO anon;

-- ---------------------------------------------------------------------------
-- ANA_DATE_VIAGGI: policy STRETTA alla sola data pubblicata (era: tutte le date
-- del viaggio se una qualsiasi edizione pubblicata). GRANT invariato.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS anon_read_if_tour_pubblicato ON ana_date_viaggi;
CREATE POLICY anon_read_if_tour_pubblicato ON ana_date_viaggi
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.data_viaggio_id_fk = ana_date_viaggi.data_viaggio_id
          AND c.stato_pubblicazione = 'pubblicato'));
