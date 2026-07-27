-- La descrizione della mappa diventa obbligatoria per TUTTE le mappe, non solo per quella d'insieme.
-- Segue gli script 493-496.
--
-- Motivo: la descrizione è il nome che vede il cliente sul sito ed è il campo che viene tradotto;
-- il nome del file GPX ("provaG1.gpx") non è un ripiego accettabile. Prima era obbligatoria solo per
-- la mappa dell'intero viaggio, quindi una mappa di giornata poteva restare senza nome.
--
-- Idempotente. Il backfill precede il vincolo: su un DB con mappe già caricate senza descrizione,
-- senza di esso il NOT NULL fallirebbe.

-- 1) Backfill difensivo: chi non ha descrizione la eredita dal nome del file GPX.
UPDATE web_tour_mappa
   SET descrizione = COALESCE(NULLIF(btrim(gpx_filename), ''), 'Mappa del tour')
 WHERE COALESCE(btrim(descrizione), '') = '';

-- 2) NOT NULL sulla colonna.
ALTER TABLE web_tour_mappa ALTER COLUMN descrizione SET NOT NULL;

-- 3) Il CHECK non è più "solo per la mappa d'insieme": vale per tutte.
--    (NOT NULL da solo non basta: una stringa di soli spazi passerebbe.)
ALTER TABLE web_tour_mappa DROP CONSTRAINT IF EXISTS ck_web_tour_mappa_descrizione_insieme;
ALTER TABLE web_tour_mappa DROP CONSTRAINT IF EXISTS ck_web_tour_mappa_descrizione;
ALTER TABLE web_tour_mappa
    ADD CONSTRAINT ck_web_tour_mappa_descrizione
    CHECK (descrizione ~ '[^[:space:]]');

COMMENT ON COLUMN web_tour_mappa.descrizione IS
    'Nome mnemonico della mappa mostrato al cliente e tradotto in web_traduzioni (es. "GIORNO 1: Olbia - Monte Limbara (Sabato 2 Maggio 2026)"). Obbligatorio: distinto da gpx_filename, che è solo tracciabilità tecnica del file caricato.';
