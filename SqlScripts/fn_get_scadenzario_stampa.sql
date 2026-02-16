-- ============================================================================
-- fn_get_scadenzario_stampa
-- Restituisce i dati per lo scadenzario (transazioni non pagate o parzialmente pagate).
-- Calcola il residuo e l'urgenza.
-- ============================================================================

-- Drop pre-existing function to allow return type changes
DROP FUNCTION IF EXISTS fn_get_scadenzario_stampa(integer,integer,character varying,character varying,date,date,integer,boolean,boolean,character varying);

CREATE OR REPLACE FUNCTION fn_get_scadenzario_stampa(
    p_azienda_id INTEGER DEFAULT NULL,
    p_controparte_id INTEGER DEFAULT NULL,
    p_causale_ciclo VARCHAR DEFAULT NULL, -- 'ATTIVO' | 'PASSIVO'
    p_urgenza VARCHAR DEFAULT NULL,       -- 'SCADUTO' | 'URGENTE' | 'IN_SCADENZA' | 'NORMALE'
    p_data_scadenza_da DATE DEFAULT NULL,
    p_data_scadenza_a DATE DEFAULT NULL,
    p_viaggio_id INTEGER DEFAULT NULL,
    p_solo_con_viaggio BOOLEAN DEFAULT FALSE,
    p_solo_senza_viaggio BOOLEAN DEFAULT FALSE,
    p_raggruppamento VARCHAR DEFAULT 'URGENZA' -- 'URGENZA' | 'MESE' | 'CONTROPARTE'
)
RETURNS TABLE (
    GruppoChiave TEXT,
    GruppoDisplay TEXT,
    GruppoOrdine INTEGER,
    
    TransazioneId INTEGER,
    DataScadenza DATE,
    DataDocumento DATE,
    NumeroDocumento VARCHAR,
    
    ControparteRagioneSociale VARCHAR,
    CausaleCiclo VARCHAR,
    CausaleDescrizione VARCHAR,
    
    ImportoOriginale NUMERIC,
    Residuo NUMERIC,
    ValutaCodiceIso VARCHAR,
    
    GiorniAScadenza INTEGER,
    Urgenza VARCHAR,
    
    Stato VARCHAR,
    ViaggioDescrizione VARCHAR,
    Note TEXT
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_oggi DATE := CURRENT_DATE;
BEGIN
    RETURN QUERY
    WITH ScadenzeBase AS (
        SELECT 
            t.transazione_id,
            t.transazione_data_scadenza,
            t.transazione_data_documento,
            t.transazione_numero_documento,
            c.ragione_sociale as controparte_ragione_sociale,
            ca.causale_ciclo,
            ca.causale_descrizione,
            
            -- Usiamo EUR come base standard per il report
            COALESCE(t.transazione_lordo_eur, t.transazione_importo) as importo_totale,
            
            -- Calcolo Residuo: Importo - Pagamenti
            (
                COALESCE(t.transazione_lordo_eur, t.transazione_importo) - 
                COALESCE((
                    SELECT SUM(ABS(p.transazione_lordo_eur))
                    FROM mov_transazioni p
                    WHERE p.transazione_fattura_fk = t.transazione_id
                      AND p.transazione_stato = 'PAGATO'
                ), 0)
            ) as residuo,
            
            'EUR'::VARCHAR as valuta_codice_iso,
            
            -- Calcolo giorni a scadenza
            (t.transazione_data_scadenza - v_oggi)::INTEGER as giorni_scadenza,
            
            t.transazione_stato,
            vg.viaggio_descrizione_breve as viaggio_descrizione,
            t.transazione_note
            
        FROM mov_transazioni t
        LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
        INNER JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
        LEFT JOIN ana_viaggi vg ON t.transazione_viaggio_id = vg.viaggio_id
        
        WHERE 
            t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
            AND (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
            AND (p_controparte_id IS NULL OR t.transazione_controparte_id = p_controparte_id)
            AND (p_causale_ciclo IS NULL OR ca.causale_ciclo::VARCHAR = p_causale_ciclo)
            AND (p_viaggio_id IS NULL OR t.transazione_viaggio_id = p_viaggio_id)
            AND (NOT p_solo_con_viaggio OR t.transazione_viaggio_id IS NOT NULL)
            AND (NOT p_solo_senza_viaggio OR t.transazione_viaggio_id IS NULL)
            AND (p_data_scadenza_da IS NULL OR t.transazione_data_scadenza >= p_data_scadenza_da)
            AND (p_data_scadenza_a IS NULL OR t.transazione_data_scadenza <= p_data_scadenza_a)
    ),
    ScadenzeConUrgenza AS (
        SELECT 
            *,
            CASE 
                WHEN giorni_scadenza < 0 THEN 'SCADUTO'
                WHEN giorni_scadenza <= 7 THEN 'URGENTE'
                WHEN giorni_scadenza <= 30 THEN 'IN_SCADENZA'
                ELSE 'NORMALE'
            END as urgenza_calcolata
        FROM ScadenzeBase
    )
    SELECT 
        -- Gruppo Chiave
        CASE 
            WHEN p_raggruppamento = 'URGENZA' THEN SCU.urgenza_calcolata
            WHEN p_raggruppamento = 'MESE' THEN TO_CHAR(SCU.transazione_data_scadenza, 'YYYY-MM')
            WHEN p_raggruppamento = 'CONTROPARTE' THEN SCU.controparte_ragione_sociale
            ELSE 'TUTTI'
        END::TEXT as GruppoChiave,
        
        -- Gruppo Display
        CASE 
            WHEN p_raggruppamento = 'URGENZA' THEN SCU.urgenza_calcolata
            WHEN p_raggruppamento = 'MESE' THEN TO_CHAR(SCU.transazione_data_scadenza, 'Month YYYY')
            WHEN p_raggruppamento = 'CONTROPARTE' THEN SCU.controparte_ragione_sociale
            ELSE 'TUTTI'
        END::TEXT as GruppoDisplay,
        
        -- Gruppo Ordine
        CASE 
            WHEN p_raggruppamento = 'URGENZA' THEN 
                CASE SCU.urgenza_calcolata
                    WHEN 'SCADUTO' THEN 1
                    WHEN 'URGENTE' THEN 2
                    WHEN 'IN_SCADENZA' THEN 3
                    ELSE 4
                END
            WHEN p_raggruppamento = 'MESE' THEN 
                (EXTRACT(YEAR FROM SCU.transazione_data_scadenza) * 100 + EXTRACT(MONTH FROM SCU.transazione_data_scadenza))::INTEGER
            WHEN p_raggruppamento = 'CONTROPARTE' THEN 0 -- Ordinamento alfabetico fatto dal client/report
            ELSE 0
        END as GruppoOrdine,
        
        SCU.transazione_id as TransazioneId,
        SCU.transazione_data_scadenza as DataScadenza,
        SCU.transazione_data_documento as DataDocumento,
        SCU.transazione_numero_documento as NumeroDocumento,
        
        SCU.controparte_ragione_sociale::VARCHAR as ControparteRagioneSociale,
        SCU.causale_ciclo::VARCHAR as CausaleCiclo,
        SCU.causale_descrizione::VARCHAR as CausaleDescrizione,
        
        SCU.importo_totale as ImportoOriginale,
        SCU.residuo as Residuo,
        SCU.valuta_codice_iso as ValutaCodiceIso,
        
        SCU.giorni_scadenza as GiorniAScadenza,
        SCU.urgenza_calcolata::VARCHAR as Urgenza,
        
        SCU.transazione_stato::VARCHAR as Stato,
        SCU.viaggio_descrizione::VARCHAR as ViaggioDescrizione,
        SCU.transazione_note::TEXT as Note
        
    FROM ScadenzeConUrgenza SCU
    WHERE 
        (p_urgenza IS NULL OR SCU.urgenza_calcolata = p_urgenza)
        AND SCU.residuo > 0.01 -- Escludi quelli già saldati completamente (tolleranza centesimi)
    ORDER BY 
        GruppoOrdine,
        SCU.transazione_data_scadenza;
END;
$function$;

COMMENT ON FUNCTION fn_get_scadenzario_stampa IS 'Restituisce le scadenze aperte con calcolo del residuo e classificazione urgenza per la stampa.';
