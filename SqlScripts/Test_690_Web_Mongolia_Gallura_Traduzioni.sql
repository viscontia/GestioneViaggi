-- ============================================================================
-- Test dello script 690. Dove l'italiano è quello tradotto (PROD), prima dello
-- script deve FALLIRE; dove la scheda è diversa (copia locale) si salta.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    r record;
    v_trad integer;
    v_rev  integer;
BEGIN
    FOR r IN SELECT c.web_tour_contenuti_id AS id, c.slug FROM web_tour_contenuti c
              WHERE (c.slug = 'mongolia-in-fuoristrada-2027-05-27' AND md5(c.info_equipaggiamento_html) = 'b9bfff32803939afb610632516d62477')
                 OR (c.slug = 'tour-enduro-gallura-2027-03-11' AND c.durata_testo = '3 giorni / 2 notti'
                     AND c.sottotitolo = 'Tra granito e macchia mediterranea')
    LOOP
        -- semaforo «Traduzioni» completo (revisionate >= traducibili × 4)
        SELECT count(*) INTO v_trad FROM fn_web_tour_campi_traducibili(r.id, 2);
        SELECT count(*) INTO v_rev
          FROM fn_web_tour_campi_traducibili(r.id, 2) f
          JOIN web_traduzioni t ON t.entita = f.entita AND t.entita_id = f.entita_id AND t.campo = f.campo
                               AND t.lingua IN ('EN','DE','FR','ES') AND NOT t.obsoleto AND t.revisionato;
        ASSERT v_rev >= v_trad * 4, format('%s: semaforo incompleto, %s revisionate su %s', r.slug, v_rev, v_trad * 4);
        -- nessuna traduzione in maiuscolo rimasta per i due campi di Gallura
        ASSERT NOT EXISTS (SELECT 1 FROM web_traduzioni t WHERE t.entita = 'web_tour_contenuti' AND t.entita_id = r.id
                            AND t.campo IN ('durata_testo', 'sottotitolo') AND t.testo = upper(t.testo) AND t.testo ~ '[A-Z]{3}'),
            r.slug || ': traduzione ancora in maiuscolo';
    END LOOP;
    -- il sito le mostra tradotte
    IF EXISTS (SELECT 1 FROM fn_web_tour_pubblicati(2, 'EN') WHERE slug = 'tour-enduro-gallura-2027-03-11'
                AND (SELECT sottotitolo FROM web_tour_contenuti WHERE slug = 'tour-enduro-gallura-2027-03-11') = 'Tra granito e macchia mediterranea') THEN
        ASSERT (SELECT sottotitolo FROM fn_web_tour_pubblicati(2, 'EN') WHERE slug = 'tour-enduro-gallura-2027-03-11')
               = 'Between granite and Mediterranean scrub', 'Gallura: sottotitolo inglese';
    END IF;
    RAISE NOTICE 'Test 690: OK';
END $$;
ROLLBACK;
