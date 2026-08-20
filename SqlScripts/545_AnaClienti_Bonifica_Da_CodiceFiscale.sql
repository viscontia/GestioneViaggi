-- =============================================================================
-- 545 — ana_clienti: bonifica guidata dal codice fiscale (idempotente)
-- =============================================================================
-- Il motore del 544, passato sulle anagrafiche reali, ha trovato 16 schede in cui
-- il codice fiscale non corrisponde ai dati. Misurato il 2026-08-20: identico su
-- PROD e in locale (il locale ne ha 12 delle 16, le altre 4 sono schede piu'
-- recenti che li' non esistono).
--
-- Tre famiglie sono riparabili, perche' il codice fiscale dice qual e' il dato
-- giusto. Un codice fiscale supera il controllo dell'ultimo carattere: un refuso
-- al suo interno lo romperebbe quasi sempre. Se il codice e' integro e la scheda
-- lo contraddice, e' la scheda ad avere il refuso.
--
-- ⚠️ OGNI REGOLA SI APPLICA SOLO SE RENDE IL CODICE FISCALE CORRETTO.
--    Non e' una precauzione formale: e' cio' che impedisce di "correggere" una
--    riga peggiorandola. Se dopo la modifica il codice ancora non torna, la
--    modifica non viene fatta.
--
-- NON riparabili, e lasciate intatte di proposito:
--   · 3 schede in cui il cognome torna ma il NOME no (il codice dice un altro
--     nome di battesimo: verosimilmente il codice fiscale di un familiare).
--     Serve chiedere alla persona.
--   · 3 codici malformati o con carattere di controllo errato, tutti di clienti
--     nati all'estero. Non si indovinano.
-- =============================================================================

BEGIN;

-- 1. Nome e cognome invertiti ----------------------------------------------------
-- Il codice fiscale torna esatto scambiando i due campi: e' la prova.
UPDATE ana_clienti c
SET cliente_cognome = c.cliente_nome,
    cliente_nome    = c.cliente_cognome
WHERE c.cliente_codicefiscale IS NOT NULL
  AND c.cliente_data_nascita IS NOT NULL
  AND c.cliente_comune_nascita_fk IS NOT NULL
  AND fn_cf_calcola(c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
                    c.cliente_sesso, c.cliente_comune_nascita_fk)
      IS DISTINCT FROM upper(btrim(c.cliente_codicefiscale))
  AND fn_cf_calcola(c.cliente_nome, c.cliente_cognome, c.cliente_data_nascita,
                    c.cliente_sesso, c.cliente_comune_nascita_fk)
      = upper(btrim(c.cliente_codicefiscale));

-- 2. Data di nascita ---------------------------------------------------------------
-- Il comune coincide, la data no: si prende quella scritta nel codice fiscale.
UPDATE ana_clienti c
SET cliente_data_nascita = (SELECT data_nascita FROM fn_cf_decodifica(c.cliente_codicefiscale))
WHERE c.cliente_codicefiscale IS NOT NULL
  AND c.cliente_comune_nascita_fk IS NOT NULL
  AND (SELECT data_nascita FROM fn_cf_decodifica(c.cliente_codicefiscale))
      IS DISTINCT FROM c.cliente_data_nascita
  AND fn_cf_calcola(c.cliente_cognome, c.cliente_nome,
                    (SELECT data_nascita FROM fn_cf_decodifica(c.cliente_codicefiscale)),
                    c.cliente_sesso, c.cliente_comune_nascita_fk)
      = upper(btrim(c.cliente_codicefiscale));

-- 3. Comune di nascita --------------------------------------------------------------
-- La data coincide, il comune no: si prende quello scritto nel codice fiscale.
UPDATE ana_clienti c
SET cliente_comune_nascita_fk = (SELECT comune_id FROM fn_cf_decodifica(c.cliente_codicefiscale))
WHERE c.cliente_codicefiscale IS NOT NULL
  AND c.cliente_data_nascita IS NOT NULL
  AND (SELECT comune_id FROM fn_cf_decodifica(c.cliente_codicefiscale))
      IS DISTINCT FROM c.cliente_comune_nascita_fk
  AND fn_cf_calcola(c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
                    c.cliente_sesso,
                    (SELECT comune_id FROM fn_cf_decodifica(c.cliente_codicefiscale)))
      = upper(btrim(c.cliente_codicefiscale));

COMMIT;
