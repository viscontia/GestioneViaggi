-- Function: get_viaggi_grouped_by_year
-- Description: Restituisce viaggi e date viaggi raggruppati per anno con stato
-- Parameters:
--   p_azienda_id: ID dell'azienda (0 o NULL per tutte le aziende - solo SuperAdmin)
-- Returns: Table con anno, viaggio_id, descrizione, data_viaggio_id, date e stato
-- Used by: TravelDataSelectorDialog per TreeView

DROP FUNCTION IF EXISTS get_viaggi_grouped_by_year(integer);

CREATE OR REPLACE FUNCTION get_viaggi_grouped_by_year(p_azienda_id integer)
RETURNS TABLE(
    anno integer,
    viaggio_id integer,
    viaggio_descrizione text,
    data_viaggio_id integer,
    data_inizio date,
    data_fine date,
    effettuato_sino char(1)
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(YEAR FROM dv.data_viaggio_data_inizio)::integer AS anno,
        av.viaggio_id::integer,
        av.viaggio_descrizione_breve::text AS viaggio_descrizione,
        dv.data_viaggio_id::integer,
        dv.data_viaggio_data_inizio,
        dv.data_viaggio_data_fine,
        COALESCE(dv.data_viaggio_effettuato_sino, 'N')::char(1) AS effettuato_sino
    FROM ana_date_viaggi dv
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
      AND dv.data_viaggio_data_inizio IS NOT NULL
    ORDER BY
        anno DESC,                                      -- Anni più recenti prima
        av.viaggio_descrizione_breve,                   -- Alfabetico per viaggio
        dv.data_viaggio_data_inizio ASC;               -- Date crescenti
END;
$function$;
