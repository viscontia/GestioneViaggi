-- ============================================================================
-- 684 — Titolo del tour e nome della sezione tradotti; paese per le card (Tappa 3)
--
-- Sul sito in inglese, tedesco, francese e spagnolo il titolo del tour e il nome
-- della sezione uscivano in italiano (misurato il 2026-10-13). Decisione di
-- Adriano (2026-10-16): si traducono, dentro la Tappa 3.
--
--   fn_web_tour_pubblicati  titolo tradotto (ana_viaggi.viaggio_descrizione_breve;
--                           ripiego: la forma leggibile del 675); nome della sezione
--                           tradotto (come già nel menu, fn_web_sezioni_tipologia);
--                           colonna nuova «paese» (ISO a due lettere) per il filtro
--                           del catalogo. In italiano niente cambia.
--   fn_web_tour_campi_traducibili  il titolo entra fra i campi da tradurre, con il
--                           testo di partenza LEGGIBILE (il gestionale lo scrive in
--                           maiuscolo). Lo stesso elenco vive nel gestionale in C#
--                           (WebTraduzioneOrchestratorService.GetTranslatableItemsAsync):
--                           vanno tenuti uguali (il semaforo conta questo).
--
-- ⚠️ Colonne nuove = DROP + CREATE: i permessi si rimettono qui sotto, gli stessi di
-- prima (postgres, anon, authenticated, service_role). Le funzioni che la chiamano
-- (menu, scheda, stati degli slug, stato sezione) leggono per nome: non cambiano.
-- Rigiocabile.
-- ============================================================================
BEGIN;

DROP FUNCTION IF EXISTS fn_web_tour_pubblicati(integer, character);

