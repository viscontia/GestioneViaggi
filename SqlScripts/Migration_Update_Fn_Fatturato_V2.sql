-- ============================================================================
-- Migration: Riscrittura funzioni fatturato V2
-- Data: 2026-02-22
-- Descrizione: Nuova logica fatturato basata su:
--   1. Flag causale_concorre_fatturato (da ana_tipi_causali)
--   2. Importo netto: COALESCE(transazione_imponibile_eur, transazione_importo_eur_old)
--   3. Segno causale: * c.causale_segno
--   4. Supporto SuperAdmin: p_azienda_id = NULL → tutte le aziende
-- ============================================================================

-- =============================================
-- Function 1: fn_get_fatturato_annuale (V2)
-- Restituisce il fatturato netto per un anno
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_annuale(
    p_azienda_id INTEGER,
    p_anno INTEGER,
    p_valuta_target_id INTEGER DEFAULT NULL
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fatturato NUMERIC(15,2);
BEGIN
    SELECT COALESCE(SUM(
        COALESCE(m.transazione_imponibile_eur, m.transazione_importo_eur_old, 0) * c.causale_segno
    ), 0)
    INTO v_fatturato
    FROM mov_transazioni m
    JOIN ana_tipi_causali c ON m.transazione_causale_tipo_id = c.causale_id
    WHERE c.causale_concorre_fatturato = TRUE
      AND m.transazione_stato <> 'ANNULLATO'
      AND EXTRACT(YEAR FROM COALESCE(m.transazione_data_documento, m.transazione_data)) = p_anno
      AND (p_azienda_id IS NULL OR m.transazione_azienda_id = p_azienda_id);

    RETURN v_fatturato;
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_annuale(INTEGER, INTEGER, INTEGER) IS
'V2 - Calcola il fatturato annuale netto (imponibili con segno causale) per un''azienda. Se p_azienda_id IS NULL, somma tutte le aziende (SuperAdmin).';

-- =============================================
-- Function 2: fn_get_fatturato_periodo (V2)
-- Restituisce il fatturato netto per un periodo
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_periodo(
    p_azienda_id INTEGER,
    p_data_inizio DATE,
    p_data_fine DATE,
    p_valuta_target_id INTEGER DEFAULT NULL
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fatturato NUMERIC(15,2);
BEGIN
    SELECT COALESCE(SUM(
        COALESCE(m.transazione_imponibile_eur, m.transazione_importo_eur_old, 0) * c.causale_segno
    ), 0)
    INTO v_fatturato
    FROM mov_transazioni m
    JOIN ana_tipi_causali c ON m.transazione_causale_tipo_id = c.causale_id
    WHERE c.causale_concorre_fatturato = TRUE
      AND m.transazione_stato <> 'ANNULLATO'
      AND COALESCE(m.transazione_data_documento, m.transazione_data) BETWEEN p_data_inizio AND p_data_fine
      AND (p_azienda_id IS NULL OR m.transazione_azienda_id = p_azienda_id);

    RETURN v_fatturato;
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_periodo(INTEGER, DATE, DATE, INTEGER) IS
'V2 - Calcola il fatturato netto per un periodo specifico. Se p_azienda_id IS NULL, somma tutte le aziende.';

-- =============================================
-- Function 3: fn_get_fatturato_mensile_trend (V2)
-- Restituisce il trend mensile gen-dic
-- =============================================
CREATE OR REPLACE FUNCTION fn_get_fatturato_mensile_trend(
    p_azienda_id INTEGER,
    p_anno INTEGER,
    p_valuta_target_id INTEGER DEFAULT NULL
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
            EXTRACT(MONTH FROM COALESCE(m.transazione_data_documento, m.transazione_data))::INTEGER AS mese_num,
            SUM(
                COALESCE(m.transazione_imponibile_eur, m.transazione_importo_eur_old, 0) * c.causale_segno
            ) AS importo_mese
        FROM mov_transazioni m
        JOIN ana_tipi_causali c ON m.transazione_causale_tipo_id = c.causale_id
        WHERE c.causale_concorre_fatturato = TRUE
          AND m.transazione_stato <> 'ANNULLATO'
          AND EXTRACT(YEAR FROM COALESCE(m.transazione_data_documento, m.transazione_data)) = p_anno
          AND (p_azienda_id IS NULL OR m.transazione_azienda_id = p_azienda_id)
        GROUP BY EXTRACT(MONTH FROM COALESCE(m.transazione_data_documento, m.transazione_data))
    )
    SELECT
        ms.mese_num::INTEGER,
        COALESCE(f.importo_mese, 0)::NUMERIC(15,2)
    FROM mesi ms
    LEFT JOIN fatturato_mensile f ON ms.mese_num = f.mese_num
    ORDER BY ms.mese_num;
END;
$$;

COMMENT ON FUNCTION fn_get_fatturato_mensile_trend(INTEGER, INTEGER, INTEGER) IS
'V2 - Restituisce il fatturato mensile netto (gen-dic). Se p_azienda_id IS NULL, somma tutte le aziende.';

-- =============================================
-- Grants
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
