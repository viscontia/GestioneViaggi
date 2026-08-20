-- =============================================================================
-- 551 — Fase 4: l'iscrizione al viaggio, con la regola che non c'era
-- =============================================================================
-- MovClientiViaggiService non ha MAI avuto una validazione: solo traduzione in
-- italiano degli errori del database. Si poteva iscrivere come pilota una persona
-- senza email e nulla lo impediva — su PROD e' successo 9 volte.
--
-- E i due percorsi di scrittura si comportavano diversamente sulla stessa tabella:
--   · sp_mov_clienti_viaggi_create (MAUI) controlla che il cliente non sia gia'
--     iscritto e lo dice in italiano;
--   · fn_wizard_insert_prenotazione (sito) inserisce e basta.
-- Due porte sulla stessa stanza, con serrature diverse.
--
-- ── Perche' la regola dell'email sta QUI e non su ana_clienti ────────────────
-- L'obbligo dipende dal RUOLO — pilota si', accompagnatore no — e il ruolo non
-- e' una proprieta' della persona: sta sull'iscrizione. Su PROD 7 clienti su 687
-- sono pilota in un viaggio e passeggero in un altro. Un campo "e' un pilota"
-- sull'anagrafica sarebbe giusto per il 99% e falso in silenzio su quei sette.
-- Qui il ruolo si conosce con certezza, e la regola prende anche loro.
--
-- Chiavi JSONB = nomi delle colonne, come per il CRUD dei clienti (550).
-- =============================================================================

BEGIN;

-- Il tipo restituito guadagna il riferimento: serve un DROP.
DROP FUNCTION IF EXISTS fn_mov_clienti_viaggi_valida(JSONB,BOOLEAN);

CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_valida(
    p_dati     JSONB,
    p_modifica BOOLEAN DEFAULT FALSE
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT, riferimento INTEGER)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_viaggio  INTEGER := (p_dati->>'viaggio_id_fk')::INTEGER;
    v_data     INTEGER := (p_dati->>'data_viaggio_id_fk')::INTEGER;
    v_cliente  INTEGER := (p_dati->>'cliente_id_fk')::INTEGER;
    v_tipo     INTEGER := (p_dati->>'tipo_partecipante_id_fk')::INTEGER;
    v_pilota   BOOLEAN;
    v_email    VARCHAR;
    v_nome     TEXT;
