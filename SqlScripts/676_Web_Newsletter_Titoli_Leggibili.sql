-- ============================================================================
-- 676 — Anche nelle newsletter i titoli dei tour non in MAIUSCOLO
--
-- fn_web_newsletter_dati_tour (514) metteva nel blocco tour della newsletter la
-- descrizione breve del viaggio cosi' come la scrive il gestionale, in
-- maiuscolo. Passa ora da fn_web_titolo_leggibile (675), la stessa del sito:
-- un tour si chiama allo stesso modo sul sito e nella mail.
-- Cambia solo la riga del titolo; permessi e proprietario restano (REPLACE).
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_web_newsletter_dati_tour(p_data_viaggio_id integer, p_azienda_id integer)
 RETURNS TABLE(titolo character varying, periodo character varying, testo character varying, slug character varying, pubblicato boolean, immagine_url character varying, immagine_storage_path character varying)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT
        -- 676: come sul sito (675), non il MAIUSCOLO del gestionale
        fn_web_titolo_leggibile(v.viaggio_descrizione_breve)::VARCHAR AS titolo,

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
$function$;

COMMIT;

-- ============================================================================
-- Verifica (atteso: titoli in forma leggibile)
-- SELECT titolo, periodo FROM fn_web_newsletter_dati_tour(<data_viaggio_id>, 2);
-- ============================================================================
