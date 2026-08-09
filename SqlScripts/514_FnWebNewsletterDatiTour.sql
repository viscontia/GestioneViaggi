-- Contenuto di un riquadro "tour" della newsletter a partire da un'edizione (Fase 3).
-- Design: "Estensione Progetto WEB/Documenti/2026-08-09-Newsletter_Blocchi_design.md" §2.3
--
-- E' il pezzo che fa risparmiare piu' tempo: scelta l'edizione, titolo, periodo, testo,
-- copertina e link si compilano da soli invece di essere ricopiati a mano dalla scheda del tour.
--
-- Da sapere sul risultato:
--   * il TITOLO e' il nome del viaggio (ana_viaggi.viaggio_descrizione_breve): web_tour_contenuti
--     non ha un titolo proprio, ha un sottotitolo editoriale e i meta per la SEO;
--   * il PERIODO e' cio' che distingue un'edizione dall'altra ed e' la prima cosa che il lettore
--     cerca ("quando si parte?"), quindi va nel sottotitolo del riquadro;
--   * la COPERTINA e' l'immagine 'principale' del contenuto, altrimenti la prima della galleria.
--     Puo' essere NULL: un tour senza foto esiste e non deve impedire di creare il blocco;
--   * storage_path torna accanto all'URL perche' la versione da email (JPEG) si deriva
--     dall'originale: l'URL della galleria e' WebP e Outlook non lo mostra;
--   * pubblicato dice se la scheda e' visibile sul sito. Un link a una scheda in bozza porta a una
--     pagina che non esiste: avvisare e' compito della UI, non di questa function.

-- I mesi in italiano: TO_CHAR li darebbe in inglese (o dipendenti dal lc_time del server,
-- che e' peggio perche' cambia da macchina a macchina).
CREATE OR REPLACE FUNCTION fn_mese_italiano(p_mese INTEGER)
RETURNS VARCHAR LANGUAGE sql IMMUTABLE AS $$
    SELECT (ARRAY['gennaio','febbraio','marzo','aprile','maggio','giugno',
                  'luglio','agosto','settembre','ottobre','novembre','dicembre'])[p_mese]::VARCHAR;
$$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_dati_tour(
    p_data_viaggio_id INTEGER,
    p_azienda_id      INTEGER)
RETURNS TABLE(
    titolo                VARCHAR,
    periodo               VARCHAR,
    testo                 VARCHAR,
    slug                  VARCHAR,
    pubblicato            BOOLEAN,
    immagine_url          VARCHAR,
    immagine_storage_path VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT
        v.viaggio_descrizione_breve::VARCHAR AS titolo,

        -- Periodo in forma LEGGIBILE, non tecnica: in una newsletter "Dal 12 al 15 ottobre 2026"
        -- si legge, "12/10/2026 - 15/10/2026" si decifra. Mese e anno non si ripetono quando
        -- coincidono, che e' come lo scriverebbe una persona.
        (CASE
            WHEN d.data_viaggio_data_fine = d.data_viaggio_data_inizio
                THEN 'Il ' || TO_CHAR(d.data_viaggio_data_inizio, 'FMDD') || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_inizio, 'YYYY')

            -- stesso mese e stesso anno: "Dal 12 al 15 ottobre 2026"
            WHEN date_trunc('month', d.data_viaggio_data_inizio) = date_trunc('month', d.data_viaggio_data_fine)
                THEN 'Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'FMDD') || ' al ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'FMDD') || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_fine)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'YYYY')

            -- stesso anno, mesi diversi: "Dal 28 ottobre al 2 novembre 2026"
            WHEN EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = EXTRACT(YEAR FROM d.data_viaggio_data_fine)
                THEN 'Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'FMDD') || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' al ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'FMDD') || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_fine)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'YYYY')

            -- a cavallo d'anno (Capodanno): l'anno serve due volte
            ELSE 'Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'FMDD') || ' ' ||
                 fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' ' ||
                 TO_CHAR(d.data_viaggio_data_inizio, 'YYYY') || ' al ' ||
                 TO_CHAR(d.data_viaggio_data_fine, 'FMDD') || ' ' ||
                 fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_fine)::INTEGER) || ' ' ||
                 TO_CHAR(d.data_viaggio_data_fine, 'YYYY')
         END)::VARCHAR AS periodo,

        NULLIF(BTRIM(c.sottotitolo), '')::VARCHAR AS testo,

        c.slug,
        (c.stato_pubblicazione = 'pubblicato') AS pubblicato,

        (SELECT i.url FROM web_tour_immagini i
          WHERE i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
          ORDER BY (i.tipo = 'principale') DESC, i.ordine, i.web_tour_immagini_id
          LIMIT 1)::VARCHAR AS immagine_url,

        (SELECT i.storage_path FROM web_tour_immagini i
          WHERE i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
          ORDER BY (i.tipo = 'principale') DESC, i.ordine, i.web_tour_immagini_id
          LIMIT 1)::VARCHAR AS immagine_storage_path

      FROM web_tour_contenuti c
      JOIN ana_date_viaggi d ON d.data_viaggio_id = c.data_viaggio_id_fk
      JOIN ana_viaggi      v ON v.viaggio_id      = d.viaggio_id_fk
     WHERE c.data_viaggio_id_fk = p_data_viaggio_id
       AND c.azienda_id = p_azienda_id;
$$;
