-- L'albero delle partenze dice troppo poco, e una descrizione ripetuta due volte.
--
-- 1) get_viaggi_grouped_by_year non restituisce quanti clienti sono iscritti a una partenza.
--    Nell'albero si vedeva solo la data: per capire se fosse quella giusta bisognava uscire,
--    aprire i partecipanti, e tornare indietro.
--
-- 2) fn_web_newsletter_filtri_insert componeva la descrizione di una partenza — "VIAGGIO del
--    gg/mm/aaaa" — in DUE punti, uno per criterio. La stessa frase serve ora anche a video, per
--    dire all'utente cosa ha scelto: alla terza copia si sarebbe divisa in tre varianti diverse.

-- =====================================================================
-- 1) Etichetta di una partenza, in un posto solo
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_partenza_etichetta(p_data_viaggio_id INTEGER, p_azienda_id INTEGER)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT v.viaggio_descrizione_breve || ' del ' || to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY')
      FROM ana_date_viaggi d
      JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
     WHERE d.data_viaggio_id = p_data_viaggio_id
       AND d.azienda_id = p_azienda_id;
$$;

COMMENT ON FUNCTION fn_partenza_etichetta(INTEGER, INTEGER) IS
'Come si nomina una partenza quando la si mostra all''utente. NULL se non esiste per quell''azienda.';

-- =====================================================================
-- 2) L'albero porta anche il numero di iscritti
-- =====================================================================
-- Cambia il tipo restituito, quindi la function va rimossa e ricreata: CREATE OR REPLACE non
-- puo' cambiare la firma del risultato.
DROP FUNCTION IF EXISTS get_viaggi_grouped_by_year(integer);

CREATE OR REPLACE FUNCTION get_viaggi_grouped_by_year(p_azienda_id INTEGER)
RETURNS TABLE(
    anno INTEGER, viaggio_id INTEGER, viaggio_descrizione TEXT, data_viaggio_id INTEGER,
    data_inizio DATE, data_fine DATE, effettuato_sino CHAR(1), iscritti INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(YEAR FROM dv.data_viaggio_data_inizio)::integer AS anno,
        av.viaggio_id::integer,
        av.viaggio_descrizione_breve::text AS viaggio_descrizione,
        dv.data_viaggio_id::integer,
        dv.data_viaggio_data_inizio,
        dv.data_viaggio_data_fine,
        COALESCE(dv.data_viaggio_effettuato_sino, 'N')::char(1) AS effettuato_sino,
        -- Sottoquery e non JOIN + GROUP BY: una partenza senza iscritti deve comunque comparire,
        -- ed e' anzi il caso che si vuole vedere a colpo d'occhio.
        (SELECT count(*)::integer FROM mov_clienti_viaggi m
          WHERE m.data_viaggio_id_fk = dv.data_viaggio_id) AS iscritti
    FROM ana_date_viaggi dv
    JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
    WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR av.azienda_id = p_azienda_id)
      AND dv.data_viaggio_data_inizio IS NOT NULL
    ORDER BY
        anno DESC,                                      -- Anni più recenti prima
        av.viaggio_descrizione_breve,                   -- Alfabetico per viaggio
        dv.data_viaggio_data_inizio ASC;                -- Date crescenti
END;
$$;

-- =====================================================================
-- 3) I criteri della newsletter usano l'etichetta condivisa
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_web_newsletter_filtri_insert(
    p_azienda_id INTEGER, p_invio_id BIGINT, p_criterio VARCHAR,
    p_param_data DATE DEFAULT NULL, p_param_int INTEGER DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_descr VARCHAR(200); v_tmp TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM web_newsletter_invii
                    WHERE web_newsletter_invii_id = p_invio_id AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'Newsletter non trovata per questa azienda.';
    END IF;

    IF EXISTS (SELECT 1 FROM web_newsletter_invii
                WHERE web_newsletter_invii_id = p_invio_id AND stato <> 'bozza') THEN
        RAISE EXCEPTION 'I destinatari di una newsletter già spedita non si cambiano.';
    END IF;

    CASE p_criterio
        WHEN 'cliente_dal' THEN
            IF p_param_data IS NULL THEN RAISE EXCEPTION 'Serve una data.'; END IF;
            v_descr := 'Clienti in anagrafica dal ' || to_char(p_param_data, 'DD/MM/YYYY');

        WHEN 'iscritti_da_partenza' THEN
            v_tmp := fn_partenza_etichetta(p_param_int, p_azienda_id);
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Partenza non trovata per questa azienda.'; END IF;
            v_descr := 'Clienti iscritti a partenze dal ' || v_tmp || ' in poi (compresa)';

        WHEN 'iscritti_a_partenza' THEN
            v_tmp := fn_partenza_etichetta(p_param_int, p_azienda_id);
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Partenza non trovata per questa azienda.'; END IF;
            v_descr := 'Clienti iscritti a ' || v_tmp;

        WHEN 'residenza_estero' THEN
            v_descr := 'Clienti residenti all''estero';

        WHEN 'residenza_nazione' THEN
            SELECT COALESCE(n.name_it, n.name) INTO v_tmp
              FROM eba_countries n WHERE n.country_id = p_param_int;
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Nazione non trovata.'; END IF;
            v_descr := 'Clienti residenti in ' || v_tmp;

        WHEN 'mai_viaggiato_anno' THEN
            IF p_param_int IS NULL THEN RAISE EXCEPTION 'Serve un anno.'; END IF;
            v_descr := 'Clienti che nel ' || p_param_int || ' non hanno viaggiato';

        ELSE
            RAISE EXCEPTION 'Criterio "%" non riconosciuto.', p_criterio;
    END CASE;

    INSERT INTO web_newsletter_filtri(invio_id_fk, criterio, param_data, param_int, descrizione, azienda_id)
    VALUES (p_invio_id, p_criterio, p_param_data, p_param_int, v_descr, p_azienda_id)
    RETURNING web_newsletter_filtri_id INTO v_id;

    RETURN v_id;
END $$;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT count(*) INTO v FROM pg_proc WHERE proname = 'get_viaggi_grouped_by_year';
    IF v <> 1 THEN RAISE EXCEPTION 'get_viaggi_grouped_by_year ha % firme.', v; END IF;
    RAISE NOTICE 'get_viaggi_grouped_by_year -> 1 versione, ora con il numero di iscritti.';
END $$;
