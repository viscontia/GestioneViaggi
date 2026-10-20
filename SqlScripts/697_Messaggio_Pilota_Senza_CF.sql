-- ============================================================================
-- 697 — Pilota senza codice fiscale: il messaggio dice perche' e cosa correggere
--
-- Caso reale (2026-10-20): un cliente svizzero non si riusciva a iscrivere come
-- pilota. La regola era giusta (634-635: il codice fiscale serve a chi guida, chi
-- risiede all'estero ne e' escluso), ma in anagrafica il comune di residenza era
-- COMO: per il gestionale era un residente in Italia senza codice fiscale. Il
-- messaggio non lo diceva, e il rifiuto sembrava un controllo sbagliato.
--
-- Ora il messaggio dice dove risulta residente e cosa correggere (il comune di
-- residenza c'e' sempre: colonna NOT NULL con chiave verso ana_geo_comuni). La regola NON cambia: cambia solo il testo.
--
-- Corpo preso da PROD (identico al locale, md5 20daf671...), toccato solo nel
-- blocco del codice fiscale. Rigiocabile. Test: Test_697_Messaggio_Pilota_Senza_CF.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_mov_clienti_viaggi_valida(p_dati jsonb, p_modifica boolean DEFAULT false)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text, riferimento integer)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_viaggio  INTEGER := (p_dati->>'viaggio_id_fk')::INTEGER;
    v_data     INTEGER := (p_dati->>'data_viaggio_id_fk')::INTEGER;
    v_cliente  INTEGER := (p_dati->>'cliente_id_fk')::INTEGER;
    v_tipo     INTEGER := (p_dati->>'tipo_partecipante_id_fk')::INTEGER;
    v_pilota   BOOLEAN;
    v_nascita  DATE;
    v_cf_cli   TEXT;
    v_res_estero BOOLEAN;
    v_comune_res TEXT;
    v_eta      INTEGER;
    v_mezzo_ob BOOLEAN;
    v_ruolo    VARCHAR;
    v_email    VARCHAR;
    v_nome     TEXT;
    v_manca    TEXT[] := ARRAY[]::TEXT[];
    v_scadenza DATE;
    v_scheda   JSONB;
    v_mancanti TEXT;
    v_motivo   TEXT;
