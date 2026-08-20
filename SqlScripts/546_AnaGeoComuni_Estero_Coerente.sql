-- =============================================================================
-- 546 — ana_geo_comuni: il flag "estero" allineato alla provincia (idempotente)
-- =============================================================================
-- Trovato il 2026-08-20 cercando i comuni italiani senza codice catastale.
-- Il risultato e' stato: NON CE NE SONO. Tutti gli 8092 comuni italiani hanno il
-- loro codice. L'unico segnato come italiano e privo di codice era BOMBAY, che
-- italiano non e': puntava gia' correttamente alla provincia "ESTERO - INDIA",
-- ma aveva comune_estero = 'N'.
--
-- La regola qui e' generale, non un aggiustamento su misura: un comune la cui
-- provincia e' una di quelle estere non puo' essere marcato come italiano.
-- =============================================================================

BEGIN;

UPDATE ana_geo_comuni g
SET comune_estero = 'Y'
FROM ana_geo_province p
WHERE p.provincia_id = g.comune_provincia_fk
  AND upper(p.provincia_descrizione) LIKE '%ESTERO%'
  AND COALESCE(g.comune_estero, 'N') <> 'Y';

COMMIT;
