-- Blocco 3 (supporto Task 3.3) - Lettura anon "gated" sulle tabelle operative minime.
--
-- Perche' serve: le funzioni di lettura pubblica (fn_web_tour_pubblicati, fn_web_prezzo_da)
-- sono SECURITY INVOKER e joinano ana_viaggi / ana_tipo_viaggi / ana_date_viaggi.
-- Chiamate come anon fallirebbero senza SELECT su quelle tabelle. Si concede quindi
-- il MINIMO indispensabile:
--   * GRANT a livello di colonna (mai note interne, blob mappa legacy, audit *_by);
--   * policy gated: visibili SOLO le righe dei viaggi con contenuto web PUBBLICATO
--     (ana_viaggi/ana_date_viaggi hanno gia' RLS abilitata: la policy e' subito effettiva).
--   * ana_tipo_viaggi NON ha RLS abilitata (lookup legacy): NIENTE enable qui per non
--     toccare il comportamento del gestionale; si espongono solo i due id di mapping
--     (tipo_viaggi_id, web_categoria_fk), nessun dato descrittivo ne' multi-tenant.

-- ---------------------------------------------------------------------------
-- ANA_VIAGGI: dati descrittivi minimi del tour pubblicato
-- ---------------------------------------------------------------------------
GRANT SELECT (viaggio_id, viaggio_descrizione_breve, viaggio_descrizione_estesa,
              viaggio_numero_giorni, viaggio_numero_notti, viaggio_num_km,
              viaggio_pasti_al_sacco, viaggio_tipo_viaggio_fk, viaggio_nazione_fk, azienda_id)
    ON ana_viaggi TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON ana_viaggi
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = ana_viaggi.viaggio_id
          AND c.stato_pubblicazione = 'pubblicato'));

-- ---------------------------------------------------------------------------
-- ANA_TIPO_VIAGGI: solo mapping tipo -> categoria sport (id numerici)
-- ---------------------------------------------------------------------------
GRANT SELECT (tipo_viaggi_id, web_categoria_fk) ON ana_tipo_viaggi TO anon;

-- ---------------------------------------------------------------------------
-- ANA_DATE_VIAGGI: date e tariffe delle partenze dei tour pubblicati
-- (il sito mostra prezzi/date; niente note interne)
-- ---------------------------------------------------------------------------
GRANT SELECT (data_viaggio_id, viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine,
              data_viaggio_costo_pilota, data_viaggio_costo_passeggero,
              data_viaggio_costo_passeggero_auto_guida, data_viaggio_costo_bambino_0_2,
              data_viaggio_costo_bambino_2_6, data_viaggio_costo_bambino_6_12, azienda_id)
    ON ana_date_viaggi TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON ana_date_viaggi
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = ana_date_viaggi.viaggio_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));
