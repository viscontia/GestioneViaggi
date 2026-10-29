-- ============================================================================
-- 708 — I numeri del database per la mail settimanale delle statistiche del sito (Tappa 4E, Task 3)
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-29-Tappa_4E_Statistiche_Disegno_e_Piano.md. Le visite le conta
-- Umami (sul server del sito); ciò che fa fede sta qui:
--   - arrivi al modulo d'iscrizione dal sito (687), e quanti di quelli hanno finito l'iscrizione («conclusi»,
--     contati quando concludono);
--   - PDF del programma consegnati (688);
--   - newsletter: nuovi iscritti confermati dal sito (707) e disiscritti dal sito.
--
--   fn_web_statistiche_settimana(azienda, dal, al) → jsonb, intervallo [dal, al):
--     { "totali": {arrivi, conclusi, pdf}, "newsletter": {nuovi, disiscritti},
--       "tour": [{data_viaggio_id, titolo, partenza, arrivi, conclusi, pdf}, …] }   (per edizione, i più cercati prima)
--
-- Solo lettura. Solo all'utente sito_guardiano (la mail parte dal server con la posta del guardiano).
-- Rigiocabile. Test: Test_708_Web_Statistiche_Settimana.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_statistiche_settimana(p_azienda_id integer, p_dal timestamptz, p_al timestamptz)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v jsonb;
BEGIN
    IF p_dal IS NULL OR p_al IS NULL OR p_al <= p_dal THEN
        RAISE EXCEPTION 'Intervallo non valido: dal % al %.', p_dal, p_al;
    END IF;

    WITH arrivi AS (
        SELECT data_viaggio_id, count(*) AS n FROM web_iscrizione_arrivi
         WHERE azienda_id = p_azienda_id AND arrivato_il >= p_dal AND arrivato_il < p_al GROUP BY 1
    ), conclusi AS (
        SELECT data_viaggio_id, count(*) AS n FROM web_iscrizione_arrivi
         WHERE azienda_id = p_azienda_id AND concluso_il >= p_dal AND concluso_il < p_al GROUP BY 1
    ), pdf AS (
        SELECT data_viaggio_id, count(*) AS n FROM web_pdf_richieste
         WHERE azienda_id = p_azienda_id AND richiesta_il >= p_dal AND richiesta_il < p_al GROUP BY 1
    ), edizioni AS (
        SELECT e.data_viaggio_id, coalesce(a.n, 0) AS arrivi, coalesce(c.n, 0) AS conclusi, coalesce(p.n, 0) AS pdf
          FROM (SELECT data_viaggio_id FROM arrivi UNION SELECT data_viaggio_id FROM conclusi
                UNION SELECT data_viaggio_id FROM pdf) e
          LEFT JOIN arrivi a   ON a.data_viaggio_id = e.data_viaggio_id
          LEFT JOIN conclusi c ON c.data_viaggio_id = e.data_viaggio_id
          LEFT JOIN pdf p      ON p.data_viaggio_id = e.data_viaggio_id
    )
    SELECT jsonb_build_object(
        'totali', jsonb_build_object(
            'arrivi',   (SELECT coalesce(sum(arrivi), 0)::int FROM edizioni),
            'conclusi', (SELECT coalesce(sum(conclusi), 0)::int FROM edizioni),
            'pdf',      (SELECT coalesce(sum(pdf), 0)::int FROM edizioni)),
        'newsletter', jsonb_build_object(
            'nuovi', (SELECT count(*)::int FROM web_newsletter_iscritti
                       WHERE azienda_id = p_azienda_id AND consenso_fonte = 'sito, doppio consenso'
                         AND conferma_usata >= p_dal AND conferma_usata < p_al),
            'disiscritti', (SELECT count(*)::int FROM web_newsletter_soppressioni
                             WHERE azienda_id = p_azienda_id AND motivo = 'disiscritto dal sito'
                               AND created >= p_dal AND created < p_al)),
        'tour', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                       'data_viaggio_id', e.data_viaggio_id,
                       'titolo',          fn_web_titolo_leggibile(v.viaggio_descrizione_breve),
                       'partenza',        d.data_viaggio_data_inizio::date,
                       'arrivi', e.arrivi, 'conclusi', e.conclusi, 'pdf', e.pdf)
                   ORDER BY e.arrivi DESC, e.pdf DESC, e.data_viaggio_id)
              FROM edizioni e
              JOIN ana_date_viaggi d ON d.data_viaggio_id = e.data_viaggio_id
              JOIN ana_viaggi v      ON v.viaggio_id = d.viaggio_id_fk), '[]'::jsonb))
      INTO v;
    RETURN v;
END;
$$;

-- Permessi: solo il guardiano (in PROD una funzione nuova nasce eseguibile da chiunque)
REVOKE EXECUTE ON FUNCTION fn_web_statistiche_settimana(integer, timestamptz, timestamptz) FROM PUBLIC;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_statistiche_settimana(integer, timestamptz, timestamptz) FROM anon, authenticated;
    END IF;
END $$;
GRANT EXECUTE ON FUNCTION fn_web_statistiche_settimana(integer, timestamptz, timestamptz) TO sito_guardiano;

COMMIT;
