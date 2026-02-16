-- =====================================================
-- Script: 08_crea_function_scadenzario_stampa.sql
-- Descrizione: Function per estrazione dati scadenzario per stampa PDF
-- Data: 16/02/2026
--
-- Questa function supporta 3 tipi di raggruppamento:
-- - URGENZA: Raggruppa per SCADUTO/URGENTE/IN_SCADENZA/NORMALE
-- - MESE: Raggruppa per mese di scadenza
-- - CONTROPARTE: Raggruppa per fornitore/cliente
-- =====================================================

CREATE OR REPLACE FUNCTION public.fn_get_scadenzario_stampa(
    p_azienda_id INTEGER,
    p_controparte_id INTEGER,
    p_causale_ciclo VARCHAR(10),
    p_urgenza VARCHAR(20),
    p_data_scadenza_da DATE,
    p_data_scadenza_a DATE,
    p_viaggio_id INTEGER,
    p_solo_con_viaggio BOOLEAN,
    p_solo_senza_viaggio BOOLEAN,
    p_raggruppamento VARCHAR(20) DEFAULT 'URGENZA'
)
RETURNS TABLE(
    -- Campi di raggruppamento
    gruppo_chiave TEXT,
    gruppo_display TEXT,
    gruppo_ordine INTEGER,

    -- Dati transazione
    transazione_id INTEGER,
    data_scadenza DATE,
    data_documento DATE,
    numero_documento VARCHAR(50),

    -- Controparte
    controparte_ragione_sociale VARCHAR(200),
    causale_ciclo VARCHAR(10),
    causale_descrizione VARCHAR(100),

    -- Importi
    importo_originale NUMERIC(15,2),
    residuo NUMERIC(15,2),
    valuta_codice_iso VARCHAR(3),

    -- Urgenza
    giorni_a_scadenza INTEGER,
    urgenza VARCHAR(20),

    -- Stato e metadati
    stato VARCHAR(50),
    viaggio_descrizione TEXT,
    note TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_gruppo_expression TEXT;
BEGIN
    -- Determina l'espressione di raggruppamento in base al parametro
    CASE p_raggruppamento
        WHEN 'URGENZA' THEN
            v_gruppo_expression := 'urgenza';
        WHEN 'MESE' THEN
            v_gruppo_expression := 'TO_CHAR(transazione_data_scadenza, ''YYYY-MM'')';
        WHEN 'CONTROPARTE' THEN
            v_gruppo_expression := 'ragione_sociale';
        ELSE
            RAISE EXCEPTION 'Raggruppamento non valido: %. Valori ammessi: URGENZA, MESE, CONTROPARTE', p_raggruppamento;
    END CASE;

    -- Costruisce e esegue la query dinamica
    RETURN QUERY EXECUTE format('
        SELECT
            -- Campi di raggruppamento
            CASE
                WHEN $7 = ''URGENZA'' THEN s.urgenza
                WHEN $7 = ''MESE'' THEN TO_CHAR(s.transazione_data_scadenza, ''YYYY-MM'')
                WHEN $7 = ''CONTROPARTE'' THEN s.ragione_sociale
            END::TEXT as gruppo_chiave,

            CASE
                WHEN $7 = ''URGENZA'' THEN s.urgenza
                WHEN $7 = ''MESE'' THEN TO_CHAR(s.transazione_data_scadenza, ''TMMonth YYYY'')
                WHEN $7 = ''CONTROPARTE'' THEN s.ragione_sociale
            END::TEXT as gruppo_display,

            CASE
                WHEN $7 = ''URGENZA'' THEN
                    CASE s.urgenza
                        WHEN ''SCADUTO'' THEN 1
                        WHEN ''URGENTE'' THEN 2
                        WHEN ''IN_SCADENZA'' THEN 3
                        ELSE 4
                    END
                WHEN $7 = ''MESE'' THEN
                    EXTRACT(YEAR FROM s.transazione_data_scadenza)::INTEGER * 100 +
                    EXTRACT(MONTH FROM s.transazione_data_scadenza)::INTEGER
                WHEN $7 = ''CONTROPARTE'' THEN 0
            END::INTEGER as gruppo_ordine,

            -- Dati transazione
            s.transazione_id::INTEGER,
            s.transazione_data_scadenza::DATE,
            s.transazione_data_documento::DATE,
            s.transazione_numero_documento::VARCHAR(50),

            -- Controparte
            s.ragione_sociale::VARCHAR(200),
            s.causale_ciclo::VARCHAR(10),
            s.causale_descrizione::VARCHAR(100),

            -- Importi
            s.importo::NUMERIC(15,2),
            s.residuo::NUMERIC(15,2),
            ''EUR''::VARCHAR(3) as valuta_codice_iso,

            -- Urgenza
            s.giorni_a_scadenza::INTEGER,
            s.urgenza::VARCHAR(20),

            -- Stato e metadati
            s.transazione_stato::VARCHAR(50),
            CASE
                WHEN s.transazione_viaggio_id IS NOT NULL
                THEN (
                    SELECT v.viaggio_descrizione_breve || '' '' || EXTRACT(YEAR FROM dv.data_viaggio_data_inizio)::TEXT
                    FROM mov_transazioni mt
                    INNER JOIN ana_viaggi v ON v.viaggio_id = mt.transazione_viaggio_id
                    INNER JOIN ana_date_viaggi dv ON dv.data_viaggio_id = mt.transazione_data_viaggio_id
                    WHERE mt.transazione_id = s.transazione_id
                    LIMIT 1
                )
                ELSE NULL
            END::TEXT as viaggio_descrizione,
            s.transazione_note::TEXT
        FROM vw_scadenzario s
        WHERE 1=1
            AND ($1 IS NULL OR s.controparte_id IN (
                SELECT controparte_id
                FROM ana_controparti
                WHERE azienda_fk = $1
            ))
            AND ($2 IS NULL OR s.controparte_id = $2)
            AND ($3 IS NULL OR s.causale_ciclo = $3)
            AND ($4 IS NULL OR s.urgenza = $4)
            AND ($5 IS NULL OR s.transazione_data_scadenza >= $5)
            AND ($6 IS NULL OR s.transazione_data_scadenza <= $6)
            AND ($8 IS NULL OR s.transazione_viaggio_id = $8)
            AND ($9 = FALSE OR s.transazione_viaggio_id IS NOT NULL)
            AND ($10 = FALSE OR s.transazione_viaggio_id IS NULL)
        ORDER BY gruppo_ordine, s.transazione_data_scadenza, s.transazione_id
    ')
    USING
        p_azienda_id,           -- $1
        p_controparte_id,       -- $2
        p_causale_ciclo,        -- $3
        p_urgenza,              -- $4
        p_data_scadenza_da,     -- $5
        p_data_scadenza_a,      -- $6
        p_raggruppamento,       -- $7
        p_viaggio_id,           -- $8
        p_solo_con_viaggio,     -- $9
        p_solo_senza_viaggio;   -- $10
END;
$$;

COMMENT ON FUNCTION fn_get_scadenzario_stampa IS
'Estrae dati scadenzario per stampa PDF con raggruppamento dinamico (URGENZA/MESE/CONTROPARTE).
Utilizza la vista vw_scadenzario come base e applica filtri multipli.
Supporta filtri per: azienda, controparte, ciclo contabile, urgenza, date scadenza, viaggio.
Restituisce campi formattati per generazione PDF con QuestPDF.';

-- Test della function
SELECT
    gruppo_display,
    COUNT(*) as num_scadenze,
    SUM(ABS(residuo)) as totale_residuo
FROM fn_get_scadenzario_stampa(
    NULL,           -- p_azienda_id
    NULL,           -- p_controparte_id
    NULL,           -- p_causale_ciclo
    NULL,           -- p_urgenza
    NULL,           -- p_data_scadenza_da
    NULL,           -- p_data_scadenza_a
    NULL,           -- p_viaggio_id
    FALSE,          -- p_solo_con_viaggio
    FALSE,          -- p_solo_senza_viaggio
    'URGENZA'       -- p_raggruppamento
)
GROUP BY gruppo_display, gruppo_ordine
ORDER BY gruppo_ordine;
