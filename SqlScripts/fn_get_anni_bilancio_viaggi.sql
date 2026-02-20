-- Function: fn_get_anni_bilancio_viaggi
-- Description: Retrieves distinct years and trip counts from Trip Dates that have linked accounting transactions
-- Created: 2026-02-20

DROP FUNCTION IF EXISTS fn_get_anni_bilancio_viaggi(INT);

CREATE OR REPLACE FUNCTION fn_get_anni_bilancio_viaggi(
    p_azienda_id INT
)
RETURNS TABLE (
    anno INT,
    numero_viaggi INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(YEAR FROM dv.data_viaggio_data_inizio)::INT as anno,
        COUNT(DISTINCT v.viaggio_id)::INT as numero_viaggi
    FROM ana_date_viaggi dv
    JOIN ana_viaggi v ON dv.viaggio_id_fk = v.viaggio_id
    WHERE v.azienda_id = p_azienda_id
      AND EXISTS (
          SELECT 1 
          FROM mov_transazioni tx 
          JOIN ana_tipi_causali tcx ON tx.transazione_causale_tipo_id = tcx.causale_id
          WHERE tx.transazione_data_viaggio_id = dv.data_viaggio_id
            AND tx.transazione_azienda_id = p_azienda_id
            AND tx.transazione_stato != 'ANNULLATO'
            AND tcx.causale_is_documento = TRUE
      )
    GROUP BY EXTRACT(YEAR FROM dv.data_viaggio_data_inizio)
    ORDER BY anno DESC;
END;
$$ LANGUAGE plpgsql;
