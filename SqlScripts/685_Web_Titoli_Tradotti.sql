-- ============================================================================
-- 685 — I titoli dei tour tradotti (dati), PRIMA che il 684 li renda obbligatori
--
-- Il 684 aggiunge il titolo ai campi da tradurre. Senza le traduzioni, il
-- semaforo «Traduzioni» di ogni scheda diventerebbe incompleto e, al primo
-- salvataggio, il gestionale riporterebbe a bozza i tour pubblicati (escono dal
-- sito). Decisione di Adriano (2026-10-16): le traduzioni dei titoli entrano
-- PRIMA del 684, già revisionate, per tutte le 11 schede (7 pubblicate, 4 bozze).
-- Autorizzazione di Adriano a farlo direttamente, anche in PROD.
--
-- Criterio (coerente con i meta titoli già rivisti da Antonio):
--   - i NOMI DI PRODOTTO restano uguali in ogni lingua (Maxi Enduro Gran Tour
--     Sardegna, Ichnusa Tour, Tour Enduro Gallura, Sardegna SSV Gran Tour, Wild
--     Marocco);
--   - i titoli descrittivi si traducono.
-- tradotto_auto = true (preparati da Claude), revisionato = true (autorizzato da
-- Adriano). Chi li vuole cambiare lo fa dal gestionale, come ogni traduzione.
--
-- Si inserisce solo per i viaggi che esistono nell'azienda 2; una traduzione già
-- presente non si tocca (ON CONFLICT DO NOTHING). Rigiocabile.
-- ============================================================================
BEGIN;

INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto,
                            data_traduzione, azienda_id, created_by)
SELECT 'ana_viaggi', x.viaggio, 'viaggio_descrizione_breve', x.lingua, x.testo, true, true, false, now(), 2, 'claude-685'
  FROM (VALUES
    (622, 'EN', 'Easter in Barbagia'),
    (622, 'DE', 'Ostern in Barbagia'),
    (622, 'FR', 'Pâques en Barbagia'),
    (622, 'ES', 'Pascua en Barbagia'),
    (681, 'EN', 'Maxi Enduro Gran Tour Sardegna'),
    (681, 'DE', 'Maxi Enduro Gran Tour Sardegna'),
    (681, 'FR', 'Maxi Enduro Gran Tour Sardegna'),
    (681, 'ES', 'Maxi Enduro Gran Tour Sardegna'),
    (722, 'EN', 'New Year''s Eve Off-Road – 8 days'),
    (722, 'DE', 'Silvester im Geländewagen – 8 Tage'),
    (722, 'FR', 'Nouvel An en tout-terrain – 8 jours'),
    (722, 'ES', 'Fin de Año en todoterreno – 8 días'),
    (741, 'EN', 'Immaculate Conception Bridge in 4x4'),
    (741, 'DE', 'Brückentag im Geländewagen'),
    (741, 'FR', 'Pont de l''Immaculée en 4x4'),
    (741, 'ES', 'Puente de la Inmaculada en 4x4'),
    (762, 'EN', 'New Year''s Eve in Ogliastra 2026 (6 days)'),
    (762, 'DE', 'Silvester in Ogliastra 2026 (6 Tage)'),
    (762, 'FR', 'Nouvel An en Ogliastra 2026 (6 jours)'),
    (762, 'ES', 'Año Nuevo en Ogliastra 2026 (6 días)'),
    (801, 'EN', 'Ichnusa Tour'),
    (801, 'DE', 'Ichnusa Tour'),
    (801, 'FR', 'Ichnusa Tour'),
    (801, 'ES', 'Ichnusa Tour'),
    (821, 'EN', 'Tour Enduro Gallura'),
    (821, 'DE', 'Tour Enduro Gallura'),
    (821, 'FR', 'Tour Enduro Gallura'),
    (821, 'ES', 'Tour Enduro Gallura'),
    (906, 'EN', 'Andalusia – Deserts and Secrets'),
    (906, 'DE', 'Andalusien – Wüsten und Geheimnisse'),
    (906, 'FR', 'Andalousie – Déserts et Secrets'),
    (906, 'ES', 'Andalucía – Desiertos y Secretos'),
    (917, 'EN', 'Off-Road Mongolia'),
    (917, 'DE', 'Mongolei im Geländewagen'),
    (917, 'FR', 'Mongolie en tout-terrain'),
    (917, 'ES', 'Mongolia en todoterreno'),
    (918, 'EN', 'Wild Marocco'),
    (918, 'DE', 'Wild Marocco'),
    (918, 'FR', 'Wild Marocco'),
    (918, 'ES', 'Wild Marocco'),
    (919, 'EN', 'Sardegna SSV Gran Tour'),
    (919, 'DE', 'Sardegna SSV Gran Tour'),
    (919, 'FR', 'Sardegna SSV Gran Tour'),
    (919, 'ES', 'Sardegna SSV Gran Tour')
  ) AS x(viaggio, lingua, testo)
  JOIN ana_viaggi v ON v.viaggio_id = x.viaggio AND v.azienda_id = 2
ON CONFLICT (entita, entita_id, campo, lingua) DO NOTHING;

COMMIT;

-- ============================================================================
-- Verifica: Test_685_Web_Titoli_Tradotti.sql
-- ============================================================================
