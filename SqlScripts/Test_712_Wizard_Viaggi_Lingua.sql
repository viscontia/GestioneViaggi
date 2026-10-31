-- ============================================================================
-- Test dello script 712. Transazione annullata.
-- Prima dello script deve FALLIRE (la funzione con la lingua non c'è).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_viaggio integer;
    v_it      text;
    v_en      text;
    v_n_it    integer;
    v_n_en    integer;
BEGIN
    SELECT count(*) INTO v_n_it FROM fn_wizard_get_viaggi_disponibili(2, 'IT');
    SELECT count(*) INTO v_n_en FROM fn_wizard_get_viaggi_disponibili(2, 'en');
    ASSERT v_n_it > 0, 'nessun viaggio iscrivibile per l''azienda 2: il test non prova niente';
    ASSERT v_n_it = v_n_en, 'la lingua non deve cambiare QUALI viaggi si vedono';
    ASSERT v_n_it = (SELECT count(*) FROM fn_wizard_get_viaggi_disponibili(2)), 'stessi viaggi della funzione di prima';

    -- italiano: il titolo leggibile (non il maiuscolo dell'anagrafica)
    SELECT viaggio_id, titolo INTO v_viaggio, v_it FROM fn_wizard_get_viaggi_disponibili(2, 'IT') ORDER BY 1 LIMIT 1;
    ASSERT v_it = fn_web_titolo_leggibile((SELECT viaggio_descrizione_breve FROM ana_viaggi WHERE viaggio_id = v_viaggio)),
           'in italiano il titolo leggibile';

    -- una traduzione valida vince; una obsoleta no (come sul sito, script 684)
    DELETE FROM web_traduzioni WHERE entita = 'ana_viaggi' AND entita_id = v_viaggio AND campo = 'viaggio_descrizione_breve' AND lingua = 'EN';
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto, azienda_id, created_by)
    VALUES ('ana_viaggi', v_viaggio, 'viaggio_descrizione_breve', 'EN', 'Test trip 712', true, true, false, 2, 'test712');
    SELECT titolo INTO v_en FROM fn_wizard_get_viaggi_disponibili(2, 'EN') WHERE viaggio_id = v_viaggio;
    ASSERT v_en = 'Test trip 712', format('traduzione non usata: %s', v_en);
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'ana_viaggi' AND entita_id = v_viaggio AND lingua = 'EN' AND created_by = 'test712';
    SELECT titolo INTO v_en FROM fn_wizard_get_viaggi_disponibili(2, 'EN') WHERE viaggio_id = v_viaggio;
    ASSERT v_en = v_it, 'una traduzione obsoleta non si usa: vale l''italiano leggibile';

    -- lingua sconosciuta: italiano
    ASSERT (SELECT titolo FROM fn_wizard_get_viaggi_disponibili(2, 'XX') WHERE viaggio_id = v_viaggio) = v_it, 'lingua sconosciuta: italiano';

    -- la nazione arriva col codice ISO (il nome lo scrive il browser nella lingua del cliente)
    ASSERT NOT EXISTS (SELECT 1 FROM fn_wizard_get_viaggi_disponibili(2, 'IT') v
                        JOIN ana_viaggi a USING (viaggio_id)
                       WHERE a.viaggio_nazione_fk IS NOT NULL AND v.nazione_iso2 IS NULL), 'manca il codice ISO di una nazione';

    -- permessi: solo il proprietario (il modulo si collega così); niente pubblico
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT NOT has_function_privilege('anon', 'fn_wizard_get_viaggi_disponibili(integer, varchar)', 'EXECUTE'), 'anon non deve leggerla';
    END IF;

    RAISE NOTICE 'Test 712: OK';
END $$;
ROLLBACK;
