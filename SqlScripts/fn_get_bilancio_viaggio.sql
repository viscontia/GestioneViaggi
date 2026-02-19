-- Function: fn_get_bilancio_viaggio
-- Description: Retrieves economic data for Trip Balance Report (Bilancio di Viaggio).
--              calculating Revenues (Ciclo ATTIVO) and Costs (Ciclo PASSIVO) 
--              grouped by Category (Tipo Fornitore) and Trip.
-- Created: 2026-02-16
-- Check: Includes Net/Vat/Gross calculations with sign normalization and "Paid" status.

CREATE OR REPLACE FUNCTION fn_get_bilancio_viaggio(
    p_azienda_id INT,
    p_viaggio_id INT,           -- Specific Trip ID
    p_data_viaggio_id INT DEFAULT NULL, -- Optional specific Trip Date ID
    p_data_da DATE DEFAULT NULL,
    p_data_a DATE DEFAULT NULL
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
BEGIN
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

        -- Economic Values (Normalized)
        -- Netto: Use Imponibile if present, else Importo (for pre-IVA compatibility) -> FORCE ABS to rely on Sign
        (ABS(COALESCE(t.transazione_imponibile_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_netto_eur,
        
        (ABS(COALESCE(t.transazione_iva_eur, 0)) * tc.causale_segno)::NUMERIC as importo_iva_eur,

        -- Lordo: Use LordoEur if present, else Importo (pre-IVA) -> FORCE ABS
        (ABS(COALESCE(t.transazione_lordo_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_lordo_eur,

        -- Financial Status (Paid Amount)
        -- Sum of related PG/IN transactions
        (COALESCE((
            SELECT SUM(pg.transazione_importo) 
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
