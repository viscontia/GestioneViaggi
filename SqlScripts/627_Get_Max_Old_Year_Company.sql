-- ============================================================================
-- 627 — get_max_old_year_company entra in uno script, come tutte le altre
--
-- PERCHE'. Questa funzione non e' mai esistita in SqlScripts/: la creava il C#,
-- da DUE posti diversi.
--   1. `DbMigrationService.ApplyMigrationsAsync()`, eseguito a ogni avvio in DEBUG
--      da MainLayout: creava funzioni e trigger, e — riga 80 — RISCRIVEVA DATI
--      (`UPDATE ana_geo_comuni SET comune_num_abitanti = 10 WHERE ... < 10 OR IS NULL`).
--   2. `StatisticYearService.CreateFunctionAsync()`, che la ricreava al volo quando
--      la chiamata falliva con 42883 «funzione inesistente».
--
-- ⚠️ Due copie della stessa DDL dentro l'applicazione, nessuna delle due in uno
-- script: e' il difetto che questo progetto rifiuta per regola (DB-first,
-- overview.md). Con il 627 la funzione esiste come tutte le altre, e il codice C#
-- torna a fare solo la chiamata.
--
-- COSA NON VIENE PORTATO QUI, e perche' (verificato il 2026-09-07):
--   • i due trigger di auto-numerazione `trg_assign_comune_id` /
--     `trg_assign_provincia_id`: inutili. `ana_geo_comuni.comune_id` e
--     `ana_geo_province.provincia_id` hanno gia' il proprio nextval(), su PROD
--     come in locale. Numeravano una cosa gia' numerata.
--   • l'UPDATE che porta a 10 gli abitanti e il CHECK `comune_num_abitanti >= 10`:
--     ⛔️ non e' una migrazione, e' un'invenzione. Decidere che un comune ha
--     almeno 10 abitanti, e riscrivere i dati che non lo rispettano a ogni avvio
--     dell'applicazione, e' una scelta di merito che spetta a chi conosce il dato.
--     Resta fuori finche' non e' Adriano a volerla.
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION get_max_old_year_company(p_azienda_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_year integer;
BEGIN
    -- Il primo anno per cui ha senso mostrare una statistica: quello della
    -- partenza piu' vecchia. Senza azienda (SuperAdmin) si guarda dappertutto.
    IF p_azienda_id IS NULL THEN
        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
          INTO v_min_year
          FROM ana_date_viaggi dv;
    ELSE
        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
          INTO v_min_year
          FROM ana_date_viaggi dv
          JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
         WHERE av.azienda_id = p_azienda_id;
    END IF;

    -- Nessuna partenza: si offrono comunque cinque anni indietro, cosi' la
    -- pagina delle statistiche non resta senza scelte.
    RETURN COALESCE(v_min_year, EXTRACT(YEAR FROM CURRENT_DATE)::integer - 5);
END;
$$;

COMMENT ON FUNCTION get_max_old_year_company(integer) IS
    'Anno della partenza piu vecchia dell azienda (o di tutte, se NULL). Script 627.';

DO $verifica$
BEGIN
    IF to_regprocedure('public.get_max_old_year_company(integer)') IS NULL THEN
        RAISE EXCEPTION '627: la funzione non risulta creata.';
    END IF;
    RAISE NOTICE '627: get_max_old_year_company creata. Azienda 2 parte dal %',
                 get_max_old_year_company(2);
END
$verifica$;

COMMIT;
