-- =====================================================
-- TEST LOGICA IVA - SERVICE LAYER
-- Scopo: Verificare la logica di auto-determinazione IVA
-- Data: 15/02/2026
-- =====================================================

-- =====================================================
-- SCENARIO 1: Transazione PASSIVO (Fornitore) in EUR con causale che genera IVA
-- ATTESO:
--   - Aliquota IVA: impostata a default della causale (22%)
--   - Modalità input: LORDO (scorporo)
--   - Tipo movimento: USCITA
-- =====================================================

-- Prerequisiti:
-- 1. Causale FT (Fattura Fornitore) esiste con:
--    - causale_ciclo = 'PASSIVO'
--    - causale_genera_iva = TRUE
--    - causale_aliquota_iva_default_fk = [ID aliquota 22%]

SELECT
    c.causale_id,
    c.causale_codice,
    c.causale_ciclo,
    c.causale_genera_iva,
    c.causale_aliquota_iva_default_fk,
    aiva.iva_codice as aliquota_default_codice
FROM ana_tipi_causali c
LEFT JOIN ana_aliquote_iva aiva ON c.causale_aliquota_iva_default_fk = aiva.iva_id
WHERE c.causale_codice = 'FT' AND c.azienda_fk = 6;

-- Test manuale tramite UI:
-- 1. Creare nuova transazione con:
--    - Causale: FT (Fattura Fornitore)
--    - Valuta: EUR
--    - Importo: 122.00
-- 2. Verificare che il service imposti automaticamente:
--    - TransazioneAliquotaIvaFk = [ID aliquota 22%]
--    - TransazioneIvaModalitaInput = 'LORDO'
--    - TransazioneTipoMovimento = 'USCITA'
-- 3. Il trigger db calcolerà:
--    - transazione_imponibile_eur = 100.00
--    - transazione_iva_eur = 22.00
--    - transazione_lordo_eur = 122.00


-- =====================================================
-- SCENARIO 2: Transazione ATTIVO (Cliente) in EUR con causale che genera IVA
-- ATTESO:
--   - Aliquota IVA: impostata a default della causale (22%)
--   - Modalità input: NETTO (calcolo)
--   - Tipo movimento: ENTRATA
-- =====================================================

SELECT
    c.causale_id,
    c.causale_codice,
    c.causale_ciclo,
    c.causale_genera_iva,
    c.causale_aliquota_iva_default_fk,
    aiva.iva_codice as aliquota_default_codice
FROM ana_tipi_causali c
LEFT JOIN ana_aliquote_iva aiva ON c.causale_aliquota_iva_default_fk = aiva.iva_id
WHERE c.causale_codice = 'FV' AND c.azienda_fk = 6;

-- Test manuale tramite UI:
-- 1. Creare nuova transazione con:
--    - Causale: FV (Fattura Cliente)
--    - Valuta: EUR
--    - Importo: 1000.00
-- 2. Verificare che il service imposti automaticamente:
--    - TransazioneAliquotaIvaFk = [ID aliquota 22%]
--    - TransazioneIvaModalitaInput = 'NETTO'
--    - TransazioneTipoMovimento = 'ENTRATA'
-- 3. Il trigger db calcolerà:
--    - transazione_imponibile_eur = 1000.00
--    - transazione_iva_eur = 220.00
--    - transazione_lordo_eur = 1220.00


-- =====================================================
-- SCENARIO 3: Transazione in valuta estera (USD, ZAR, TND)
-- ATTESO:
--   - Tutti i campi IVA azzerati (NULL)
--   - Anche se causale genera IVA
-- =====================================================

SELECT
    v.valuta_id,
    v.valuta_codice_iso,
    v.valuta_is_base,
    v.valuta_descrizione
FROM ana_valute v
WHERE v.valuta_is_base = FALSE
ORDER BY v.valuta_codice_iso;

-- Test manuale tramite UI:
-- 1. Creare nuova transazione con:
--    - Causale: FT (Fattura Fornitore) - genera IVA
--    - Valuta: USD (o ZAR, TND)
--    - Importo: 500.00 USD
-- 2. Verificare che il service azzeri tutti i campi IVA:
--    - TransazioneAliquotaIvaFk = NULL
--    - TransazioneImponibileEur = NULL
--    - TransazioneIvaEur = NULL
--    - TransazioneLordoEur = NULL
--    - TransazioneIvaModalitaInput = NULL
-- 3. Il trigger db calcolerà solo la conversione EUR:
--    - transazione_importo_eur (trigger cambio) = [importo convertito]


-- =====================================================
-- SCENARIO 4: Causale che NON genera IVA (PG, IN, NC)
-- ATTESO:
--   - TransazioneAliquotaIvaFk = NULL
--   - Altri campi IVA gestiti dal trigger
-- =====================================================

SELECT
    c.causale_id,
    c.causale_codice,
    c.causale_descrizione,
    c.causale_ciclo,
    c.causale_genera_iva
FROM ana_tipi_causali c
WHERE c.causale_genera_iva = FALSE AND c.azienda_fk = 6
ORDER BY c.causale_codice;

-- Test manuale tramite UI:
-- 1. Creare nuova transazione con:
--    - Causale: PG (Pagamento) - NON genera IVA
--    - Valuta: EUR
--    - Importo: 150.00
-- 2. Verificare che il service azzeri solo l'aliquota:
--    - TransazioneAliquotaIvaFk = NULL
-- 3. Il trigger db popolerà correttamente imponibile/IVA/lordo


