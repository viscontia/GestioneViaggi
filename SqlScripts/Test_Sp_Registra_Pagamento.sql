-- =============================================
-- Script di Test per sp_registra_pagamento
-- Data Creazione: 2026-02-15
-- Autore: Claude Code
-- Descrizione: Test completi per la stored function sp_registra_pagamento
-- =============================================

-- PREREQUISITI:
-- 1. Deve esistere almeno un'azienda
-- 2. Devono esistere causali PG (Pagamento) e IN (Incasso) per l'azienda di test
-- 3. Deve esistere la valuta EUR come valuta base
-- 4. Devono esistere transazioni di test

-- =============================================
-- SETUP: Verifica prerequisiti
-- =============================================

-- Verifica valuta EUR
SELECT
    valuta_id,
    valuta_codice_iso,
    valuta_is_base
FROM ana_valute
WHERE valuta_is_base = TRUE;

-- Verifica causali PG e IN (cambia azienda_fk con l'ID della tua azienda di test)
SELECT
    causale_id,
    causale_codice,
    causale_descrizione,
    causale_ciclo,
    azienda_fk
FROM ana_tipi_causali
WHERE causale_codice IN ('PG', 'IN')
  AND is_active = TRUE
ORDER BY azienda_fk, causale_codice;

-- =============================================
-- TEST 1: Pagamento totale di transazione DA_PAGARE
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_id IS 'TEST 1: Creare una transazione DA_PAGARE di test e registrarne il pagamento totale';

-- Esempio (sostituire con ID transazione reale):
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 123,          -- ID transazione da pagare
--     p_importo_pagamento => NULL,      -- NULL = pagamento totale
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Pagamento test totale',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - pg_transazione_id: NOT NULL (ID nuova transazione PG/IN creata)
-- - nuovo_stato: 'PAGATO'
-- - importo_effettivo: uguale a importo_lordo_eur della transazione originale
-- - error_message: NULL

-- =============================================
-- TEST 2: Pagamento parziale di transazione DA_PAGARE
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_stato IS 'TEST 2: Registrare pagamento parziale (50% dell''importo)';

-- Esempio:
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 124,
--     p_importo_pagamento => 500.00,    -- Pagamento parziale
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Acconto 50%',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - pg_transazione_id: NOT NULL
-- - nuovo_stato: 'PARZIALMENTE_PAGATO'
-- - importo_effettivo: 500.00
-- - error_message: NULL

-- =============================================
-- TEST 3: Pagamento finale di transazione PARZIALMENTE_PAGATO
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_data_pagamento IS 'TEST 3: Completare pagamento di transazione già parzialmente pagata';

-- Esempio (dopo aver eseguito TEST 2):
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 124,          -- Stessa transazione di TEST 2
--     p_importo_pagamento => 500.00,    -- Resto 50%
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Saldo finale',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - pg_transazione_id: NOT NULL (seconda transazione PG/IN)
-- - nuovo_stato: 'PAGATO'
-- - importo_effettivo: 500.00
-- - error_message: NULL

-- =============================================
-- TEST 4: Errore - Tentativo di pagare transazione già PAGATO
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_fattura_fk IS 'TEST 4: Verificare errore per transazione già pagata';

-- Esempio (dopo aver eseguito TEST 1 o TEST 3):
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 123,          -- Transazione già PAGATO
--     p_importo_pagamento => NULL,
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Tentativo pagamento duplicato',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - pg_transazione_id: NULL
-- - nuovo_stato: NULL
-- - importo_effettivo: NULL
-- - error_message: 'La transazione è già stata pagata completamente'

-- =============================================
-- TEST 5: Errore - Tentativo di pagare transazione ANNULLATO
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_note IS 'TEST 5: Verificare errore per transazione annullata';

-- Prima annullare una transazione di test:
-- UPDATE mov_transazioni
-- SET transazione_stato = 'ANNULLATO'
-- WHERE transazione_id = 125;

-- Poi tentare il pagamento:
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 125,
--     p_importo_pagamento => NULL,
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Tentativo pagamento annullato',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - error_message: 'Impossibile pagare una transazione annullata'

-- =============================================
-- TEST 6: Errore - Importo supera residuo disponibile
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_importo IS 'TEST 6: Verificare errore per importo eccessivo';

-- Esempio (su transazione parzialmente pagata):
-- SELECT * FROM sp_registra_pagamento(
--     p_transazione_id => 124,          -- Già pagati 500 EUR su totale 1000 EUR
--     p_importo_pagamento => 600.00,    -- Troppo! Residuo = 500 EUR
--     p_data_pagamento => CURRENT_DATE,
--     p_note_pagamento => 'Tentativo pagamento eccessivo',
--     p_current_user => 'TestUser'
-- );

-- Verifica risultato atteso:
-- - error_message: 'Impossibile registrare il pagamento: totale pagamenti ... supererebbe l''importo del documento ...'

-- =============================================
-- TEST 7: Errore - Transazione non trovata
-- =============================================

SELECT * FROM sp_registra_pagamento(
    p_transazione_id => 999999,       -- ID inesistente
    p_importo_pagamento => 100.00,
    p_data_pagamento => CURRENT_DATE,
    p_note_pagamento => 'Test transazione inesistente',
    p_current_user => 'TestUser'
);

-- Verifica risultato atteso:
-- - pg_transazione_id: NULL
-- - error_message: 'Transazione 999999 non trovata'

-- =============================================
-- TEST 8: Errore - Causale PG/IN non trovata
-- =============================================
COMMENT ON COLUMN mov_transazioni.transazione_causale IS 'TEST 8: Verificare errore quando manca causale PG/IN';

-- Questo test richiede che la causale PG o IN non esista per l'azienda
-- (normalmente non dovrebbe accadere in produzione, ma è un test di robustezza)

-- =============================================
-- QUERY DI VERIFICA POST-TEST
-- =============================================

-- Verifica lo stato delle transazioni di test
SELECT
    t.transazione_id,
    t.transazione_stato,
    t.transazione_numero_documento,
    t.transazione_importo,
    t.transazione_valuta_id,
    t.transazione_importo_eur,
    t.transazione_lordo_eur,
    t.transazione_data_pagamento,
    -- Totale pagamenti collegati
    (
        SELECT COALESCE(SUM(ABS(pt.transazione_importo_eur)), 0)
        FROM mov_transazioni pt
        WHERE pt.transazione_fattura_fk = t.transazione_id
          AND pt.transazione_stato = 'PAGATO'
    ) as totale_pagato,
    -- Numero pagamenti collegati
    (
        SELECT COUNT(*)
        FROM mov_transazioni pt
        WHERE pt.transazione_fattura_fk = t.transazione_id
          AND pt.transazione_stato = 'PAGATO'
    ) as numero_pagamenti
FROM mov_transazioni t
WHERE t.transazione_id IN (123, 124, 125) -- IDs di test
ORDER BY t.transazione_id;

-- Verifica le transazioni PG/IN create
SELECT
    t.transazione_id,
    t.transazione_causale_tipo_id,
    tc.causale_codice,
    t.transazione_tipo_movimento,
    t.transazione_importo,
    t.transazione_importo_eur,
    t.transazione_stato,
    t.transazione_causale,
    t.transazione_note,
    t.transazione_fattura_fk,
    t.created_at,
    t.created_by
FROM mov_transazioni t
JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
WHERE t.transazione_fattura_fk IN (123, 124, 125) -- IDs di test
ORDER BY t.transazione_fattura_fk, t.created_at;

-- =============================================
-- NOTE FINALI
-- =============================================
-- Dopo aver eseguito tutti i test, verificare che:
-- 1. Le transazioni PAGATO hanno transazione_data_pagamento valorizzato
-- 2. Le transazioni PARZIALMENTE_PAGATO hanno transazione_data_pagamento = NULL
-- 3. Le transazioni PG/IN create hanno transazione_fattura_fk che punta alla transazione originale
-- 4. La somma dei pagamenti non supera mai l'importo del documento
-- 5. Gli errori vengono gestiti correttamente senza lasciare dati inconsistenti
