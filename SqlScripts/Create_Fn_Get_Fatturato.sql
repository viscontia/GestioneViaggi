-- =============================================
-- Function: Calcolo Fatturato Aziendale
-- Data Creazione: 2026-02-08
-- Descrizione: Calcola il fatturato aziendale (entrate) per anno
--              convertito nella valuta di riferimento dell'utente
-- =============================================

-- =============================================
-- Function 1: fn_get_fatturato_annuale
-- Restituisce il fatturato totale per un anno specifico
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_annuale(
    p_azienda_id INTEGER,
    p_anno INTEGER,
    p_valuta_target_id INTEGER
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fatturato NUMERIC(15,2);
    v_importo_convertito NUMERIC(15,2);
    v_tasso NUMERIC(15,6);
    v_record RECORD;
    v_totale NUMERIC(15,2) := 0;
BEGIN
    -- Itera su tutte le transazioni di tipo ENTRATA per l'anno specificato
    FOR v_record IN
        SELECT
            transazione_importo,
            transazione_valuta_id,
            transazione_data_documento,
            transazione_data  -- fallback se data_documento è NULL
        FROM mov_transazioni
        WHERE transazione_azienda_id = p_azienda_id
          AND transazione_tipo_movimento = 'ENTRATA'
          AND transazione_stato != 'ANNULLATO'
          AND EXTRACT(YEAR FROM COALESCE(transazione_data_documento, transazione_data)) = p_anno
    LOOP
        -- Se la valuta della transazione è uguale alla valuta target, usa l'importo diretto
        IF v_record.transazione_valuta_id = p_valuta_target_id THEN
            v_importo_convertito := v_record.transazione_importo;
        ELSE
            -- Ottieni il tasso di cambio alla data del documento (o data transazione come fallback)
            v_tasso := fn_get_tasso_cambio(
                v_record.transazione_valuta_id,
                p_valuta_target_id,
                COALESCE(v_record.transazione_data_documento, v_record.transazione_data)
            );

            -- Se il tasso esiste, converti l'importo
            IF v_tasso IS NOT NULL THEN
                v_importo_convertito := ROUND((v_record.transazione_importo * v_tasso), 2);
            ELSE
                -- Se non c'è tasso di cambio disponibile, salta questa transazione
                -- (oppure potremmo usare l'importo EUR come fallback)
                v_importo_convertito := 0;
            END IF;
        END IF;

        -- Somma al totale
        v_totale := v_totale + v_importo_convertito;
    END LOOP;

    RETURN COALESCE(v_totale, 0);
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_annuale(INTEGER, INTEGER, INTEGER) IS
'Calcola il fatturato annuale (entrate non annullate) per un''azienda, convertito nella valuta target. Usa l''anno di transazione_data_documento.';

-- =============================================
-- Function 2: fn_get_fatturato_periodo
-- Restituisce il fatturato per un periodo specifico
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_periodo(
    p_azienda_id INTEGER,
    p_data_inizio DATE,
    p_data_fine DATE,
    p_valuta_target_id INTEGER
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_importo_convertito NUMERIC(15,2);
    v_tasso NUMERIC(15,6);
    v_record RECORD;
    v_totale NUMERIC(15,2) := 0;
BEGIN
    -- Itera su tutte le transazioni di tipo ENTRATA per il periodo specificato
    FOR v_record IN
        SELECT
            transazione_importo,
            transazione_valuta_id,
            transazione_data_documento,
            transazione_data  -- fallback se data_documento è NULL
        FROM mov_transazioni
        WHERE transazione_azienda_id = p_azienda_id
          AND transazione_tipo_movimento = 'ENTRATA'
          AND transazione_stato != 'ANNULLATO'
          AND COALESCE(transazione_data_documento, transazione_data) BETWEEN p_data_inizio AND p_data_fine
    LOOP
        -- Se la valuta della transazione è uguale alla valuta target, usa l'importo diretto
        IF v_record.transazione_valuta_id = p_valuta_target_id THEN
            v_importo_convertito := v_record.transazione_importo;
        ELSE
            -- Ottieni il tasso di cambio alla data del documento (o data transazione come fallback)
            v_tasso := fn_get_tasso_cambio(
                v_record.transazione_valuta_id,
                p_valuta_target_id,
                COALESCE(v_record.transazione_data_documento, v_record.transazione_data)
            );

            -- Se il tasso esiste, converti l'importo
            IF v_tasso IS NOT NULL THEN
                v_importo_convertito := ROUND((v_record.transazione_importo * v_tasso), 2);
            ELSE
                -- Se non c'è tasso di cambio disponibile, salta questa transazione
                v_importo_convertito := 0;
            END IF;
        END IF;

        -- Somma al totale
        v_totale := v_totale + v_importo_convertito;
    END LOOP;

    RETURN COALESCE(v_totale, 0);
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_periodo(INTEGER, DATE, DATE, INTEGER) IS
'Calcola il fatturato per un periodo specifico (entrate non annullate), convertito nella valuta target.';

-- =============================================
-- Function 3: fn_get_fatturato_mensile_trend
-- Restituisce il trend mensile del fatturato per un anno
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_mensile_trend(
    p_azienda_id INTEGER,
    p_anno INTEGER,
    p_valuta_target_id INTEGER
)
RETURNS TABLE (
    mese INTEGER,
    fatturato NUMERIC(15,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH mesi AS (
        SELECT generate_series(1, 12) AS mese_num
    ),
    fatturato_mensile AS (
        SELECT
            EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INTEGER AS mese_num,
            SUM(
                CASE
                    WHEN t.transazione_valuta_id = p_valuta_target_id THEN
                        t.transazione_importo
                    ELSE
                        COALESCE(
                            ROUND(
                                t.transazione_importo * fn_get_tasso_cambio(
                                    t.transazione_valuta_id,
                                    p_valuta_target_id,
                                    COALESCE(t.transazione_data_documento, t.transazione_data)
                                ),
                                2
                            ),
                            0
                        )
                END
            ) AS importo_mese
        FROM mov_transazioni t
        WHERE t.transazione_azienda_id = p_azienda_id
          AND t.transazione_tipo_movimento = 'ENTRATA'
          AND t.transazione_stato != 'ANNULLATO'
          AND EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data)) = p_anno
        GROUP BY EXTRACT(MONTH FROM COALESCE(t.transazione_data_documento, t.transazione_data))
    )
    SELECT
        m.mese_num::INTEGER,
        COALESCE(f.importo_mese, 0)::NUMERIC(15,2)
    FROM mesi m
    LEFT JOIN fatturato_mensile f ON m.mese_num = f.mese_num
    ORDER BY m.mese_num;
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_mensile_trend(INTEGER, INTEGER, INTEGER) IS
'Restituisce il fatturato mensile (gen-dic) per un anno specifico, convertito nella valuta target. Restituisce 0 per mesi senza entrate.';

-- =============================================
-- Grants (permessi di esecuzione)
-- =============================================
GRANT EXECUTE ON FUNCTION fn_get_fatturato_annuale(INTEGER, INTEGER, INTEGER) TO app_superadmin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_annuale(INTEGER, INTEGER, INTEGER) TO app_admin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_annuale(INTEGER, INTEGER, INTEGER) TO app_user;

GRANT EXECUTE ON FUNCTION fn_get_fatturato_periodo(INTEGER, DATE, DATE, INTEGER) TO app_superadmin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_periodo(INTEGER, DATE, DATE, INTEGER) TO app_admin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_periodo(INTEGER, DATE, DATE, INTEGER) TO app_user;

GRANT EXECUTE ON FUNCTION fn_get_fatturato_mensile_trend(INTEGER, INTEGER, INTEGER) TO app_superadmin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_mensile_trend(INTEGER, INTEGER, INTEGER) TO app_admin;
GRANT EXECUTE ON FUNCTION fn_get_fatturato_mensile_trend(INTEGER, INTEGER, INTEGER) TO app_user;
