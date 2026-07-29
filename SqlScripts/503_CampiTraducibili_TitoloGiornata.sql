-- Il titolo della giornata entra fra i campi traducibili. Segue lo script 499.
--
-- Perché: i titoli ("GIORNO 1 : Olbia - Monte Limbara - Tempio") compaiono nell'itinerario mostrato
-- al cliente. Restando fuori dai campi tradotti, una scheda in inglese avrebbe avuto testi tradotti
-- e intestazioni delle giornate in italiano.
--
-- ⚠️ CONSEGUENZA IMMEDIATA su dati esistenti: il denominatore del semaforo Traduzioni cresce di una
-- voce per ogni giornata, quindi i tour già tradotti e approvati tornano INCOMPLETI (e non
-- pubblicabili) finché non si traducono anche i titoli. È il comportamento voluto: prima quei titoli
-- sarebbero finiti sul sito non tradotti senza che nessuno lo segnalasse.

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
-- Titolo delle giornate dell'itinerario (script 503).
SELECT 'web_tour_itinerario'::VARCHAR, i.web_tour_itinerario_id, 'titolo_giornata'::VARCHAR
  FROM c
  JOIN web_tour_itinerario i ON i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id
                            AND i.azienda_id = p_azienda_id
 WHERE COALESCE(i.titolo_giornata, '') ~ '[^[:space:]]'

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
'Campi traducibili di una edizione (entita, entita_id, campo), titoli delle giornate inclusi (503). Unica definizione: la usano fn_web_tour_stato_sezioni, fn_web_traduzioni_approva_contenuto e fn_web_traduzioni_per_contenuto. Va tenuta allineata a WebTraduzioneOrchestratorService.GetTranslatableItemsAsync.';
