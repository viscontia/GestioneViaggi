-- Funzioni di servizio dell'estensione web (Blocco 2 - Task 2.11).
-- Tutte SECURITY INVOKER (default): chiamate dal sito come ruolo anon rispettano le RLS
-- (script 450-453); chiamate dal gestionale (postgres) le bypassano come il resto.
--
--   1. fn_web_prezzo_da(viaggio)            -> prezzo minimo "da" tra le partenze future
--   2. fn_web_tour_pubblicati(azienda,lingua)-> lista tour pubblicati per il sito (testi in lingua, fallback IT)
--   3. fn_web_destinatari_newsletter(azienda)-> unione+dedup clienti/iscritti meno soppressioni

-- ---------------------------------------------------------------------------
-- 1) Prezzo "da": minimo tra TUTTE le tariffe (pilota / passeggero / passeggero
--    auto guida / bambino 0-2 / 2-6 / 6-12) delle sole partenze future
--    (data_inizio >= oggi). Tariffe a 0 o NULL ignorate. NULL se nessuna
--    partenza futura con tariffa valorizzata.
--    NB: LEAST() in PostgreSQL ignora i NULL -> NULLIF(costo,0) esclude gli zeri.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_prezzo_da(p_viaggio_id INTEGER)
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT MIN(LEAST(
               NULLIF(d.data_viaggio_costo_pilota, 0),
               NULLIF(d.data_viaggio_costo_passeggero, 0),
               NULLIF(d.data_viaggio_costo_passeggero_auto_guida, 0),
               NULLIF(d.data_viaggio_costo_bambino_0_2, 0),
               NULLIF(d.data_viaggio_costo_bambino_2_6, 0),
               NULLIF(d.data_viaggio_costo_bambino_6_12, 0)))
      FROM ana_date_viaggi d
     WHERE d.viaggio_id_fk = p_viaggio_id
       AND d.data_viaggio_data_inizio >= CURRENT_DATE;
$$;

-- ---------------------------------------------------------------------------
-- 2) Lista tour pubblicati per il sito.
--    - solo stato_pubblicazione='pubblicato', scoped per azienda;
--    - categoria sport via ana_tipo_viaggi.web_categoria_fk;
--    - sottotitolo/descrizione/durata in lingua da web_traduzioni (entita='web_tour_contenuti',
--      traduzioni non obsolete), fallback sul testo IT della tabella base;
--    - titolo = ana_viaggi.viaggio_descrizione_breve (la traduzione del titolo
--      sara' decisa col Blocco 10 - per ora sempre IT);
--    - immagine principale (web_tour_immagini.tipo='principale') e prezzo "da".
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_tour_pubblicati(p_azienda_id INTEGER, p_lingua CHAR(2) DEFAULT 'IT')
RETURNS TABLE (
    viaggio_id            INTEGER,
    contenuto_id          BIGINT,
    titolo                VARCHAR,
    sottotitolo           VARCHAR,
    descrizione_html      TEXT,
    slug                  VARCHAR,
    difficolta            VARCHAR,
    durata_testo          VARCHAR,
    numero_giorni         INTEGER,
    categoria_codice      VARCHAR,
    categoria_etichetta   VARCHAR,
    categoria_slug        VARCHAR,
    prezzo_da             INTEGER,
    immagine_url          TEXT,
    immagine_storage_path VARCHAR,
    data_pubblicazione    TIMESTAMPTZ,
    ordine                INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT v.viaggio_id,
           c.web_tour_contenuti_id,
           v.viaggio_descrizione_breve,
           COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR,
           COALESCE(t_descr.testo, c.descrizione_html),
           c.slug,
           c.difficolta,
           COALESCE(t_dur.testo, c.durata_testo)::VARCHAR,
           v.viaggio_numero_giorni,
           cat.codice,
           cat.etichetta,
           cat.slug,
           fn_web_prezzo_da(v.viaggio_id),
           img.url,
           img.storage_path,
           c.data_pubblicazione,
           c.ordine
      FROM web_tour_contenuti c
      JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
      LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      LEFT JOIN web_categorie_sport cat ON cat.web_categorie_sport_id = tv.web_categoria_fk
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
$$;

-- ---------------------------------------------------------------------------
-- 3) Destinatari newsletter: UNION con dedup per email (CITEXT = case-insensitive)
--    di ana_clienti con consenso_marketing e web_newsletter_iscritti attivi,
--    MENO le email in web_newsletter_soppressioni.
--    In caso di email presente su entrambi i lati (fonte='entrambi') prevalgono
--    i dati dell'iscritto (lingua + token_disiscrizione), ma resta anche cliente_id.
--    Duplicati interni ad ana_clienti (stessa email su piu' clienti): vince il cliente_id minore.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_destinatari_newsletter(p_azienda_id INTEGER)
RETURNS TABLE (
    email               CITEXT,
    nome                VARCHAR,
    cognome             VARCHAR,
    lingua              CHAR(2),
    fonte               VARCHAR,   -- 'cliente' | 'iscritto' | 'entrambi'
    cliente_id          INTEGER,
    iscritto_id         BIGINT,
    token_disiscrizione VARCHAR)
LANGUAGE sql STABLE AS $$
    WITH clienti AS (
        SELECT DISTINCT ON (TRIM(cl.cliente_email)::CITEXT)
               TRIM(cl.cliente_email)::CITEXT AS email,
               cl.cliente_nome, cl.cliente_cognome, cl.cliente_id
          FROM ana_clienti cl
         WHERE cl.azienda_fk = p_azienda_id
           AND cl.consenso_marketing = true
           AND NULLIF(TRIM(cl.cliente_email), '') IS NOT NULL
         ORDER BY TRIM(cl.cliente_email)::CITEXT, cl.cliente_id
    ),
    iscritti AS (
        SELECT i.email, i.nome, i.cognome, i.lingua,
               i.web_newsletter_iscritti_id, i.token_disiscrizione
          FROM web_newsletter_iscritti i
         WHERE i.azienda_id = p_azienda_id
           AND i.stato = 'attivo'
           AND i.consenso = true
    )
    SELECT COALESCE(i.email, c.email)                       AS email,
           COALESCE(i.nome, c.cliente_nome)::VARCHAR        AS nome,
           COALESCE(i.cognome, c.cliente_cognome)::VARCHAR  AS cognome,
           COALESCE(i.lingua, 'IT')::CHAR(2)                AS lingua,
           CASE WHEN i.email IS NOT NULL AND c.email IS NOT NULL THEN 'entrambi'
                WHEN i.email IS NOT NULL THEN 'iscritto'
                ELSE 'cliente' END::VARCHAR                 AS fonte,
           c.cliente_id,
           i.web_newsletter_iscritti_id                     AS iscritto_id,
           i.token_disiscrizione
      FROM clienti c
      FULL JOIN iscritti i ON i.email = c.email
     WHERE NOT EXISTS (
           SELECT 1 FROM web_newsletter_soppressioni s
            WHERE s.azienda_id = p_azienda_id
              AND s.email = COALESCE(i.email, c.email))
     ORDER BY 1;
$$;
