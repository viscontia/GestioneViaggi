-- ============================================================================
-- Test dello script 680. Transazione annullata: niente resta scritto.
-- Prima dello script deve FALLIRE (i meta arrivano in italiano in ogni lingua).
-- ============================================================================
BEGIN;
DO $$
DECLARE
    r record;
    n_tradotti integer := 0;
    v_id bigint;
    v_titolo varchar;
    v_descr varchar;
BEGIN
    -- 1. Ogni tour pubblicato con un meta tradotto (non obsoleto) lo riceve nella sua lingua.
    FOR r IN
        SELECT p.lingua, t.contenuto_id, t.meta_title, t.meta_description,
               tt.testo AS tit_trad, td.testo AS des_trad
          FROM unnest(ARRAY['EN','DE','FR','ES']) AS p(lingua)
         CROSS JOIN LATERAL fn_web_tour_pubblicati(2, p.lingua::char(2)) t
          LEFT JOIN web_traduzioni tt ON tt.entita = 'web_tour_contenuti' AND tt.entita_id = t.contenuto_id
               AND tt.campo = 'meta_title' AND tt.lingua = p.lingua AND NOT tt.obsoleto
          LEFT JOIN web_traduzioni td ON td.entita = 'web_tour_contenuti' AND td.entita_id = t.contenuto_id
               AND td.campo = 'meta_description' AND td.lingua = p.lingua AND NOT td.obsoleto
    LOOP
        IF NULLIF(btrim(r.tit_trad), '') IS NOT NULL THEN
            ASSERT r.meta_title = btrim(r.tit_trad),
                format('meta_title non tradotto: %s %s → %s', r.lingua, r.contenuto_id, r.meta_title);
            n_tradotti := n_tradotti + 1;
        END IF;
        IF NULLIF(btrim(r.des_trad), '') IS NOT NULL THEN
            ASSERT r.meta_description = btrim(r.des_trad),
                format('meta_description non tradotta: %s %s', r.lingua, r.contenuto_id);
        END IF;
    END LOOP;
    ASSERT n_tradotti > 0, 'nessun meta tradotto da provare: il test non proverebbe niente';

    -- 2. In italiano il risultato è quello di sempre: meta del gestionale, ripiego su titolo/sottotitolo.
    FOR r IN SELECT t.*, c.meta_title AS c_tit, c.meta_description AS c_des, c.sottotitolo AS c_sott
               FROM fn_web_tour_pubblicati(2, 'IT') t
               JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = t.contenuto_id
    LOOP
        ASSERT r.meta_title = COALESCE(NULLIF(btrim(r.c_tit), ''), r.titolo), 'IT cambiato (titolo): ' || r.contenuto_id;
        ASSERT r.meta_description IS NOT DISTINCT FROM COALESCE(NULLIF(btrim(r.c_des), ''), r.sottotitolo),
            'IT cambiato (descrizione): ' || r.contenuto_id;
    END LOOP;

    -- 3. Ripieghi in un'altra lingua: senza meta tradotto, titolo → meta italiano; descrizione →
    --    sottotitolo TRADOTTO (meglio di una meta descrizione italiana su una pagina inglese).
    SELECT t.contenuto_id INTO v_id FROM fn_web_tour_pubblicati(2, 'EN') t
     WHERE EXISTS (SELECT 1 FROM web_traduzioni s WHERE s.entita = 'web_tour_contenuti'
                     AND s.entita_id = t.contenuto_id AND s.campo = 'sottotitolo' AND s.lingua = 'EN'
                     AND NOT s.obsoleto AND btrim(s.testo) <> '')
     LIMIT 1;
    ASSERT v_id IS NOT NULL, 'serve un tour con il sottotitolo inglese';
    UPDATE web_traduzioni SET obsoleto = true
     WHERE entita = 'web_tour_contenuti' AND entita_id = v_id AND lingua = 'EN'
       AND campo IN ('meta_title', 'meta_description');
    SELECT t.meta_title, t.meta_description INTO v_titolo, v_descr
      FROM fn_web_tour_pubblicati(2, 'EN') t WHERE t.contenuto_id = v_id;
    ASSERT v_titolo = (SELECT COALESCE(NULLIF(btrim(c.meta_title), ''), fn_web_titolo_leggibile(v.viaggio_descrizione_breve))
                         FROM web_tour_contenuti c JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk
                        WHERE c.web_tour_contenuti_id = v_id),
        'ripiego del titolo: atteso il meta italiano, ottenuto ' || v_titolo;
    ASSERT v_descr = (SELECT btrim(s.testo) FROM web_traduzioni s WHERE s.entita = 'web_tour_contenuti'
                        AND s.entita_id = v_id AND s.campo = 'sottotitolo' AND s.lingua = 'EN' AND NOT s.obsoleto),
        'ripiego della descrizione: atteso il sottotitolo inglese, ottenuto ' || v_descr;

    -- 4. Una traduzione vuota o di soli spazi vale come mancante.
    UPDATE web_traduzioni SET obsoleto = false, testo = '   '
     WHERE entita = 'web_tour_contenuti' AND entita_id = v_id AND lingua = 'EN' AND campo = 'meta_title';
    SELECT t.meta_title INTO v_titolo FROM fn_web_tour_pubblicati(2, 'EN') t WHERE t.contenuto_id = v_id;
    ASSERT btrim(v_titolo) <> '', 'una traduzione di soli spazi non deve dare un titolo vuoto';

    -- 5. Stessa firma, stesse colonne, stessi permessi: il sito e il gestionale non se ne accorgono.
    ASSERT (SELECT pg_get_function_identity_arguments(p.oid) FROM pg_proc p WHERE p.proname = 'fn_web_tour_pubblicati')
           = 'p_azienda_id integer, p_lingua character', 'firma cambiata';
    ASSERT (SELECT pg_get_function_result(p.oid) FROM pg_proc p WHERE p.proname = 'fn_web_tour_pubblicati')
           LIKE '%meta_title character varying, meta_description character varying%', 'colonne cambiate';
    -- (dal 684 dopo meta_description c'è anche «paese»: si controlla che le colonne meta ci siano)
    ASSERT has_function_privilege('anon', 'fn_web_tour_pubblicati(integer, character)', 'EXECUTE'),
        'anon deve poter chiamare la funzione';
    ASSERT (SELECT p.prosecdef FROM pg_proc p WHERE p.proname = 'fn_web_tour_pubblicati'), 'deve restare SECURITY DEFINER';

    RAISE NOTICE 'Test 680: OK (% meta titoli tradotti controllati)', n_tradotti;
END $$;
ROLLBACK;
