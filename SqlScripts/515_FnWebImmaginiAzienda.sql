-- Tutte le immagini della galleria di un'azienda, per il picker della newsletter.
--
-- Il picker dell'itinerario mostra le foto di UN tour, perche' un passo appartiene a quel tour.
-- Una newsletter invece pesca da tutto il repertorio: la testata puo' essere una foto qualsiasi,
-- e chi la compone non ragiona per tour ma per "quella bella foto del Supramonte".
--
-- Il nome del viaggio torna come contesto: senza, l'utente vede una parete di miniature
-- indistinguibili e non sa cosa sta scegliendo.

CREATE OR REPLACE FUNCTION fn_web_immagini_azienda(p_azienda_id INTEGER)
RETURNS TABLE(
    url          VARCHAR,
    storage_path VARCHAR,
    alt_text     VARCHAR,
    contesto     VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT i.url,
           i.storage_path,
           COALESCE(NULLIF(BTRIM(i.alt_text), ''), NULLIF(BTRIM(i.titolo), ''))::VARCHAR AS alt_text,
           (v.viaggio_descrizione_breve ||
            CASE WHEN d.data_viaggio_data_inizio IS NOT NULL
                 THEN ' — ' || TO_CHAR(d.data_viaggio_data_inizio, 'DD/MM/YYYY')
                 ELSE '' END)::VARCHAR AS contesto
      FROM web_tour_immagini i
      JOIN web_tour_contenuti c ON c.web_tour_contenuti_id = i.web_tour_contenuti_id_fk
      JOIN ana_date_viaggi    d ON d.data_viaggio_id       = c.data_viaggio_id_fk
      JOIN ana_viaggi         v ON v.viaggio_id            = d.viaggio_id_fk
     WHERE i.azienda_id = p_azienda_id
     ORDER BY d.data_viaggio_data_inizio DESC NULLS LAST,
              (i.tipo = 'principale') DESC,
              i.ordine,
              i.web_tour_immagini_id;
$$;
