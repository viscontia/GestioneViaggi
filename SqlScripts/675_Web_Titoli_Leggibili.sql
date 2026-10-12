-- ============================================================================
-- 675 — I titoli dei tour, sul sito, non in MAIUSCOLO
--
-- Il gestionale scrive la descrizione breve del viaggio in maiuscolo (regola
-- dei dati interni: AnaViaggiDialog, uppercase converter) e fn_web_tour_pubblicati
-- la passava al sito cosi' com'era: «PONTE DELL'IMMACOLATA IN 4X4». La forma
-- leggibile la decide il database, come tutto quello che il sito mostra; il
-- sito non riscrive i testi.
--
--   fn_web_titolo_leggibile(testo) → testo
--     parola per parola:
--     * una parola che ha gia' delle minuscole resta com'e' (vince chi l'ha
--       scritta a mano: «1st STAGE» → «1st Stage»);
--     * le sigle restano maiuscole (SSV, MTB, ATV…); 4X4 diventa 4x4;
--     * articoli e preposizioni in minuscolo, tranne in testa al titolo o dopo
--       «:», «-», «–»; anche elisi: DELL'IMMACOLATA → dell'Immacolata;
--     * tutte le altre: iniziale maiuscola.
--     Non sa quali sono i nomi propri: per questo l'iniziale va su ogni parola
--     e non solo sulla prima («Capodanno in Ogliastra», non «in ogliastra»).
--
-- Usata da fn_web_tour_pubblicati per `titolo` (e quindi per il meta_title di
-- riserva). La usera' anche la funzione pubblica dell'itinerario quando
-- nascera' con la scheda tour del sito (titoli delle tappe).
--
-- Funzione di sola trasformazione: IMMUTABLE, nessun GRANT (659), search_path
-- fissato (655). fn_web_tour_pubblicati e' SECURITY DEFINER e la chiama come
-- proprietario. Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_titolo_leggibile(p_testo text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path = public, pg_temp
AS $$
DECLARE
    -- Articoli, preposizioni (semplici e articolate) e congiunzioni: minuscole
    -- dentro il titolo.
    c_piccole CONSTANT text[] := ARRAY[
        'il','lo','la','i','gli','le','un','uno','una',
        'di','a','da','in','con','su','per','tra','fra','e','ed','o',
        'del','dello','della','dei','degli','delle',
        'al','allo','alla','ai','agli','alle',
        'dal','dallo','dalla','dai','dagli','dalle',
        'nel','nello','nella','nei','negli','nelle',
        'sul','sullo','sulla','sui','sugli','sulle','col','coi',
        'gg',                                             -- «8 GG» → «8 gg»
        -- le stesse parole nelle lingue delle traduzioni (titoli delle tappe)
        'of','the','and','to','from','on','at','by','for','with','an',
        'du','des','les','et','au','aux','en','sur','dans','par',
        'el','los','las','y','por','sin',
        'und','der','die','das','den','dem','von','zu','im','am','mit','nach','zum','zur'];
    -- Prima dell'apostrofo: l', dell', all', dall', nell', sull', un', d' (anche francese).
    c_elise CONSTANT text[] := ARRAY['l','dell','all','dall','nell','sull','un','d'];
    -- Sigle che restano maiuscole.
    c_sigle CONSTANT text[] := ARRAY['SSV','MTB','ATV','UTV','SUV','GPS','GPX','KTM','BMW','GS'];
    v_parti  text[] := '{}';
    v_parola text;
    v_nudo   text;
    v_testa  boolean := true;   -- la prossima parola apre il titolo o una sua parte
    v_pos    int;
BEGIN
    IF p_testo IS NULL THEN
        RETURN NULL;
    END IF;

    FOREACH v_parola IN ARRAY string_to_array(p_testo, ' ')
    LOOP
        v_nudo := regexp_replace(v_parola, '[^[:alnum:]]', '', 'g');

        IF v_parola ~ '[[:lower:]]' OR v_parola !~ '[[:upper:]]' THEN
            -- Gia' scritta in minuscolo/misto, oppure senza lettere (numeri,
            -- trattini): non si tocca.
            NULL;
        ELSIF upper(v_nudo) = ANY (c_sigle) THEN
            NULL;
        ELSIF strpos(replace(v_parola, '’', ''''), '''') > 1
              AND lower(split_part(replace(v_parola, '’', ''''), '''', 1)) = ANY (c_elise)
              AND split_part(replace(v_parola, '’', ''''), '''', 2) <> '' THEN
            -- DELL'IMMACOLATA → dell'Immacolata (L'OGLIASTRA in testa → L'Ogliastra)
            v_pos := strpos(replace(v_parola, '’', ''''), '''');
            v_parola := CASE WHEN v_testa THEN initcap(left(v_parola, v_pos - 1))
                             ELSE lower(left(v_parola, v_pos - 1)) END
                        || substr(v_parola, v_pos, 1)
                        || initcap(substr(v_parola, v_pos + 1));
        ELSIF NOT v_testa AND lower(v_nudo) = ANY (c_piccole) THEN
            v_parola := lower(v_parola);
        ELSE
            -- initcap: «4X4» → «4x4», «(6» resta, «GIORNI)» → «Giorni)»
            v_parola := initcap(v_parola);
        END IF;

        v_parti := v_parti || v_parola;

        -- Dopo «:» o un trattino si riparte come in testa al titolo.
        IF v_parola <> '' THEN
            v_testa := v_parola ~ '[:]$' OR v_parola IN ('-', '–', '—');
        END IF;
    END LOOP;

    -- Ricomposta con gli stessi spazi: string_to_array tiene gli spazi doppi
    -- come parole vuote, array_to_string li rimette.
    RETURN array_to_string(v_parti, ' ');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_titolo_leggibile(text) FROM PUBLIC;

-- fn_web_tour_pubblicati: identica alla versione di 506/655, cambia solo b_titolo.
CREATE OR REPLACE FUNCTION public.fn_web_tour_pubblicati(p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar)
 RETURNS TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying, descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying, numero_giorni integer, descrizione_web character varying, descrizione_slug character varying, prezzo_da integer, data_inizio date, data_fine date, immagine_url text, immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer, incluso text, escluso text, posti_rimasti integer, posti_stato text, is_tour_breve boolean, meta_title character varying, meta_description character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    WITH base AS (
        SELECT v.viaggio_id                          AS b_viaggio_id,
               c.web_tour_contenuti_id               AS b_contenuto_id,
               -- 675: il gestionale scrive in maiuscolo, il sito mostra la forma leggibile
               fn_web_titolo_leggibile(v.viaggio_descrizione_breve)::VARCHAR AS b_titolo,
               COALESCE(t_sott.testo, c.sottotitolo)::VARCHAR   AS b_sottotitolo,
               COALESCE(t_descr.testo, c.descrizione_html)      AS b_descrizione_html,
               c.slug                                AS b_slug,
               v.viaggio_difficolta                  AS b_difficolta,
               COALESCE(t_dur.testo, c.durata_testo)::VARCHAR   AS b_durata_testo,
               v.viaggio_numero_giorni               AS b_numero_giorni,
               d.descrizione_web                     AS b_descrizione_web,
               d.slug                                AS b_descrizione_slug,
               fn_web_prezzo_da_data(dv.data_viaggio_id)        AS b_prezzo_da,
               dv.data_viaggio_data_inizio           AS b_data_inizio,
               dv.data_viaggio_data_fine             AS b_data_fine,
               img.url                               AS b_immagine_url,
               img.storage_path                      AS b_immagine_storage_path,
               c.data_pubblicazione                  AS b_data_pubblicazione,
               c.ordine                              AS b_ordine,
               COALESCE(t_inc.testo, v.viaggio_incluso)         AS b_incluso,
               COALESCE(t_esc.testo, v.viaggio_escluso)         AS b_escluso,
               v.viaggio_capienza_max                AS b_cap_max,
               v.viaggio_capienza_alert              AS b_cap_alert,
               fn_web_mezzi_occupati_data(dv.data_viaggio_id)   AS b_occupati,
               COALESCE(tv.tipo_viaggio_breve, false)           AS b_is_tour_breve,
               c.meta_title                          AS b_meta_title,
               c.meta_description                    AS b_meta_description
          FROM web_tour_contenuti c
          JOIN ana_date_viaggi dv      ON dv.data_viaggio_id = c.data_viaggio_id_fk
          JOIN ana_viaggi v            ON v.viaggio_id = c.viaggio_id_fk
          LEFT JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
          LEFT JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
          LEFT JOIN web_tour_immagini img   ON img.web_tour_contenuti_id_fk = c.web_tour_contenuti_id AND img.tipo = 'principale'
          LEFT JOIN web_traduzioni t_sott  ON p_lingua <> 'IT'
               AND t_sott.entita = 'web_tour_contenuti' AND t_sott.entita_id = c.web_tour_contenuti_id
               AND t_sott.campo = 'sottotitolo'      AND t_sott.lingua = p_lingua AND NOT t_sott.obsoleto
          LEFT JOIN web_traduzioni t_descr ON p_lingua <> 'IT'
               AND t_descr.entita = 'web_tour_contenuti' AND t_descr.entita_id = c.web_tour_contenuti_id
               AND t_descr.campo = 'descrizione_html' AND t_descr.lingua = p_lingua AND NOT t_descr.obsoleto
          LEFT JOIN web_traduzioni t_dur   ON p_lingua <> 'IT'
               AND t_dur.entita = 'web_tour_contenuti'  AND t_dur.entita_id = c.web_tour_contenuti_id
               AND t_dur.campo = 'durata_testo'       AND t_dur.lingua = p_lingua AND NOT t_dur.obsoleto
          LEFT JOIN web_traduzioni t_inc   ON p_lingua <> 'IT'
               AND t_inc.entita = 'ana_viaggi'          AND t_inc.entita_id = v.viaggio_id
               AND t_inc.campo = 'viaggio_incluso'    AND t_inc.lingua = p_lingua AND NOT t_inc.obsoleto
          LEFT JOIN web_traduzioni t_esc   ON p_lingua <> 'IT'
               AND t_esc.entita = 'ana_viaggi'          AND t_esc.entita_id = v.viaggio_id
               AND t_esc.campo = 'viaggio_escluso'    AND t_esc.lingua = p_lingua AND NOT t_esc.obsoleto
         WHERE c.azienda_id = p_azienda_id
           AND c.stato_pubblicazione = 'pubblicato'
           -- Una partenza già iniziata non si vende più: il sito pubblico non deve mostrarla.
           -- Taglio alla data di INIZIO, lo stesso che StatoPartenzaRules.MotivoNonPubblicabile impone
           -- in scrittura (si pubblica solo una partenza che deve ancora iniziare): senza questo filtro
           -- una scheda pubblicata resterebbe visibile per sempre, perché nulla la ritira allo scadere.
           AND dv.data_viaggio_data_inizio > CURRENT_DATE
    )
    SELECT b_viaggio_id, b_contenuto_id, b_titolo, b_sottotitolo, b_descrizione_html, b_slug,
           b_difficolta, b_durata_testo, b_numero_giorni, b_descrizione_web, b_descrizione_slug,
           b_prezzo_da, b_data_inizio, b_data_fine, b_immagine_url, b_immagine_storage_path,
           b_data_pubblicazione, b_ordine, b_incluso, b_escluso,
           CASE WHEN b_cap_max IS NULL THEN NULL
                ELSE GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) END AS posti_rimasti,
           CASE WHEN b_cap_max IS NULL THEN NULL
                WHEN GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) = 0 THEN 'sold_out'
                WHEN b_cap_alert IS NOT NULL
                     AND GREATEST(b_cap_max - COALESCE(b_occupati, 0), 0) <= b_cap_alert THEN 'ultimi'
                ELSE 'disponibile' END AS posti_stato,
           b_is_tour_breve,
           COALESCE(NULLIF(btrim(b_meta_title), ''), b_titolo)::VARCHAR       AS meta_title,
           COALESCE(NULLIF(btrim(b_meta_description), ''), b_sottotitolo)::VARCHAR AS meta_description
      FROM base
     ORDER BY b_ordine, b_titolo;
$function$;

COMMIT;

-- ============================================================================
-- Verifica
--
-- 1. Casi di prova (atteso: ok = true su ogni riga)
SELECT t, fn_web_titolo_leggibile(t) AS risultato, fn_web_titolo_leggibile(t) = atteso AS ok
  FROM (VALUES
    ('PONTE DELL''IMMACOLATA IN 4X4',            'Ponte dell''Immacolata in 4x4'),
    ('CAPODANNO IN OGLIASTRA 2026 - (6 GIORNI)', 'Capodanno in Ogliastra 2026 - (6 Giorni)'),
    ('ANDALUCIA - DESERTI E SEGRETI',            'Andalucia - Deserti e Segreti'),
    ('SARDEGNA SSV GRAN TOUR ',                  'Sardegna SSV Gran Tour '),
    ('MONGOLIA IN FUORISTRADA',                  'Mongolia in Fuoristrada'),
    ('L''OGLIASTRA IN MTB',                      'L''Ogliastra in MTB'),
    ('1st STAGE: OLBIA – PADRU – BITTI',         '1st Stage: Olbia – Padru – Bitti'),
    ('MAXI ENDURO TOUR GPX',                     'Maxi Enduro Tour GPX'),
    ('CAPODANNO IN FUORISTRADA 8 GG',            'Capodanno in Fuoristrada 8 gg'),
    ('2° STAGE: JERZU – HEART OF OGLIASTRA',     '2° Stage: Jerzu – Heart of Ogliastra'),
    ('Tour scritto a mano',                      'Tour scritto a mano')
  ) AS c(t, atteso);
--
-- 2. I titoli dei tour pubblicati
SELECT titolo, meta_title FROM fn_web_tour_pubblicati(2, 'IT');
-- ============================================================================
