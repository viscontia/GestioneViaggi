-- ============================================================================
-- 700 — Il sito mostra l'email dei messaggi del sito (Tappa 4A)
--
-- Decisione di Adriano del 2026-10-21 (Antonio vuole info@fuoritracciatravel.com
-- sul sito): la pagina Contatti, il piede e i dati per Google mostrano l'email scelta
-- nella scheda «Sito web» per i messaggi del modulo Contatti; se non è scelta, la
-- principale, come prima. L'email principale NON cambia: resta per la stampa delle
-- fatture, le newsletter e le mail del gestionale.
-- Corpo preso dal locale (identico a PROD, md5 bb408d6c...), cambiata solo la riga
-- 'email'. CREATE OR REPLACE conserva i permessi. Rigiocabile.
-- Test: Test_700_Web_Sito_Piede_Email.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_web_sito_piede(p_azienda_id integer, p_lingua character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
        -- 700: l'email dei messaggi del sito (scheda «Sito web»), altrimenti la principale: chi scrive a mano
        -- e chi usa il modulo Contatti arrivano nella stessa casella. La principale resta per fatture e gestionale.
        'email',     coalesce((SELECT e.email FROM web_sito_contenuti c
                                 JOIN ana_aziende_email e ON e.email_id = c.email_messaggi_fk
                                WHERE c.azienda_id = a.azienda_id),
                              fn_ana_aziende_email_principale(a.azienda_id)),
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
$function$;

COMMIT;
