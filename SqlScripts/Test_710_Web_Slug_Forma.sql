-- ============================================================================
-- Test dello script 710. Transazione annullata.
-- Prima dello script deve FALLIRE (gli slug fuori forma passano).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_tipo  bigint;
    v_tour  bigint;
    v_buono text;
    v_cattivo text;
    v_rifiutati integer := 0;
BEGIN
    SELECT web_tipi_viaggio_descrizioni_id INTO v_tipo FROM web_tipi_viaggio_descrizioni ORDER BY 1 LIMIT 1;
    SELECT web_tour_contenuti_id INTO v_tour FROM web_tour_contenuti ORDER BY 1 LIMIT 1;
    ASSERT v_tipo IS NOT NULL AND v_tour IS NOT NULL, 'servono una sezione e un tour';

    -- i dati di oggi rispettano già la forma (altrimenti lo script non si applicherebbe)
    ASSERT NOT EXISTS (SELECT 1 FROM web_tipi_viaggio_descrizioni WHERE slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'), 'sezioni fuori forma';
    ASSERT NOT EXISTS (SELECT 1 FROM web_tour_contenuti WHERE slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'), 'tour fuori forma';

    -- forme rifiutate: maiuscole, spazio, trattino in testa, in coda o doppio, accento, barra, vuoto
    FOREACH v_cattivo IN ARRAY ARRAY['Viaggi-4x4', 'viaggi 4x4', '-viaggi', 'viaggi-', 'viaggi--4x4', 'perù', 'viaggi/4x4', '']
    LOOP
        BEGIN
            UPDATE web_tour_contenuti SET slug = v_cattivo WHERE web_tour_contenuti_id = v_tour;
        EXCEPTION WHEN check_violation THEN v_rifiutati := v_rifiutati + 1;
        END;
        BEGIN
            UPDATE web_tipi_viaggio_descrizioni SET slug = v_cattivo WHERE web_tipi_viaggio_descrizioni_id = v_tipo;
        EXCEPTION WHEN check_violation THEN v_rifiutati := v_rifiutati + 1;
        END;
    END LOOP;
    ASSERT v_rifiutati = 16, format('slug fuori forma rifiutati: %s su 16', v_rifiutati);

    -- forme ammesse: cifre, trattini singoli, una parola sola
    FOREACH v_buono IN ARRAY ARRAY['viaggi-4x4', 'tour-enduro-gallura-2027-03-11', 'esperienze', '4x4']
    LOOP
        UPDATE web_tour_contenuti SET slug = v_buono || '-prova-710' WHERE web_tour_contenuti_id = v_tour;
        UPDATE web_tipi_viaggio_descrizioni SET slug = v_buono || '-prova-710' WHERE web_tipi_viaggio_descrizioni_id = v_tipo;
    END LOOP;

    -- il vincolo c'è anche sul blog (oggi vuoto)
    ASSERT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_web_blog_articoli_slug_forma'), 'manca il vincolo del blog';

    RAISE NOTICE 'Test 710: OK';
END $$;
ROLLBACK;
