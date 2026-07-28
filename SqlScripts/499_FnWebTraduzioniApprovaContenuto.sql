-- Approvazione in blocco delle traduzioni di una edizione + estrazione dell'elenco campi traducibili.
-- Segue lo script 498.
--
-- Perché serve: un tour completo ha ~20 campi × 4 lingue = 80 traduzioni. Controllarle tutte a mano
-- non è realistico; l'operatore ne verifica alcune a campione e poi approva il resto. Senza questo,
-- il gating introdotto dal 498 (Completo solo se revisionate) renderebbe di fatto impossibile
-- pubblicare. La condizione "almeno una revisionata per lingua" è applicata lato UI.
--
-- Nota di manutenzione: l'elenco dei campi traducibili era già duplicato dentro
-- fn_web_tour_stato_sezioni; aggiungerne una terza copia qui avrebbe garantito che prima o poi
-- divergessero. Lo si estrae quindi in fn_web_tour_campi_traducibili, unica fonte, usata da
-- entrambe. Resta da tenere allineato con WebTraduzioneOrchestratorService.GetTranslatableItemsAsync.

-- ---------------------------------------------------------------------------
-- 1) Elenco dei campi traducibili di una edizione (unica definizione)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_tour_campi_traducibili(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER)
RETURNS TABLE (entita VARCHAR, entita_id BIGINT, campo VARCHAR)
LANGUAGE sql STABLE AS $$
WITH c AS (
    SELECT * FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_contenuto_id AND azienda_id = p_azienda_id
)
-- Il test ~ '[^[:space:]]' (almeno un carattere non-spazio) replica string.IsNullOrWhiteSpace del C#.
SELECT 'web_tour_contenuti'::VARCHAR, c.web_tour_contenuti_id, x.campo::VARCHAR
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
-- Descrizioni delle mappe (intero viaggio e giornate).
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
 WHERE COALESCE(p.testo_html, '') ~ '[^[:space:]]';
$$;

COMMENT ON FUNCTION fn_web_tour_campi_traducibili(BIGINT, INTEGER) IS
'Campi traducibili di una edizione (entita, entita_id, campo). Unica definizione: la usano fn_web_tour_stato_sezioni e fn_web_traduzioni_approva_contenuto. Va tenuta allineata a WebTraduzioneOrchestratorService.GetTranslatableItemsAsync.';

-- ---------------------------------------------------------------------------
-- 2) Il semaforo riusa la definizione unica
-- ---------------------------------------------------------------------------
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
    SELECT * FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_contenuto_id AND azienda_id = p_azienda_id
),
traducibili AS (
    SELECT * FROM fn_web_tour_campi_traducibili(p_contenuto_id, p_azienda_id)
),
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
'Fatti grezzi per il semaforo dei sotto-tab contenuti web di una edizione. n_tradotte = righe presenti; n_revisionate = revisionate e non obsolete (è questo che rende Completo il tab Traduzioni e sblocca la pubblicazione). Soglie in C# (WebTabStatoRules).';

-- ---------------------------------------------------------------------------
-- 3) Approvazione in blocco
-- ---------------------------------------------------------------------------
-- Marca revisionate (e non obsolete) tutte le traduzioni dei campi traducibili dell'edizione,
-- nelle lingue indicate. Ritorna il numero di righe effettivamente cambiate: quelle già a posto
-- non vengono toccate, così il conteggio dice davvero quante ne sono state approvate ora.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_approva_contenuto(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER,
    p_lingue       VARCHAR[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_traduzioni w
       SET revisionato = TRUE,
           obsoleto = FALSE
      FROM fn_web_tour_campi_traducibili(p_contenuto_id, p_azienda_id) t
     WHERE w.entita = t.entita
       AND w.entita_id = t.entita_id
       AND w.campo = t.campo
       AND w.azienda_id = p_azienda_id
       AND w.lingua = ANY (p_lingue)
       AND (NOT w.revisionato OR w.obsoleto);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

COMMENT ON FUNCTION fn_web_traduzioni_approva_contenuto(BIGINT, INTEGER, VARCHAR[]) IS
'Approva in blocco le traduzioni di una edizione (revisionato=true, obsoleto=false). Ritorna quante righe sono cambiate. La condizione "almeno una revisionata a mano per lingua" è applicata dalla UI.';
