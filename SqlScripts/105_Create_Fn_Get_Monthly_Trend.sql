-- Function: fn_get_monthly_trend
-- Description: Calculates monthly volume counts (trend) for a specific table and year.

CREATE OR REPLACE FUNCTION fn_get_monthly_trend(
    p_table_name TEXT,
    p_year INT,
    p_azienda_id INT DEFAULT NULL,
    p_date_column TEXT DEFAULT 'created'
)
RETURNS TABLE (
    month_num INT,
    count_val BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    -- Validate table name
    IF p_table_name NOT IN ('ana_viaggi', 'ana_clienti', 'ana_aziende', 'ana_date_viaggi') THEN
        RAISE EXCEPTION 'Invalid table name for trend calculation: %', p_table_name;
    END IF;

    -- Validate column name (basic check)
    IF p_date_column NOT IN ('created', 'data_creazione', 'data_viaggio_data_inizio') THEN
         RAISE EXCEPTION 'Invalid date column: %', p_date_column;
    END IF;

    -- Construct dynamic SQL
    v_sql := '
        WITH months AS (
            SELECT generate_series(1, 12) AS month_num
        ),
        counts AS (
            SELECT 
                EXTRACT(MONTH FROM ' || quote_ident(p_date_column) || ')::INT AS month_num,
                COUNT(*) as cnt
            FROM ' || quote_ident(p_table_name) || '
            WHERE EXTRACT(YEAR FROM ' || quote_ident(p_date_column) || ') = $1 ';

    -- Add azienda_id filter if provided
    IF p_azienda_id IS NOT NULL THEN
        -- Verify table has azienda fields if filtering? 
        -- assuming ana_clienti (azienda_fk) and ana_viaggi (azienda_id) and ana_aziende (azienda_id? no, ana_aziende is different)
        
        IF p_table_name = 'ana_clienti' THEN
             v_sql := v_sql || ' AND azienda_fk = $2 ';
        ELSIF p_table_name = 'ana_viaggi' THEN
             v_sql := v_sql || ' AND azienda_id = $2 ';
        ELSIF p_table_name = 'ana_date_viaggi' THEN
             v_sql := v_sql || ' AND azienda_id = $2 ';
        ELSIF p_table_name = 'ana_aziende' THEN
             -- ana_aziende technically has azienda_id self-ref but usually we list ALL companies for superadmin, 
             -- so p_azienda_id is likely NULL for ana_aziende anyway.
             v_sql := v_sql || ' AND id = $2 '; -- unlikely usage but safe to add if needed
        END IF;
    END IF;

    v_sql := v_sql || '
            GROUP BY 1
        )
        SELECT 
            m.month_num,
            COALESCE(c.cnt, 0)
        FROM months m
        LEFT JOIN counts c ON m.month_num = c.month_num
        ORDER BY m.month_num;
    ';

    -- Execute
    IF p_azienda_id IS NOT NULL THEN
        RETURN QUERY EXECUTE v_sql USING p_year, p_azienda_id;
    ELSE
        RETURN QUERY EXECUTE v_sql USING p_year;
    END IF;
END;
$$;