CREATE FUNCTION fn_web_tour_pubblicati(p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar)
 RETURNS TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying, descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying, numero_giorni integer, descrizione_web character varying, descrizione_slug character varying, prezzo_da integer, data_inizio date, data_fine date, immagine_url text, immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer, incluso text, escluso text, posti_rimasti integer, posti_stato text, is_tour_breve boolean, meta_title character varying, meta_description character varying, paese character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    WITH base AS (
        SELECT v.viaggio_id                          AS b_viaggio_id,
               c.web_tour_contenuti_id               AS b_contenuto_id,
               -- 675: il gestionale scrive in maiuscolo, il sito mostra la forma leggibile
               -- 684: tradotto nella lingua chiesta (ripiego: forma leggibile italiana)
               COALESCE(NULLIF(btrim(t_tit.testo), ''), fn_web_titolo_leggibile(v.viaggio_descrizione_breve))::VARCHAR AS b_titolo,
               COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR   AS b_sottotitolo,
               COALESCE(t_descr.testo, c.descrizione_html)      AS b_descrizione_html,
               c.slug                                AS b_slug,
               v.viaggio_difficolta                  AS b_difficolta,
               COALESCE(t_dur.testo, c.durata_testo)::VARCHAR   AS b_durata_testo,
               v.viaggio_numero_giorni               AS b_numero_giorni,
               -- 684: nome della sezione tradotto (prima sempre italiano; il menu lo traduceva già)
               COALESCE(NULLIF(btrim(t_sez.testo), ''), d.descrizione_web)::VARCHAR AS b_descrizione_web,
               ec.iso_alpha2::VARCHAR                AS b_paese,
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
               -- 680: meta tradotti nella lingua chiesta (prima arrivavano in italiano in ogni lingua)
               c.meta_title                          AS b_meta_title,
               c.meta_description                    AS b_meta_description,
               t_mtit.testo                          AS b_meta_title_trad,
               t_mdes.testo                          AS b_meta_description_trad,
               t_sott.testo                          AS b_sottotitolo_trad
          FROM web_tour_contenuti c
          JOIN ana_date_viaggi dv      ON dv.data_viaggio_id = c.data_viaggio_id_fk
          JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
          LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
          LEFT JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
          LEFT JOIN web_tour_immagini img   ON img.web_tour_contenuti_id_fk = c.web_tour_contenuti_id AND img.tipo = 'principale'
          LEFT JOIN eba_countries ec   ON ec.country_id = v.viaggio_nazione_fk
          LEFT JOIN web_traduzioni t_tit   ON p_lingua <> 'IT'
               AND t_tit.entita = 'ana_viaggi'          AND t_tit.entita_id = v.viaggio_id
               AND t_tit.campo = 'viaggio_descrizione_breve' AND t_tit.lingua = p_lingua AND NOT t_tit.obsoleto
          LEFT JOIN web_traduzioni t_sez   ON p_lingua <> 'IT'
               AND t_sez.entita = 'web_tipi_viaggio_descrizioni' AND t_sez.entita_id = d.web_tipi_viaggio_descrizioni_id
               AND t_sez.campo = 'descrizione_web'    AND t_sez.lingua = p_lingua AND NOT t_sez.obsoleto
          LEFT JOIN web_traduzioni t_sott  ON p_lingua <> 'IT'
               AND t_sott.entita = 'web_tour_contenuti' AND t_sott.entita_id = c.web_tour_contenuti_id
               AND t_sott.campo = 'sottotitolo'      AND t_sott.lingua = p_lingua AND NOT t_sott.obsoleto
          LEFT JOIN web_traduzioni t_descr ON p_lingua <> 'IT'
               AND t_descr.entita = 'web_tour_contenuti' AND t_descr.entita_id = c.web_tour_contenuti_id
               AND t_descr.campo = 'descrizione_html' AND t_descr.lingua = p_lingua AND NOT t_descr.obsoleto
          LEFT JOIN web_traduzioni t_dur   ON p_lingua <> 'IT'
               AND t_dur.entita = 'web_tour_contenuti'  AND t_dur.entita_id = c.web_tour_contenuti_id
               AND t_dur.campo = 'durata_testo'       AND t_dur.lingua = p_lingua AND NOT t_dur.obsoleto
          LEFT JOIN web_traduzioni t_mtit  ON p_lingua <> 'IT'
               AND t_mtit.entita = 'web_tour_contenuti' AND t_mtit.entita_id = c.web_tour_contenuti_id
               AND t_mtit.campo = 'meta_title'        AND t_mtit.lingua = p_lingua AND NOT t_mtit.obsoleto
          LEFT JOIN web_traduzioni t_mdes  ON p_lingua <> 'IT'
               AND t_mdes.entita = 'web_tour_contenuti' AND t_mdes.entita_id = c.web_tour_contenuti_id
               AND t_mdes.campo = 'meta_description'  AND t_mdes.lingua = p_lingua AND NOT t_mdes.obsoleto
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
           -- 680: ripieghi. Titolo: meta tradotto → meta italiano → titolo.
           -- Descrizione: meta tradotta → sottotitolo tradotto → meta italiana → sottotitolo.
           -- In italiano le traduzioni sono NULL: il risultato è quello di prima.
           COALESCE(NULLIF(btrim(b_meta_title_trad), ''),
                    NULLIF(btrim(b_meta_title), ''),
                    b_titolo)::VARCHAR                                           AS meta_title,
           COALESCE(NULLIF(btrim(b_meta_description_trad), ''),
                    NULLIF(btrim(b_sottotitolo_trad), ''),
                    NULLIF(btrim(b_meta_description), ''),
                    b_sottotitolo)::VARCHAR                                      AS meta_description,
           b_paese                                                               AS paese
      FROM base
     ORDER BY b_ordine, b_titolo;
$function$;

REVOKE EXECUTE ON FUNCTION fn_web_tour_pubblicati(integer, character) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_web_tour_pubblicati(integer, character) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION fn_web_tour_campi_traducibili(p_contenuto_id bigint, p_azienda_id integer)
 RETURNS TABLE(entita character varying, entita_id bigint, campo character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH c AS (
    SELECT * FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_contenuto_id AND azienda_id = p_azienda_id
)
-- Il test ~ '[^[:space:]]' (almeno un carattere non-spazio) replica string.IsNullOrWhiteSpace del C#.
SELECT 'web_tour_contenuti'::VARCHAR, c.web_tour_contenuti_id, x.campo::VARCHAR
  FROM c
  CROSS JOIN LATERAL (VALUES
      ('sottotitolo',               c.sottotitolo::TEXT),
      ('descrizione_html',          c.descrizione_html),
      ('durata_testo',              c.durata_testo::TEXT),
      ('luoghi_visitati',           c.luoghi_visitati),
      ('info_pernottamento_html',   c.info_pernottamento_html),
      ('info_pasti_html',           c.info_pasti_html),
      ('info_equipaggiamento_html', c.info_equipaggiamento_html),
      ('altre_info_html',           c.altre_info_html),
      ('meta_title',                c.meta_title::TEXT),
      ('meta_description',          c.meta_description::TEXT)
  ) AS x(campo, valore)
 WHERE COALESCE(x.valore, '') ~ '[^[:space:]]'

UNION ALL
-- Incluso/Escluso vivono su ana_viaggi (livello viaggio, condivisi tra le edizioni).
SELECT 'ana_viaggi'::VARCHAR, v.viaggio_id::BIGINT, y.campo::VARCHAR
  FROM c
  JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk AND v.azienda_id = p_azienda_id
  CROSS JOIN LATERAL (VALUES
      ('viaggio_incluso', v.viaggio_incluso),
      ('viaggio_escluso', v.viaggio_escluso),
      -- 684: il titolo del tour, come lo legge il sito (forma leggibile, non il maiuscolo)
      ('viaggio_descrizione_breve', fn_web_titolo_leggibile(v.viaggio_descrizione_breve))
  ) AS y(campo, valore)
 WHERE COALESCE(y.valore, '') ~ '[^[:space:]]'

UNION ALL
-- Descrizioni delle mappe (intero viaggio e giornate).
SELECT 'web_tour_mappa'::VARCHAR, m.web_tour_mappa_id, 'descrizione'::VARCHAR
  FROM c
  JOIN web_tour_mappa m ON m.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                       AND m.azienda_id = p_azienda_id
 WHERE COALESCE(m.descrizione, '') ~ '[^[:space:]]'

UNION ALL
-- Titolo delle giornate dell'itinerario (script 503).
SELECT 'web_tour_itinerario'::VARCHAR, i.web_tour_itinerario_id, 'titolo_giornata'::VARCHAR
  FROM c
  JOIN web_tour_itinerario i ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                            AND i.azienda_id = p_azienda_id
 WHERE COALESCE(i.titolo_giornata, '') ~ '[^[:space:]]'

UNION ALL
-- Testo dei passi dell'itinerario.
SELECT 'web_tour_itinerario_passaggi'::VARCHAR, p.web_tour_itinerario_passaggi_id, 'testo_html'::VARCHAR
  FROM c
  JOIN web_tour_itinerario i ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                            AND i.azienda_id = p_azienda_id
  JOIN web_tour_itinerario_passaggi p ON p.itinerario_id_fk = i.web_tour_itinerario_id
                                     AND p.azienda_id = p_azienda_id
 WHERE COALESCE(p.testo_html, '') ~ '[^[:space:]]';
$function$;

COMMIT;

-- ============================================================================
-- Verifica: Test_684_Web_Titolo_Sezioni_Tradotti.sql
-- ============================================================================
