-- =============================================
-- Stored Procedure: Registra Pagamento
-- Data Creazione: 2026-02-15
-- Autore: Claude Code
-- Descrizione: Registra un pagamento per una transazione DA_PAGARE o PARZIALMENTE_PAGATO.
--              Crea automaticamente una transazione PG (Pagamento) o IN (Incasso) collegata
--              e aggiorna lo stato della transazione originale.
-- =============================================

CREATE OR REPLACE FUNCTION sp_registra_pagamento(
    p_transazione_id INTEGER,
    p_importo_pagamento NUMERIC(10,2) DEFAULT NULL,
    p_data_pagamento DATE DEFAULT NULL,
    p_note_pagamento TEXT DEFAULT NULL,
    p_current_user VARCHAR(50) DEFAULT 'System'
)
RETURNS TABLE (
    pg_transazione_id INTEGER,
    nuovo_stato VARCHAR(20),
    importo_effettivo NUMERIC(10,2),
    error_message TEXT
) AS $$
DECLARE
    v_original_tx RECORD;
    v_original_causale RECORD;
    v_pg_causale RECORD;
    v_importo_nuovo_pagamento NUMERIC(10,2);
    v_importo_documento NUMERIC(10,2);
    v_totale_pagato_precedente NUMERIC(10,2);
    v_totale_pagato_complessivo NUMERIC(10,2);
    v_nuovo_stato VARCHAR(20);
    v_importo_effettivo NUMERIC(10,2);
    v_data_effettiva_pagamento DATE;
    v_pg_codice VARCHAR(10);
    v_pg_transazione_id INTEGER;
    v_valuta_base_id INTEGER;
