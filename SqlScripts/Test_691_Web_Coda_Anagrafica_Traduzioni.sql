-- ============================================================================
-- Test dello script 691. Transazione annullata: modifiche e righe di coda spariscono.
-- Prima dello script deve FALLIRE (queste tabelle non avvisano la coda).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_cont  bigint;
    v_viag  integer;
    v_giorn bigint;
    v_pass  bigint;
    v_mappa bigint;
    v_sez   bigint;
    v_n     integer;
    -- c'è in attesa una riga per l'azienda 2 con questo oggetto (e riferimento, se dato)?
    c       text := 'select count(*) from web_revalidate_coda where azienda_id = 2 and completata_il is null and oggetto = $1 and coalesce(riferimento, 0) = coalesce($2, 0)';
BEGIN
    -- una scheda con giornate, passaggi e mappa
    SELECT c.web_tour_contenuti_id, c.viaggio_id_fk INTO v_cont, v_viag
      FROM web_tour_contenuti c
     WHERE c.azienda_id = 2 AND EXISTS (SELECT 1 FROM web_tour_itinerario i JOIN web_tour_itinerario_passaggi p ON p.itinerario_id_fk = i.web_tour_itinerario_id
                                         WHERE i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id)
     ORDER BY c.web_tour_contenuti_id LIMIT 1;
    SELECT i.web_tour_itinerario_id, p.web_tour_itinerario_passaggi_id INTO v_giorn, v_pass
      FROM web_tour_itinerario i JOIN web_tour_itinerario_passaggi p ON p.itinerario_id_fk = i.web_tour_itinerario_id
     WHERE i.web_tour_contenuti_id_fk = v_cont LIMIT 1;
    SELECT web_tour_mappa_id INTO v_mappa FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = v_cont LIMIT 1;
    SELECT web_tipi_viaggio_descrizioni_id INTO v_sez FROM web_tipi_viaggio_descrizioni LIMIT 1;
    ASSERT v_cont IS NOT NULL AND v_pass IS NOT NULL, 'serve una scheda con giornate e passaggi';

    -- 1. anagrafica dell'azienda (nome, P.IVA, sede, email): tutto il sito e tutti i PDF
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE ana_aziende SET ragione_sociale = ragione_sociale WHERE azienda_id = 2;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint; ASSERT v_n = 1, 'ana_aziende: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE ana_aziende_sedi SET comune_fk = comune_fk WHERE azienda_fk = 2;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint; ASSERT v_n = 1, 'ana_aziende_sedi: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE ana_aziende_email SET azienda_fk = azienda_fk WHERE azienda_fk = 2;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint;
    ASSERT v_n = 1 OR NOT EXISTS (SELECT 1 FROM ana_aziende_email WHERE azienda_fk = 2), 'ana_aziende_email: atteso menu';

    -- 2. WhatsApp e recensioni: tutto il sito
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE web_indirizzi SET azienda_id = azienda_id WHERE azienda_id = 2;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint;
    ASSERT v_n = 1 OR NOT EXISTS (SELECT 1 FROM web_indirizzi WHERE azienda_id = 2), 'web_indirizzi: atteso menu';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE web_aziende_funzioni SET azienda_id = azienda_id WHERE azienda_id = 2;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint;
    ASSERT v_n = 1 OR NOT EXISTS (SELECT 1 FROM web_aziende_funzioni WHERE azienda_id = 2), 'web_aziende_funzioni: atteso menu';

    -- 3. il nome di una sezione (tabella comune): il menu delle aziende col sito
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = descrizione_web WHERE web_tipi_viaggio_descrizioni_id = v_sez;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint; ASSERT v_n = 1, 'web_tipi_viaggio_descrizioni: atteso menu';

    -- 4. il testo di una giornata: quella scheda
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE web_tour_itinerario_passaggi SET testo_html = testo_html WHERE web_tour_itinerario_passaggi_id = v_pass;
    EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'passaggio: attesa la sua scheda';

    -- 5. le traduzioni: la scheda giusta per ogni tipo, il menu per i nomi delle sezioni
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_tour_contenuti', v_cont, 'sottotitolo', 'EN', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'traduzione della scheda: attesa la scheda';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE web_traduzioni SET testo = testo WHERE entita = 'web_tour_itinerario_passaggi' AND entita_id = v_pass AND azienda_id = 2;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_tour_itinerario_passaggi', v_pass, 'testo_html', 'DE', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'traduzione di un passaggio: attesa la scheda';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_tour_itinerario', v_giorn, 'titolo_giornata', 'FR', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'traduzione di una giornata: attesa la scheda';
    IF v_mappa IS NOT NULL THEN
        DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
        INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
        VALUES ('web_tour_mappa', v_mappa, 'descrizione', 'ES', 'prova 691', 2, 'test691')
        ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
        EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'traduzione della mappa: attesa la scheda';
    END IF;
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('ana_viaggi', v_viag, 'viaggio_incluso', 'ES', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    EXECUTE c INTO v_n USING 'tour', v_cont; ASSERT v_n = 1, 'traduzione del viaggio: attese le sue schede';
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_tipi_viaggio_descrizioni', v_sez, 'descrizione_web', 'DE', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    EXECUTE c INTO v_n USING 'menu', NULL::bigint; ASSERT v_n = 1, 'traduzione di una sezione: atteso menu';

    -- 6. una traduzione che il sito non usa (es. newsletter): nessuna riga
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_newsletter_blocchi', 999999, 'testo', 'EN', 'prova 691', 2, 'test691')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo;
    ASSERT NOT EXISTS (SELECT 1 FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL), 'traduzione estranea: nessuna riga';

    -- 7. molte modifiche insieme: una riga sola in attesa (la coda unisce i doppioni)
    DELETE FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL;
    UPDATE ana_aziende SET ragione_sociale = ragione_sociale WHERE azienda_id = 2;
    UPDATE ana_aziende SET ragione_sociale = ragione_sociale WHERE azienda_id = 2;
    UPDATE web_indirizzi SET azienda_id = azienda_id WHERE azienda_id = 2;
    ASSERT (SELECT count(*) FROM web_revalidate_coda WHERE azienda_id = 2 AND completata_il IS NULL) = 1, 'doppioni non uniti';

    RAISE NOTICE 'Test 691: OK';
END $$;
ROLLBACK;
