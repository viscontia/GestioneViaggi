-- ============================================================================
-- 696 — Le partenze della home in ordine di data (Tappa 4A, blocco «Si parte»)
--
-- La home elenca tutte le partenze dalla più vicina. fn_web_tour_pubblicati le dà
-- nell'ordine del catalogo (ordine scelto, poi titolo): il sito non riordina (regola
-- «il database decide»), quindi l'ordine di data lo dà questa funzione.
--   - «pubblicato» ha una sola definizione: si CHIAMA fn_web_tour_pubblicati;
--   - stessi campi delle card (jsonb), già tradotti;
--   - nessuna partenza → [] (non null).
-- SECURITY DEFINER + search_path fissato; EXECUTE solo ad anon/authenticated (come 693).
-- Rigiocabile.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_sito_partenze(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.data_inizio, p.titolo, p.contenuto_id), '[]'::jsonb)
      INTO v
      FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua::char(2)) p;
    RETURN v;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_sito_partenze(integer, varchar) FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION fn_web_sito_partenze(integer, varchar) TO anon, authenticated;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- Verifica: Test_696_Web_Sito_Partenze.sql
-- ============================================================================