-- =====================================================
-- SCENARIO 5: Utente specifica manualmente aliquota diversa da default
-- ATTESO:
--   - Aliquota manuale NON sovrascritta dal service
--   - Modalità input auto-determinata
-- =====================================================

-- Prerequisiti: avere aliquota 10% disponibile
SELECT
    iva_id,
    iva_codice,
    iva_descrizione,
    iva_percentuale
FROM ana_aliquote_iva
WHERE azienda_fk = 6 AND iva_codice = '10';

-- Test manuale tramite UI:
-- 1. Creare nuova transazione con:
--    - Causale: FT (default 22%)
--    - Valuta: EUR
--    - Aliquota IVA: MANUALMENTE SELEZIONATA 10%
--    - Importo: 110.00
-- 2. Verificare che il service NON sovrascriva l'aliquota:
--    - TransazioneAliquotaIvaFk = [ID aliquota 10%] (NON 22%)
--    - TransazioneIvaModalitaInput = 'LORDO' (auto-determinata)
-- 3. Il trigger db calcolerà con 10%:
--    - transazione_imponibile_eur = 100.00
--    - transazione_iva_eur = 10.00
--    - transazione_lordo_eur = 110.00


-- =====================================================
-- SCENARIO 6: Utente specifica manualmente modalità input
-- ATTESO:
--   - Modalità manuale NON sovrascritta dal service
-- =====================================================

-- Test manuale tramite UI:
-- 1. Creare nuova transazione PASSIVO (FT) con:
--    - Causale: FT (ciclo PASSIVO, default modalità LORDO)
--    - Valuta: EUR
--    - Modalità IVA: MANUALMENTE SELEZIONATA 'NETTO'
--    - Importo: 100.00
-- 2. Verificare che il service NON sovrascriva la modalità:
--    - TransazioneIvaModalitaInput = 'NETTO' (NON 'LORDO')
-- 3. Il trigger db calcolerà in modalità NETTO:
--    - transazione_imponibile_eur = 100.00
--    - transazione_iva_eur = 22.00
--    - transazione_lordo_eur = 122.00


-- =====================================================
-- SCENARIO 7: UPDATE - Cambio valuta da EUR a USD
-- ATTESO:
--   - Campi IVA azzerati durante update
-- =====================================================

-- Test manuale tramite UI:
-- 1. Creare transazione in EUR con IVA popolata
-- 2. Modificare la valuta da EUR a USD
-- 3. Salvare
-- 4. Verificare che il service abbia azzerato:
--    - TransazioneAliquotaIvaFk = NULL
--    - TransazioneImponibileEur = NULL
--    - TransazioneIvaEur = NULL
--    - TransazioneLordoEur = NULL
--    - TransazioneIvaModalitaInput = NULL


-- =====================================================
-- SCENARIO 8: UPDATE - Cambio causale da FT (genera IVA) a PG (non genera IVA)
-- ATTESO:
--   - Aliquota azzerata durante update
-- =====================================================

-- Test manuale tramite UI:
-- 1. Creare transazione con causale FT (genera IVA)
-- 2. Modificare la causale in PG (non genera IVA)
-- 3. Salvare
-- 4. Verificare che il service abbia azzerato:
--    - TransazioneAliquotaIvaFk = NULL


-- =====================================================
-- VERIFICA STATO DATI DOPO TEST
-- =====================================================

-- Ultime 10 transazioni create, con dettaglio IVA
SELECT
    t.transazione_id,
    t.transazione_data,
    c.causale_codice,
    c.causale_ciclo,
    c.causale_genera_iva,
    v.valuta_codice_iso,
    v.valuta_is_base,
    t.transazione_importo,
    aiva.iva_codice,
    t.transazione_iva_modalita_input,
    t.transazione_imponibile_eur,
    t.transazione_iva_eur,
    t.transazione_lordo_eur,
    t.transazione_tipo_movimento
FROM mov_transazioni t
JOIN ana_tipi_causali c ON t.transazione_causale_tipo_id = c.causale_id
JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
WHERE t.transazione_azienda_id = 6
ORDER BY t.transazione_id DESC
LIMIT 10;


-- =====================================================
-- CHECKLIST VALIDAZIONE FINALE
-- =====================================================

/*
✅ SCENARIO 1: PASSIVO + EUR + genera IVA
   - Aliquota default impostata?
   - Modalità LORDO impostata?
   - Tipo movimento USCITA?

✅ SCENARIO 2: ATTIVO + EUR + genera IVA
   - Aliquota default impostata?
   - Modalità NETTO impostata?
   - Tipo movimento ENTRATA?

✅ SCENARIO 3: Valuta estera
   - Tutti campi IVA NULL?

✅ SCENARIO 4: Causale non genera IVA
   - Aliquota NULL?

✅ SCENARIO 5: Aliquota manuale
   - Aliquota manuale preservata?

✅ SCENARIO 6: Modalità manuale
   - Modalità manuale preservata?

✅ SCENARIO 7: UPDATE cambio valuta
   - IVA azzerata se passa a non-EUR?

✅ SCENARIO 8: UPDATE cambio causale
   - Aliquota azzerata se passa a non-genera-IVA?
*/
