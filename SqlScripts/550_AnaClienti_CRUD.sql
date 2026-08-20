-- =============================================================================
-- 550 — Fase 3: il CRUD unico di ana_clienti
-- =============================================================================
-- "Inserisci un cliente" era implementato TRE volte: ClienteRepository.InsertAsync
-- (SQL inline, 31 colonne), sp_ana_clienti_create (33 colonne, mai chiamata da
-- nessuno) e fn_wizard_insert_cliente (23 colonne, usata dal sito — le mancavano
-- foto, documento, IBAN e note). Nessuna delle tre scriveva consenso e lingua.
--
-- Qui ce n'e' una sola, e la chiamano entrambi.
--
-- ── I dati passano in JSONB, con i NOMI ESATTI DELLE COLONNE come chiavi ──────
-- Non e' pigrizia: sono ~30 campi, e trenta parametri posizionali chiamati da due
-- linguaggi diversi sono un invito a scambiarne due adiacenti — proprio l'errore
-- che il codice fiscale ci ha fatto scoprire su tre anagrafiche (nome e cognome
-- invertiti). Usando i nomi delle colonne non c'e' nessuna corrispondenza da
-- ricordare, e un campo nuovo domani non costringe ad aggiornare i due client
-- nello stesso momento.
--
-- ── Validare e scrivere sono due gesti diversi ───────────────────────────────
-- fn_ana_clienti_valida non scrive: serve al client per SAPERE prima di salvare,
-- e poter chiedere conferma. Insert e update rivalidano comunque, perche' la
-- guardia autoritativa non puo' stare nel client.
--
--   ERRORE   -> non si salva, mai
--   CONFERMA -> non si salva a meno che il chiamante dichiari di aver chiesto
--               conferma all'utente (p_conferme_accettate)
--   AVVISO   -> si salva, e il client decide se mostrarlo
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Validazione: tutte le segnalazioni, la piu' grave per prima. Non scrive nulla.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_ana_clienti_valida(
    p_dati       JSONB,
    p_cliente_id INTEGER DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_azienda   INTEGER := (p_dati->>'azienda_fk')::INTEGER;
    v_cognome   VARCHAR := p_dati->>'cliente_cognome';
    v_nome      VARCHAR := p_dati->>'cliente_nome';
    v_nascita   DATE    := (p_dati->>'cliente_data_nascita')::DATE;
    v_com_nasc  INTEGER := (p_dati->>'cliente_comune_nascita_fk')::INTEGER;
    v_cf        VARCHAR := p_dati->>'cliente_codicefiscale';
    v_titolo    INTEGER := (p_dati->>'cliente_titolo_fk')::INTEGER;
    v_sesso     CHAR;
    v_rilascio  DATE    := (p_dati->>'cliente_documento_rilasciato_data')::DATE;
    v_scadenza  DATE    := (p_dati->>'cliente_documento_rilasciato_scadenza')::DATE;
