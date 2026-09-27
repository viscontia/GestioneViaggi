-- ============================================================================
-- 673 — La mail del lunedi' (prosegue il promemoria all'apertura, L2)
--
-- Disegno: Documents/Progetti/Promemoria_Apertura/2026-09-27-mail-del-lunedi-design.md
--
-- Ogni lunedi' alle 7:30 il server del sito di iscrizione manda le righe di
-- fn_promemoria_apertura (671). Se partire e a chi lo decide questa funzione:
--
--   fn_promemoria_mail_destinatari(azienda) → text[]
--     vuoto se la funzione 'mail_lunedi' dell'azienda manca o e' spenta;
--     altrimenti gli indirizzi del parametro 'destinatari' (separati da
--     virgola) o, se non ce ne sono, l'email principale dell'azienda
--     (ana_aziende_email.is_principale: per SFT la segreteria).
--
-- La riga 'mail_lunedi' nasce SPENTA per ogni azienda: nessuno riceve mail che
-- non ha chiesto. Si accende dalla linguetta Funzioni Web dell'azienda.
--
-- Solo per il gestionale e il server del sito (postgres): nessun GRANT (659).
-- search_path fissato (655). Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_promemoria_mail_destinatari(p_azienda_id integer)
 RETURNS text[]
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    WITH f AS (
        SELECT f.parametri->>'destinatari' AS grezzo
          FROM web_aziende_funzioni f
         WHERE f.azienda_id = p_azienda_id AND f.funzione = 'mail_lunedi' AND f.attiva
    ), dal_parametro AS (
        SELECT array_agg(btrim(x) ORDER BY ord) AS indirizzi
          FROM f, unnest(string_to_array(f.grezzo, ',')) WITH ORDINALITY AS u(x, ord)
         WHERE btrim(x) <> ''
    )
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM f) THEN '{}'::text[]
        WHEN (SELECT indirizzi FROM dal_parametro) IS NOT NULL THEN (SELECT indirizzi FROM dal_parametro)
        -- La stessa email principale che usano il gestionale e il sito (se manca la
        -- principale, la prima dell'azienda: regola di fn_ana_aziende_email_principale).
        ELSE COALESCE(
            (SELECT ARRAY[btrim(e)::text] FROM fn_ana_aziende_email_principale(p_azienda_id) e
              WHERE btrim(coalesce(e, '')) <> ''),
            '{}'::text[])
    END;
$$;

INSERT INTO web_aziende_funzioni (azienda_id, funzione, attiva, parametri, created_by)
SELECT a.azienda_id, 'mail_lunedi', false, NULL, 'script 673'
  FROM ana_aziende a
ON CONFLICT (azienda_id, funzione) DO NOTHING;

COMMIT;