BEGIN
    -- Partenza non piu' aperta alle iscrizioni. Prima di tutto il resto: se non ci
    -- si puo' iscrivere, discutere del documento non ha senso.
    IF NOT p_modifica THEN
        v_motivo := fn_partenza_motivo_non_iscrivibile(v_data);
        IF v_motivo IS NOT NULL THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PARTENZA_NON_ISCRIVIBILE'::VARCHAR,
                   v_motivo, v_data;
            RETURN;
        END IF;
    END IF;

    IF NOT p_modifica AND EXISTS (
        SELECT 1 FROM mov_clienti_viaggi
        WHERE viaggio_id_fk = v_viaggio AND data_viaggio_id_fk = v_data
          AND cliente_id_fk = v_cliente) THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'GIA_ISCRITTO'::VARCHAR,
               'Questo cliente è già iscritto a questo viaggio in questa data.'::TEXT, v_cliente;
    END IF;

    SELECT tp.tipo_partecipante_pilota,
           tp.tipo_partecipante_dati_mezzo_obb = 'Y',
           tp.tipo_partecipante_descrizione
      INTO v_pilota, v_mezzo_ob, v_ruolo
    FROM ana_tipo_partecipante tp WHERE tp.tipo_partecipante_id = v_tipo;

    SELECT c.cliente_email, c.cliente_cognome || ' ' || c.cliente_nome, c.cliente_data_nascita
      INTO v_email, v_nome, v_nascita
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    -- Chi guida deve essere raggiungibile: e' a lui che vanno convocazione,
    -- variazioni di programma e istruzioni.
    IF COALESCE(v_pilota, FALSE) AND btrim(COALESCE(v_email, '')) = '' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_EMAIL'::VARCHAR,
               format('%s viene iscritto come pilota ma non ha un indirizzo email in anagrafica.',
                      COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
    END IF;

    -- ⚠️ Chi guida dev'essere maggiorenne. Adriano, 2026-09-07: «un minorenne non
    -- può avere il ruolo di pilota». Vale per TUTTI i ruoli che guidano — auto,
    -- moto, quad, enduro e le guide — riconosciuti da ana_tipo_partecipante.
    -- tipo_partecipante_pilota, non da un elenco di codici scritto qui: i ruoli
    -- cambiano, la colonna resta.
    --
    -- ⚠️ L'età si conta ALLA PARTENZA, non oggi: chi compie 18 anni prima del
    -- viaggio può guidarlo, e rifiutarlo sarebbe sbagliato. Trovato collaudando il
    -- sito il 2026-09-07: una cliente di 14 anni veniva accettata come pilota
    -- senza un rilievo.
    --
    -- Nessuna iscrizione esistente ne è toccata: misurato, zero piloti minorenni
    -- alla partenza, né su partenze future né su quelle passate.
    -- ⚠️ Il codice fiscale serve a CHI GUIDA, perche' e' a lui che si emette la
    -- fattura (Adriano, 2026-09-07). Ai passeggeri non si chiede: alleggerisce
    -- l'iscrizione, che e' il momento in cui la gente rinuncia.
    --
    -- Il ruolo si riconosce da tipo_partecipante_pilota, non dall'ordine in cui il
    -- sito chiede le email: cosi' copre moto, quad, enduro e le guide, e regge se
    -- domani l'interfaccia cambia.
    --
    -- Chi risiede all'estero e' escluso: il codice fiscale italiano non ce l'ha.
    IF COALESCE(v_pilota, FALSE) THEN
        SELECT btrim(COALESCE(c.cliente_codicefiscale, '')),
               COALESCE((g.comune_estero = 'Y'), FALSE),
               g.comune_descrizione
          INTO v_cf_cli, v_res_estero, v_comune_res
          FROM ana_clienti c
          LEFT JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
         WHERE c.cliente_id = v_cliente;

        IF v_cf_cli = '' AND NOT v_res_estero THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_CF'::VARCHAR,
                   -- 697: il messaggio dice PERCHE' il codice fiscale serve a questa
                   -- persona (la residenza in anagrafica) e cosa correggere se e' sbagliata.
                   format('%s viene iscritto come pilota ma non ha il codice fiscale e in anagrafica '
                          || 'risulta residente in Italia (%s): il codice fiscale serve per emettere la '
                          || 'fattura a chi guida. Se risiede all''estero, correggi il comune di residenza.',
                          COALESCE(v_nome, 'Il cliente'), v_comune_res)::TEXT, v_cliente;
        END IF;
    END IF;

    IF COALESCE(v_pilota, FALSE) AND v_nascita IS NOT NULL THEN
        SELECT EXTRACT(YEAR FROM age(dv.data_viaggio_data_inizio, v_nascita))::INTEGER
          INTO v_eta
          FROM ana_date_viaggi dv WHERE dv.data_viaggio_id = v_data;

        IF v_eta IS NOT NULL AND v_eta < 18 THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_MINORENNE'::VARCHAR,
                   format('%s alla partenza avrà %s anni: chi guida deve essere maggiorenne. '
                          || 'Può viaggiare come passeggero.',
                          COALESCE(v_nome, 'Il cliente'), v_eta)::TEXT, v_cliente;
        END IF;
    END IF;

    -- L'anagrafica dev'essere completa PRIMA della partenza: in albergo i documenti
    -- di tutti gli occupanti si presentano per legge (script 563).
    SELECT to_jsonb(c) INTO v_scheda FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    IF v_scheda IS NOT NULL THEN
        SELECT regexp_replace(string_agg(m.etichetta, ', ' ORDER BY m.campo), ', ([^,]+)$', ' e \1')
          INTO v_mancanti
        FROM fn_ana_clienti_campi_mancanti(v_scheda, COALESCE(v_pilota, FALSE)) m;

        IF v_mancanti IS NOT NULL THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'ANAGRAFICA_INCOMPLETA'::VARCHAR,
                   format('L''anagrafica di %s non è completa: manca %s. Va completata prima dell''iscrizione.',
                          COALESCE(v_nome, 'questo cliente'), v_mancanti)::TEXT,
                   v_cliente;
        END IF;
    END IF;

    -- Il documento: regola e gravita' in fn_documento_esito_per_partenza (582), che
    -- il sito interroga anche PRIMA di comporre l'iscrizione.
    SELECT c.cliente_documento_rilasciato_scadenza INTO v_scadenza
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    RETURN QUERY
    SELECT e.gravita, e.esito, e.messaggio, v_cliente
    FROM fn_documento_esito_per_partenza(v_data, v_scadenza, v_nome) e;

    -- Il mezzo, se il ruolo lo richiede. La segnalazione dice QUALE dato manca.
    IF COALESCE(v_mezzo_ob, FALSE) THEN
        IF (p_dati->>'ana_mezzi_id_fk') IS NULL THEN
            v_manca := array_append(v_manca, 'la marca');
        END IF;
        IF (p_dati->>'mezzo_modello_id_fk') IS NULL THEN
            v_manca := array_append(v_manca, 'il modello');
        END IF;
        IF btrim(COALESCE(p_dati->>'mov_cliente_viaggio_targa_mezzo','')) = '' THEN
            v_manca := array_append(v_manca, 'la targa');
        END IF;

        IF array_length(v_manca, 1) > 0 THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'MEZZO_INCOMPLETO'::VARCHAR,
                   format('Per il ruolo «%s» i dati del mezzo sono obbligatori: manca %s.',
                          COALESCE(v_ruolo, 'selezionato'),
                          regexp_replace(array_to_string(v_manca, ', '), ', ([^,]+)$', ' e \1'))::TEXT,
                   v_cliente;
        END IF;
    END IF;

    -- ⚠️ QUI NON SI CHIAMA PIU' fn_cliente_iscrivibile. Il 631 ce l'aveva messa
    -- per portare la regola del codice fiscale anche nel gestionale; dal 634 quella
    -- regola e' scritta qui sopra, e conosce il RUOLO — cosa che l'altra non poteva
    -- sapere. Tenerle tutte e due significava due messaggi diversi per lo stesso
    -- rifiuto: la duplicazione che questo progetto passa il tempo a togliere.
    --
    -- fn_cliente_iscrivibile resta, ma serve a UN'ALTRA cosa: al sito, che al passo 2
    -- chiede «questa persona puo' iscriversi?» PRIMA di far compilare mezzo,
    -- passeggeri e camere. E' la stessa domanda fatta prima, non una seconda regola.

END;
$function$;

COMMIT;
