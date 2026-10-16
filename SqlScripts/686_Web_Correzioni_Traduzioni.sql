-- ============================================================================
-- 686 — Correzioni di traduzioni (dati): il marchio non si traduce; i nomi
-- delle sezioni nelle 4 lingue (Tappa 3 del sito)
--
-- 1. In tre meta titoli il marchio era stato tradotto («Off Track Travel»,
--    «Hors Piste Travel»): il marchio è un nome, resta «Fuori Traccia Travel».
--    Si cambia solo il marchio, il resto del testo resta quello rivisto.
-- 2. I nomi delle 5 sezioni del sito non avevano traduzioni: il menu e le
--    pagine in EN/DE/FR/ES li mostravano in italiano. Traduzioni globali (la
--    tabella delle sezioni è comune), salvate come fa il gestionale
--    (WebTipoDescrizioneTraduzioniDialog: azienda corrente, letture globali).
--
-- Autorizzazione di Adriano (2026-10-16) a farlo direttamente, anche in PROD.
-- revisionato = true. Una traduzione di sezione già presente non si tocca.
-- Rigiocabile.
-- ============================================================================
BEGIN;

UPDATE web_traduzioni
   SET testo = replace(replace(testo, 'Off Track Travel', 'Fuori Traccia Travel'), 'Hors Piste Travel', 'Fuori Traccia Travel'),
       updated = now(), updated_by = 'claude-686'
 WHERE testo LIKE '%Off Track Travel%' OR testo LIKE '%Hors Piste Travel%';

INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto,
                            data_traduzione, azienda_id, created_by)
SELECT 'web_tipi_viaggio_descrizioni', d.web_tipi_viaggio_descrizioni_id, 'descrizione_web', x.lingua, x.testo,
       true, true, false, now(), 2, 'claude-686'
  FROM (VALUES
    ('viaggi-4x4',            'EN', '4x4 Tours'),
    ('viaggi-4x4',            'DE', '4x4-Reisen'),
    ('viaggi-4x4',            'FR', 'Voyages en 4x4'),
    ('viaggi-4x4',            'ES', 'Viajes en 4x4'),
    ('viaggi-in-moto',        'EN', 'Motorcycle Tours'),
    ('viaggi-in-moto',        'DE', 'Motorradreisen'),
    ('viaggi-in-moto',        'FR', 'Voyages à moto'),
    ('viaggi-in-moto',        'ES', 'Viajes en moto'),
    ('viaggi-in-quad-e-ssv',  'EN', 'Quad and SSV Tours'),
    ('viaggi-in-quad-e-ssv',  'DE', 'Quad- und SSV-Reisen'),
    ('viaggi-in-quad-e-ssv',  'FR', 'Voyages en quad et SSV'),
    ('viaggi-in-quad-e-ssv',  'ES', 'Viajes en quad y SSV'),
    ('escursioni-e-bike-mtb', 'EN', 'E-bike MTB Excursions'),
    ('escursioni-e-bike-mtb', 'DE', 'E-MTB-Touren'),
    ('escursioni-e-bike-mtb', 'FR', 'Excursions en VTT électrique'),
    ('escursioni-e-bike-mtb', 'ES', 'Excursiones en e-bike MTB'),
    ('esperienze',            'EN', 'Experiences'),
    ('esperienze',            'DE', 'Erlebnisse'),
    ('esperienze',            'FR', 'Expériences'),
    ('esperienze',            'ES', 'Experiencias')
  ) AS x(slug, lingua, testo)
  JOIN web_tipi_viaggio_descrizioni d ON d.slug = x.slug
ON CONFLICT (entita, entita_id, campo, lingua) DO NOTHING;

COMMIT;

-- ============================================================================
-- Verifica: Test_686_Web_Correzioni_Traduzioni.sql
-- ============================================================================
