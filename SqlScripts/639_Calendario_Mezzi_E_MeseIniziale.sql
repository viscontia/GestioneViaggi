-- ============================================================================
-- Calendario dei viaggi: il numero dei mezzi, e su quale mese aprirsi
--
-- Due aggiunte, entrambe chieste guardando il calendario in uso:
--
-- 1. `tot_mezzi` — il calendario mostra i partecipanti ma non i **mezzi**, che
--    per un tour offroad è il numero che conta davvero: le persone si
--    ridistribuiscono, i mezzi no. Il conteggio è lo stesso già usato dal
--    bilancio viaggi: un mezzo per ogni pilota, dove «pilota» è chi ha un tipo
--    partecipante marcato come tale, e i passeggeri si contano sul pilota a cui
--    sono agganciati.
--
-- 2. `fn_get_calendar_mese_iniziale` — oggi il calendario si apre sul mese
--    corrente. ⛔️ A novembre, con la prossima partenza a marzo, si apre su un
--    mese vuoto e sembra che non ci sia niente in programma. La funzione dice su
--    quale mese posizionarsi: quello della prossima partenza.
--
-- ⚠️ DROP + CREATE su fn_get_calendar_data: cambia il tipo del risultato (una
-- colonna in più) e CREATE OR REPLACE non può farlo.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Il calendario, con il numero dei mezzi
-- ============================================================================
DROP FUNCTION IF EXISTS fn_get_calendar_data(integer, integer, integer);

CREATE OR REPLACE FUNCTION public.fn_get_calendar_data(
    p_year integer,
    p_month integer,
    p_azienda_id integer DEFAULT NULL::integer
)
RETURNS TABLE(
    data_viaggio_id integer, viaggio_id integer, descrizione_viaggio text,
    data_inizio date, data_fine date,
    tot_clienti integer, tot_mezzi integer,
    effettuato_sino character, azienda_id integer, azienda_nome text
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_month_start date;
    v_month_end date;
BEGIN
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

        -- Un mezzo per pilota: chi guida ha un tipo partecipante marcato pilota,
        -- e chi viaggia con lui porta l'id del proprio pilota. Stesso conteggio
        -- del bilancio viaggi, per non avere due definizioni di «mezzo».
        COALESCE((
            SELECT COUNT(DISTINCT
                CASE
                    WHEN mcv.cliente_pilota_id_fk IS NOT NULL AND mcv.cliente_pilota_id_fk > 0
                        THEN mcv.cliente_pilota_id_fk
                    WHEN tp.tipo_partecipante_pilota = true
                        THEN mcv.cliente_id_fk
                    ELSE NULL
                END
            )::integer
            FROM mov_clienti_viaggi mcv
            JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) AS tot_mezzi,

        COALESCE(dv.data_viaggio_effettuato_sino, 'N')::char(1) AS effettuato_sino,
        av.azienda_id::integer,
        az.ragione_sociale::text AS azienda_nome

    FROM ana_date_viaggi dv
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    JOIN ana_aziende az ON av.azienda_id = az.azienda_id
    WHERE
        dv.data_viaggio_data_inizio <= v_month_end
        AND dv.data_viaggio_data_fine >= v_month_start
        AND (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
    ORDER BY
        dv.data_viaggio_data_inizio,
        av.viaggio_descrizione_breve;
END;
$function$;

COMMENT ON FUNCTION fn_get_calendar_data(integer, integer, integer) IS
    'Partenze che intersecano il mese indicato, con partecipanti e mezzi. tot_mezzi usa lo stesso conteggio del bilancio viaggi.';

-- ============================================================================
-- 2) Su quale mese aprire il calendario
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_calendar_mese_iniziale(
    p_azienda_id integer DEFAULT NULL::integer
)
RETURNS date
LANGUAGE sql STABLE
AS $function$
    -- Ordine di preferenza:
    --   1. la prossima partenza ancora in corso o futura  -> il suo mese
    --   2. se non ce n'è, l'ultima conclusa               -> il suo mese
    --   3. se non c'è nessuna partenza                    -> il mese corrente
    SELECT COALESCE(
        (SELECT date_trunc('month', dv.data_viaggio_data_inizio)::date
           FROM ana_date_viaggi dv
           JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
          WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
            AND dv.data_viaggio_data_fine >= CURRENT_DATE
          ORDER BY dv.data_viaggio_data_inizio
          LIMIT 1),
        (SELECT date_trunc('month', dv.data_viaggio_data_inizio)::date
           FROM ana_date_viaggi dv
           JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
          WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
          ORDER BY dv.data_viaggio_data_inizio DESC
          LIMIT 1),
        date_trunc('month', CURRENT_DATE)::date
    );
$function$;

COMMENT ON FUNCTION fn_get_calendar_mese_iniziale(integer) IS
    'Mese su cui aprire il calendario: quello della prossima partenza; se non ce ne sono, l''ultima conclusa; altrimenti il mese corrente.';

COMMIT;

-- ============================================================================
-- Verifica:
--   SELECT fn_get_calendar_mese_iniziale(2);
--   SELECT descrizione_viaggio, tot_clienti, tot_mezzi
--     FROM fn_get_calendar_data(2027, 1, 2);
-- ============================================================================
