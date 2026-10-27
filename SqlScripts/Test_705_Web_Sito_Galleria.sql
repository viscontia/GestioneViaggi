-- ============================================================================
-- Test dello script 705. Transazione annullata: i tour e le foto di prova spariscono.
-- Prima dello script deve FALLIRE (la funzione non esiste).
-- I tour di prova usano partenze dell'azienda 2 ancora senza contenuti web (scelte qui, non scritte):
-- il test non dipende da quali tour ci sono oggi. Si guardano solo le foto di prova (https://test705/…).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_j      jsonb;
    v_mie    jsonb;
    v_moto   bigint;
    v_4x4    bigint;
    d_moto_futura integer; d_moto_passata integer; d_4x4_passata integer; d_4x4_altra integer;
    c_futuro bigint; c_passato bigint; c_archiviato bigint; c_bozza bigint;
BEGIN
    -- le partenze libere: una per caso
    SELECT dv.data_viaggio_id INTO d_moto_futura FROM ana_date_viaggi dv
      JOIN ana_viaggi v ON v.viaggio_id = dv.viaggio_id_fk JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
     WHERE dv.azienda_id = 2 AND d.slug = 'viaggi-in-moto' AND dv.data_viaggio_data_inizio > current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id) LIMIT 1;
    SELECT dv.data_viaggio_id INTO d_moto_passata FROM ana_date_viaggi dv
      JOIN ana_viaggi v ON v.viaggio_id = dv.viaggio_id_fk JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
     WHERE dv.azienda_id = 2 AND d.slug = 'viaggi-in-moto' AND dv.data_viaggio_data_inizio < current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id) LIMIT 1;
    SELECT dv.data_viaggio_id INTO d_4x4_passata FROM ana_date_viaggi dv
      JOIN ana_viaggi v ON v.viaggio_id = dv.viaggio_id_fk JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
     WHERE dv.azienda_id = 2 AND d.slug = 'viaggi-4x4' AND dv.data_viaggio_data_inizio < current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id)
     ORDER BY dv.data_viaggio_id LIMIT 1;
    SELECT dv.data_viaggio_id INTO d_4x4_altra FROM ana_date_viaggi dv
      JOIN ana_viaggi v ON v.viaggio_id = dv.viaggio_id_fk JOIN ana_tipo_viaggi tv ON tv.tipo_viaggi_id = v.viaggio_tipo_viaggio_fk
      JOIN web_tipi_viaggio_descrizioni d ON d.web_tipi_viaggio_descrizioni_id = tv.descrizione_web_fk
     WHERE dv.azienda_id = 2 AND d.slug = 'viaggi-4x4' AND dv.data_viaggio_data_inizio < current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id)
     ORDER BY dv.data_viaggio_id DESC LIMIT 1;
    ASSERT d_moto_futura IS NOT NULL AND d_moto_passata IS NOT NULL AND d_4x4_passata IS NOT NULL
           AND d_4x4_altra IS NOT NULL AND d_4x4_altra <> d_4x4_passata, 'mancano partenze libere per i tour di prova';

    INSERT INTO web_tour_contenuti (viaggio_id_fk, data_viaggio_id_fk, slug, stato_pubblicazione, data_pubblicazione, azienda_id, created_by)
    SELECT dv.viaggio_id_fk, dv.data_viaggio_id, x.slug, x.stato, CASE WHEN x.stato <> 'bozza' THEN now() END, 2, 'test705'
      FROM (VALUES (d_moto_futura, 'test705-futuro', 'pubblicato'), (d_moto_passata, 'test705-passato', 'pubblicato'),
                   (d_4x4_passata, 'test705-archiviato', 'archiviato'), (d_4x4_altra, 'test705-bozza', 'bozza')) x(d, slug, stato)
      JOIN ana_date_viaggi dv ON dv.data_viaggio_id = x.d;
    SELECT web_tour_contenuti_id INTO c_futuro FROM web_tour_contenuti WHERE slug = 'test705-futuro' AND azienda_id = 2;
    SELECT web_tour_contenuti_id INTO c_passato FROM web_tour_contenuti WHERE slug = 'test705-passato' AND azienda_id = 2;
    SELECT web_tour_contenuti_id INTO c_archiviato FROM web_tour_contenuti WHERE slug = 'test705-archiviato' AND azienda_id = 2;
    SELECT web_tour_contenuti_id INTO c_bozza FROM web_tour_contenuti WHERE slug = 'test705-bozza' AND azienda_id = 2;

    INSERT INTO web_tour_immagini (web_tour_contenuti_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, ordine, azienda_id, created_by)
    VALUES (c_futuro,    'galleria',   'https://test705/f2.webp', 'tour/2/f2.webp', NULL, NULL, 800, 600, 2, 2, 'test705'),
           (c_futuro,    'galleria',   'https://test705/f1.webp', 'tour/2/f1.webp', 'Duna al tramonto', NULL, 800, 600, 1, 2, 'test705'),
           (c_futuro,    'principale', 'https://test705/p.webp',  'tour/2/p.webp',  NULL, NULL, 800, 600, 1, 2, 'test705'),
           (c_passato,   'galleria',   'https://test705/f1.webp', 'tour/2/f1.webp', 'Duna al tramonto', NULL, 800, 600, 1, 2, 'test705'),   -- la stessa foto in un'altra edizione
           (c_passato,   'galleria',   'https://test705/s1.webp', 'tour/2/s1.webp', NULL, 'Guado', 600, 900, 1, 2, 'test705'),
           (c_archiviato,'galleria',   'https://test705/a1.webp', 'tour/2/a1.webp', NULL, NULL, 800, 600, 1, 2, 'test705'),
           (c_bozza,     'galleria',   'https://test705/b1.webp', 'tour/2/b1.webp', NULL, NULL, 800, 600, 1, 2, 'test705');

    -- il caso «pubblicato e con partenza futura» dev'essere davvero in vendita, altrimenti il test non prova il link
    ASSERT EXISTS (SELECT 1 FROM fn_web_tour_pubblicati(2, 'IT') p WHERE p.contenuto_id = c_futuro), 'il tour futuro di prova non risulta pubblicato';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_web_tour_pubblicati(2, 'IT') p WHERE p.contenuto_id IN (c_passato, c_archiviato)), 'passato e archiviato non sono in vendita';

    v_j := fn_web_sito_galleria(2, 'IT');
    -- solo le foto di prova, raggruppate per tipo
    SELECT jsonb_object_agg(g->>'slug', (SELECT jsonb_agg(f) FROM jsonb_array_elements(g->'foto') f WHERE f->>'url' LIKE 'https://test705/%'))
      INTO v_mie FROM jsonb_array_elements(v_j) g;

    -- 1. le bozze no, le foto principali no, ogni foto una volta sola
    ASSERT v_j::text NOT LIKE '%test705/b1%', 'foto di una bozza in galleria';
    ASSERT v_j::text NOT LIKE '%test705/p.webp%', 'foto principale in galleria';
    ASSERT (SELECT count(*) FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/f1.webp') = 1, 'foto doppia';

    -- 2. per tipo: moto (futuro + passato), 4x4 (archiviato); nell'ordine delle sezioni
    ASSERT jsonb_array_length(coalesce(nullif(v_mie->'viaggi-in-moto', 'null'::jsonb), '[]'::jsonb)) = 3, 'moto: ' || coalesce(v_mie->>'viaggi-in-moto', 'niente');
    ASSERT jsonb_array_length(coalesce(nullif(v_mie->'viaggi-4x4', 'null'::jsonb), '[]'::jsonb)) = 1, '4x4: ' || coalesce(v_mie->>'viaggi-4x4', 'niente');
    ASSERT (SELECT array_agg(g->>'slug' ORDER BY n) FROM jsonb_array_elements(v_j) WITH ORDINALITY e(g, n))
           = (SELECT array_agg(d.slug::text ORDER BY d.ordine, d.web_tipi_viaggio_descrizioni_id) FROM web_tipi_viaggio_descrizioni d
               WHERE d.slug IN (SELECT g->>'slug' FROM jsonb_array_elements(v_j) g)), 'ordine dei tipi: quello delle sezioni';
    ASSERT (SELECT bool_and(g->>'nome' IS NOT NULL) FROM jsonb_array_elements(v_j) g), 'ogni tipo ha il nome';

    -- 3. il link solo per il tour ancora in vendita; la foto condivisa porta al tour in vendita
    ASSERT (SELECT f->'link' FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/f1.webp')
           = jsonb_build_object('sezione', 'viaggi-in-moto', 'slug', 'test705-futuro'), 'link della foto condivisa';
    ASSERT (SELECT f->'link' FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/s1.webp') = 'null'::jsonb, 'tour passato: niente link';
    ASSERT (SELECT f->'link' FROM jsonb_array_elements(v_mie->'viaggi-4x4') f WHERE f->>'url' = 'https://test705/a1.webp') = 'null'::jsonb, 'tour archiviato: niente link';

    -- 4. ordine nel tipo: prima i tour più recenti, poi l'ordine delle foto del tour
    ASSERT (SELECT array_agg(f->>'url' ORDER BY n) FROM jsonb_array_elements(v_mie->'viaggi-in-moto') WITH ORDINALITY e(f, n))
           = ARRAY['https://test705/f1.webp', 'https://test705/f2.webp', 'https://test705/s1.webp'], 'ordine: ' || (v_mie->'viaggi-in-moto')::text;

    -- 5. il testo alternativo: quello della foto, poi il suo titolo, poi il titolo del tour; misure; mai il percorso interno
    ASSERT (SELECT f->>'alt' FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/f1.webp') = 'Duna al tramonto', 'alt';
    ASSERT (SELECT f->>'alt' FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/s1.webp') = 'Guado', 'alt dal titolo';
    ASSERT (SELECT f->>'alt' = f->>'tour' AND f->>'tour' <> '' FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/f2.webp'), 'alt dal titolo del tour';
    ASSERT (SELECT (f->>'larghezza')::int = 600 AND (f->>'altezza')::int = 900 FROM jsonb_array_elements(v_mie->'viaggi-in-moto') f WHERE f->>'url' = 'https://test705/s1.webp'), 'misure';
    ASSERT v_j::text NOT LIKE '%tour/2/%', 'il percorso interno dello Storage non va al pubblico';

    -- 6. nelle altre lingue il nome del tipo tradotto (se c'è); le foto le stesse
    ASSERT jsonb_array_length(fn_web_sito_galleria(2, 'DE')) = jsonb_array_length(v_j), 'stessi tipi in tedesco';

    -- 7. l'altra azienda non vede queste foto; la pagina esiste solo se c'è una foto
    ASSERT fn_web_sito_galleria(6, 'IT')::text NOT LIKE '%test705%', 'foto dell''azienda 2 nella galleria della 6';
    ASSERT fn_web_sito_pagine(2) ? 'galleria', 'con foto la pagina c''è: ' || fn_web_sito_pagine(2)::text;
    DELETE FROM web_tour_immagini WHERE web_tour_contenuti_id_fk IN
        (SELECT web_tour_contenuti_id FROM web_tour_contenuti WHERE azienda_id = 2 AND stato_pubblicazione <> 'bozza') AND tipo = 'galleria';
    ASSERT fn_web_sito_galleria(2, 'IT') = '[]'::jsonb, 'senza foto: vuota';
    ASSERT NOT fn_web_sito_pagine(2) ? 'galleria', 'senza foto: niente pagina';

    -- 8. permessi e lingua
    CREATE ROLE test705_nessuno NOLOGIN;
    ASSERT NOT has_function_privilege('test705_nessuno', 'fn_web_sito_galleria(integer, character varying)', 'EXECUTE'), 'lettura a chiunque';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        ASSERT has_function_privilege('anon', 'fn_web_sito_galleria(integer, character varying)', 'EXECUTE'), 'anon legge la galleria';
    END IF;
    ASSERT (SELECT prosecdef FROM pg_proc WHERE proname = 'fn_web_sito_galleria'), 'SECURITY DEFINER';
    BEGIN PERFORM fn_web_sito_galleria(2, 'XX'); RAISE EXCEPTION 'lingua inventata accettata';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM = 'lingua inventata accettata' THEN RAISE; END IF; END;

    RAISE NOTICE 'Test 705: OK';
END $$;
ROLLBACK;
