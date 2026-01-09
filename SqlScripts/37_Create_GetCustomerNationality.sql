-- Function: get_customer_nationality
-- Description: Retrieves the ISO Alpha-2 code for a customer's nationality based on:
-- 1. Birth Place (Priority)
-- 2. Residence (Fallback)
-- Returns: TEXT (ISO Alpha-2 code, e.g., 'IT', 'FR') or NULL if not found.

CREATE OR REPLACE FUNCTION get_customer_nationality(p_cliente_id INT)
RETURNS TEXT AS $$
DECLARE
    v_iso_code TEXT;
BEGIN
    -- 1. Try Lookup by Birth Place (Priority)
    SELECT 
        e.iso_alpha2
    INTO 
        v_iso_code
    FROM 
        ana_clienti c
    JOIN 
        ana_geo_comuni co ON c.cliente_comune_nascita_fk = co.comune_id
    JOIN 
        ana_geo_province p ON co.comune_provincia_fk = p.provincia_id
    JOIN 
        ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
    JOIN 
        eba_countries e ON r.country_id_fk = e.country_id
    WHERE 
        c.cliente_id = p_cliente_id;

    -- 2. If not found (e.g. birth place missing/not linked), Fallback to Residence
    IF v_iso_code IS NULL THEN
        SELECT 
            e.iso_alpha2
        INTO 
            v_iso_code
        FROM 
            ana_clienti c
        JOIN 
            ana_geo_comuni co ON c.cliente_comune_residenza_fk = co.comune_id
        JOIN 
            ana_geo_province p ON co.comune_provincia_fk = p.provincia_id
        JOIN 
            ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
        JOIN 
            eba_countries e ON r.country_id_fk = e.country_id
        WHERE 
            c.cliente_id = p_cliente_id;
    END IF;

    RETURN v_iso_code;
END;
$$ LANGUAGE plpgsql;