BEGIN
    -- Il sesso non arriva da fuori: lo porta il titolo (SqlScripts/538).
    SELECT t.titolo_persone_sesso INTO v_sesso
    FROM ana_titolo_persone t WHERE t.titolo_persone_cod = v_titolo;

    -- 1. Duplicati e omonimi
    RETURN QUERY
    SELECT d.gravita, d.esito, d.messaggio
    FROM fn_ana_clienti_verifica_duplicato(v_azienda, v_cognome, v_nome, v_nascita,
                                           v_com_nasc, v_cf, p_cliente_id) d;

    -- 2. Codice fiscale
    RETURN QUERY
    SELECT c.gravita, c.esito, c.messaggio
    FROM fn_cf_verifica(v_cf, v_cognome, v_nome, v_nascita, v_sesso, v_com_nasc) c
    WHERE c.gravita <> 'OK';

    -- 3. Le regole che un CHECK non puo' esprimere, perche' guardano l'oggi.
    --    (CURRENT_DATE non e' IMMUTABLE: PostgreSQL rifiuta il vincolo.)
    IF v_rilascio IS NOT NULL AND v_rilascio > CURRENT_DATE THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'RILASCIO_FUTURO'::VARCHAR,
               'La data di rilascio del documento è nel futuro.'::TEXT;
    END IF;

    IF v_nascita IS NOT NULL AND v_nascita > CURRENT_DATE THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'NASCITA_FUTURA'::VARCHAR,
               'La data di nascita è nel futuro.'::TEXT;
    END IF;

    -- Un documento scade da solo col tempo: e' un avviso, non un difetto del dato.
    IF v_scadenza IS NOT NULL AND v_scadenza < CURRENT_DATE THEN
        RETURN QUERY SELECT 'AVVISO'::VARCHAR, 'DOCUMENTO_SCADUTO'::VARCHAR,
               format('Il documento risulta scaduto il %s.', to_char(v_scadenza,'DD/MM/YYYY'))::TEXT;
    END IF;

    -- Un numero senza prefisso non e' chiamabile dall'estero.
    IF btrim(COALESCE(p_dati->>'cliente_telefono','')) <> ''
       AND btrim(COALESCE(p_dati->>'cliente_preftelint','')) = '' THEN
        RETURN QUERY SELECT 'CONFERMA'::VARCHAR, 'PREFISSO_MANCANTE'::VARCHAR,
               'C''è un numero di telefono ma manca il prefisso internazionale.'::TEXT;
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- La guardia comune a insert e update.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_ana_clienti_guardia(
    p_dati JSONB, p_cliente_id INTEGER, p_conferme_accettate BOOLEAN
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_msg TEXT;
BEGIN
    -- Una segnalazione per riga: due frasi di seguito su una riga sola si leggono male.
    SELECT string_agg(messaggio, E'\n') INTO v_msg
    FROM fn_ana_clienti_valida(p_dati, p_cliente_id)
    WHERE gravita = 'ERRORE' OR (gravita = 'CONFERMA' AND NOT COALESCE(p_conferme_accettate, FALSE));

    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION '%', v_msg;
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Inserimento. Il consenso arriva QUI, non con una chiamata successiva: va
-- raccolto nel momento in cui l'anagrafica nasce, o non e' dimostrabile.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_ana_clienti_insert(
    p_dati JSONB, p_conferme_accettate BOOLEAN DEFAULT FALSE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER;
BEGIN
    PERFORM fn_ana_clienti_guardia(p_dati, NULL, p_conferme_accettate);

    INSERT INTO ana_clienti (
        azienda_fk, cliente_titolo_fk, cliente_cognome, cliente_nome, cliente_sesso,
        cliente_comune_residenza_fk, cliente_indirizzo_residenza,
        cliente_comune_nascita_fk, cliente_data_nascita,
        cliente_preftelint, cliente_telefono, cliente_email, cliente_codicefiscale,
        cliente_iban, cliente_foto, cliente_carta_identita,
        cliente_tipodoc_identita, cliente_documento_numero, cliente_documento_rilasciato_da,
        cliente_documento_rilasciato_data, cliente_documento_rilasciato_scadenza,
        cliente_note, cliente_intolleranza,
        cliente_foto_mimetype, cliente_foto_filename, cliente_foto_charset, cliente_foto_upd_date,
        cliente_documento_mimetype, cliente_documento_filename, cliente_documento_chartset,
        cliente_documento_upd_date, controparte_fk,
        cliente_lingua, consenso_marketing, consenso_marketing_data, consenso_marketing_fonte
    ) VALUES (
        (p_dati->>'azienda_fk')::INTEGER, (p_dati->>'cliente_titolo_fk')::INTEGER,
        upper(btrim(p_dati->>'cliente_cognome')), upper(btrim(p_dati->>'cliente_nome')),
        'M',   -- segnaposto: lo riscrive il trigger dal titolo (SqlScripts/538)
        (p_dati->>'cliente_comune_residenza_fk')::INTEGER, p_dati->>'cliente_indirizzo_residenza',
        (p_dati->>'cliente_comune_nascita_fk')::INTEGER, (p_dati->>'cliente_data_nascita')::DATE,
        p_dati->>'cliente_preftelint', p_dati->>'cliente_telefono',
        lower(btrim(p_dati->>'cliente_email')), upper(btrim(p_dati->>'cliente_codicefiscale')),
        upper(btrim(p_dati->>'cliente_iban')),
        decode(COALESCE(p_dati->>'cliente_foto',''), 'base64'),
        decode(COALESCE(p_dati->>'cliente_carta_identita',''), 'base64'),
        p_dati->>'cliente_tipodoc_identita', p_dati->>'cliente_documento_numero',
        p_dati->>'cliente_documento_rilasciato_da',
        (p_dati->>'cliente_documento_rilasciato_data')::DATE,
        (p_dati->>'cliente_documento_rilasciato_scadenza')::DATE,
        p_dati->>'cliente_note', p_dati->>'cliente_intolleranza',
        p_dati->>'cliente_foto_mimetype', p_dati->>'cliente_foto_filename',
        p_dati->>'cliente_foto_charset', (p_dati->>'cliente_foto_upd_date')::DATE,
        p_dati->>'cliente_documento_mimetype', p_dati->>'cliente_documento_filename',
        p_dati->>'cliente_documento_chartset', (p_dati->>'cliente_documento_upd_date')::DATE,
        (p_dati->>'controparte_fk')::INTEGER,
        COALESCE(upper(btrim(p_dati->>'cliente_lingua')), 'IT'),
        COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE),
        -- data e fonte esistono per DIMOSTRARE il consenso: se c'e' il consenso e
        -- non sono state passate, si registrano comunque.
        CASE WHEN COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE)
             THEN COALESCE((p_dati->>'consenso_marketing_data')::TIMESTAMPTZ, now()) END,
        CASE WHEN COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE)
             THEN COALESCE(p_dati->>'consenso_marketing_fonte', 'NON_DICHIARATA') END
    ) RETURNING cliente_id INTO v_id;

    RETURN v_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Aggiornamento PARZIALE: si tocca solo cio' che il JSON nomina.
