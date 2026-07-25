-- Mappe multiple per edizione, con abbinamento dichiarato (Blocco 9 — estensione 2026-07-25).
-- Design: "Estensione Progetto WEB/Documenti/2026-07-25-Mappe_Multiple_GPX_design.md"
--
-- Da 1 mappa per edizione a N, ognuna con un significato dichiarato dall'utente:
--   - mappa dell'INTERO VIAGGIO  → web_tour_itinerario_id_fk IS NULL, descrizione obbligatoria;
--   - mappa di UNA GIORNATA      → FK verso la giornata dell'itinerario, descrizione ereditata dal titolo.
-- Non sono ammessi GPX che coprono porzioni di giornata: sarebbero irrappresentabili in modo
-- relazionale e incomprensibili per il cliente su sito e flyer. La regola è imposta qui, non nella form.
--
-- Idempotente: ADD COLUMN IF NOT EXISTS, DROP CONSTRAINT IF EXISTS prima di ADD, CREATE INDEX IF NOT EXISTS.

-- 1) Via il vincolo 1:1 ------------------------------------------------------
ALTER TABLE web_tour_mappa
    DROP CONSTRAINT IF EXISTS web_tour_mappa_web_tour_contenuti_id_fk_key;

-- 2) Colonne nuove -----------------------------------------------------------
ALTER TABLE web_tour_mappa
    ADD COLUMN IF NOT EXISTS web_tour_itinerario_id_fk BIGINT,
    ADD COLUMN IF NOT EXISTS descrizione VARCHAR(255),
    ADD COLUMN IF NOT EXISTS gpx_bytes INTEGER;

COMMENT ON COLUMN web_tour_mappa.web_tour_itinerario_id_fk IS
    'Giornata dell''itinerario a cui si riferisce la mappa. NULL = mappa dell''intero viaggio.';
COMMENT ON COLUMN web_tour_mappa.descrizione IS
    'Testo mostrato al cliente (tradotto in web_traduzioni). Obbligatorio per la mappa d''insieme.';
COMMENT ON COLUMN web_tour_mappa.gpx_bytes IS
    'Dimensione in byte (UTF-8) del GPX caricato: con gpx_filename impedisce di ricaricare lo stesso file.';

-- 3) FK COMPOSITA verso la giornata ------------------------------------------
-- Non basta una FK sul solo id giornata: impedirebbe di puntare a una giornata di un ALTRO contenuto.
-- Includendo web_tour_contenuti_id_fk nella FK, il DB garantisce che la giornata appartenga
-- alla stessa edizione della mappa. Serve un UNIQUE sulla coppia lato itinerario come target.
-- Creazione guardata invece di DROP+ADD: al secondo giro il DROP fallirebbe, perché la FK
-- fk_web_tour_mappa_itinerario dipende da questo UNIQUE (in PROD il deploy gira con ON_ERROR_STOP=1).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conname = 'uq_web_tour_itinerario_id_contenuto'
                      AND conrelid = 'web_tour_itinerario'::regclass) THEN
        ALTER TABLE web_tour_itinerario
            ADD CONSTRAINT uq_web_tour_itinerario_id_contenuto
            UNIQUE (web_tour_itinerario_id, web_tour_contenuti_id_fk);
    END IF;
END $$;

-- ON DELETE RESTRICT: eliminando una giornata che ha una mappa il DB blocca con messaggio tradotto,
-- invece di far sparire in silenzio una mappa generata lasciando il WebP orfano nel bucket.
ALTER TABLE web_tour_mappa
    DROP CONSTRAINT IF EXISTS fk_web_tour_mappa_itinerario;
ALTER TABLE web_tour_mappa
    ADD CONSTRAINT fk_web_tour_mappa_itinerario
    FOREIGN KEY (web_tour_itinerario_id_fk, web_tour_contenuti_id_fk)
    REFERENCES web_tour_itinerario (web_tour_itinerario_id, web_tour_contenuti_id_fk)
    ON DELETE RESTRICT;

-- 4) Backfill PRIMA dei vincoli ----------------------------------------------
-- Le mappe esistenti diventano mappe d'insieme: senza descrizione il CHECK del punto 6 le rifiuterebbe.
UPDATE web_tour_mappa
   SET descrizione = COALESCE(NULLIF(btrim(gpx_filename), ''), 'Mappa del tour')
 WHERE web_tour_itinerario_id_fk IS NULL
   AND COALESCE(btrim(descrizione), '') = '';

UPDATE web_tour_mappa
   SET gpx_bytes = octet_length(gpx_originale)
 WHERE gpx_originale IS NOT NULL
   AND gpx_bytes IS NULL;

-- 5) Una sola mappa per giornata, una sola mappa d'insieme -------------------
-- NULL distinti: le righe con giornata NULL (mappe d'insieme) non collidono qui,
-- sono limitate a una per edizione dall'indice parziale successivo.
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_tour_mappa_giornata
    ON web_tour_mappa (web_tour_itinerario_id_fk);

CREATE UNIQUE INDEX IF NOT EXISTS uq_web_tour_mappa_insieme
    ON web_tour_mappa (web_tour_contenuti_id_fk)
 WHERE web_tour_itinerario_id_fk IS NULL;

-- 6) Descrizione obbligatoria per la mappa d'insieme -------------------------
-- COALESCE necessario: senza, con descrizione NULL il CHECK varrebbe NULL e quindi PASSEREBBE.
ALTER TABLE web_tour_mappa
    DROP CONSTRAINT IF EXISTS ck_web_tour_mappa_descrizione_insieme;
ALTER TABLE web_tour_mappa
    ADD CONSTRAINT ck_web_tour_mappa_descrizione_insieme
    CHECK (web_tour_itinerario_id_fk IS NOT NULL
           OR COALESCE(descrizione, '') ~ '[^[:space:]]');

-- 7) Stesso GPX non ricaricabile nella stessa edizione -----------------------
-- Confronto per nome (case-insensitive) + dimensione, come richiesto.
-- NULL distinti: su una riga senza nome o senza dimensione non si può stabilire un doppione.
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_tour_mappa_gpx_dedup
    ON web_tour_mappa (web_tour_contenuti_id_fk, lower(gpx_filename), gpx_bytes);
