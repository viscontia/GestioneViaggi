-- ============================================================================
-- Test dello script 685. Transazione annullata.
-- Prima dello script deve FALLIRE (nessun titolo tradotto).
-- ============================================================================
BEGIN;
DO $$
DECLARE r record;
BEGIN
    -- ogni viaggio con una scheda web ha il titolo nelle 4 lingue, revisionato e valido:
    -- così il semaforo «Traduzioni» resta verde quando il 684 aggiunge il titolo ai campi da tradurre
    FOR r IN SELECT DISTINCT c.viaggio_id_fk AS v FROM web_tour_contenuti c WHERE c.azienda_id = 2 LOOP
        ASSERT (SELECT count(*) FROM web_traduzioni t
                 WHERE t.entita = 'ana_viaggi' AND t.entita_id = r.v AND t.campo = 'viaggio_descrizione_breve'
                   AND t.revisionato AND NOT t.obsoleto AND btrim(t.testo) <> '' AND t.testo = btrim(t.testo)) = 4,
            'titolo non tradotto in tutte le lingue (o non revisionato): viaggio ' || r.v;
    END LOOP;
    -- mai il titolo in MAIUSCOLO: si traduce la forma leggibile
    ASSERT NOT EXISTS (SELECT 1 FROM web_traduzioni WHERE entita = 'ana_viaggi' AND campo = 'viaggio_descrizione_breve'
                        AND testo = upper(testo) AND testo ~ '[A-Z]{4}'), 'un titolo tradotto è in maiuscolo';
    RAISE NOTICE 'Test 685: OK';
END $$;
ROLLBACK;
