-- ============================================================================
-- 693 — Le letture del sito per home e piede (Tappa 4A; voci L24, L26, L28)
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md §3
-- Quattro funzioni per il sito, aperte ad anon (come le altre fn_web_*):
--   fn_web_sito_home(azienda, lingua)      foto, motto, frase (tradotti)
--   fn_web_sito_evidenza(azienda, lingua)  titolo e tour scelti ANCORA PUBBLICATI
--   fn_web_sito_piede(azienda, lingua)     dati dell'azienda, contatti, social, garanzie
--   fn_web_tour_zone(azienda, lingua)      zone della mappa della home
--
-- ⛔️ «Pubblicato» ha una sola definizione: si CHIAMA fn_web_tour_pubblicati, non
--    si riscrive il filtro (regola del sito: il database decide, una volta sola).
-- ⛔️ La mappa delle zone mostra il CENTRO del riquadro di ogni percorso, mai la
--    traccia né il riquadro: ad Antonio sono già stati copiati i percorsi.
-- Traduzioni: la traduzione non obsoleta e non vuota, altrimenti l'italiano.
-- SECURITY DEFINER + search_path fissato (lezione dello script 655); EXECUTE tolto a
-- PUBLIC e dato SOLO ad anon e authenticated (non si conta sul permesso predefinito,
-- che apre a chiunque). Rigiocabile.
-- ============================================================================
BEGIN;

-- Lingua del sito: le 5, maiuscole (come 688).
CREATE OR REPLACE FUNCTION fn_web_sito_lingua_valida(p_lingua varchar)
RETURNS void
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF p_lingua IS NULL OR p_lingua NOT IN ('IT', 'EN', 'DE', 'FR', 'ES') THEN
        RAISE EXCEPTION 'Lingua non valida: %', left(coalesce(p_lingua, '(nulla)'), 10);
    END IF;
END;
$$;

-- Un testo della scheda «Sito web» nella lingua chiesta: la traduzione non obsoleta e
-- non vuota, altrimenti l'italiano. Solo per le funzioni qui sotto (non pubblica).
CREATE OR REPLACE FUNCTION fn_web_sito_testo(p_entita varchar, p_entita_id bigint, p_campo varchar,
                                             p_lingua varchar, p_italiano text)
RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT coalesce(
        CASE WHEN p_lingua <> 'IT' THEN
            (SELECT nullif(btrim(t.testo), '') FROM web_traduzioni t
              WHERE t.entita = p_entita AND t.entita_id = p_entita_id AND t.campo = p_campo
                AND t.lingua = p_lingua AND NOT t.obsoleto)
        END,
        p_italiano);
$$;

CREATE OR REPLACE FUNCTION fn_web_sito_home(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT jsonb_build_object(
               'foto', (SELECT jsonb_build_object('url', i.url, 'larghezza', i.larghezza,
                                                  'altezza', i.altezza, 'descrizione', i.descrizione)
                          FROM web_immagini_libreria i WHERE i.web_immagini_libreria_id = c.foto_home_fk),
               'motto', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'motto', p_lingua, c.motto),
               'frase', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'frase_home', p_lingua, c.frase_home))
      INTO v
      FROM web_sito_contenuti c
     WHERE c.azienda_id = p_azienda_id;
    RETURN v;
END;
$$;

-- I tour «In evidenza» con gli stessi campi di fn_web_tour_pubblicati (le card del sito),
-- nell'ordine scelto. Solo quelli ancora pubblicati; nessuno → NULL (il blocco non c'è).
CREATE OR REPLACE FUNCTION fn_web_sito_evidenza(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_tour jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT jsonb_agg(to_jsonb(p) ORDER BY e.ordine)
      INTO v_tour
      FROM web_sito_evidenza e
      JOIN fn_web_tour_pubblicati(p_azienda_id, p_lingua::char(2)) p ON p.contenuto_id = e.web_tour_contenuti_id_fk
     WHERE e.azienda_id = p_azienda_id;
    IF v_tour IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN jsonb_build_object(
        'titolo', (SELECT fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'evidenza_titolo', p_lingua, c.evidenza_titolo)
                     FROM web_sito_contenuti c WHERE c.azienda_id = p_azienda_id),
        'tour', v_tour);
END;
$$;

