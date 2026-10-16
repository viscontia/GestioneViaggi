-- ============================================================================
-- 682 — Lo stato di ogni indirizzo di tour, per il proxy del sito (Tappa 3)
--
-- Un'edizione già partita o ritirata lascia il suo indirizzo nei link di Google,
-- delle newsletter e dei social. Il sito risponde (decisione di Adriano, 2026-10-16):
--   pubblicato → la pagina;
--   sostituito → 308 alla PROSSIMA edizione pubblicata dello stesso viaggio
--                (la partenza più vicina);
--   ritirato   → 410 «questo viaggio non ha partenze in programma», con il link
--                alla sua sezione;
--   assente    → 404 (scheda mai pubblicata o indirizzo inventato).
-- Lo decide il database: «pubblicato» resta definito da fn_web_tour_pubblicati.
-- Una scheda mai pubblicata (data_pubblicazione nulla) non compare: il suo
-- indirizzo non è mai stato pubblico.
--
-- Un elenco solo per azienda: il proxy lo legge ogni 60 secondi (nessuna
-- chiamata per gli indirizzi inventati).
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-16-Tappa_3_Catalogo_e_Scheda_Disegno.md §5
-- Lettura pubblica: SECURITY DEFINER, search_path fissato (655), EXECUTE ad anon.
-- Rigiocabile.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_tour_slug_stato(p_azienda_id integer)
 RETURNS TABLE(slug varchar, stato varchar, sezione_slug varchar, slug_nuovo varchar, sezione_nuova varchar)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
    WITH pubblicati AS (
        SELECT p.viaggio_id, p.slug, p.descrizione_slug, p.data_inizio
          FROM fn_web_tour_pubblicati(p_azienda_id, 'IT') p
    ), prossima AS (
        -- per ogni viaggio, l'edizione pubblicata con la partenza più vicina
        SELECT DISTINCT ON (viaggio_id) viaggio_id, slug, descrizione_slug
          FROM pubblicati
         ORDER BY viaggio_id, data_inizio, slug
    ), uscite AS (
        -- le schede che sono state online e oggi non lo sono
        SELECT c.slug, c.viaggio_id_fk AS viaggio_id, d.slug AS sezione
          FROM web_tour_contenuti c
          JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
          LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
          LEFT JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
         WHERE c.azienda_id = p_azienda_id
           AND c.data_pubblicazione IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM pubblicati p WHERE p.slug = c.slug)
    )
    SELECT p.slug::varchar, 'pubblicato'::varchar, p.descrizione_slug::varchar, NULL::varchar, NULL::varchar
      FROM pubblicati p
    UNION ALL
    SELECT u.slug::varchar,
           (CASE WHEN pr.slug IS NULL THEN 'ritirato' ELSE 'sostituito' END)::varchar,
           u.sezione::varchar, pr.slug::varchar, pr.descrizione_slug::varchar
      FROM uscite u
      LEFT JOIN prossima pr ON pr.viaggio_id = u.viaggio_id;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_tour_slug_stato(integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_web_tour_slug_stato(integer) TO anon, authenticated;

COMMIT;

-- ============================================================================
-- Verifica: Test_682_Web_Tour_Slug_Stato.sql
-- ============================================================================
