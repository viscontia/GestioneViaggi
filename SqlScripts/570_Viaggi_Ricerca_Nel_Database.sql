-- =============================================================================
-- 570 — Cercare un viaggio significa chiederlo al database
-- =============================================================================
--
-- In ufficio il gestionale lo usano piu' persone insieme, e due possono inserire
-- viaggi nello stesso momento. La griglia pero' filtrava la lista letta all'apertura
-- della pagina: un viaggio appena inserito da un collega non c'era, e nessuna
-- ricerca poteva trovarlo — bisognava uscire e rientrare, cioe' sapere che il dato
-- e' nato dopo. L'unica cosa che chi cerca non puo' sapere.
--
-- Non nasce una fn_search_viaggi separata: avrebbe dovuto ricopiare per intero la
-- SELECT di questa, con i suoi join e i suoi trentacinque campi, e sarebbe diventata
-- la solita seconda copia da tenere allineata. Qui c'e' un parametro in piu', in
-- coda e con un default: le chiamate che non lo passano continuano a funzionare
-- esattamente come prima.
--
-- I campi cercati sono gli stessi su cui filtrava la griglia — descrizione, nazione,
-- tipo di viaggio, trattamento — cosi' chi usa il programma non nota differenze
-- se non che adesso trova anche cio' che e' appena stato scritto.
-- =============================================================================
--
-- ⚠️ Il DROP qui sotto NON e' un dettaglio. Un parametro in piu' non sostituisce la
-- funzione: ne crea una SECONDA con la stessa base e un argomento facoltativo, e da
-- quel momento la chiamata a quattro argomenti diventa ambigua — "could not choose a
-- best candidate function" — cioe' il gestionale smette di leggere i viaggi. Stessa
-- famiglia dell'inciampo di 544/547 gia' annotato nella Checklist Go-Live.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ana_viaggi_get_all(integer, integer, boolean, boolean);

CREATE OR REPLACE FUNCTION public.fn_ana_viaggi_get_all(p_azienda_id integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer, p_only_completed boolean DEFAULT NULL::boolean, p_future_only boolean DEFAULT NULL::boolean, p_search_text character varying DEFAULT NULL::character varying)
 RETURNS TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_difficolta character varying, viaggio_incluso text, viaggio_escluso text, viaggio_capienza_max integer, viaggio_capienza_alert integer, viaggio_note text, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_nazione_fk integer, viaggio_tipo_pernottamento_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, viaggio_link character varying, viaggio_mappa bytea, viaggio_mappa_mimetype character varying, viaggio_mappa_filename character varying, viaggio_mappa_charset character varying, viaggio_mappa_upd_date date, azienda_id integer, viaggio_tipo_avvicinamento_fk integer, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying, matching_dates_count bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        v.viaggio_id, v.viaggio_descrizione_breve, v.viaggio_descrizione_estesa,
        v.viaggio_numero_giorni, v.viaggio_numero_notti, v.viaggio_pasti_al_sacco,
        v.viaggio_num_km, v.viaggio_difficolta, v.viaggio_incluso, v.viaggio_escluso,
        v.viaggio_capienza_max, v.viaggio_capienza_alert, v.viaggio_note,
        v.viaggio_tipo_viaggio_fk, v.viaggio_tipo_trattamento_fk, v.viaggio_nazione_fk,
        v.viaggio_tipo_pernottamento_fk, v.created_by, v.created, v.updated_by, v.updated,
        v.viaggio_link, v.viaggio_mappa, v.viaggio_mappa_mimetype, v.viaggio_mappa_filename,
        v.viaggio_mappa_charset, v.viaggio_mappa_upd_date, v.azienda_id, v.viaggio_tipo_avvicinamento_fk,
        c.name::VARCHAR(255) as nazione_nome,
        t.tipo_viaggi_descrizione::VARCHAR(255),
        tr.tipo_trattamento_descrizione::VARCHAR(255),
        p.ana_tipo_pernottamento_descrizione::VARCHAR(255),
        a.tipo_avvicinamento_descrizione::VARCHAR(255),
        az.ragione_sociale::VARCHAR(255) as azienda_nome,
        (
            SELECT COUNT(1) FROM ana_date_viaggi d
            WHERE d.viaggio_id_fk = v.viaggio_id
            AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = p_filter_year)
            AND (p_only_completed IS NULL
                OR (p_only_completed = TRUE AND d.data_viaggio_effettuato_sino = 'Y')
                OR (p_only_completed = FALSE AND d.data_viaggio_effettuato_sino = 'N'))
            AND (p_future_only IS NULL OR (p_future_only = TRUE AND d.data_viaggio_data_inizio >= CURRENT_DATE))
        )::BIGINT as matching_dates_count
    FROM ana_viaggi v
    LEFT JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
    LEFT JOIN ana_tipo_viaggi t ON v.viaggio_tipo_viaggio_fk = t.tipo_viaggi_id
    LEFT JOIN ana_tipo_trattamento tr ON v.viaggio_tipo_trattamento_fk = tr.tipo_trattamento_id
    LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
    LEFT JOIN ana_tipo_avvicinamento a ON v.viaggio_tipo_avvicinamento_fk = a.tipo_avvicinamento_id
    LEFT JOIN ana_aziende az ON v.azienda_id = az.azienda_id
    WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR v.azienda_id = p_azienda_id)
    -- Il testo cercato, sugli stessi campi su cui filtrava la griglia in memoria:
    -- descrizione, nazione, tipo di viaggio, trattamento. Cercare qui e non a valle
    -- e' cio' che permette di trovare anche un viaggio inserito poco fa da un collega,
    -- che nella lista gia' letta non c'e' e non ci sara' finche' non la si rilegge.
    AND (NULLIF(btrim(COALESCE(p_search_text, '')), '') IS NULL
         OR UPPER(v.viaggio_descrizione_breve) LIKE '%' || UPPER(btrim(p_search_text)) || '%'
         OR UPPER(COALESCE(c.name, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%'
         OR UPPER(COALESCE(t.tipo_viaggi_descrizione, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%'
         OR UPPER(COALESCE(tr.tipo_trattamento_descrizione, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%')
    AND (p_filter_year IS NULL OR EXISTS (
        SELECT 1 FROM ana_date_viaggi d
        WHERE d.viaggio_id_fk = v.viaggio_id
        AND EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = p_filter_year
        AND (p_only_completed IS NULL
            OR (p_only_completed = TRUE AND d.data_viaggio_effettuato_sino = 'Y')
            OR (p_only_completed = FALSE AND d.data_viaggio_effettuato_sino = 'N'))
        AND (p_future_only IS NULL OR (p_future_only = TRUE AND d.data_viaggio_data_inizio >= CURRENT_DATE))
    ))
    ORDER BY c.name, t.tipo_viaggi_descrizione, v.viaggio_descrizione_breve;
END;
$function$;