-- Chiave assente = campo invariato. Chiave presente a null = campo svuotato.
-- E' la differenza che permette al sito di aggiornare tre campi senza dover
-- rimandare indietro foto e documenti che non ha mai avuto.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_ana_clienti_update(
    p_cliente_id INTEGER, p_dati JSONB, p_conferme_accettate BOOLEAN DEFAULT FALSE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_righe INTEGER; v_completo JSONB;
BEGIN
    -- Per validare serve il quadro completo, non solo i campi che cambiano.
    SELECT to_jsonb(c) || p_dati INTO v_completo FROM ana_clienti c WHERE c.cliente_id = p_cliente_id;
    IF v_completo IS NULL THEN
        RAISE EXCEPTION 'Cliente % non trovato.', p_cliente_id;
    END IF;

    PERFORM fn_ana_clienti_guardia(v_completo, p_cliente_id, p_conferme_accettate);

    UPDATE ana_clienti c SET
        cliente_titolo_fk = CASE WHEN p_dati ? 'cliente_titolo_fk' THEN (p_dati->>'cliente_titolo_fk')::INTEGER ELSE c.cliente_titolo_fk END,
        cliente_cognome   = CASE WHEN p_dati ? 'cliente_cognome' THEN upper(btrim(p_dati->>'cliente_cognome')) ELSE c.cliente_cognome END,
        cliente_nome      = CASE WHEN p_dati ? 'cliente_nome' THEN upper(btrim(p_dati->>'cliente_nome')) ELSE c.cliente_nome END,
        cliente_comune_residenza_fk = CASE WHEN p_dati ? 'cliente_comune_residenza_fk' THEN (p_dati->>'cliente_comune_residenza_fk')::INTEGER ELSE c.cliente_comune_residenza_fk END,
        cliente_indirizzo_residenza = CASE WHEN p_dati ? 'cliente_indirizzo_residenza' THEN p_dati->>'cliente_indirizzo_residenza' ELSE c.cliente_indirizzo_residenza END,
        cliente_comune_nascita_fk   = CASE WHEN p_dati ? 'cliente_comune_nascita_fk' THEN (p_dati->>'cliente_comune_nascita_fk')::INTEGER ELSE c.cliente_comune_nascita_fk END,
        cliente_data_nascita        = CASE WHEN p_dati ? 'cliente_data_nascita' THEN (p_dati->>'cliente_data_nascita')::DATE ELSE c.cliente_data_nascita END,
        cliente_preftelint = CASE WHEN p_dati ? 'cliente_preftelint' THEN p_dati->>'cliente_preftelint' ELSE c.cliente_preftelint END,
        cliente_telefono   = CASE WHEN p_dati ? 'cliente_telefono' THEN p_dati->>'cliente_telefono' ELSE c.cliente_telefono END,
        cliente_email      = CASE WHEN p_dati ? 'cliente_email' THEN lower(btrim(p_dati->>'cliente_email')) ELSE c.cliente_email END,
        cliente_codicefiscale = CASE WHEN p_dati ? 'cliente_codicefiscale' THEN upper(btrim(p_dati->>'cliente_codicefiscale')) ELSE c.cliente_codicefiscale END,
        cliente_iban       = CASE WHEN p_dati ? 'cliente_iban' THEN upper(btrim(p_dati->>'cliente_iban')) ELSE c.cliente_iban END,
        cliente_foto       = CASE WHEN p_dati ? 'cliente_foto' THEN decode(COALESCE(p_dati->>'cliente_foto',''),'base64') ELSE c.cliente_foto END,
        cliente_carta_identita = CASE WHEN p_dati ? 'cliente_carta_identita' THEN decode(COALESCE(p_dati->>'cliente_carta_identita',''),'base64') ELSE c.cliente_carta_identita END,
        cliente_tipodoc_identita = CASE WHEN p_dati ? 'cliente_tipodoc_identita' THEN p_dati->>'cliente_tipodoc_identita' ELSE c.cliente_tipodoc_identita END,
        cliente_documento_numero = CASE WHEN p_dati ? 'cliente_documento_numero' THEN p_dati->>'cliente_documento_numero' ELSE c.cliente_documento_numero END,
        cliente_documento_rilasciato_da = CASE WHEN p_dati ? 'cliente_documento_rilasciato_da' THEN p_dati->>'cliente_documento_rilasciato_da' ELSE c.cliente_documento_rilasciato_da END,
        cliente_documento_rilasciato_data = CASE WHEN p_dati ? 'cliente_documento_rilasciato_data' THEN (p_dati->>'cliente_documento_rilasciato_data')::DATE ELSE c.cliente_documento_rilasciato_data END,
        cliente_documento_rilasciato_scadenza = CASE WHEN p_dati ? 'cliente_documento_rilasciato_scadenza' THEN (p_dati->>'cliente_documento_rilasciato_scadenza')::DATE ELSE c.cliente_documento_rilasciato_scadenza END,
        cliente_note = CASE WHEN p_dati ? 'cliente_note' THEN p_dati->>'cliente_note' ELSE c.cliente_note END,
        cliente_intolleranza = CASE WHEN p_dati ? 'cliente_intolleranza' THEN p_dati->>'cliente_intolleranza' ELSE c.cliente_intolleranza END,
        cliente_foto_mimetype = CASE WHEN p_dati ? 'cliente_foto_mimetype' THEN p_dati->>'cliente_foto_mimetype' ELSE c.cliente_foto_mimetype END,
        cliente_foto_filename = CASE WHEN p_dati ? 'cliente_foto_filename' THEN p_dati->>'cliente_foto_filename' ELSE c.cliente_foto_filename END,
        cliente_foto_charset  = CASE WHEN p_dati ? 'cliente_foto_charset' THEN p_dati->>'cliente_foto_charset' ELSE c.cliente_foto_charset END,
        cliente_foto_upd_date = CASE WHEN p_dati ? 'cliente_foto_upd_date' THEN (p_dati->>'cliente_foto_upd_date')::DATE ELSE c.cliente_foto_upd_date END,
        cliente_documento_mimetype = CASE WHEN p_dati ? 'cliente_documento_mimetype' THEN p_dati->>'cliente_documento_mimetype' ELSE c.cliente_documento_mimetype END,
        cliente_documento_filename = CASE WHEN p_dati ? 'cliente_documento_filename' THEN p_dati->>'cliente_documento_filename' ELSE c.cliente_documento_filename END,
        cliente_documento_chartset = CASE WHEN p_dati ? 'cliente_documento_chartset' THEN p_dati->>'cliente_documento_chartset' ELSE c.cliente_documento_chartset END,
        cliente_documento_upd_date = CASE WHEN p_dati ? 'cliente_documento_upd_date' THEN (p_dati->>'cliente_documento_upd_date')::DATE ELSE c.cliente_documento_upd_date END,
        controparte_fk = CASE WHEN p_dati ? 'controparte_fk' THEN (p_dati->>'controparte_fk')::INTEGER ELSE c.controparte_fk END,
        cliente_lingua = CASE WHEN p_dati ? 'cliente_lingua' THEN COALESCE(upper(btrim(p_dati->>'cliente_lingua')),'IT') ELSE c.cliente_lingua END,
        consenso_marketing = CASE WHEN p_dati ? 'consenso_marketing' THEN COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE) ELSE c.consenso_marketing END,
        -- Il consenso si "accende" con una data e una fonte; spegnendolo restano
        -- a memoria di quando c'era: cancellarle renderebbe indimostrabile il passato.
        consenso_marketing_data = CASE
            WHEN p_dati ? 'consenso_marketing' AND COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE)
                 AND NOT c.consenso_marketing
            THEN COALESCE((p_dati->>'consenso_marketing_data')::TIMESTAMPTZ, now())
            ELSE c.consenso_marketing_data END,
        consenso_marketing_fonte = CASE
            WHEN p_dati ? 'consenso_marketing' AND COALESCE((p_dati->>'consenso_marketing')::BOOLEAN, FALSE)
                 AND NOT c.consenso_marketing
            THEN COALESCE(p_dati->>'consenso_marketing_fonte', 'NON_DICHIARATA')
            ELSE c.consenso_marketing_fonte END
    WHERE c.cliente_id = p_cliente_id;

    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Cancellazione. L'azienda e' obbligatoria: e' la difesa dei silos.
-- I trigger trg_prevent_client_delete* restano al loro posto e bloccano se il
-- cliente ha viaggi o alloggi.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_ana_clienti_delete(
    p_cliente_id INTEGER, p_azienda_id INTEGER
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_righe INTEGER;
BEGIN
    DELETE FROM ana_clienti WHERE cliente_id = p_cliente_id AND azienda_fk = p_azienda_id;
    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

COMMENT ON FUNCTION fn_ana_clienti_valida(JSONB,INTEGER) IS
'Tutte le segnalazioni su un''anagrafica, con gravita'', senza scrivere. Serve al client per sapere PRIMA di salvare. Chiavi JSONB = nomi delle colonne.';
COMMENT ON FUNCTION fn_ana_clienti_insert(JSONB,BOOLEAN) IS
'CRUD unico (SqlScripts/550): unica scrittura di ana_clienti per gestionale e sito. Sostituisce ClienteRepository.InsertAsync, sp_ana_clienti_create e fn_wizard_insert_cliente.';
COMMENT ON FUNCTION fn_ana_clienti_update(INTEGER,JSONB,BOOLEAN) IS
'Aggiornamento PARZIALE: chiave assente = campo invariato, chiave presente a null = campo svuotato.';

COMMIT;
