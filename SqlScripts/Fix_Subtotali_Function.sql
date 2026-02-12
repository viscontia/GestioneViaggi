-- ============================================================================
-- Fix: Reload correct version of fn_get_transazioni_stampa_subtotali
-- Issue: Database has old version with only 3 return columns
-- Solution: Drop all versions and reload the correct one
-- ============================================================================

-- Drop ALL existing versions of the subtotali function
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, integer, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_stampa_subtotali(integer, integer, character varying, character varying[], integer, integer, integer, date, date, date, date, numeric, numeric, character varying, boolean, boolean, boolean, boolean, boolean, character varying, integer);

-- Now source the correct version from the dedicated file
\i SqlScripts/fn_get_transazioni_stampa_subtotali.sql

-- Verify the function signature
SELECT
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'fn_get_transazioni_stampa_subtotali';
