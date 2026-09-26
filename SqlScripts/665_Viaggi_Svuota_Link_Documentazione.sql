-- ============================================================================
-- 665 — Si svuota il «Link Documentazione» dei viaggi SFT
--
-- Il campo `ana_viaggi.viaggio_link` e' arrivato con la migrazione da Oracle:
-- nei 10 viaggi SFT (azienda 2) che lo avevano puntava alle pagine dei vecchi
-- siti (sardegnafuoritraccia.it, adventures-offroad.com). Nessuno lo legge: ne'
-- il sito di iscrizione, ne' le mail, ne' il sito nuovo (verificato il 2026-09-26).
-- Con il dominio nuovo (fuoritracciatravel.com) quei link sarebbero solo
-- indirizzi vecchi pronti a riaffiorare. Deciso da Adriano il 2026-09-26: si
-- svuotano. Il campo resta nella maschera, libero per un uso futuro.
--
-- Solo azienda 2. L'azienda 6 ha 36 link suoi e non si tocca senza una
-- decisione esplicita.
-- ============================================================================

BEGIN;

SELECT set_config('my.app_user', 'script_665', true);

UPDATE ana_viaggi
   SET viaggio_link = NULL
 WHERE azienda_id = 2
   AND viaggio_link IS NOT NULL;

COMMIT;

-- Verifica (atteso: azienda 2 → 0; azienda 6 invariata)
-- SELECT azienda_id, COUNT(*) FILTER (WHERE viaggio_link IS NOT NULL) FROM ana_viaggi GROUP BY 1 ORDER BY 1;
