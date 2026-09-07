-- ============================================================================
-- 635 — fn_cliente_iscrivibile impara a distinguere chi guida
--
-- Completa il 634. Il sito, al passo 2, chiede «questa persona puo' iscriversi?»
-- PRIMA di far compilare mezzo, passeggeri e camere. Ma dopo il 634 la risposta
-- dipende dal RUOLO: al pilota il codice fiscale serve, al passeggero no.
--
-- Senza il parametro il sito avrebbe due comportamenti sbagliati, opposti:
-- chiedendo sempre il codice fiscale tornerebbe a pesare sui passeggeri; non
-- chiedendolo mai, farebbe compilare tutta l'iscrizione a un pilota che verra'
-- rifiutato alla fine — il difetto che quella funzione esisteva per evitare.
--
-- ⚠️ Il default e' TRUE (guida): chi non passa il parametro ottiene il controllo
-- piu' severo. Un default permissivo avrebbe spento la regola in silenzio per
-- ogni chiamante non aggiornato.
--
-- ⚠️ DUE COSE DA SISTEMARE INSIEME, scoperte applicando:
--   1. la vecchia firma a due parametri va ELIMINATA, altrimenti la chiamata
--      resta ambigua («function is not unique») — ed e' comunque il difetto della
--      funzione vecchia lasciata accanto alla nuova;
--   2. fn_mov_clienti_viaggi_valida non deve piu' chiamarla: dal 634 la regola del
--      codice fiscale e' scritta li' dentro e conosce il ruolo. Tenendo entrambe
--      si sarebbero avuti DUE messaggi diversi per lo stesso rifiuto.
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

-- 1. La validazione dell'iscrizione smette di chiamarla (la regola e' sua, dal 634).
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
               COALESCE((g.comune_estero = 'Y'), FALSE)
          INTO v_cf_cli, v_res_estero
          FROM ana_clienti c
          LEFT JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
         WHERE c.cliente_id = v_cliente;

        IF v_cf_cli = '' AND NOT v_res_estero THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_CF'::VARCHAR,
                   format('%s viene iscritto come pilota ma non ha il codice fiscale: '
                          || 'serve per emettere la fattura a chi guida.',
                          COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
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

-- 2. Via la firma vecchia: due firme per la stessa domanda sono un'ambiguita'.
DROP FUNCTION IF EXISTS public.fn_cliente_iscrivibile(INTEGER, INTEGER);

-- 3. La nuova, che conosce il ruolo.
CREATE OR REPLACE FUNCTION fn_cliente_iscrivibile(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER,
    p_guida      BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
STABLE
AS $iscr$
DECLARE
    v_cf       VARCHAR;
    v_com_res  INTEGER;
    v_estero   BOOLEAN;
BEGIN
    SELECT c.cliente_codicefiscale, c.cliente_comune_residenza_fk
      INTO v_cf, v_com_res
      FROM ana_clienti c
     WHERE c.cliente_id = p_cliente_id AND c.azienda_fk = p_azienda_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'CLIENTE_INESISTENTE'::VARCHAR,
               'Questa scheda cliente non esiste.'::TEXT;
        RETURN;
    END IF;

    -- Il codice fiscale: solo a chi guida, e solo se risiede in Italia.
    -- ⚠️ Ai passeggeri non si chiede: e' il punto del 634.
    IF COALESCE(p_guida, TRUE) AND btrim(COALESCE(v_cf, '')) = '' AND v_com_res IS NOT NULL THEN
        SELECT (g.comune_estero = 'Y') INTO v_estero
          FROM ana_geo_comuni g WHERE g.comune_id = v_com_res;

        IF COALESCE(v_estero, FALSE) = FALSE THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'MANCA_CF_PER_ISCRIZIONE'::VARCHAR,
                   ('Per iscriverti come pilota manca il codice fiscale: serve per '
                    || 'emettere la fattura a chi guida. Integra la tua anagrafica per proseguire.')::TEXT;
        END IF;
    END IF;
END;
$iscr$;

COMMENT ON FUNCTION fn_cliente_iscrivibile(INTEGER, INTEGER, BOOLEAN) IS
    'Cosa manca a un cliente per iscriversi, secondo il RUOLO. Script 630, ruolo aggiunto dal 635.';

DO $verifica$
DECLARE v_senza INTEGER; v_n INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
               WHERE n.nspname='public' AND p.proname='fn_cliente_iscrivibile'
                 AND pg_get_function_identity_arguments(p.oid) = 'p_cliente_id integer, p_azienda_id integer') THEN
        RAISE EXCEPTION '635: la firma vecchia a due parametri e ancora presente.';
    END IF;

    SELECT c.cliente_id INTO v_senza FROM ana_clienti c
      JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
     WHERE c.azienda_fk = 2 AND g.comune_estero = 'N'
       AND btrim(COALESCE(c.cliente_codicefiscale,'')) = '' LIMIT 1;

    IF v_senza IS NOT NULL THEN
        SELECT count(*) INTO v_n FROM fn_cliente_iscrivibile(v_senza, 2, TRUE);
        IF v_n <> 1 THEN RAISE EXCEPTION '635: come guida doveva essere fermato.'; END IF;
        SELECT count(*) INTO v_n FROM fn_cliente_iscrivibile(v_senza, 2, FALSE);
        IF v_n <> 0 THEN RAISE EXCEPTION '635: come passeggero NON doveva essere fermato.'; END IF;
        SELECT count(*) INTO v_n FROM fn_cliente_iscrivibile(v_senza, 2);
        IF v_n <> 1 THEN RAISE EXCEPTION '635: senza parametro doveva valere il caso severo.'; END IF;
        RAISE NOTICE '635: cliente % -> guida: fermato | passeggero: passa | default: severo', v_senza;
    END IF;
END
$verifica$;

COMMIT;
