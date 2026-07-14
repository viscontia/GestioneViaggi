-- ============================================================================
-- §A.4 Recensioni Google + TripAdvisor.
-- Nessuna tabella recensioni interna: si usano le schede Google/TripAdvisor.
-- La config per-azienda (identificativi) vive nel JSONB web_aziende_funzioni.parametri
-- della riga funzione='recensioni', es. {"google_place_id":"…","tripadvisor_url":"…"}.
-- Il flag attiva (già esistente) governa on/off.
--
-- Strato pubblico: fn_web_recensioni_config espone la config SOLO se recensioni è
-- ATTIVA per l'azienda; altrimenti NULL (il sito non mostra il widget). SECURITY
-- DEFINER perché web_aziende_funzioni è multi-tenant (RLS) e anon non vi accede
-- direttamente; la funzione ritorna solo gli identificativi pubblici delle schede.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_recensioni_config(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT parametri
      FROM web_aziende_funzioni
     WHERE azienda_id = p_azienda_id
       AND funzione = 'recensioni'
       AND attiva = true;
$$;
REVOKE ALL ON FUNCTION fn_web_recensioni_config(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_web_recensioni_config(integer) TO anon;

COMMIT;
