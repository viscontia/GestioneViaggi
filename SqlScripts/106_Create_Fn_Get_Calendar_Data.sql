-- Function: fn_get_calendar_data
-- Description: Recupera i viaggi per il calendario mensile
-- Parameters:
--   p_year: Anno del calendario
--   p_month: Mese del calendario (1-12)
--   p_azienda_id: ID dell'azienda (NULL o 0 per tutte - solo SuperAdmin)
-- Returns: Table con dati per rendering calendario
-- Used by: TravelCalendar component

DROP FUNCTION IF EXISTS fn_get_calendar_data(integer, integer, integer);

CREATE OR REPLACE FUNCTION fn_get_calendar_data(
    p_year integer,
    p_month integer,
    p_azienda_id integer DEFAULT NULL
)
RETURNS TABLE(
    data_viaggio_id integer,
    viaggio_id integer,
    descrizione_viaggio text,
    data_inizio date,
    data_fine date,
    tot_clienti integer,
    effettuato_sino char(1),
    azienda_id integer,
    azienda_nome text
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_month_start date;
    v_month_end date;
BEGIN
    -- Calcola primo e ultimo giorno del mese
    v_month_start := make_date(p_year, p_month, 1);
    v_month_end := (v_month_start + INTERVAL '1 month' - INTERVAL '1 day')::date;

    RETURN QUERY
    SELECT
        dv.data_viaggio_id::integer,
        av.viaggio_id::integer,
        av.viaggio_descrizione_breve::text AS descrizione_viaggio,
        dv.data_viaggio_data_inizio AS data_inizio,
        dv.data_viaggio_data_fine AS data_fine,
        COALESCE((
            SELECT COUNT(*)::integer
            FROM mov_clienti_viaggi mcv
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) AS tot_clienti,
        COALESCE(dv.data_viaggio_effettuato_sino, 'N')::char(1) AS effettuato_sino,
        av.azienda_id::integer,
        az.ragione_sociale::text AS azienda_nome
    FROM ana_date_viaggi dv
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    JOIN ana_aziende az ON av.azienda_id = az.azienda_id
    WHERE
        -- Il viaggio interseca il mese: inizia prima della fine del mese E finisce dopo l'inizio del mese
        dv.data_viaggio_data_inizio <= v_month_end
        AND dv.data_viaggio_data_fine >= v_month_start
        -- Filtro azienda (NULL o 0 = tutte le aziende)
        AND (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
    ORDER BY
        dv.data_viaggio_data_inizio,
        av.viaggio_descrizione_breve;
END;
$function$;

-- Commento funzione
COMMENT ON FUNCTION fn_get_calendar_data(integer, integer, integer) IS
'Recupera viaggi che intersecano un mese specifico per il calendario.
Un viaggio viene incluso se: data_inizio <= fine_mese AND data_fine >= inizio_mese.
Include conteggio partecipanti e nome azienda per tooltip.';
