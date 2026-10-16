-- ============================================================================
-- Test dello script 686. Transazione annullata.
-- Prima dello script deve FALLIRE (sezioni non tradotte).
-- ============================================================================
BEGIN;
DO $$
DECLARE r record;
BEGIN
    -- 1. il marchio è un nome: mai tradotto nei testi del sito
    ASSERT NOT EXISTS (SELECT 1 FROM web_traduzioni WHERE testo ILIKE '%Off Track Travel%' OR testo ILIKE '%Hors Piste Travel%'),
        'il marchio è ancora tradotto in qualche testo';
    -- 2. ogni sezione ha il nome nelle 4 lingue, revisionato e valido
    FOR r IN SELECT web_tipi_viaggio_descrizioni_id AS id, descrizione_web FROM web_tipi_viaggio_descrizioni LOOP
        ASSERT (SELECT count(*) FROM web_traduzioni t WHERE t.entita = 'web_tipi_viaggio_descrizioni' AND t.entita_id = r.id
                  AND t.campo = 'descrizione_web' AND t.revisionato AND NOT t.obsoleto AND btrim(t.testo) <> '') = 4,
            'sezione non tradotta in tutte le lingue: ' || r.descrizione_web;
    END LOOP;
    -- 3. il menu del sito le mostra tradotte
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_sezioni_tipologia(2, 'DE') s JOIN web_tipi_viaggio_descrizioni d
                         ON d.web_tipi_viaggio_descrizioni_id = s.sezione_id WHERE s.nome = d.descrizione_web),
        'nel menu tedesco c''è ancora un nome italiano';
    RAISE NOTICE 'Test 686: OK';
END $$;
ROLLBACK;
