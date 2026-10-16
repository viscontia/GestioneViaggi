-- ============================================================================
-- Test dello script 684. Transazione annullata: le traduzioni di prova spariscono.
-- Prima dello script deve FALLIRE (titolo e sezione non tradotti, niente paese).
-- Viaggio di prova: il Ponte dell'Immacolata (741), pubblicato in locale e in PROD.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    r       record;
    v_viag  integer := 741;
    v_slug  varchar;
    v_sez   bigint;
    v_cont  bigint;
    v_it    varchar;
BEGIN
    SELECT p.slug, c.web_tour_contenuti_id INTO v_slug, v_cont
      FROM fn_web_tour_pubblicati(2, 'IT') p JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = p.contenuto_id
     WHERE p.viaggio_id = v_viag;
    ASSERT v_slug IS NOT NULL, 'il viaggio di prova 741 deve essere pubblicato';
    SELECT d.web_tipi_viaggio_descrizioni_id INTO v_sez
      FROM ana_viaggi v JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
     WHERE v.viaggio_id = v_viag;

    -- 1. in italiano titolo e sezione sono quelli di prima (forma leggibile, nome della sezione)
    FOR r IN SELECT p.*, v.viaggio_descrizione_breve AS breve, d.descrizione_web AS sez_it
               FROM fn_web_tour_pubblicati(2, 'IT') p
               JOIN ana_viaggi v ON v.viaggio_id = p.viaggio_id
               JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
               JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk LOOP
        ASSERT r.titolo = fn_web_titolo_leggibile(r.breve), 'IT: titolo cambiato per ' || r.slug;
        ASSERT r.descrizione_web = r.sez_it, 'IT: nome della sezione cambiato per ' || r.slug;
        ASSERT r.paese IS NOT DISTINCT FROM (SELECT ec.iso_alpha2 FROM ana_viaggi v2 JOIN eba_countries ec ON ec.country_id = v2.viaggio_nazione_fk WHERE v2.viaggio_id = r.viaggio_id),
            'colonna paese mancante o sbagliata: ' || r.slug;
    END LOOP;

    -- 2. titolo tradotto: inglese se c'è, leggibile italiano se manca o è obsoleto
    -- (dal 685 la traduzione esiste già: la si sovrascrive, con spazi da ripulire)
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('ana_viaggi', v_viag, 'viaggio_descrizione_breve', 'EN', '  Immaculate Conception Bridge in 4x4 ', 2, 'test684')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo, obsoleto = false;
    DELETE FROM web_traduzioni WHERE entita = 'ana_viaggi' AND entita_id = v_viag AND campo = 'viaggio_descrizione_breve' AND lingua = 'DE';
    ASSERT (SELECT titolo FROM fn_web_tour_pubblicati(2, 'EN') WHERE viaggio_id = v_viag) = 'Immaculate Conception Bridge in 4x4',
        'EN: titolo non tradotto (o non ripulito dagli spazi)';
    v_it := (SELECT titolo FROM fn_web_tour_pubblicati(2, 'IT') WHERE viaggio_id = v_viag);
    ASSERT v_it = fn_web_titolo_leggibile((SELECT viaggio_descrizione_breve FROM ana_viaggi WHERE viaggio_id = v_viag)), 'IT: la traduzione non deve toccare l''italiano';
    ASSERT (SELECT titolo FROM fn_web_tour_pubblicati(2, 'DE') WHERE viaggio_id = v_viag) = v_it, 'DE senza traduzione: titolo italiano';
    ASSERT fn_web_tour_scheda(2, v_slug, 'EN')->'tour'->>'titolo' = 'Immaculate Conception Bridge in 4x4', 'anche la scheda ha il titolo tradotto';
    UPDATE web_traduzioni SET obsoleto = true WHERE entita = 'ana_viaggi' AND entita_id = v_viag AND campo = 'viaggio_descrizione_breve';
    ASSERT (SELECT titolo FROM fn_web_tour_pubblicati(2, 'EN') WHERE viaggio_id = v_viag) = v_it, 'traduzione obsoleta: titolo italiano';

    -- 3. nome della sezione tradotto nei tour (prima usciva sempre in italiano)
    INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, azienda_id, created_by)
    VALUES ('web_tipi_viaggio_descrizioni', v_sez, 'descrizione_web', 'EN', '4x4 trips', 2, 'test684')
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE SET testo = EXCLUDED.testo, obsoleto = false;
    ASSERT (SELECT descrizione_web FROM fn_web_tour_pubblicati(2, 'EN') WHERE viaggio_id = v_viag) = '4x4 trips', 'EN: sezione non tradotta';
    ASSERT (SELECT nome FROM fn_web_sezioni_tipologia(2, 'EN') WHERE sezione_id = v_sez) = '4x4 trips', 'il menu usa la stessa traduzione';
    ASSERT (SELECT descrizione_web FROM fn_web_tour_pubblicati(2, 'IT') WHERE viaggio_id = v_viag)
         = (SELECT descrizione_web FROM web_tipi_viaggio_descrizioni WHERE web_tipi_viaggio_descrizioni_id = v_sez), 'IT: sezione invariata';

    -- 4. il titolo è fra i campi da tradurre (il testo di partenza leggibile lo dà il gestionale, in C#)
    ASSERT EXISTS (SELECT 1 FROM fn_web_tour_campi_traducibili(v_cont, 2)
                    WHERE entita = 'ana_viaggi' AND entita_id = v_viag AND campo = 'viaggio_descrizione_breve'),
        'il titolo deve essere fra i campi traducibili';
    ASSERT (SELECT n_traducibili FROM fn_web_tour_stato_sezioni(v_cont, 2, ARRAY['EN','DE','FR','ES']))
         = (SELECT count(*) FROM fn_web_tour_campi_traducibili(v_cont, 2)),
        'il semaforo conta gli stessi campi';

    -- 5. permessi di fn_web_tour_pubblicati ricreata: gli stessi di prima
    ASSERT has_function_privilege('anon', 'fn_web_tour_pubblicati(integer, character)', 'EXECUTE'), 'anon';
    ASSERT has_function_privilege('authenticated', 'fn_web_tour_pubblicati(integer, character)', 'EXECUTE'), 'authenticated';
    ASSERT has_function_privilege('service_role', 'fn_web_tour_pubblicati(integer, character)', 'EXECUTE'), 'service_role';
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_tour_pubblicati'), 'SECURITY DEFINER';
    -- le funzioni che la usano rispondono ancora
    ASSERT (SELECT count(*) FROM fn_web_sezioni_tipologia(2, 'IT')) > 0, 'menu';
    ASSERT (SELECT count(*) FROM fn_web_tour_slug_stato(2)) > 0, 'stati degli slug';
    ASSERT fn_web_tour_scheda(2, v_slug, 'IT') IS NOT NULL, 'scheda';

    RAISE NOTICE 'Test 684: OK';
END $$;
ROLLBACK;
