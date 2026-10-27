-- ============================================================================
-- 705 — La Galleria del sito (Tappa 4C, Task 2-bis)
--
-- Decisioni del 2026-10-27 (disegno della Tappa 4, §10; Antonio e Adriano): la galleria
-- si alimenta DA SOLA dalle foto di galleria dei tour, divisa per tipo di viaggio (le
-- sezioni del sito: 4x4, moto, quad e SSV…), con i tour che sono stati in vendita almeno
-- una volta: pubblicati (anche già svolti) e archiviati; le bozze no (foto provvisorie).
-- Nessuna tabella nuova, nessuna scelta nel gestionale.
--   - fn_web_sito_galleria(azienda, lingua) → [{nome, slug, foto: [{url, larghezza,
--     altezza, alt, tour, link}]}]: tipi nell'ordine delle sezioni (nome tradotto); nel
--     tipo prima i tour più recenti, poi l'ordine delle foto del tour. Ogni foto una volta
--     sola (le edizioni nuove ripetono le stesse foto): vince il tour in vendita, poi il
--     più recente. 'link' = {sezione, slug} solo se il tour è in vendita ADESSO (la stessa
--     regola del catalogo: fn_web_tour_pubblicati), altrimenti null. 'alt': quello della
--     foto, poi il suo titolo, poi il titolo del tour (tradotto). Mai il percorso interno.
--     Tipo senza foto escluso;
--   - fn_web_sito_pagine: 'galleria' dopo 'faq', se la galleria non è vuota.
-- La coda: una foto o un tour che cambia avvisa già la coda («tour», «menu»); il sito
-- rinfresca la galleria con quegli avvisi (Tappa 4C, Task 7-bis), senza rigenerare i PDF.
-- ⚠️ In PROD insieme al sito del 4C (Task 5), non prima: il sito del 4B rifiuta come
-- «sconosciuta» una pagina nuova nell'elenco.
-- Rigiocabile. Test: Test_705_Web_Sito_Galleria.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_web_sito_galleria(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    WITH in_vendita AS (
        SELECT p.contenuto_id, p.slug, p.descrizione_slug FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua::char(2)) p
    ),
    foto AS (
        -- ogni foto una volta sola: vince il tour in vendita, poi il più recente
        SELECT DISTINCT ON (i.url)
               d.web_tipi_viaggio_descrizioni_id AS tipo_id, i.url, i.larghezza, i.altezza, i.ordine,
               dv.data_viaggio_data_inizio AS inizio, c.web_tour_contenuti_id,
               coalesce(nullif(btrim(t_tit.testo), ''), fn_web_titolo_leggibile(v.viaggio_descrizione_breve)) AS tour,
               coalesce(nullif(btrim(i.alt_text), ''), nullif(btrim(i.titolo), '')) AS alt,
               CASE WHEN iv.contenuto_id IS NOT NULL THEN jsonb_build_object('sezione', iv.descrizione_slug, 'slug', iv.slug) END AS link
          FROM web_tour_immagini i
          JOIN web_tour_contenuti c  ON c.web_tour_contenuti_id = i.web_tour_contenuti_id_fk
          JOIN ana_date_viaggi dv    ON dv.data_viaggio_id = c.data_viaggio_id_fk
          JOIN ana_viaggi v          ON v.viaggio_id = c.viaggio_id_fk
          JOIN ana_tipo_viaggi tv    ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
          JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
          LEFT JOIN in_vendita iv    ON iv.contenuto_id = c.web_tour_contenuti_id
          LEFT JOIN web_traduzioni t_tit ON p_lingua <> 'IT'
               AND t_tit.entita = 'ana_viaggi' AND t_tit.entita_id = v.viaggio_id
               AND t_tit.campo = 'viaggio_descrizione_breve' AND t_tit.lingua = p_lingua AND NOT t_tit.obsoleto
         WHERE c.azienda_id = p_azienda_id
           AND c.stato_pubblicazione IN ('pubblicato', 'archiviato')
           AND i.tipo = 'galleria'
           AND i.url IS NOT NULL
         ORDER BY i.url, (iv.contenuto_id IS NOT NULL) DESC, dv.data_viaggio_data_inizio DESC, c.web_tour_contenuti_id DESC
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'nome', fn_web_sito_testo('web_tipi_viaggio_descrizioni', d.web_tipi_viaggio_descrizioni_id, 'descrizione_web', p_lingua, d.descrizione_web),
               'slug', d.slug,
               'foto', f.foto)
           ORDER BY d.ordine, d.web_tipi_viaggio_descrizioni_id), '[]'::jsonb)
      INTO v
      FROM web_tipi_viaggio_descrizioni d
      JOIN LATERAL (
          SELECT jsonb_agg(jsonb_build_object(
                     'url', x.url, 'larghezza', x.larghezza, 'altezza', x.altezza,
                     'alt', coalesce(x.alt, x.tour), 'tour', x.tour, 'link', x.link)
                     ORDER BY x.inizio DESC, x.web_tour_contenuti_id DESC, x.ordine, x.url) AS foto
            FROM foto x WHERE x.tipo_id = d.web_tipi_viaggio_descrizioni_id) f ON f.foto IS NOT NULL;
    RETURN v;
END;
$$;

-- Le pagine: come la 704, più 'galleria' (con la stessa definizione della lettura). CREATE OR REPLACE conserva i permessi.
CREATE OR REPLACE FUNCTION fn_web_sito_pagine(p_azienda_id integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_agg(x.p ORDER BY x.o), '[]'::jsonb)
      FROM (SELECT v.o, v.p
              FROM web_sito_contenuti c,
                   LATERAL (VALUES (0, 'chi_siamo', c.chi_siamo), (3, 'note_legali', c.note_legali),
                                   (4, 'privacy', c.privacy), (5, 'cookie', c.cookie)) v(o, p, testo)
             WHERE c.azienda_id = p_azienda_id AND fn_web_sito_html_pieno(v.testo) IS NOT NULL
            UNION ALL
            SELECT 1, 'faq' WHERE fn_web_sito_faq(p_azienda_id, 'IT') <> '[]'::jsonb
            UNION ALL
            SELECT 2, 'galleria' WHERE fn_web_sito_galleria(p_azienda_id, 'IT') <> '[]'::jsonb) x;
$$;

-- Permessi: la lettura al pubblico (esplicitamente).
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION fn_web_sito_galleria(integer, varchar) FROM PUBLIC;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION fn_web_sito_galleria(integer, varchar) TO anon, authenticated;
    END IF;
END $$;

COMMIT;
