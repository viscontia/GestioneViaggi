-- Function: get_max_old_year_company
-- Description: Restituisce l'anno più vecchio basato sui viaggi in ana_date_viaggi.
--              Se p_azienda_id è NULL (SuperAdmin), cerca globalmente.
--              Se p_azienda_id è valorizzato, filtra per azienda.
-- Parameters:
--   p_azienda_id: ID dell'azienda (se NULL, cerca globalmente per SuperAdmin)
-- Returns: Anno più vecchio (o anno corrente - 5 se nessun viaggio)

DROP FUNCTION IF EXISTS get_max_old_year_company(integer);

CREATE OR REPLACE FUNCTION get_max_old_year_company(p_azienda_id integer)
RETURNS integer AS $$
DECLARE
    v_min_year integer;
BEGIN
    IF p_azienda_id IS NULL THEN
        -- SuperAdmin: cerca globalmente su tutte le aziende
        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
        INTO v_min_year
        FROM ana_date_viaggi dv;
    ELSE
        -- Utente normale: filtra per azienda
        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
        INTO v_min_year
        FROM ana_date_viaggi dv
        JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
        WHERE av.azienda_id = p_azienda_id;
    END IF;

    -- Ritorna l'anno minimo trovato, oppure Current Year - 5 come default
    RETURN COALESCE(v_min_year, EXTRACT(YEAR FROM CURRENT_DATE)::integer - 5);
END;
$$ LANGUAGE plpgsql;
