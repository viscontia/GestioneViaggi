-- ============================================================================
-- Test dello script 697. Transazione annullata.
-- Prima dello script deve FALLIRE (il messaggio non dice la residenza).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_cli     integer;
    v_tipo    integer;
    v_it      integer;
    v_estero  integer;
    v_msg     text;
    v_dati    jsonb;
BEGIN
    -- un cliente qualunque con email (chi guida deve averla: non è la regola provata qui)
    SELECT cliente_id INTO v_cli FROM ana_clienti WHERE btrim(COALESCE(cliente_email, '')) <> '' ORDER BY cliente_id LIMIT 1;
    SELECT tipo_partecipante_id INTO v_tipo FROM ana_tipo_partecipante WHERE tipo_partecipante_pilota ORDER BY 1 LIMIT 1;
    SELECT comune_id INTO v_it FROM ana_geo_comuni WHERE comune_estero = 'N' AND comune_descrizione = 'COMO' LIMIT 1;
    SELECT comune_id INTO v_estero FROM ana_geo_comuni WHERE comune_estero = 'Y' ORDER BY 1 LIMIT 1;
    ASSERT v_cli IS NOT NULL AND v_tipo IS NOT NULL AND v_it IS NOT NULL AND v_estero IS NOT NULL, 'dati di prova';

    -- data di nascita nulla: il controllo dell'età non entra in gioco
    UPDATE ana_clienti SET cliente_codicefiscale = NULL, cliente_data_nascita = NULL WHERE cliente_id = v_cli;
    v_dati := jsonb_build_object('cliente_id_fk', v_cli, 'tipo_partecipante_id_fk', v_tipo);

    -- 1. residente in Italia: il messaggio dice dove risulta residente e cosa correggere
    UPDATE ana_clienti SET cliente_comune_residenza_fk = v_it WHERE cliente_id = v_cli;
    SELECT messaggio INTO v_msg FROM fn_mov_clienti_viaggi_valida(v_dati, true) WHERE esito = 'PILOTA_SENZA_CF';
    ASSERT v_msg IS NOT NULL, 'pilota residente in Italia senza codice fiscale: rifiutato';
    ASSERT v_msg LIKE '%residente in Italia (COMO)%', 'il messaggio dice la residenza: ' || v_msg;
    ASSERT v_msg LIKE '%correggi il comune di residenza%', 'il messaggio dice cosa correggere: ' || v_msg;

    -- 2. residente all'estero: nessun rifiuto (la regola non cambia)
    UPDATE ana_clienti SET cliente_comune_residenza_fk = v_estero WHERE cliente_id = v_cli;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_mov_clienti_viaggi_valida(v_dati, true) WHERE esito = 'PILOTA_SENZA_CF'),
        'residente all''estero: il codice fiscale non serve';

    -- 3. con il codice fiscale: nessun rifiuto
    UPDATE ana_clienti SET cliente_comune_residenza_fk = v_it, cliente_codicefiscale = 'RSSMRA80A01H501U' WHERE cliente_id = v_cli;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_mov_clienti_viaggi_valida(v_dati, true) WHERE esito = 'PILOTA_SENZA_CF'),
        'con il codice fiscale: nessun rifiuto';

    RAISE NOTICE 'Test 697: OK';
END $$;
ROLLBACK;
