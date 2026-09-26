-- ============================================================================
-- 664 — Il messaggio del documento scaduto si legge in italiano
--
-- fn_documento_esito_per_partenza (script 582) attaccava il nome alla frase di
-- fn_documento_stato_per_viaggio: ne uscivano «Il cliente documento scaduto il
-- 15/01/2026…» (sito, senza nome) e «Mario Rossi documento scaduto il…»
-- (gestionale). Trovato il 2026-09-26 nelle prove del gruppo H.
--
-- Ora: «Documento scaduto il…» senza nome, «Mario Rossi: documento scaduto il…»
-- con il nome. Cambia solo il testo: gravita', esito e firma restano uguali,
-- quindi chi chiama (fn_web_cliente_profilo_pubblico, fn_mov_clienti_viaggi_valida,
-- il sito Flask) non se ne accorge. Nessuno confronta il testo del messaggio.
--
-- Indipendente da 660–663: si puo' applicare a PROD da solo.
--
-- ✅ Applicato in locale e a PROD il 2026-09-26.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_documento_esito_per_partenza(p_data_viaggio_id integer, p_scadenza date, p_nome text DEFAULT NULL::text)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_inizio        DATE;
    v_fine          DATE;
    v_estero        BOOLEAN;
    v_doc_stato     VARCHAR;
    v_doc_messaggio TEXT;
BEGIN
    SELECT d.data_viaggio_data_inizio, d.data_viaggio_data_fine,
           -- Nazione non indicata = si assume estero: e' il caso piu' severo, e sui
           -- documenti di chi parte non si tira a indovinare.
           COALESCE(co.iso_alpha2, 'XX') <> 'IT'
      INTO v_inizio, v_fine, v_estero
    FROM ana_date_viaggi d
    JOIN ana_viaggi vg         ON vg.viaggio_id = d.viaggio_id_fk
    LEFT JOIN eba_countries co ON co.country_id = vg.viaggio_nazione_fk
    WHERE d.data_viaggio_id = p_data_viaggio_id;

    IF v_inizio IS NULL THEN
        RETURN;   -- partenza sconosciuta: non e' questa funzione a doverlo dire
    END IF;

    SELECT s.stato, s.messaggio INTO v_doc_stato, v_doc_messaggio
    FROM fn_documento_stato_per_viaggio(p_scadenza, v_inizio, v_fine) s;

    IF v_doc_stato = 'VALIDO' THEN
        RETURN;   -- nessun esito: non c'e' niente da dire
    END IF;

    RETURN QUERY SELECT
        -- All'estero e' un ERRORE: senza documento valido non si parte, e iscrivere
        -- qualcuno a un viaggio che non potra' fare non e' un servizio. In Italia e'
        -- un AVVISO: si parte, ma l'albergo puo' rifiutare la registrazione — i
        -- documenti di tutti gli occupanti si presentano per legge (script 563).
        CASE WHEN v_estero THEN 'ERRORE' ELSE 'AVVISO' END::VARCHAR,
        ('DOCUMENTO_' || v_doc_stato)::VARCHAR,
        -- «Mario Rossi: documento scaduto il…», oppure, senza nome, «Documento
        -- scaduto il…». Fino allo script 664 il nome si attaccava alla frase
        -- («Il cliente documento scaduto il…»), che non stava in piedi.
        format('%s%s%s',
               CASE WHEN p_nome IS NULL THEN '' ELSE p_nome || ': ' END,
               CASE WHEN p_nome IS NULL THEN v_doc_messaggio
                    ELSE lower(left(v_doc_messaggio, 1)) || substr(v_doc_messaggio, 2) END,
               CASE WHEN v_estero
                    THEN ' Il viaggio è all''estero: senza documento valido non si parte.'
                    ELSE ' In albergo i documenti di tutti gli occupanti si presentano per legge.'
               END)::TEXT;
END;
$function$;


-- Verifica (atteso: una riga che comincia per «Documento scaduto il» e una per
-- «Mario Rossi: documento scaduto il»)
-- SELECT e.messaggio FROM ana_date_viaggi d,
--        LATERAL fn_documento_esito_per_partenza(d.data_viaggio_id, d.data_viaggio_data_inizio - 30, n) e,
--        (VALUES (NULL::text), ('Mario Rossi')) v(n)
--  WHERE d.data_viaggio_data_inizio > current_date LIMIT 2;
