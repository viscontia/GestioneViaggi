-- =============================================================================
-- 553 — Il mezzo e' obbligatorio se la tabella lo richiede
-- =============================================================================
-- ana_tipo_partecipante.tipo_partecipante_dati_mezzo_obb dichiara, per ogni
-- ruolo, se i dati del mezzo servono. La colonna esiste da sempre, la si puo'
-- spuntare dall'interfaccia... e non la legge NESSUNO. Cercandone gli usi si
-- trovano solo il dialogo che la modifica e la griglia che la mostra: e' una
-- regola scritta nei dati e applicata da nessuna parte.
--
-- Su PROD questo aveva lasciato 14 iscrizioni senza mezzo su ruoli che lo
-- richiedono. Sono acqua passata; da qui in avanti la regola vale.
--
-- ── Cosa vuol dire "dati del mezzo" ─────────────────────────────────────────
-- Lo dicono i dati: marca, modello e targa si valorizzano INSIEME. Su 611
-- iscrizioni come PILOTA MEZZO PROPRIO ne mancano rispettivamente 3, 5 e 4, e
-- sono in pratica le stesse righe. Anche il mezzo NOLEGGIATO li ha tutti e tre.
-- Quindi: tutti e tre, e la segnalazione dice quale manca.
--
-- ⚠️ La regola scatta all'inserimento E alla modifica. Le 14 iscrizioni storiche
--    incomplete non si potranno quindi modificare senza completare il mezzo: e'
--    una bonifica graduale, voluta.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Prima: la tabella dei ruoli deve dire la stessa cosa nei due ambienti.
-- Il committente ha corretto PROD il 2026-08-20 (GUIIDA IN SECONDA e PILOTA
-- ENDURO PROPRIO sono piloti a tutti gli effetti); qui si allinea il locale.
-- Su PROD e' un no-op.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE ana_tipo_partecipante SET tipo_partecipante_pilota = TRUE
WHERE tipo_partecipante_id IN (22, 62) AND tipo_partecipante_pilota IS DISTINCT FROM TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- La regola, nell'unico posto in cui vive.
-- ─────────────────────────────────────────────────────────────────────────────
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
    v_mezzo_ob BOOLEAN;
    v_ruolo    VARCHAR;
    v_email    VARCHAR;
    v_nome     TEXT;
    v_manca    TEXT[] := ARRAY[]::TEXT[];
BEGIN
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

    SELECT c.cliente_email, c.cliente_cognome || ' ' || c.cliente_nome INTO v_email, v_nome
    FROM ana_clienti c WHERE c.cliente_id = v_cliente;

    -- Chi guida deve essere raggiungibile: e' a lui che vanno convocazione,
    -- variazioni di programma e istruzioni.
    IF COALESCE(v_pilota, FALSE) AND btrim(COALESCE(v_email, '')) = '' THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PILOTA_SENZA_EMAIL'::VARCHAR,
               format('%s viene iscritto come pilota ma non ha un indirizzo email in anagrafica.',
                      COALESCE(v_nome, 'Il cliente'))::TEXT, v_cliente;
    END IF;

    -- Il mezzo, se il ruolo lo richiede. La segnalazione dice QUALE dato manca:
    -- "dati del mezzo mancanti" costringerebbe a indovinare.
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
                          -- "la marca, il modello e la targa" si legge; con tre virgole no.
                          regexp_replace(array_to_string(v_manca, ', '), ', ([^,]+)$', ' e \1'))::TEXT,
                   v_cliente;
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_mov_clienti_viaggi_valida(JSONB,BOOLEAN) IS
'Regole dell''iscrizione al viaggio (SqlScripts/551, 553): email obbligatoria per i PILOTI e dati del mezzo obbligatori quando ana_tipo_partecipante.tipo_partecipante_dati_mezzo_obb lo richiede. Entrambe dipendono dal RUOLO, che sta sull''iscrizione e non sulla persona.';

COMMIT;