BEGIN
    -- Step 0: Ottieni ID valuta base (EUR)
    SELECT valuta_id INTO v_valuta_base_id
    FROM ana_valute
    WHERE valuta_is_base = TRUE
    LIMIT 1;

    -- Step 1: Retrieve original transaction
    SELECT
        t.*,
        COALESCE(t.transazione_lordo_eur, t.transazione_importo) as importo_lordo_calcolato
    INTO v_original_tx
    FROM mov_transazioni t
    WHERE t.transazione_id = p_transazione_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            ('Transazione ' || p_transazione_id || ' non trovata')::TEXT;
        RETURN;
    END IF;

    -- Step 2: Validate stato
    IF v_original_tx.transazione_stato = 'PAGATO' THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            'La transazione è già stata pagata completamente'::TEXT;
        RETURN;
    END IF;

    IF v_original_tx.transazione_stato = 'ANNULLATO' THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            'Impossibile pagare una transazione annullata'::TEXT;
        RETURN;
    END IF;

    -- Step 3: Get causale metadata
    SELECT * INTO v_original_causale
    FROM ana_tipi_causali
    WHERE causale_id = v_original_tx.transazione_causale_tipo_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            'Causale originale non trovata'::TEXT;
        RETURN;
    END IF;

    -- Step 4: Find PG/IN causale (Pagamento for PASSIVO, Incasso for ATTIVO)
    v_pg_codice := CASE
        WHEN v_original_causale.causale_ciclo = 'ATTIVO' THEN 'IN'
        ELSE 'PG'
    END;

    SELECT * INTO v_pg_causale
    FROM ana_tipi_causali
    WHERE azienda_fk = v_original_tx.transazione_azienda_id
      AND causale_codice = v_pg_codice
      AND is_active = TRUE
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            ('Causale ''' || v_pg_codice || ''' non trovata per questa azienda. Creare prima la causale di pagamento.')::TEXT;
        RETURN;
    END IF;

    -- Step 5: Calculate payment amount and check existing payments
    v_importo_documento := v_original_tx.importo_lordo_calcolato;
    v_importo_nuovo_pagamento := COALESCE(p_importo_pagamento, v_importo_documento);

    -- Step 5a: Somma tutti i pagamenti PG/IN già effettuati per questa fattura
    -- Nota: I pagamenti PG/IN sono sempre in EUR (transazione_importo è già in EUR)
    SELECT COALESCE(SUM(ABS(transazione_importo)), 0)
    INTO v_totale_pagato_precedente
    FROM mov_transazioni
    WHERE transazione_fattura_fk = p_transazione_id
      AND transazione_stato = 'PAGATO';

    -- Step 5b: Calcola totale complessivo dopo questo pagamento
    v_totale_pagato_complessivo := v_totale_pagato_precedente + v_importo_nuovo_pagamento;

    -- Step 5c: Verifica che non si superi l'importo del documento
    IF v_totale_pagato_complessivo > v_importo_documento THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            ('Impossibile registrare il pagamento: totale pagamenti (' ||
             ROUND(v_totale_pagato_complessivo, 2)::TEXT || ' EUR) supererebbe l''importo del documento (' ||
             ROUND(v_importo_documento, 2)::TEXT || ' EUR). Già pagati: ' ||
             ROUND(v_totale_pagato_precedente, 2)::TEXT || ' EUR. Residuo disponibile: ' ||
             ROUND(v_importo_documento - v_totale_pagato_precedente, 2)::TEXT || ' EUR.')::TEXT;
        RETURN;
    END IF;

    IF v_importo_nuovo_pagamento <= 0 THEN
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            'L''importo del pagamento deve essere maggiore di zero'::TEXT;
        RETURN;
    END IF;

    -- Step 6: Determine new stato based on TOTAL paid
    v_importo_effettivo := v_importo_nuovo_pagamento;

    IF v_totale_pagato_complessivo >= v_importo_documento THEN
        v_nuovo_stato := 'PAGATO';
        -- Se il totale supererebbe, cap l'importo corrente
        IF v_totale_pagato_complessivo > v_importo_documento THEN
            v_importo_effettivo := v_importo_documento - v_totale_pagato_precedente;
        END IF;
    ELSIF v_totale_pagato_complessivo > 0 THEN
        v_nuovo_stato := 'PARZIALMENTE_PAGATO';
    ELSE
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            'Errore nel calcolo dello stato'::TEXT;
        RETURN;
    END IF;

    v_data_effettiva_pagamento := COALESCE(p_data_pagamento, CURRENT_DATE);

    -- Step 7: Create PG/IN transaction (no explicit transaction needed - atomic by default)

    -- Insert PG/IN transaction
    INSERT INTO mov_transazioni (
        transazione_azienda_id,
        transazione_viaggio_id,
        transazione_data_viaggio_id,
        transazione_controparte_id,
        transazione_causale_tipo_id,
        transazione_tipo_movimento,
        transazione_importo,
        transazione_valuta_id,
        transazione_data,
        transazione_data_pagamento,
        transazione_stato,
        transazione_causale,
        transazione_note,
        transazione_fattura_fk,
        created_at,
        created_by
    ) VALUES (
        v_original_tx.transazione_azienda_id,
        v_original_tx.transazione_viaggio_id,
        v_original_tx.transazione_data_viaggio_id,
        v_original_tx.transazione_controparte_id,
        v_pg_causale.causale_id,
        CASE
            WHEN v_original_causale.causale_ciclo = 'ATTIVO' THEN 'ENTRATA'
            ELSE 'USCITA'
        END,
        v_importo_effettivo,
        v_valuta_base_id, -- Always in EUR for payments
        v_data_effettiva_pagamento,
        v_data_effettiva_pagamento,
        'PAGATO',
        'PAGAMENTO ' ||
        CASE WHEN v_nuovo_stato = 'PARZIALMENTE_PAGATO' THEN 'PARZIALE' ELSE 'TOTALE' END ||
        ' ' ||
        CASE
            WHEN v_original_tx.transazione_numero_documento IS NOT NULL
            THEN 'FATTURA ' || v_original_tx.transazione_numero_documento
            ELSE 'TRANSAZIONE #' || v_original_tx.transazione_id
        END,
        COALESCE(p_note_pagamento, 'Pagamento automatico da transazione #' || v_original_tx.transazione_id),
        p_transazione_id,
        NOW(),
        p_current_user
    ) RETURNING transazione_id INTO v_pg_transazione_id;

    -- Update original transaction stato and data_pagamento
    UPDATE mov_transazioni
    SET transazione_stato = v_nuovo_stato,
        transazione_data_pagamento = CASE
            WHEN v_nuovo_stato = 'PAGATO' THEN v_data_effettiva_pagamento
            ELSE NULL
        END,
        updated_at = NOW(),
        updated_by = p_current_user
    WHERE transazione_id = p_transazione_id;

    -- Return success result
    RETURN QUERY SELECT
        v_pg_transazione_id,
        v_nuovo_stato,
        v_importo_effettivo,
        NULL::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        -- Return error
        RETURN QUERY SELECT
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::NUMERIC(10,2),
            ('Errore durante registrazione pagamento: ' || SQLERRM)::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION sp_registra_pagamento(INTEGER, NUMERIC, DATE, TEXT, VARCHAR) TO app_superadmin;
GRANT EXECUTE ON FUNCTION sp_registra_pagamento(INTEGER, NUMERIC, DATE, TEXT, VARCHAR) TO app_azienda_user;
GRANT EXECUTE ON FUNCTION sp_registra_pagamento(INTEGER, NUMERIC, DATE, TEXT, VARCHAR) TO app_azienda_admin;
GRANT EXECUTE ON FUNCTION sp_registra_pagamento(INTEGER, NUMERIC, DATE, TEXT, VARCHAR) TO app_tenant_user;
GRANT EXECUTE ON FUNCTION sp_registra_pagamento(INTEGER, NUMERIC, DATE, TEXT, VARCHAR) TO app_tenant_admin;

-- Comments
COMMENT ON FUNCTION sp_registra_pagamento IS 'Registra un pagamento immediato per una transazione DA_PAGARE o PARZIALMENTE_PAGATO. Crea automaticamente una transazione PG (Pagamento) o IN (Incasso) collegata e aggiorna lo stato.';
