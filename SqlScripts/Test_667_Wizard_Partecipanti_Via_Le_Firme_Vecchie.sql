-- ============================================================================
-- Test dello script 667: le firme senza azienda non ci sono piu', le nuove si'
-- ============================================================================

DO $$
BEGIN
    ASSERT to_regprocedure('fn_wizard_get_client_data(integer)') IS NULL,
           'esiste ancora fn_wizard_get_client_data senza azienda';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti_details(integer[])') IS NULL,
           'esiste ancora fn_wizard_get_partecipanti_details senza azienda';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti(integer[])') IS NULL,
           'esiste ancora fn_wizard_get_partecipanti senza azienda';
    ASSERT to_regprocedure('fn_wizard_get_client_data(integer,integer)') IS NOT NULL,
           'manca fn_wizard_get_client_data con azienda (script 663)';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti_details(integer[],integer)') IS NOT NULL,
           'manca fn_wizard_get_partecipanti_details con azienda (script 663)';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti(integer[],integer)') IS NOT NULL,
           'manca fn_wizard_get_partecipanti con azienda (script 663)';
    RAISE NOTICE 'OK: solo le firme con azienda';
END $$;
