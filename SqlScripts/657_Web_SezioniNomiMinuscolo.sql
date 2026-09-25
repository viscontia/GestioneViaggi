-- ============================================================================
-- I nomi delle sezioni del sito, con maiuscole e minuscole
--
-- Antonio ha creato le cinque sezioni quando la schermata «Descrizioni WEB»
-- trasformava ancora il testo in MAIUSCOLO. La schermata è stata corretta, ma i
-- nomi erano già salvati così — e sono esattamente ciò che il visitatore legge
-- nel menu del sito.
--
-- Cambia solo il maiuscolo/minuscolo: le parole restano quelle scelte da
-- Antonio. Lo SLUG NON si tocca: è l'indirizzo della pagina.
--
-- ⚠️ Ogni UPDATE confronta anche il vecchio valore: se nel frattempo Antonio ha
-- già riscritto un nome a mano, lo script non lo sovrascrive. Rieseguirlo è
-- innocuo.
--
-- ℹ️ Nessuna traduzione da marcare obsoleta: al 2026-09-25 web_traduzioni non ha
-- righe per queste sezioni.
--
-- ✅ Applicato in locale e a PROD il 2026-09-25.
-- ============================================================================

BEGIN;

UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = 'Viaggi 4x4'
 WHERE web_tipi_viaggio_descrizioni_id = 1 AND descrizione_web = 'VIAGGI 4X4';
UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = 'Viaggi in moto'
 WHERE web_tipi_viaggio_descrizioni_id = 2 AND descrizione_web = 'VIAGGI IN MOTO';
UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = 'Viaggi in quad e SSV'
 WHERE web_tipi_viaggio_descrizioni_id = 3 AND descrizione_web = 'VIAGGI IN QUAD E SSV';
UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = 'Escursioni e-bike MTB'
 WHERE web_tipi_viaggio_descrizioni_id = 4 AND descrizione_web = 'ESCURSIONI E-BIKE MTB';
UPDATE web_tipi_viaggio_descrizioni SET descrizione_web = 'Esperienze'
 WHERE web_tipi_viaggio_descrizioni_id = 5 AND descrizione_web = 'ESPERIENZE';

COMMIT;

-- Verifica
SELECT web_tipi_viaggio_descrizioni_id, descrizione_web, slug, ordine
  FROM web_tipi_viaggio_descrizioni ORDER BY ordine;
