-- ============================================================================
-- Test dello script 678. Transazione annullata.
-- ============================================================================
BEGIN;
DO $$
DECLARE r record;
BEGIN
    -- ogni sezione del menu è «attiva»: la funzione poggia su fn_web_sezioni_tipologia
    FOR r IN SELECT slug FROM fn_web_sezioni_tipologia(2, 'IT') LOOP
        ASSERT fn_web_sezione_stato(2, r.slug) = 'attiva', 'attesa attiva: ' || r.slug;
    END LOOP;
    -- una sezione nota ma senza tour pubblicati è «ritirata»
    ASSERT fn_web_sezione_stato(2, 'esperienze') = 'ritirata', 'esperienze deve essere ritirata';
    -- uno slug mai esistito è «sconosciuta»
    ASSERT fn_web_sezione_stato(2, 'non-esiste-mai') = 'sconosciuta', 'atteso sconosciuta';
    ASSERT fn_web_sezione_stato(2, NULL) = 'sconosciuta', 'NULL deve essere sconosciuta';
    -- un'azienda senza tour pubblicati: nessuna sezione è attiva
    ASSERT fn_web_sezione_stato(999999, 'viaggi-4x4') = 'ritirata', 'azienda inesistente: ritirata, mai attiva';
    RAISE NOTICE 'Test 678: OK';
END $$;
ROLLBACK;
