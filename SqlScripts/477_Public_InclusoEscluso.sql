-- ============================================================================
-- Incluso/Escluso nello strato pubblico: fn_web_tour_pubblicati emette anche
-- viaggio_incluso/escluso (da ana_viaggi), tradotti per lingua via web_traduzioni
-- (entita='ana_viaggi', entita_id=viaggio_id). Fallback all'italiano quando manca
-- la traduzione o è obsoleta. Colonne aggiunte in coda per non riordinare l'output.
-- ============================================================================

DROP FUNCTION IF EXISTS fn_web_tour_pubblicati(integer, character);

CREATE OR REPLACE FUNCTION fn_web_tour_pubblicati(p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar)
 RETURNS TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying,
               descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying,
               numero_giorni integer, descrizione_web character varying, descrizione_slug character varying,
               prezzo_da integer, data_inizio date, data_fine date, immagine_url text,
               immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer,
               incluso text, escluso text)
 LANGUAGE sql STABLE
AS $function$
    SELECT v.viaggio_id,
           c.web_tour_contenuti_id,
           v.viaggio_descrizione_breve,
           COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR,
           COALESCE(t_descr.testo, c.descrizione_html),
           c.slug,
           v.viaggio_difficolta,
           COALESCE(t_dur.testo, c.durata_testo)::VARCHAR,
           v.viaggio_numero_giorni,
           d.descrizione_web,
           d.slug,
           fn_web_prezzo_da_data(dv.data_viaggio_id),
           dv.data_viaggio_data_inizio,
           dv.data_viaggio_data_fine,
           img.url,
           img.storage_path,
           c.data_pubblicazione,
           c.ordine,
           COALESCE(t_inc.testo, v.viaggio_incluso),
           COALESCE(t_esc.testo, v.viaggio_escluso)
      FROM web_tour_contenuti c
      JOIN ana_date_viaggi dv      ON dv.data_viaggio_id = c.data_viaggio_id_fk
      JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
      LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      LEFT JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
      LEFT JOIN web_tour_immagini img   ON img.web_tour_contenuti_id_fk = c.web_tour_contenuti_id AND img.tipo = 'principale'
      LEFT JOIN web_traduzioni t_sott  ON p_lingua <> 'IT'
           AND t_sott.entita = 'web_tour_contenuti' AND t_sott.entita_id = c.web_tour_contenuti_id
           AND t_sott.campo = 'sottotitolo'      AND t_sott.lingua = p_lingua AND NOT t_sott.obsoleto
      LEFT JOIN web_traduzioni t_descr ON p_lingua <> 'IT'
           AND t_descr.entita = 'web_tour_contenuti' AND t_descr.entita_id = c.web_tour_contenuti_id
           AND t_descr.campo = 'descrizione_html' AND t_descr.lingua = p_lingua AND NOT t_descr.obsoleto
      LEFT JOIN web_traduzioni t_dur   ON p_lingua <> 'IT'
           AND t_dur.entita = 'web_tour_contenuti'  AND t_dur.entita_id = c.web_tour_contenuti_id
           AND t_dur.campo = 'durata_testo'       AND t_dur.lingua = p_lingua AND NOT t_dur.obsoleto
      LEFT JOIN web_traduzioni t_inc   ON p_lingua <> 'IT'
           AND t_inc.entita = 'ana_viaggi'          AND t_inc.entita_id = v.viaggio_id
           AND t_inc.campo = 'viaggio_incluso'    AND t_inc.lingua = p_lingua AND NOT t_inc.obsoleto
      LEFT JOIN web_traduzioni t_esc   ON p_lingua <> 'IT'
           AND t_esc.entita = 'ana_viaggi'          AND t_esc.entita_id = v.viaggio_id
           AND t_esc.campo = 'viaggio_escluso'    AND t_esc.lingua = p_lingua AND NOT t_esc.obsoleto
     WHERE c.azienda_id = p_azienda_id
       AND c.stato_pubblicazione = 'pubblicato'
     ORDER BY c.ordine, v.viaggio_descrizione_breve;
$function$;

GRANT EXECUTE ON FUNCTION fn_web_tour_pubblicati(integer, character) TO anon;
