-- Function: Recupera gli anni distinti con fatture attive per azienda
-- Usato per popolare il combobox Anno nella pagina Stampa Fatture Attive
-- Data: 2026-03-02

DROP FUNCTION IF EXISTS fn_get_anni_fatture_attive(INTEGER);

CREATE OR REPLACE FUNCTION fn_get_anni_fatture_attive(p_azienda_id INTEGER)
RETURNS TABLE (
    anno INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT EXTRACT(YEAR FROM COALESCE(t.transazione_data_documento, t.transazione_data))::INT AS anno
    FROM mov_transazioni t
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    WHERE tc.causale_ciclo = 'ATTIVO'
      AND t.transazione_azienda_id = p_azienda_id
    ORDER BY anno DESC;
END;
$$;
