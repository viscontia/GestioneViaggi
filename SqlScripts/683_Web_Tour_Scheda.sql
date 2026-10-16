-- ============================================================================
-- 683 — La scheda di un tour in una chiamata sola, già tradotta (Tappa 3 del sito)
--
-- La pagina del tour del sito pubblico ha bisogno di galleria, giornate con i
-- loro passaggi, mappe, altre partenze e dati aziendali (piede del PDF). Oggi
-- questi dati hanno solo le funzioni del gestionale: chiuse al pubblico e non
-- tradotte. Decisione di Adriano (2026-10-16, «strada A»): una funzione sola
-- che restituisce tutto, già nella lingua chiesta (ripiego: italiano).
--
--   tour            i campi di fn_web_tour_pubblicati (un solo «pubblicato»)
--                   + testi della scheda tradotti, paese (ISO), edizione_id
--   galleria        foto di galleria nell'ordine del gestionale
--   itinerario      giornate in ordine, ognuna con passaggi (testo, foto) e
--                   mappe della giornata
--   mappa           la mappa del tour intero (o null)
--   altre_partenze  le altre edizioni pubblicate dello stesso viaggio
--   azienda         fn_web_newsletter_dati_azienda + WhatsApp (web_indirizzi)
--
-- null se lo slug non è fra i pubblicati dell'azienda.
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-16-Tappa_3_Catalogo_e_Scheda_Disegno.md §1
-- Lettura pubblica: SECURITY DEFINER, search_path fissato (655), EXECUTE ad anon.
-- Rigiocabile.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_tour_scheda(p_azienda_id integer, p_slug varchar, p_lingua char(2))
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
    WITH t AS (
        SELECT p.* FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua) p WHERE p.slug = p_slug LIMIT 1
    ), c AS (
        SELECT c.* FROM web_tour_contenuti c JOIN t ON c.web_tour_contenuti_id = t.contenuto_id
         WHERE c.azienda_id = p_azienda_id
    ), tr AS (
        -- le traduzioni valide nella lingua chiesta (in italiano: nessuna, vale l'originale)
        SELECT w.entita, w.entita_id, w.campo, btrim(w.testo) AS testo
          FROM web_traduzioni w
         WHERE p_lingua <> 'IT' AND w.lingua = p_lingua AND NOT w.obsoleto AND btrim(coalesce(w.testo, '')) <> ''
    )
    SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM c) THEN NULL ELSE jsonb_build_object(

        'tour', (SELECT to_jsonb(t) || jsonb_build_object(
                    'luoghi_visitati',           coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_contenuti' AND entita_id = c.web_tour_contenuti_id AND campo = 'luoghi_visitati'), c.luoghi_visitati),
                    'info_pernottamento_html',   coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_contenuti' AND entita_id = c.web_tour_contenuti_id AND campo = 'info_pernottamento_html'), c.info_pernottamento_html),
                    'info_pasti_html',           coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_contenuti' AND entita_id = c.web_tour_contenuti_id AND campo = 'info_pasti_html'), c.info_pasti_html),
                    'info_equipaggiamento_html', coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_contenuti' AND entita_id = c.web_tour_contenuti_id AND campo = 'info_equipaggiamento_html'), c.info_equipaggiamento_html),
                    'altre_info_html',           coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_contenuti' AND entita_id = c.web_tour_contenuti_id AND campo = 'altre_info_html'), c.altre_info_html),
                    'paese',       (SELECT ec.iso_alpha2 FROM ana_viaggi v JOIN eba_countries ec ON ec.country_id = v.viaggio_nazione_fk
                                     WHERE v.viaggio_id = t.viaggio_id),
                    'edizione_id', c.data_viaggio_id_fk)
                   FROM t, c),

        'galleria', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                       'url', i.url, 'larghezza', i.larghezza, 'altezza', i.altezza,
                       'alt', coalesce(nullif(btrim(i.alt_text), ''), i.titolo))
                   ORDER BY i.ordine, i.web_tour_immagini_id)
              FROM web_tour_immagini i JOIN c ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
             WHERE i.tipo = 'galleria'), '[]'::jsonb),

        'itinerario', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                       'giorno', g.giorno_numero,
                       'titolo', coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_itinerario' AND entita_id = g.web_tour_itinerario_id AND campo = 'titolo_giornata'), g.titolo_giornata),
                       'passaggi', coalesce((
                            SELECT jsonb_agg(jsonb_build_object(
                                       'testo_html', coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_itinerario_passaggi' AND entita_id = ps.web_tour_itinerario_passaggi_id AND campo = 'testo_html'), ps.testo_html),
                                       'foto', CASE WHEN ps.immagine_url IS NULL THEN NULL
                                                    ELSE jsonb_build_object('url', ps.immagine_url, 'didascalia', ps.immagine_didascalia) END)
                                   ORDER BY ps.ordine, ps.web_tour_itinerario_passaggi_id)
                              FROM web_tour_itinerario_passaggi ps WHERE ps.itinerario_id_fk = g.web_tour_itinerario_id), '[]'::jsonb),
                       'mappe', coalesce((
                            SELECT jsonb_agg(jsonb_build_object(
                                       'url', m.immagine_url,
                                       'descrizione', coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_mappa' AND entita_id = m.web_tour_mappa_id AND campo = 'descrizione'), m.descrizione))
                                   ORDER BY m.web_tour_mappa_id)
                              FROM web_tour_mappa m WHERE m.web_tour_itinerario_id_fk = g.web_tour_itinerario_id AND m.immagine_url IS NOT NULL), '[]'::jsonb))
                   ORDER BY g.ordine, g.giorno_numero, g.web_tour_itinerario_id)
              FROM web_tour_itinerario g JOIN c ON g.web_tour_contenuti_id_fk = c.web_tour_contenuti_id), '[]'::jsonb),

        'mappa', (
            SELECT jsonb_build_object(
                       'url', m.immagine_url,
                       'descrizione', coalesce((SELECT testo FROM tr WHERE entita = 'web_tour_mappa' AND entita_id = m.web_tour_mappa_id AND campo = 'descrizione'), m.descrizione))
              FROM web_tour_mappa m JOIN c ON m.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
             WHERE m.web_tour_itinerario_id_fk IS NULL AND m.immagine_url IS NOT NULL
             ORDER BY m.data_generazione DESC NULLS LAST, m.web_tour_mappa_id DESC
             LIMIT 1),

        'altre_partenze', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                       'slug', o.slug, 'sezione_slug', o.descrizione_slug,
                       'data_inizio', o.data_inizio, 'data_fine', o.data_fine,
                       'posti_rimasti', o.posti_rimasti, 'posti_stato', o.posti_stato)
                   ORDER BY o.data_inizio, o.slug)
              FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua) o, t
             WHERE o.viaggio_id = t.viaggio_id AND o.slug <> t.slug), '[]'::jsonb),

        'azienda', (
            SELECT to_jsonb(a) || jsonb_build_object('whatsapp',
                       (SELECT w.url FROM web_indirizzi w
                         WHERE w.azienda_id = p_azienda_id AND w.social = 'whatsapp' AND w.attivo
                         ORDER BY w.ordine LIMIT 1))
              FROM fn_web_newsletter_dati_azienda(p_azienda_id) a)
    ) END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_tour_scheda(integer, varchar, char) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_web_tour_scheda(integer, varchar, char) TO anon, authenticated;

COMMIT;

-- ============================================================================
-- Verifica: Test_683_Web_Tour_Scheda.sql
-- ============================================================================
