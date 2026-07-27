-- Verifiche non bloccanti sui contenuti web di una edizione ("controllo fatto dal software").
-- Nessun vincolo puo' intercettare queste situazioni: non sono dati incoerenti, sono dimenticanze
-- (5 giornate e 4 con foto, 6 giornate e 2 con mappa...). Costano una figuraccia sul sito, non un errore.
--
-- Come per il semaforo (fn_web_tour_stato_sezioni): qui SOLO fatti grezzi, le soglie e i testi
-- restano in C# (WebVerificheRules) — i messaggi all'utente non stanno nel database.
-- Le verifiche sulle traduzioni riusano i conteggi di fn_web_tour_stato_sezioni, non si duplicano qui.

CREATE OR REPLACE FUNCTION fn_web_tour_verifiche(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER)
RETURNS TABLE (
    n_giornate             INTEGER,
    n_giornate_senza_passi INTEGER,
    n_giornate_senza_foto  INTEGER,
    n_giornate_senza_mappa INTEGER,
    ha_mappa_insieme       BOOLEAN,
    n_immagini             INTEGER,
    ha_meta_title          BOOLEAN,
    ha_meta_description    BOOLEAN,
    ha_incluso             BOOLEAN,
    ha_escluso             BOOLEAN,
    ha_capienza            BOOLEAN)
LANGUAGE sql STABLE AS $$
WITH c AS (
    SELECT * FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_contenuto_id AND azienda_id = p_azienda_id
),
g AS (
    SELECT i.web_tour_itinerario_id,
           -- "foto della giornata" = immagine agganciata a un passaggio di quella giornata.
           EXISTS (SELECT 1 FROM web_tour_itinerario_passaggi p
                    WHERE p.itinerario_id_fk = i.web_tour_itinerario_id
                      AND COALESCE(p.immagine_storage_path, '') ~ '[^[:space:]]') AS ha_foto,
           EXISTS (SELECT 1 FROM web_tour_itinerario_passaggi p
                    WHERE p.itinerario_id_fk = i.web_tour_itinerario_id)          AS ha_passi,
           EXISTS (SELECT 1 FROM web_tour_mappa m
                    WHERE m.web_tour_itinerario_id_fk = i.web_tour_itinerario_id) AS ha_mappa
      FROM c
      JOIN web_tour_itinerario i ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                                AND i.azienda_id = p_azienda_id
)
SELECT
    (SELECT COUNT(*)::INTEGER FROM g),
    (SELECT COUNT(*)::INTEGER FROM g WHERE NOT ha_passi),
    (SELECT COUNT(*)::INTEGER FROM g WHERE NOT ha_foto),
    (SELECT COUNT(*)::INTEGER FROM g WHERE NOT ha_mappa),
    (SELECT EXISTS (SELECT 1 FROM web_tour_mappa m
                     WHERE m.web_tour_contenuti_id_fk = p_contenuto_id
                       AND m.azienda_id = p_azienda_id
                       AND m.web_tour_itinerario_id_fk IS NULL)),
    (SELECT COUNT(*)::INTEGER FROM web_tour_immagini im
      WHERE im.web_tour_contenuti_id_fk = p_contenuto_id AND im.azienda_id = p_azienda_id),
    (SELECT COALESCE(meta_title, '')       ~ '[^[:space:]]' FROM c),
    (SELECT COALESCE(meta_description, '') ~ '[^[:space:]]' FROM c),
    (SELECT COALESCE(v.viaggio_incluso, '') ~ '[^[:space:]]'
       FROM c JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk AND v.azienda_id = p_azienda_id),
    (SELECT COALESCE(v.viaggio_escluso, '') ~ '[^[:space:]]'
       FROM c JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk AND v.azienda_id = p_azienda_id),
    (SELECT COALESCE(v.viaggio_capienza_max, 0) > 0
       FROM c JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk AND v.azienda_id = p_azienda_id)
WHERE EXISTS (SELECT 1 FROM c);
$$;

COMMENT ON FUNCTION fn_web_tour_verifiche(BIGINT, INTEGER) IS
'Fatti grezzi per le verifiche NON bloccanti sui contenuti web di una edizione (giornate senza foto/mappa/passi, galleria vuota, SEO, incluso/escluso, capienza). Soglie e messaggi in C# (WebVerificheRules).';