BEGIN
    -- 1. Gia' iscritto: era il solo controllo esistente, e solo da un lato.
    IF NOT p_modifica AND EXISTS (
        SELECT 1 FROM mov_clienti_viaggi
        WHERE viaggio_id_fk = v_viaggio AND data_viaggio_id_fk = v_data
          AND cliente_id_fk = v_cliente) THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'GIA_ISCRITTO'::VARCHAR,
               'Questo cliente è già iscritto a questo viaggio in questa data.'::TEXT, v_cliente;
    END IF;

    SELECT tp.tipo_partecipante_pilota INTO v_pilota
    FROM ana_tipo_partecipante tp WHERE tp.tipo_partecipante_id = v_tipo;

    SELECT c.cliente_email, c.cliente_cognome || ' ' || c.cliente_nome INTO v_email, v_nome
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    -- 2. Chi guida deve essere raggiungibile: e' a lui che vanno convocazione,
    --    variazioni di programma e istruzioni. Per l'accompagnatore l'email resta
    --    facoltativa (decisione del committente, 2026-08-20).
    IF COALESCE(v_pilota, FALSE) AND btrim(COALESCE(v_email, '')) = '' THEN
        -- Il riferimento porta il cliente_id: serve a chi chiama per aprire la
        -- richiesta dell'email SULLA PERSONA GIUSTA, invece di lasciare l'operatore
        -- a cercarla in anagrafica. L'email si scrive poi con
        -- fn_ana_clienti_update(id, '{"cliente_email":"..."}'), che la valida.
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_EMAIL'::VARCHAR,
               format('%s viene iscritto come pilota ma non ha un indirizzo email in anagrafica.',
                      COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_guardia(
    p_dati JSONB, p_modifica BOOLEAN, p_conferme_accettate BOOLEAN
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_msg TEXT;
BEGIN
    SELECT string_agg(messaggio, E'\n') INTO v_msg
    FROM fn_mov_clienti_viaggi_valida(p_dati, p_modifica)
    WHERE gravita = 'ERRORE' OR (gravita = 'CONFERMA' AND NOT COALESCE(p_conferme_accettate, FALSE));

    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION '%', v_msg;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_insert(
    p_dati JSONB, p_conferme_accettate BOOLEAN DEFAULT FALSE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_righe INTEGER;
BEGIN
    PERFORM fn_mov_clienti_viaggi_guardia(p_dati, FALSE, p_conferme_accettate);

    INSERT INTO mov_clienti_viaggi (
        viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk, tipo_partecipante_id_fk,
        cliente_pilota_id_fk, ana_mezzi_id_fk, mezzo_modello_id_fk,
        mov_cliente_viaggio_scontoval_totale, mov_cliente_viaggio_targa_mezzo,
        mov_cliente_viaggio_cane_sino, mov_cliente_viaggio_note
    ) VALUES (
        (p_dati->>'viaggio_id_fk')::INTEGER, (p_dati->>'data_viaggio_id_fk')::INTEGER,
        (p_dati->>'cliente_id_fk')::INTEGER, (p_dati->>'tipo_partecipante_id_fk')::INTEGER,
        (p_dati->>'cliente_pilota_id_fk')::INTEGER, (p_dati->>'ana_mezzi_id_fk')::INTEGER,
        (p_dati->>'mezzo_modello_id_fk')::INTEGER,
        (p_dati->>'mov_cliente_viaggio_scontoval_totale')::NUMERIC,
        upper(btrim(p_dati->>'mov_cliente_viaggio_targa_mezzo')),
        COALESCE(p_dati->>'mov_cliente_viaggio_cane_sino', 'N'),
        p_dati->>'mov_cliente_viaggio_note'
    );

    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

-- Aggiornamento parziale, come per i clienti: si tocca solo cio' che il JSON
-- nomina. La chiave dell'iscrizione (viaggio + data + cliente) non si cambia:
-- spostare qualcuno su un altro viaggio e' una cancellazione e un inserimento.
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_update(
    p_dati JSONB, p_conferme_accettate BOOLEAN DEFAULT FALSE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_righe INTEGER; v_completo JSONB;
BEGIN
    SELECT to_jsonb(m) || p_dati INTO v_completo
    FROM mov_clienti_viaggi m
    WHERE m.viaggio_id_fk = (p_dati->>'viaggio_id_fk')::INTEGER
      AND m.data_viaggio_id_fk = (p_dati->>'data_viaggio_id_fk')::INTEGER
      AND m.cliente_id_fk = (p_dati->>'cliente_id_fk')::INTEGER;

    IF v_completo IS NULL THEN
        RAISE EXCEPTION 'Iscrizione non trovata.';
    END IF;

    PERFORM fn_mov_clienti_viaggi_guardia(v_completo, TRUE, p_conferme_accettate);

    UPDATE mov_clienti_viaggi m SET
        tipo_partecipante_id_fk = CASE WHEN p_dati ? 'tipo_partecipante_id_fk' THEN (p_dati->>'tipo_partecipante_id_fk')::INTEGER ELSE m.tipo_partecipante_id_fk END,
        cliente_pilota_id_fk    = CASE WHEN p_dati ? 'cliente_pilota_id_fk' THEN (p_dati->>'cliente_pilota_id_fk')::INTEGER ELSE m.cliente_pilota_id_fk END,
        ana_mezzi_id_fk         = CASE WHEN p_dati ? 'ana_mezzi_id_fk' THEN (p_dati->>'ana_mezzi_id_fk')::INTEGER ELSE m.ana_mezzi_id_fk END,
        mezzo_modello_id_fk     = CASE WHEN p_dati ? 'mezzo_modello_id_fk' THEN (p_dati->>'mezzo_modello_id_fk')::INTEGER ELSE m.mezzo_modello_id_fk END,
        mov_cliente_viaggio_scontoval_totale = CASE WHEN p_dati ? 'mov_cliente_viaggio_scontoval_totale' THEN (p_dati->>'mov_cliente_viaggio_scontoval_totale')::NUMERIC ELSE m.mov_cliente_viaggio_scontoval_totale END,
        mov_cliente_viaggio_targa_mezzo = CASE WHEN p_dati ? 'mov_cliente_viaggio_targa_mezzo' THEN upper(btrim(p_dati->>'mov_cliente_viaggio_targa_mezzo')) ELSE m.mov_cliente_viaggio_targa_mezzo END,
        mov_cliente_viaggio_cane_sino = CASE WHEN p_dati ? 'mov_cliente_viaggio_cane_sino' THEN p_dati->>'mov_cliente_viaggio_cane_sino' ELSE m.mov_cliente_viaggio_cane_sino END,
        mov_cliente_viaggio_note = CASE WHEN p_dati ? 'mov_cliente_viaggio_note' THEN p_dati->>'mov_cliente_viaggio_note' ELSE m.mov_cliente_viaggio_note END
    WHERE m.viaggio_id_fk = (p_dati->>'viaggio_id_fk')::INTEGER
      AND m.data_viaggio_id_fk = (p_dati->>'data_viaggio_id_fk')::INTEGER
      AND m.cliente_id_fk = (p_dati->>'cliente_id_fk')::INTEGER;

    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_delete(
    p_viaggio_id INTEGER, p_data_viaggio_id INTEGER, p_cliente_id INTEGER
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_righe INTEGER;
BEGIN
    DELETE FROM mov_clienti_viaggi
    WHERE viaggio_id_fk = p_viaggio_id AND data_viaggio_id_fk = p_data_viaggio_id
      AND cliente_id_fk = p_cliente_id;
    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

COMMENT ON FUNCTION fn_mov_clienti_viaggi_valida(JSONB,BOOLEAN) IS
'Regole dell''iscrizione al viaggio (SqlScripts/551). Qui vive l''obbligo dell''email per i PILOTI: dipende dal ruolo, e il ruolo sta sull''iscrizione, non sulla persona.';
COMMENT ON FUNCTION fn_mov_clienti_viaggi_insert(JSONB,BOOLEAN) IS
'Iscrizione al viaggio, unica per gestionale e sito. Sostituira'' sp_mov_clienti_viaggi_create e fn_wizard_insert_prenotazione.';

COMMIT;
