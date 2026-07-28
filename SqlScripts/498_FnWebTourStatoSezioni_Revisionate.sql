-- Il semaforo Traduzioni distingue "tradotte" da "REVISIONATE": segue gli script 492/495.
--
-- Prima il conteggio guardava solo l'esistenza della riga in web_traduzioni, quindi un tour con
-- 80 traduzioni automatiche mai lette risultava Completo e si poteva pubblicare. Le traduzioni
-- automatiche vanno sul sito nella lingua del cliente: pubblicarle senza che nessuno le abbia
-- approvate è il rischio che questo conteggio deve impedire.
--
-- Si aggiunge n_revisionate in coda al RETURNS TABLE (le colonne esistenti restano al loro posto,
-- così i lettori attuali non si rompono):
--   n_tradotte    = righe presenti          -> serve a distinguere "nulla di fatto" da "in corso"
--   n_revisionate = revisionato AND NOT obsoleto -> è ciò che rende il tab Completo
--
-- "obsoleto" esclude anche le traduzioni invecchiate: se l'italiano cambia dopo la traduzione,
-- i service marcano obsolete le righe (MarkObsoleteAsync) e il tour torna non pubblicabile finché
-- non vengono riviste. Pubblicare un testo tradotto da una versione superata è lo stesso problema.

-- Il RETURNS TABLE cambia (colonna in più): CREATE OR REPLACE non basta, le colonne di ritorno sono
-- parametri OUT e Postgres non ne consente la modifica. Drop esplicito, come da convenzione Blocco 13.
DROP FUNCTION IF EXISTS fn_web_tour_stato_sezioni(BIGINT, INTEGER, VARCHAR[]);

CREATE OR REPLACE FUNCTION fn_web_tour_stato_sezioni(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER,
    p_lingue       VARCHAR[])
RETURNS TABLE (
    ha_slug        BOOLEAN,
    ha_sottotitolo BOOLEAN,
    ha_descrizione BOOLEAN,
    n_immagini     INTEGER,
    ha_principale  BOOLEAN,
    n_giornate     INTEGER,
    n_traducibili  INTEGER,
    n_tradotte     INTEGER,
    n_revisionate  INTEGER)
LANGUAGE sql STABLE AS $$
WITH c AS (
    SELECT *
    FROM web_tour_contenuti
    WHERE web_tour_contenuti_id = p_contenuto_id
      AND azienda_id = p_azienda_id
),
-- Item traducibili = campi valorizzati, come in GetTranslatableItemsAsync.
-- Il test ~ '[^[:space:]]' (almeno un carattere non-spazio) replica string.IsNullOrWhiteSpace del C#.
traducibili AS (
    SELECT 'web_tour_contenuti'::VARCHAR AS entita, c.web_tour_contenuti_id AS entita_id, x.campo::VARCHAR AS campo
    FROM c
    CROSS JOIN LATERAL (VALUES
        ('sottotitolo',               c.sottotitolo::TEXT),
        ('descrizione_html',          c.descrizione_html),
        ('durata_testo',              c.durata_testo::TEXT),
        ('luoghi_visitati',           c.luoghi_visitati),
        ('info_pernottamento_html',   c.info_pernottamento_html),
        ('info_pasti_html',           c.info_pasti_html),
        ('info_equipaggiamento_html', c.info_equipaggiamento_html),
        ('altre_info_html',           c.altre_info_html),
        ('meta_title',                c.meta_title::TEXT),
        ('meta_description',          c.meta_description::TEXT)
    ) AS x(campo, valore)
    WHERE COALESCE(x.valore, '') ~ '[^[:space:]]'

    UNION ALL
    -- Incluso/Escluso vivono su ana_viaggi (livello viaggio, condivisi tra le edizioni).
    SELECT 'ana_viaggi'::VARCHAR, v.viaggio_id::BIGINT, y.campo::VARCHAR
    FROM c
    JOIN ana_viaggi v ON v.viaggio_id = c.viaggio_id_fk AND v.azienda_id = p_azienda_id
    CROSS JOIN LATERAL (VALUES
        ('viaggio_incluso', v.viaggio_incluso),
        ('viaggio_escluso', v.viaggio_escluso)
    ) AS y(campo, valore)
    WHERE COALESCE(y.valore, '') ~ '[^[:space:]]'

    UNION ALL
    -- Descrizioni delle mappe (intero viaggio e giornate) — script 495.
    SELECT 'web_tour_mappa'::VARCHAR, m.web_tour_mappa_id, 'descrizione'::VARCHAR
    FROM c
    JOIN web_tour_mappa m ON m.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                         AND m.azienda_id = p_azienda_id
    WHERE COALESCE(m.descrizione, '') ~ '[^[:space:]]'

    UNION ALL
    -- Testo dei passi dell'itinerario.
    SELECT 'web_tour_itinerario_passaggi'::VARCHAR, p.web_tour_itinerario_passaggi_id, 'testo_html'::VARCHAR
    FROM c
    JOIN web_tour_itinerario i ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                              AND i.azienda_id = p_azienda_id
    JOIN web_tour_itinerario_passaggi p ON p.itinerario_id_fk = i.web_tour_itinerario_id
                                       AND p.azienda_id = p_azienda_id
    WHERE COALESCE(p.testo_html, '') ~ '[^[:space:]]'
),
-- Le righe di traduzione che corrispondono a un campo effettivamente traducibile.
presenti AS (
    SELECT w.revisionato, w.obsoleto
      FROM traducibili t
      JOIN web_traduzioni w ON w.entita = t.entita
                           AND w.entita_id = t.entita_id
                           AND w.campo = t.campo
                           AND w.azienda_id = p_azienda_id
                           AND w.lingua = ANY (p_lingue)
)
SELECT
    (SELECT COALESCE(slug, '')             ~ '[^[:space:]]' FROM c),
    (SELECT COALESCE(sottotitolo, '')      ~ '[^[:space:]]' FROM c),
    (SELECT COALESCE(descrizione_html, '') ~ '[^[:space:]]' FROM c),
    (SELECT COUNT(*)::INTEGER FROM web_tour_immagini
      WHERE web_tour_contenuti_id_fk = p_contenuto_id AND azienda_id = p_azienda_id),
    (SELECT EXISTS (SELECT 1 FROM web_tour_immagini
                     WHERE web_tour_contenuti_id_fk = p_contenuto_id AND azienda_id = p_azienda_id
                       AND tipo = 'principale')),
    (SELECT COUNT(*)::INTEGER FROM web_tour_itinerario
      WHERE web_tour_contenuti_id_fk = p_contenuto_id AND azienda_id = p_azienda_id),
    (SELECT COUNT(*)::INTEGER FROM traducibili),
    (SELECT COUNT(*)::INTEGER FROM presenti),
    (SELECT COUNT(*)::INTEGER FROM presenti WHERE revisionato AND NOT obsoleto)
WHERE EXISTS (SELECT 1 FROM c);
$$;

COMMENT ON FUNCTION fn_web_tour_stato_sezioni(BIGINT, INTEGER, VARCHAR[]) IS
'Fatti grezzi per il semaforo dei sotto-tab contenuti web di una edizione. n_tradotte = righe presenti; n_revisionate = revisionate e non obsolete (è questo che rende Completo il tab Traduzioni e sblocca la pubblicazione). Soglie in C# (WebTabStatoRules); l''elenco dei campi traducibili deve restare allineato a WebTraduzioneOrchestratorService.GetTranslatableItemsAsync.';
