-- Blocco 8: fn_web_tour_pubblicati ora espone la DESCRIZIONE WEB del tipo di viaggio
-- (via ana_tipo_viaggi.descrizione_web_fk → web_tipi_viaggio_descrizioni), non più la vecchia
-- "categoria sport". Il reshape (459) ha rinominato tabella/colonne → questa funzione era rotta.
-- Cambio la firma di output (via categoria_codice; categoria_etichetta→descrizione_web;
-- categoria_slug→descrizione_slug) quindi serve DROP + CREATE. Nessun consumatore C# (verificato).
DROP FUNCTION IF EXISTS fn_web_tour_pubblicati(integer, character);

CREATE OR REPLACE FUNCTION fn_web_tour_pubblicati(p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar)
 RETURNS TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying, descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying, numero_giorni integer, descrizione_web character varying, descrizione_slug character varying, prezzo_da integer, immagine_url text, immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT v.viaggio_id,
           c.web_tour_contenuti_id,
           v.viaggio_descrizione_breve,
           COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR,
           COALESCE(t_descr.testo, c.descrizione_html),
           c.slug,
           c.difficolta,
           COALESCE(t_dur.testo, c.durata_testo)::VARCHAR,
           v.viaggio_numero_giorni,
           d.descrizione_web,
           d.slug,
           fn_web_prezzo_da(v.viaggio_id),
           img.url,
           img.storage_path,
           c.data_pubblicazione,
           c.ordine
      FROM web_tour_contenuti c
      JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
      LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      LEFT JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
      LEFT JOIN web_tour_immagini img   ON img.viaggio_id_fk = v.viaggio_id AND img.tipo = 'principale'
      LEFT JOIN web_traduzioni t_sott  ON p_lingua <> 'IT'
           AND t_sott.entita = 'web_tour_contenuti' AND t_sott.entita_id = c.web_tour_contenuti_id
           AND t_sott.campo = 'sottotitolo'      AND t_sott.lingua = p_lingua AND NOT t_sott.obsoleto
      LEFT JOIN web_traduzioni t_descr ON p_lingua <> 'IT'
           AND t_descr.entita = 'web_tour_contenuti' AND t_descr.entita_id = c.web_tour_contenuti_id
           AND t_descr.campo = 'descrizione_html' AND t_descr.lingua = p_lingua AND NOT t_descr.obsoleto
      LEFT JOIN web_traduzioni t_dur   ON p_lingua <> 'IT'
           AND t_dur.entita = 'web_tour_contenuti'  AND t_dur.entita_id = c.web_tour_contenuti_id
           AND t_dur.campo = 'durata_testo'       AND t_dur.lingua = p_lingua AND NOT t_dur.obsoleto
     WHERE c.azienda_id = p_azienda_id
       AND c.stato_pubblicazione = 'pubblicato'
     ORDER BY c.ordine, v.viaggio_descrizione_breve;
$function$;
