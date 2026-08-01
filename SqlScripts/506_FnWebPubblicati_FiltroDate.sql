-- Filtro sulle date in lettura: il sito pubblico non deve mostrare partenze già iniziate.
--
-- fn_web_tour_pubblicati filtrava solo su azienda + stato_pubblicazione = 'pubblicato'. Una partenza
-- pubblicata restava quindi visibile anche a viaggio concluso: nessun processo la ritira, e un trigger
-- non potrebbe farlo perché il semplice passare del tempo non produce nessun evento DML.
-- Il filtro in lettura risolve alla radice: la scheda esce dal sito da sola quando la data arriva,
-- qualunque sia lo stato registrato. Lo stato 'archiviato' resta una scelta editoriale dell'utente.
--
-- Taglio scelto: data di INIZIO. È lo stesso confine della scrittura (StatoPartenzaRules.MotivoNonPubblicabile
-- consente di pubblicare solo una partenza che deve ancora iniziare), così le due regole non divergono.
--
-- Stesso trattamento a fn_web_ha_tour_brevi_pubblicati: decide se il sito mostra la sezione "tour brevi",
-- e senza il filtro l'avrebbe mostrata vuota sulla base di partenze ormai passate.

CREATE OR REPLACE FUNCTION public.fn_web_tour_pubblicati(p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar)
 RETURNS TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying, descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying, numero_giorni integer, descrizione_web character varying, descrizione_slug character varying, prezzo_da integer, data_inizio date, data_fine date, immagine_url text, immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer, incluso text, escluso text, posti_rimasti integer, posti_stato text, is_tour_breve boolean, meta_title character varying, meta_description character varying)
 LANGUAGE sql
 STABLE
AS $function$
    WITH base AS (
        SELECT v.viaggio_id                          AS b_viaggio_id,
               c.web_tour_contenuti_id               AS b_contenuto_id,
               v.viaggio_descrizione_breve           AS b_titolo,
               COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR   AS b_sottotitolo,
               COALESCE(t_descr.testo, c.descrizione_html)      AS b_descrizione_html,
               c.slug                                AS b_slug,
               v.viaggio_difficolta                  AS b_difficolta,
               COALESCE(t_dur.testo, c.durata_testo)::VARCHAR   AS b_durata_testo,
               v.viaggio_numero_giorni               AS b_numero_giorni,
               d.descrizione_web                     AS b_descrizione_web,
               d.slug                                AS b_descrizione_slug,
               fn_web_prezzo_da_data(dv.data_viaggio_id)        AS b_prezzo_da,
               dv.data_viaggio_data_inizio           AS b_data_inizio,
               dv.data_viaggio_data_fine             AS b_data_fine,
               img.url                               AS b_immagine_url,
               img.storage_path                      AS b_immagine_storage_path,
               c.data_pubblicazione                  AS b_data_pubblicazione,
               c.ordine                              AS b_ordine,
               COALESCE(t_inc.testo, v.viaggio_incluso)         AS b_incluso,
               COALESCE(t_esc.testo, v.viaggio_escluso)         AS b_escluso,
               v.viaggio_capienza_max                AS b_cap_max,
               v.viaggio_capienza_alert              AS b_cap_alert,
               fn_web_mezzi_occupati_data(dv.data_viaggio_id)   AS b_occupati,
               COALESCE(tv.tipo_viaggio_breve, false)           AS b_is_tour_breve,
               c.meta_title                          AS b_meta_title,
               c.meta_description                    AS b_meta_description
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
           -- Una partenza già iniziata non si vende più: il sito pubblico non deve mostrarla.
           -- Taglio alla data di INIZIO, lo stesso che StatoPartenzaRules.MotivoNonPubblicabile impone
           -- in scrittura (si pubblica solo una partenza che deve ancora iniziare): senza questo filtro
           -- una scheda pubblicata resterebbe visibile per sempre, perché nulla la ritira allo scadere.
           AND dv.data_viaggio_data_inizio > CURRENT_DATE
    )
    SELECT b_viaggio_id, b_contenuto_id, b_titolo, b_sottotitolo, b_descrizione_html, b_slug,
           b_difficolta, b_durata_testo, b_numero_giorni, b_descrizione_web, b_descrizione_slug,
           b_prezzo_da, b_data_inizio, b_data_fine, b_immagine_url, b_immagine_storage_path,
           b_data_pubblicazione, b_ordine, b_incluso, b_escluso,
           CASE WHEN b_cap_max IS NULL THEN NULL
                ELSE GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) END AS posti_rimasti,
           CASE WHEN b_cap_max IS NULL THEN NULL
                WHEN GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) = 0 THEN 'sold_out'
                WHEN b_cap_alert IS NOT NULL
                     AND GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) <= b_cap_alert THEN 'ultimi'
                ELSE 'disponibile' END AS posti_stato,
           b_is_tour_breve,
           COALESCE(NULLIF(btrim(b_meta_title), ''), b_titolo)::VARCHAR       AS meta_title,
           COALESCE(NULLIF(btrim(b_meta_description), ''), b_sottotitolo)::VARCHAR AS meta_description
      FROM base
     ORDER BY b_ordine, b_titolo;
$function$;

CREATE OR REPLACE FUNCTION public.fn_web_ha_tour_brevi_pubblicati(p_azienda_id integer)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
    SELECT EXISTS (
        SELECT 1
          FROM web_tour_contenuti c
          JOIN ana_viaggi v      ON v.viaggio_id = c.viaggio_id_fk
          JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
          JOIN ana_date_viaggi dv ON dv.data_viaggio_id = c.data_viaggio_id_fk
         WHERE c.azienda_id = p_azienda_id
           AND c.stato_pubblicazione = 'pubblicato'
           AND tv.tipo_viaggio_breve = true
           -- Una partenza già iniziata non si vende più: il sito pubblico non deve mostrarla.
           -- Taglio alla data di INIZIO, lo stesso che StatoPartenzaRules.MotivoNonPubblicabile impone
           -- in scrittura (si pubblica solo una partenza che deve ancora iniziare): senza questo filtro
           -- una scheda pubblicata resterebbe visibile per sempre, perché nulla la ritira allo scadere.
           AND dv.data_viaggio_data_inizio > CURRENT_DATE
    );
$function$;
