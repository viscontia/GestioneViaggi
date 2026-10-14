-- ============================================================================
-- 678 — La sezione è attiva, ritirata o mai esistita? (Tappa 2 del sito)
--
-- Il sito risponde 410 Gone a una sezione che c'era e non c'è più, 404 a un
-- indirizzo mai esistito. La differenza la decide il database:
--   attiva      → compare oggi in fn_web_sezioni_tipologia (il criterio di
--                 «pubblicato» resta uno solo, quello di fn_web_tour_pubblicati);
--   ritirata    → lo slug esiste in web_tipi_viaggio_descrizioni ma oggi non
--                 ha tour pubblicati;
--   sconosciuta → lo slug non esiste.
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-13-Tappa_2_Impianto_Disegno.md §2
-- Lettura pubblica: SECURITY DEFINER, search_path fissato (655), EXECUTE ad anon.
-- Rigiocabile.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_sezione_stato(p_azienda_id integer, p_slug varchar)
 RETURNS varchar
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
    SELECT (CASE
        WHEN EXISTS (SELECT 1 FROM fn_web_sezioni_tipologia(p_azienda_id, 'IT') s
                      WHERE s.slug = p_slug) THEN 'attiva'
        WHEN EXISTS (SELECT 1 FROM web_tipi_viaggio_descrizioni d
                      WHERE d.slug = p_slug) THEN 'ritirata'
        ELSE 'sconosciuta'
    END)::varchar;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_sezione_stato(integer, varchar) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_web_sezione_stato(integer, varchar) TO anon, authenticated;

COMMIT;

-- ============================================================================
-- Verifica: Test_678_Web_Sezione_Stato.sql
-- ============================================================================
