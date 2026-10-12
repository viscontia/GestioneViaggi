-- ============================================================================
-- 677 — Il periodo delle newsletter in italiano corretto: «dall'8», «all'11»
--
-- fn_web_newsletter_dati_tour (514, 676) scriveva «Dal 4 al 8 dicembre» e
-- «Dal 11 al 13 marzo». Davanti a 8 e 11 la preposizione si elide (dall'8,
-- all'11, l'8); il primo del mese si scrive 1° (dal 1° al 5 maggio).
--
--   fn_web_giorno(preposizione, data) → «Dal 4» · «Dall'8» · «al 1°» · «L'11»
--     preposizione: 'Dal', 'al' o 'Il' (maiuscola/minuscola come la si passa).
--
-- Solo il periodo cambia; il resto della funzione e' quello del 676.
-- Nessun GRANT (659), search_path fissato (655). Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_giorno(p_preposizione text, p_data date)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path = public, pg_temp
AS $$
    SELECT CASE
        WHEN EXTRACT(DAY FROM p_data) = 1 THEN p_preposizione || ' 1°'
        WHEN EXTRACT(DAY FROM p_data) IN (8, 11) THEN
            CASE p_preposizione
                WHEN 'Dal' THEN 'Dall'''  WHEN 'dal' THEN 'dall'''
                WHEN 'Al'  THEN 'All'''   WHEN 'al'  THEN 'all'''
                WHEN 'Il'  THEN 'L'''     WHEN 'il'  THEN 'l'''
                ELSE p_preposizione || ' '
            END || EXTRACT(DAY FROM p_data)::int
        ELSE p_preposizione || ' ' || EXTRACT(DAY FROM p_data)::int
    END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_giorno(text, date) FROM PUBLIC;

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
                THEN fn_web_giorno('Il', d.data_viaggio_data_inizio) || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_inizio, 'YYYY')

            -- stesso mese e stesso anno: "Dal 12 al 15 ottobre 2026"
            WHEN date_trunc('month', d.data_viaggio_data_inizio) = date_trunc('month', d.data_viaggio_data_fine)
                THEN fn_web_giorno('Dal', d.data_viaggio_data_inizio) || ' ' ||
                     fn_web_giorno('al', d.data_viaggio_data_fine) || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_fine)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'YYYY')

            -- stesso anno, mesi diversi: "Dal 28 ottobre al 2 novembre 2026"
            WHEN EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = EXTRACT(YEAR FROM d.data_viaggio_data_fine)
                THEN fn_web_giorno('Dal', d.data_viaggio_data_inizio) || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' ' ||
                     fn_web_giorno('al', d.data_viaggio_data_fine) || ' ' ||
                     fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_fine)::INTEGER) || ' ' ||
                     TO_CHAR(d.data_viaggio_data_fine, 'YYYY')

            -- a cavallo d'anno (Capodanno): l'anno serve due volte
            ELSE fn_web_giorno('Dal', d.data_viaggio_data_inizio) || ' ' ||
                 fn_mese_italiano(EXTRACT(MONTH FROM d.data_viaggio_data_inizio)::INTEGER) || ' ' ||
                 TO_CHAR(d.data_viaggio_data_inizio, 'YYYY') || ' ' ||
                 fn_web_giorno('al', d.data_viaggio_data_fine) || ' ' ||
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
-- Verifica (atteso: ok = true su ogni riga)
SELECT p, d, fn_web_giorno(p, d) AS risultato, fn_web_giorno(p, d) = atteso AS ok
  FROM (VALUES ('Dal', DATE '2026-12-04', 'Dal 4'),   ('Dal', DATE '2026-12-08', 'Dall''8'),
               ('al',  DATE '2027-03-11', 'all''11'), ('al',  DATE '2027-05-01', 'al 1°'),
               ('Il',  DATE '2027-03-08', 'L''8'),    ('Dal', DATE '2027-03-18', 'Dal 18')) AS c(p, d, atteso);
-- ============================================================================
