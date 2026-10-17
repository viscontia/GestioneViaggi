-- ============================================================================
-- 689 — Andalucia: la durata tradotta torna giusta (dati, Tappa 3 del sito)
--
-- La durata italiana della scheda «Andalucia - Deserti e Segreti» è passata da
-- «8 giorni / 8 notti» a «9 giorni / 8 notti»: le 4 traduzioni sono rimaste
-- «8 …» e il gestionale le ha segnate obsolete. Il sito, giustamente, mostra
-- l'italiano in ogni lingua (trovato il 2026-10-17 sulla card inglese) e il
-- semaforo «Traduzioni» della scheda pubblicata è incompleto.
--
-- Si riscrivono le 4 traduzioni, revisionate, SOLO se l'italiano è ancora
-- «9 giorni / 8 notti» (altrimenti nessun effetto: in locale la copia è più
-- vecchia). Autorizzazione di Adriano (2026-10-17), anche in PROD.
-- Rigiocabile.
-- ============================================================================
BEGIN;

UPDATE web_traduzioni t
   SET testo = x.testo, obsoleto = false, revisionato = true,
       data_traduzione = now(), updated = now(), updated_by = 'claude-689'
  FROM (VALUES
    ('EN', '9 days / 8 nights'),
    ('DE', '9 Tage / 8 Nächte'),
    ('FR', '9 jours / 8 nuits'),
    ('ES', '9 días / 8 noches')
  ) AS x(lingua, testo),
  web_tour_contenuti c
 WHERE c.slug = 'andalucia-deserti-e-segreti'
   AND c.durata_testo = '9 giorni / 8 notti'
   AND t.entita = 'web_tour_contenuti' AND t.entita_id = c.web_tour_contenuti_id
   AND t.campo = 'durata_testo' AND t.lingua = x.lingua;

COMMIT;

-- ============================================================================
-- Verifica: Test_689_Web_Andalucia_Durata_Tradotta.sql
-- ============================================================================
