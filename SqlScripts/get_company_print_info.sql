-- Function to get company info for printing
DROP FUNCTION IF EXISTS get_company_print_info(INT);

CREATE OR REPLACE FUNCTION get_company_print_info(p_azienda_id INT)
RETURNS TABLE (
    ragione_sociale VARCHAR,
    telefono VARCHAR,
    email VARCHAR,
    sito_web VARCHAR,
    piva VARCHAR,
    logo_data BYTEA
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.ragione_sociale,
        a.telefono_principale,
        a.pec, -- Using PEC as main email/contact for official docs, or coalesce with normal email if exists
        a.sito_web,
        a.partita_iva,
        (SELECT al.binary_data 
         FROM ana_aziende_logo al 
         WHERE al.azienda_fk = a.azienda_id 
           AND al.is_active = true 
           AND al.is_default = true 
         LIMIT 1) as logo_data
    FROM ana_aziende a
    WHERE a.azienda_id = p_azienda_id;
END;
$$ LANGUAGE plpgsql;
