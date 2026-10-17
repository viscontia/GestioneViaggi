-- ============================================================================
-- Test dello script 689. Dove l'italiano è «9 giorni / 8 notti» (PROD), prima
-- dello script deve FALLIRE (traduzioni obsolete con «8 …»). Dove la scheda ha
-- ancora la durata vecchia (copia locale) non c'è nulla da verificare.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_cont bigint;
    v_trad integer;
    v_rev  integer;
BEGIN
    SELECT web_tour_contenuti_id INTO v_cont FROM web_tour_contenuti
     WHERE slug = 'andalucia-deserti-e-segreti' AND durata_testo = '9 giorni / 8 notti';
    IF v_cont IS NULL THEN
        RAISE NOTICE 'Test 689: durata italiana diversa (copia locale), nulla da verificare';
        RETURN;
    END IF;

    -- le 4 traduzioni: valide, revisionate, con 9 giorni
    ASSERT (SELECT count(*) FROM web_traduzioni WHERE entita = 'web_tour_contenuti' AND entita_id = v_cont
             AND campo = 'durata_testo' AND lingua IN ('EN','DE','FR','ES')
             AND NOT obsoleto AND revisionato AND testo LIKE '9 %') = 4, 'durata tradotta non corretta';
    -- il sito la mostra tradotta
    ASSERT (SELECT durata_testo FROM fn_web_tour_pubblicati(2, 'EN') WHERE slug = 'andalucia-deserti-e-segreti')
           = '9 days / 8 nights', 'sul sito inglese la durata non è tradotta';
    -- e il semaforo «Traduzioni» della scheda è completo (revisionate >= traducibili × 4)
    SELECT count(*) INTO v_trad FROM fn_web_tour_campi_traducibili(v_cont, 2);
    SELECT count(*) INTO v_rev
      FROM fn_web_tour_campi_traducibili(v_cont, 2) f
      JOIN web_traduzioni t ON t.entita = f.entita AND t.entita_id = f.entita_id AND t.campo = f.campo
                           AND t.lingua IN ('EN','DE','FR','ES') AND NOT t.obsoleto AND t.revisionato;
    ASSERT v_rev >= v_trad * 4, format('semaforo incompleto: %s revisionate su %s', v_rev, v_trad * 4);

    RAISE NOTICE 'Test 689: OK';
END $$;
ROLLBACK;
