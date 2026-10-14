-- ============================================================================
-- 679 — Un utente del database che sa solo svuotare la coda di rigenerazione
--
-- Il programma che svuota web_revalidate_coda (654) gira sul server del sito,
-- non nel browser, e non può usare la chiave pubblica: le funzioni della coda
-- non sono di anon. Gli serve un utente suo, che possa SOLO chiamarle: se la
-- password uscisse, si potrebbe al massimo svuotare la coda.
--
-- Per questo le quattro funzioni che usa diventano SECURITY DEFINER con
-- search_path fissato (655): l'utente non ha alcun permesso sulle tabelle.
-- fn_web_revalidate_accoda resta com'è: la chiamano i trigger, non il sito.
--
-- fn_web_revalidate_prossimi prende un filtro facoltativo per azienda: con un
-- secondo sito, ognuno svuota solo le proprie righe. La vecchia firma senza
-- azienda si toglie: non la chiama nessuno (verificato il 2026-10-14 nel
-- gestionale, nel sito Flask e fra le funzioni; la coda non ha ancora un
-- ascoltatore).
--
-- ⛔️ Il ruolo nasce NOLOGIN e senza password: login e password si danno a mano
-- (ALTER ROLE ... LOGIN PASSWORD) e la password vive solo nel .env del server.
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-13-Tappa_2_Impianto_Disegno.md §5
-- Rigiocabile.
-- ============================================================================
BEGIN;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_rigenera') THEN
        CREATE ROLE sito_rigenera NOLOGIN;
    END IF;
END $$;

-- Senza USAGE sullo schema il ruolo non «vede» le funzioni per nome (su Supabase
-- public è aperto solo al proprietario e ad anon). USAGE non dà letture: i
-- permessi veri sono gli EXECUTE qui sotto. Trovato dal test 679 il 2026-10-14.
GRANT USAGE ON SCHEMA public TO sito_rigenera;

DROP FUNCTION IF EXISTS fn_web_revalidate_prossimi(integer);

CREATE OR REPLACE FUNCTION fn_web_revalidate_prossimi(p_limite integer DEFAULT 20, p_azienda_id integer DEFAULT NULL)
 RETURNS TABLE(coda_id bigint, azienda_id integer, oggetto character varying, riferimento bigint,
               slug character varying, origine character varying, creata timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
BEGIN
    RETURN QUERY
    WITH prese AS (
        SELECT q.coda_id FROM web_revalidate_coda q
         WHERE q.completata_il IS NULL
           AND (p_azienda_id IS NULL OR q.azienda_id = p_azienda_id)
         ORDER BY q.creata LIMIT p_limite FOR UPDATE SKIP LOCKED
    ), marcate AS (
        UPDATE web_revalidate_coda q SET presa_il = now(), tentativi = q.tentativi + 1
          FROM prese WHERE q.coda_id = prese.coda_id RETURNING q.*
    )
    SELECT m.coda_id, m.azienda_id, m.oggetto, m.riferimento, c.slug, m.origine, m.creata
      FROM marcate m
      LEFT JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = m.riferimento
     ORDER BY m.creata;
END; $function$;

ALTER FUNCTION fn_web_revalidate_completa(bigint[])    SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_web_revalidate_fallita(bigint, text) SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_web_revalidate_pulisci(integer)      SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION fn_web_revalidate_prossimi(integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_web_revalidate_completa(bigint[])         FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_web_revalidate_fallita(bigint, text)      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_web_revalidate_pulisci(integer)           FROM PUBLIC;

GRANT EXECUTE ON FUNCTION fn_web_revalidate_prossimi(integer, integer) TO sito_rigenera;
GRANT EXECUTE ON FUNCTION fn_web_revalidate_completa(bigint[])         TO sito_rigenera;
GRANT EXECUTE ON FUNCTION fn_web_revalidate_fallita(bigint, text)      TO sito_rigenera;
GRANT EXECUTE ON FUNCTION fn_web_revalidate_pulisci(integer)           TO sito_rigenera;

COMMIT;

-- ============================================================================
-- Verifica: Test_679_Web_Utente_Sito_Rigenera.sql
-- ============================================================================
