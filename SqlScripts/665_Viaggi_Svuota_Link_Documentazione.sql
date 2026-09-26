-- ============================================================================
-- 665 — Si svuota il «Link Documentazione» dei viaggi
--
-- Il campo `ana_viaggi.viaggio_link` e' arrivato con la migrazione da Oracle:
-- nei 10 viaggi SFT (azienda 2) che lo avevano puntava alle pagine dei vecchi
-- siti (sardegnafuoritraccia.it, adventures-offroad.com). Nessuno lo legge: ne'
-- il sito di iscrizione, ne' le mail, ne' il sito nuovo (verificato il 2026-09-26).
-- Con il dominio nuovo (fuoritracciatravel.com) quei link sarebbero solo
-- indirizzi vecchi pronti a riaffiorare. Deciso da Adriano il 2026-09-26: si
-- svuotano. Il campo resta nella maschera, libero per un uso futuro.
--
-- Tutte le aziende: la 2 (10 link) e la 6 (36 link, stessi vecchi domini).
-- Anche per la 6 lo ha deciso Adriano il 2026-09-26.
--
-- ✅ Applicato in locale e a PROD il 2026-09-26.
-- ============================================================================

BEGIN;

SELECT set_config('my.app_user', 'script_665', true);

UPDATE ana_viaggi
   SET viaggio_link = NULL
 WHERE viaggio_link IS NOT NULL;

COMMIT;

-- Verifica (atteso: 0 per ogni azienda)
-- SELECT azienda_id, COUNT(*) FILTER (WHERE viaggio_link IS NOT NULL) FROM ana_viaggi GROUP BY 1 ORDER BY 1;
