-- =====================================================================
-- 490 - UNIQUE su web_tipi_viaggio_descrizioni.ordine
-- Protezione lato DB contro ordini duplicati (anche via SQL diretto):
-- la validazione applicativa non basta. Lookup GLOBALE (nessun azienda_id),
-- quindi l'ordine deve essere univoco sull'intera tabella.
-- Idempotente.
-- =====================================================================

-- 1) Normalizza: rinumera gli ordini in sequenza contigua 1..N (per ordine, poi id),
--    risolvendo eventuali zeri o duplicati preesistenti PRIMA di aggiungere il vincolo.
--    Nessun vincolo attivo qui: l'UPDATE non può violare l'unicità.
WITH ranked AS (
    SELECT web_tipi_viaggio_descrizioni_id AS id,
           ROW_NUMBER() OVER (ORDER BY ordine, web_tipi_viaggio_descrizioni_id) AS rn
    FROM web_tipi_viaggio_descrizioni
)
UPDATE web_tipi_viaggio_descrizioni t
SET ordine = r.rn
FROM ranked r
WHERE t.web_tipi_viaggio_descrizioni_id = r.id
  AND t.ordine <> r.rn;

-- 2) Vincolo di unicità sull'ordine (idempotente: rimuove e ricrea).
ALTER TABLE web_tipi_viaggio_descrizioni
    DROP CONSTRAINT IF EXISTS uq_web_tipi_viaggio_descrizioni_ordine;
ALTER TABLE web_tipi_viaggio_descrizioni
    ADD CONSTRAINT uq_web_tipi_viaggio_descrizioni_ordine UNIQUE (ordine);
