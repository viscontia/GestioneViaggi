-- Function: fn_get_bilancio_viaggio
-- Description: Retrieves economic data for Trip Balance Report (Bilancio di Viaggio).
--              calculating Revenues (Ciclo ATTIVO) and Costs (Ciclo PASSIVO) 
--              grouped by Category (Tipo Fornitore) and Trip, converting to Valuta Target
-- Created: 2026-02-16
-- Updated: 2026-02-20 (Added Currency Conversion)

CREATE OR REPLACE FUNCTION fn_get_bilancio_viaggio(
    p_azienda_id INT,
    p_viaggio_id INT,           -- Specific Trip ID
    p_data_viaggio_id INT DEFAULT NULL, -- Optional specific Trip Date ID
    p_data_da DATE DEFAULT NULL,
    p_data_a DATE DEFAULT NULL,
    p_valuta_target_id INT DEFAULT NULL
)
RETURNS TABLE (
    -- Trip Info
    viaggio_id INT,
    viaggio_descrizione TEXT,
    viaggio_data_inizio DATE,
    viaggio_data_fine DATE,
    viaggio_numero_partecipanti INT,
    viaggio_numero_mezzi INT,
    
    -- Transaction Info
    transazione_id INT,
    data_documento DATE,
    data_registrazione DATE,
    numero_documento VARCHAR,
    transazione_descrizione TEXT, -- Note or Causale Description
    
    -- Counterparty Info
    controparte_ragione_sociale VARCHAR,
    categoria_nome VARCHAR,       -- "Vendite" (Revenue) or Tipo Fornitore (Cost)
    categoria_tipo VARCHAR,       -- "RICAVO" or "COSTO"
    
    -- Economic Values (Normalized with Sign)
    importo_netto_eur NUMERIC, -- Imponibile * Segno
    importo_iva_eur NUMERIC,   -- IVA * Segno
    importo_lordo_eur NUMERIC, -- Lordo * Segno
    
    -- Financial Status
    importo_pagato_eur NUMERIC, -- Amount actually paid/collected
    stato_pagamento VARCHAR     -- PAGATO, PARZIALMENTE_PAGATO, DA_PAGARE
) AS $$
DECLARE
    v_eur_id INT;