-- Il piede: chi è il tour operator, come si contatta, le sue garanzie.
CREATE OR REPLACE FUNCTION fn_web_sito_piede(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT jsonb_build_object(
        'ragione_sociale',  a.ragione_sociale,
        'forma_giuridica',  a.forma_giuridica,
        'partita_iva',      a.partita_iva,
        'codice_fiscale',   a.codice_fiscale,
        'rea',              CASE WHEN nullif(btrim(a.rea_numero), '') IS NULL THEN NULL
                                 ELSE concat_ws('-', pr.provincia_sigla, btrim(a.rea_numero)) END,
        'capitale_sociale', a.capitale_sociale,
        'socio_unico',      a.socio_unico,
        'anno_inizio',      extract(year FROM coalesce(a.data_inizio_attivita, a.data_costituzione))::int,
        'sede', (SELECT jsonb_build_object(
                            'indirizzo', nullif(btrim(concat_ws(' ', s.indirizzo, s.numero_civico)), ''),
                            'cap', co.comune_cap, 'comune', co.comune_descrizione, 'provincia', ps.provincia_sigla,
                            'lat', s.coordinate_lat, 'lng', s.coordinate_lng)
                   FROM ana_aziende_sedi s
                   LEFT JOIN ana_geo_comuni co ON co.comune_id = s.comune_fk
                   LEFT JOIN ana_geo_province ps ON ps.provincia_id = co.comune_provincia_fk
                  WHERE s.azienda_fk = a.azienda_id
                  ORDER BY s.is_principale DESC, s.sede_id
                  LIMIT 1),
        'telefono',  nullif(btrim(a.telefono_principale), ''),
        'email',     fn_ana_aziende_email_principale(a.azienda_id),
        'whatsapp',  (SELECT w.url FROM web_indirizzi w
                       WHERE w.azienda_id = a.azienda_id AND w.social = 'whatsapp' AND w.attivo
                       ORDER BY w.ordine LIMIT 1),
        'social',    coalesce((SELECT jsonb_agg(jsonb_build_object('social', w.social, 'descrizione', w.descrizione,
                                                                    'url', w.url, 'icona', w.icona_url) ORDER BY w.ordine)
                                 FROM web_indirizzi w
                                WHERE w.azienda_id = a.azienda_id AND w.attivo
                                  AND nullif(btrim(w.social), '') IS NOT NULL AND w.social <> 'whatsapp'), '[]'::jsonb),
        'polizza_rc', CASE WHEN a.polizza_rc_compagnia IS NULL AND a.polizza_rc_numero IS NULL THEN NULL
                           ELSE jsonb_build_object('compagnia', a.polizza_rc_compagnia, 'numero', a.polizza_rc_numero) END,
        'fondo_garanzia', CASE WHEN a.fondo_garanzia_ente IS NULL AND a.fondo_garanzia_estremi IS NULL THEN NULL
                               ELSE jsonb_build_object('ente', a.fondo_garanzia_ente, 'estremi', a.fondo_garanzia_estremi) END)
      INTO v
      FROM ana_aziende a
      LEFT JOIN ana_geo_province pr ON pr.provincia_id = a.rea_provincia_fk
     WHERE a.azienda_id = p_azienda_id;
    RETURN v;
END;
$$;

-- Le zone della mappa della home: il centro del riquadro del percorso di ogni tour
-- pubblicato, raggruppato per mezzo grado (tour vicini = una zona). Mai la traccia.
CREATE OR REPLACE FUNCTION fn_web_tour_zone(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    WITH pub AS (
        SELECT p.*, row_number() OVER () AS pos
          FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua::char(2)) p
    ), centri AS (
        SELECT pub.pos, pub.contenuto_id, pub.titolo, pub.descrizione_slug, pub.slug, pub.data_inizio,
               (m.bbox_min_lat + m.bbox_max_lat) / 2 AS lat,
               (m.bbox_min_lon + m.bbox_max_lon) / 2 AS lng
          FROM pub
          JOIN LATERAL (SELECT * FROM web_tour_mappa m
                         WHERE m.web_tour_contenuti_id_fk = pub.contenuto_id
                           AND m.bbox_min_lat IS NOT NULL AND m.bbox_max_lat IS NOT NULL
                           AND m.bbox_min_lon IS NOT NULL AND m.bbox_max_lon IS NOT NULL
                         ORDER BY m.web_tour_mappa_id LIMIT 1) m ON true
    ), zone AS (
        SELECT round(lat * 2) / 2 AS zlat, round(lng * 2) / 2 AS zlng,
               round(avg(lat), 4) AS lat, round(avg(lng), 4) AS lng, min(pos) AS pos,
               jsonb_agg(jsonb_build_object('contenuto_id', contenuto_id, 'titolo', titolo,
                                            'sezione_slug', descrizione_slug, 'slug', slug,
                                            'data_inizio', data_inizio) ORDER BY pos) AS tour
          FROM centri
         GROUP BY 1, 2
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object('lat', lat, 'lng', lng, 'tour', tour) ORDER BY pos), '[]'::jsonb)
      INTO v FROM zone;
    RETURN v;
END;
$$;

-- Permessi: le quattro letture al pubblico (esplicitamente), gli aiuti no.
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_web_sito_lingua_valida(varchar)',
                             'fn_web_sito_testo(varchar, bigint, varchar, varchar, text)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
    FOREACH f IN ARRAY ARRAY['fn_web_sito_home(integer, varchar)', 'fn_web_sito_evidenza(integer, varchar)',
                             'fn_web_sito_piede(integer, varchar)', 'fn_web_tour_zone(integer, varchar)'] LOOP
        -- Una funzione nuova nasce eseguibile da PUBLIC: si toglie, e il permesso resta
        -- SOLO dove serve (scoperto con l'errore introdotto apposta, 2026-10-20).
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated', f);
        END IF;
    END LOOP;
END $$;

COMMIT;

-- ============================================================================
-- Verifica: Test_693_Web_Sito_Letture.sql
-- ============================================================================
