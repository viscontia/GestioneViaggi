-- ============================================================================
-- Test dello script 671. Transazione annullata: costruisce un caso per voce sui
-- dati esistenti, verifica che compaia e che sparisca risolto.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_az   integer := 2;
    d      RECORD;
    v_n    integer;
    v_cont bigint;
BEGIN
    -- 0. parametro: senza riga vale 90
    DELETE FROM web_aziende_funzioni WHERE azienda_id = v_az AND funzione = 'promemoria';
    ASSERT fn_promemoria_giorni_newsletter(v_az) = 90, '0: default 90';
    INSERT INTO web_aziende_funzioni (azienda_id, funzione, attiva, parametri, created_by)
    VALUES (v_az, 'promemoria', true, '{"giorni_newsletter": 3650}', 'test 671');
    ASSERT fn_promemoria_giorni_newsletter(v_az) = 3650, '0: parametro letto';

    -- 1. partenza passata non effettuata
    SELECT * INTO d FROM ana_date_viaggi WHERE azienda_id = v_az AND data_viaggio_data_fine < current_date LIMIT 1;
    UPDATE ana_date_viaggi SET data_viaggio_effettuato_sino = 'N' WHERE data_viaggio_id = d.data_viaggio_id;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'PARTENZA_NON_EFFETTUATA' AND data_viaggio_id = d.data_viaggio_id), '1: manca';
    UPDATE ana_date_viaggi SET data_viaggio_effettuato_sino = 'Y' WHERE data_viaggio_id = d.data_viaggio_id;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'PARTENZA_NON_EFFETTUATA' AND data_viaggio_id = d.data_viaggio_id), '1: non sparisce';

    -- 2. scheda in bozza / pubblicata, e senza foto
    SELECT c.web_tour_contenuti_id, c.data_viaggio_id_fk INTO v_cont, v_n
      FROM web_tour_contenuti c JOIN ana_date_viaggi dv ON dv.data_viaggio_id = c.data_viaggio_id_fk
     WHERE c.azienda_id = v_az AND dv.data_viaggio_data_inizio >= current_date LIMIT 1;
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'bozza' WHERE web_tour_contenuti_id = v_cont;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_IN_BOZZA' AND data_viaggio_id = v_n), '2: bozza manca';
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'pubblicato' WHERE web_tour_contenuti_id = v_cont;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_IN_BOZZA' AND data_viaggio_id = v_n), '2: bozza non sparisce';
    DELETE FROM web_tour_immagini WHERE web_tour_contenuti_id_fk = v_cont;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_SENZA_FOTO' AND data_viaggio_id = v_n), '2: senza foto manca';

    -- 3. partenza futura senza scheda
    SELECT dv.* INTO d FROM ana_date_viaggi dv
     WHERE dv.azienda_id = v_az AND dv.data_viaggio_data_inizio >= current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id) LIMIT 1;
    IF FOUND THEN
        ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_SCHEDA_WEB' AND data_viaggio_id = d.data_viaggio_id), '3: manca';
    END IF;

    -- 4. capienza: una riga per viaggio
    SELECT * INTO d FROM ana_date_viaggi WHERE azienda_id = v_az AND data_viaggio_data_inizio >= current_date LIMIT 1;
    UPDATE ana_viaggi SET viaggio_capienza_max = 20, viaggio_capienza_alert = 5 WHERE viaggio_id = d.viaggio_id_fk;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_CAPIENZA' AND viaggio_id = d.viaggio_id_fk), '4: con capienza non deve comparire';
    UPDATE ana_viaggi SET viaggio_capienza_alert = NULL WHERE viaggio_id = d.viaggio_id_fk;
    SELECT count(*) INTO v_n FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_CAPIENZA' AND viaggio_id = d.viaggio_id_fk;
    ASSERT v_n = 1, '4: una sola riga per viaggio, trovate ' || v_n;

    -- 5. newsletter: con 3650 giorni la partenza futura c'e'; con 0 no
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_NEWSLETTER' AND data_viaggio_id = d.data_viaggio_id), '5: manca';
    UPDATE web_aziende_funzioni SET parametri = '{"giorni_newsletter": 0}' WHERE azienda_id = v_az AND funzione = 'promemoria';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_NEWSLETTER'), '5: con 0 giorni niente';

    -- 6. isolamento: un'azienda inesistente non vede niente
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(999999)), '6: altra azienda';

    -- 7. ordinamento: urgenza non nulla su ogni riga
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE urgenza IS NULL OR voce_titolo IS NULL OR oggetto IS NULL), '7: colonne vuote';

    -- 8. chiusa ad anon/authenticated
    FOR d IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(d.rolname, 'fn_promemoria_apertura(integer)', 'EXECUTE'), d.rolname || ' esegue';
    END LOOP;

    RAISE NOTICE 'Test 671: tutto OK';
END $$;
ROLLBACK;