BEGIN
    SELECT valuta_id INTO v_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    
    IF p_valuta_target_id IS NULL THEN
        p_valuta_target_id := v_eur_id;
    END IF;

    RETURN QUERY
    SELECT 
        v.viaggio_id,
        (v.viaggio_descrizione_breve)::TEXT as viaggio_descrizione,
        -- Get min/max dates from ana_date_viaggi if specific date not selected, else use specific date
        CASE 
            WHEN p_data_viaggio_id IS NOT NULL THEN (SELECT data_viaggio_data_inizio FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id)
            ELSE (SELECT MIN(data_viaggio_data_inizio) FROM ana_date_viaggi WHERE viaggio_id_fk = v.viaggio_id)
        END as viaggio_data_inizio,
        
        CASE 
            WHEN p_data_viaggio_id IS NOT NULL THEN (SELECT data_viaggio_data_fine FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id)
            ELSE (SELECT MAX(data_viaggio_data_fine) FROM ana_date_viaggi WHERE viaggio_id_fk = v.viaggio_id)
        END as viaggio_data_fine,
        
        -- Participants: Count all people (records in mov_clienti_viaggi)
        COALESCE((
            SELECT COUNT(mcv.cliente_id_fk)::INT
            FROM ana_date_viaggi d
            JOIN mov_clienti_viaggi mcv ON mcv.data_viaggio_id_fk = d.data_viaggio_id
            WHERE d.viaggio_id_fk = v.viaggio_id
              AND (p_data_viaggio_id IS NULL OR d.data_viaggio_id = p_data_viaggio_id)
        ), 0) as viaggio_numero_partecipanti,

        -- Vehicles/Crews: Count distinct grouping keys (Pilot ID or Own ID if Pilot)
        COALESCE((
            SELECT COUNT(DISTINCT 
                CASE 
                    WHEN mcv.cliente_pilota_id_fk IS NOT NULL AND mcv.cliente_pilota_id_fk > 0 THEN mcv.cliente_pilota_id_fk 
                    WHEN tp.tipo_partecipante_pilota = true THEN mcv.cliente_id_fk 
                    ELSE NULL 
                END
            )::INT
            FROM ana_date_viaggi d
            JOIN mov_clienti_viaggi mcv ON mcv.data_viaggio_id_fk = d.data_viaggio_id
            JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
            WHERE d.viaggio_id_fk = v.viaggio_id
              AND (p_data_viaggio_id IS NULL OR d.data_viaggio_id = p_data_viaggio_id)
        ), 0) as viaggio_numero_mezzi,

        t.transazione_id,
        COALESCE(t.transazione_data_documento, t.transazione_data) as data_documento,
        t.transazione_data as data_registrazione,
        COALESCE(t.transazione_numero_documento, '-')::VARCHAR as numero_documento,
        COALESCE(t.transazione_note, tc.causale_descrizione)::TEXT as transazione_descrizione,

        c.ragione_sociale as controparte_ragione_sociale,

        -- Category Logic
        CASE 
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'VENDITE'::VARCHAR
            ELSE COALESCE(UPPER(tf.descrizione), 'ALTRO/VARIE')::VARCHAR
        END as categoria_nome,

        CASE 
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'RICAVO'::VARCHAR
            ELSE 'COSTO'::VARCHAR
        END as categoria_tipo,

        -- Economic Values (Normalized & Converted)
        ((ABS(COALESCE(t.transazione_imponibile_eur, t.transazione_importo)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_netto_eur,
        ((ABS(COALESCE(t.transazione_iva_eur, 0)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_iva_eur,
        ((ABS(COALESCE(t.transazione_lordo_eur, t.transazione_importo)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_lordo_eur,

        -- Financial Status (Paid Amount)
        (COALESCE((
            SELECT SUM(pg.transazione_importo * COALESCE(fn_get_tasso_cambio(pg.transazione_valuta_id, p_valuta_target_id, pg.transazione_data), 1)) 
            FROM mov_transazioni pg 
            WHERE pg.transazione_fattura_fk = t.transazione_id 
              AND pg.transazione_stato != 'ANNULLATO'
        ), 0))::NUMERIC as importo_pagato_eur,

        t.transazione_stato::VARCHAR as stato_pagamento

    FROM mov_transazioni t
    JOIN ana_viaggi v ON t.transazione_viaggio_id = v.viaggio_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id

    WHERE t.transazione_azienda_id = p_azienda_id
      AND t.transazione_viaggio_id = p_viaggio_id
      AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
      AND t.transazione_stato != 'ANNULLATO'
      AND tc.causale_is_documento = TRUE -- Only invoices/notes, exclude payments from main list
      AND (p_data_da IS NULL OR t.transazione_data >= p_data_da)
      AND (p_data_a IS NULL OR t.transazione_data <= p_data_a)
    
    ORDER BY 
        v.viaggio_id, -- Group by trip
        tc.causale_ciclo DESC, -- Revenue (ATTIVO) first, then Cost (PASSIVO)
        categoria_nome ASC, -- Alphabetical category
        t.transazione_data ASC; -- Chronological
END;
$$ LANGUAGE plpgsql;

-- Function: fn_get_bilancio_annuale_viaggi
-- Description: Retrieves economic data for Annual Trip Balance Report (Bilancio Annuale Viaggi).
--              calculating Revenues and Costs grouped by Category and Trip Date for a specific Year.
-- Created: 2026-02-20
-- Updated: 2026-02-20 (Added Currency Conversion)

CREATE OR REPLACE FUNCTION fn_get_bilancio_annuale_viaggi(
    p_azienda_id INT,
    p_anno INT,
    p_valuta_target_id INT DEFAULT NULL
)
RETURNS TABLE (
    -- Trip Info (Testata)
    viaggio_id INT,
    viaggio_descrizione TEXT,
    
    -- Trip Date Info (Riga)
    data_viaggio_id INT,
    data_viaggio_data_inizio DATE,
    data_viaggio_data_fine DATE,
    data_viaggio_numero_partecipanti INT,
    data_viaggio_numero_mezzi INT,
    
    -- Transaction Info
    transazione_id INT,
    data_documento DATE,
    data_registrazione DATE,
    numero_documento VARCHAR,
    transazione_descrizione TEXT,
    
    -- Counterparty Info
    controparte_ragione_sociale VARCHAR,
    categoria_nome VARCHAR,
    categoria_tipo VARCHAR,
    
    -- Economic Values (Normalized with Sign)
    importo_netto_eur NUMERIC,
    importo_iva_eur NUMERIC,
    importo_lordo_eur NUMERIC,
    
    -- Financial Status
    importo_pagato_eur NUMERIC,
    stato_pagamento VARCHAR
) AS $$
DECLARE
    v_eur_id INT;
BEGIN
    SELECT valuta_id INTO v_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    
    IF p_valuta_target_id IS NULL THEN
        p_valuta_target_id := v_eur_id;
    END IF;

    RETURN QUERY
    SELECT 
        v.viaggio_id,
        (v.viaggio_descrizione_breve)::TEXT as viaggio_descrizione,
        
        dv.data_viaggio_id,
        dv.data_viaggio_data_inizio,
        dv.data_viaggio_data_fine,
        
        -- Participants for specific Date
        COALESCE((
            SELECT COUNT(mcv.cliente_id_fk)::INT
            FROM mov_clienti_viaggi mcv
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) as data_viaggio_numero_partecipanti,

        -- Vehicles/Crews for specific Date
        COALESCE((
            SELECT COUNT(DISTINCT 
                CASE 
                    WHEN mcv.cliente_pilota_id_fk IS NOT NULL AND mcv.cliente_pilota_id_fk > 0 THEN mcv.cliente_pilota_id_fk 
                    WHEN tp.tipo_partecipante_pilota = true THEN mcv.cliente_id_fk 
                    ELSE NULL 
                END
            )::INT
            FROM mov_clienti_viaggi mcv
            JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) as data_viaggio_numero_mezzi,

        t.transazione_id,
        COALESCE(t.transazione_data_documento, t.transazione_data) as data_documento,
        t.transazione_data as data_registrazione,
        COALESCE(t.transazione_numero_documento, '-')::VARCHAR as numero_documento,
        COALESCE(t.transazione_note, tc.causale_descrizione)::TEXT as transazione_descrizione,

        c.ragione_sociale as controparte_ragione_sociale,

        -- Category Logic
        CASE 
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'VENDITE'::VARCHAR
            ELSE COALESCE(UPPER(tf.descrizione), 'ALTRO/VARIE')::VARCHAR
        END as categoria_nome,

        CASE 
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'RICAVO'::VARCHAR
            ELSE 'COSTO'::VARCHAR
        END as categoria_tipo,

        -- Economic Values (Normalized & Converted)
        ((ABS(COALESCE(t.transazione_imponibile_eur, t.transazione_importo)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_netto_eur,
        ((ABS(COALESCE(t.transazione_iva_eur, 0)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_iva_eur,
        ((ABS(COALESCE(t.transazione_lordo_eur, t.transazione_importo)) * tc.causale_segno) * COALESCE(fn_get_tasso_cambio(t.transazione_valuta_id, p_valuta_target_id, t.transazione_data), 1))::NUMERIC as importo_lordo_eur,

        -- Financial Status (Paid Amount)
        (COALESCE((
            SELECT SUM(pg.transazione_importo * COALESCE(fn_get_tasso_cambio(pg.transazione_valuta_id, p_valuta_target_id, pg.transazione_data), 1)) 
            FROM mov_transazioni pg 
            WHERE pg.transazione_fattura_fk = t.transazione_id 
              AND pg.transazione_stato != 'ANNULLATO'
        ), 0))::NUMERIC as importo_pagato_eur,

        t.transazione_stato::VARCHAR as stato_pagamento

    FROM mov_transazioni t
    JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    JOIN ana_viaggi v ON dv.viaggio_id_fk = v.viaggio_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id

    WHERE t.transazione_azienda_id = p_azienda_id
      AND t.transazione_stato != 'ANNULLATO'
      AND tc.causale_is_documento = TRUE
      AND EXTRACT(YEAR FROM dv.data_viaggio_data_inizio) = p_anno
      
      -- Sicurezza aggiuntiva: verifica che non sia una partenza vuota (solo fatture legate a data_viaggio)
      AND EXISTS (
          SELECT 1 
          FROM mov_transazioni tx 
          JOIN ana_tipi_causali tcx ON tx.transazione_causale_tipo_id = tcx.causale_id
          WHERE tx.transazione_data_viaggio_id = dv.data_viaggio_id
            AND tx.transazione_stato != 'ANNULLATO'
            AND tcx.causale_is_documento = TRUE
      )
    
    ORDER BY 
        dv.data_viaggio_data_inizio ASC, -- Chronological start date of the trip
        v.viaggio_id, -- Keep same trip together if multiple start dates
        dv.data_viaggio_id,
        tc.causale_ciclo DESC, -- Revenue first, then Cost
        categoria_nome ASC,
        t.transazione_data ASC;
END;
$$ LANGUAGE plpgsql;
