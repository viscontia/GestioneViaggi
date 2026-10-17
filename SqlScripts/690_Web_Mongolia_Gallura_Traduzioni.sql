-- ============================================================================
-- 690 — Mongolia e Gallura: traduzioni mancanti o obsolete (dati, Tappa 3 del sito)
--
-- Le ultime due schede pubblicate con il semaforo «Traduzioni» incompleto (dopo
-- Andalucia, script 689):
--   - Mongolia in fuoristrada: il testo «Equipaggiamento» non era mai stato
--     tradotto (sul sito EN/DE/FR/ES compariva in italiano);
--   - Tour Enduro Gallura: durata e sottotitolo riscritti in minuscolo in
--     italiano; le traduzioni, in MAIUSCOLO, erano diventate obsolete.
--
-- Revisionate. Ogni gruppo si applica SOLO se l'italiano è ancora quello
-- tradotto (testo uguale, o impronta md5 per il testo lungo): se Antonio lo ha
-- cambiato nel frattempo, nessun effetto. Autorizzazione di Adriano
-- (2026-10-17), anche in PROD. Rigiocabile.
-- ============================================================================
BEGIN;

-- Mongolia: «Equipaggiamento» nelle 4 lingue (mancavano: si inseriscono)
INSERT INTO web_traduzioni (entita, entita_id, campo, lingua, testo, tradotto_auto, revisionato, obsoleto,
                            data_traduzione, azienda_id, created_by)
SELECT 'web_tour_contenuti', c.web_tour_contenuti_id, 'info_equipaggiamento_html', x.lingua, x.testo,
       true, true, false, now(), c.azienda_id, 'claude-690'
  FROM (VALUES
    ('EN', '<p>Comfortable, technical clothing in layers, suited to the strong temperature swings of Mongolia. Recommended: a windproof and waterproof jacket, a fleece or light down jacket, sturdy trousers, hiking shoes, a hat, gloves and sun protection. A daypack with a water bottle, sunglasses, head torch, power bank and personal medication is useful. For the nights in the ger camps, it is also advisable to bring a small sleeping bag liner or a light sleeping bag.</p>'),
    ('DE', '<p>Bequeme, funktionelle Kleidung nach dem Zwiebelprinzip, passend zu den starken Temperaturschwankungen in der Mongolei. Empfohlen werden eine wind- und wasserdichte Jacke, eine Fleece- oder leichte Daunenjacke, robuste Hosen, Wanderschuhe, Mütze, Handschuhe und Sonnenschutz. Nützlich ist ein Tagesrucksack mit Trinkflasche, Sonnenbrille, Stirnlampe, Powerbank und persönlichen Medikamenten. Für die Übernachtungen in den Jurtencamps empfiehlt sich außerdem ein kleiner Hüttenschlafsack oder ein leichter Schlafsack.</p>'),
    ('FR', '<p>Vêtements confortables et techniques à superposer, adaptés aux fortes amplitudes thermiques de la Mongolie. Sont conseillés : une veste coupe-vent et imperméable, une polaire ou une doudoune légère, un pantalon résistant, des chaussures de randonnée, un chapeau, des gants et une protection solaire. Un sac à dos de journée avec gourde, lunettes de soleil, lampe frontale, batterie externe et médicaments personnels est utile. Pour les nuits dans les camps de yourtes, il est également conseillé d''apporter un petit drap de sac ou un sac de couchage léger.</p>'),
    ('ES', '<p>Ropa cómoda y técnica por capas, adecuada a las fuertes oscilaciones térmicas de Mongolia. Se recomiendan una chaqueta cortavientos e impermeable, un forro polar o un plumífero ligero, pantalones resistentes, calzado de trekking, gorro, guantes y protección solar. Es útil una mochila de día con cantimplora, gafas de sol, linterna frontal, batería externa y medicamentos personales. Para las noches en los campamentos de yurtas, se recomienda llevar también un saco sábana o un saco de dormir ligero.</p>')
  ) AS x(lingua, testo)
  JOIN web_tour_contenuti c ON c.slug = 'mongolia-in-fuoristrada-2027-05-27'
                           AND md5(c.info_equipaggiamento_html) = 'b9bfff32803939afb610632516d62477'
ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE
   SET testo = EXCLUDED.testo, revisionato = true, obsoleto = false, data_traduzione = now(),
       updated = now(), updated_by = 'claude-690';

-- Gallura: durata e sottotitolo, come l'italiano (non più in maiuscolo)
UPDATE web_traduzioni t
   SET testo = x.testo, obsoleto = false, revisionato = true,
       data_traduzione = now(), updated = now(), updated_by = 'claude-690'
  FROM (VALUES
    ('durata_testo', '3 giorni / 2 notti', 'EN', '3 days / 2 nights'),
    ('durata_testo', '3 giorni / 2 notti', 'DE', '3 Tage / 2 Nächte'),
    ('durata_testo', '3 giorni / 2 notti', 'FR', '3 jours / 2 nuits'),
    ('durata_testo', '3 giorni / 2 notti', 'ES', '3 días / 2 noches'),
    ('sottotitolo', 'Tra granito e macchia mediterranea', 'EN', 'Between granite and Mediterranean scrub'),
    ('sottotitolo', 'Tra granito e macchia mediterranea', 'DE', 'Zwischen Granit und mediterraner Macchia'),
    ('sottotitolo', 'Tra granito e macchia mediterranea', 'FR', 'Entre granit et maquis méditerranéen'),
    ('sottotitolo', 'Tra granito e macchia mediterranea', 'ES', 'Entre granito y matorral mediterráneo')
  ) AS x(campo, italiano, lingua, testo),
  web_tour_contenuti c
 WHERE c.slug = 'tour-enduro-gallura-2027-03-11'
   AND CASE x.campo WHEN 'durata_testo' THEN c.durata_testo ELSE c.sottotitolo END = x.italiano
   AND t.entita = 'web_tour_contenuti' AND t.entita_id = c.web_tour_contenuti_id
   AND t.campo = x.campo AND t.lingua = x.lingua;

COMMIT;

-- ============================================================================
-- Verifica: Test_690_Web_Mongolia_Gallura_Traduzioni.sql
-- ============================================================================
