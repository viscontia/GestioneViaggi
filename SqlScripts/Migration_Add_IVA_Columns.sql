-- =====================================================
-- MIGRAZIONE: Aggiunta Colonne IVA su mov_transazioni
-- Scopo: Gestione IVA con compatibilità dati storici
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- Implementazione: STEP 2 - Implementazione_IVA.md
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Rinomina colonna esistente (DEPRECAZIONE)
-- =====================================================
-- La colonna transazione_importo_eur diventa ambigua dopo l'integrazione IVA
-- (è lordo? netto? totale senza distinzione per transazioni pre-IVA?)
-- Soluzione: rinominare in _old e creare nuove colonne esplicite

ALTER TABLE public.mov_transazioni
RENAME COLUMN transazione_importo_eur TO transazione_importo_eur_old;

COMMENT ON COLUMN mov_transazioni.transazione_importo_eur_old IS
'DEPRECATO dal 14/02/2026 - Sostituito da transazione_lordo_eur. Mantenuto per compatibilità dati storici (eliminare dopo 6 mesi).';

-- =====================================================
-- STEP 2: Aggiungi nuove colonne IVA
-- =====================================================
-- Tutte le colonne sono NULLABLE per compatibilità con transazioni pre-IVA

ALTER TABLE public.mov_transazioni
ADD COLUMN transazione_aliquota_iva_fk INTEGER REFERENCES ana_aliquote_iva(iva_id) ON DELETE RESTRICT,
ADD COLUMN transazione_imponibile_eur NUMERIC(10, 2),
ADD COLUMN transazione_iva_eur NUMERIC(10, 2),
ADD COLUMN transazione_lordo_eur NUMERIC(10, 2),
ADD COLUMN transazione_iva_modalita_input VARCHAR(10) CHECK (transazione_iva_modalita_input IN ('LORDO', 'NETTO', NULL));

-- =====================================================
-- STEP 3: Commenti colonne
-- =====================================================

COMMENT ON COLUMN mov_transazioni.transazione_aliquota_iva_fk IS
'FK a aliquota IVA - NULL se transazione in valuta estera o causale senza IVA (PG, IN, NC)';

COMMENT ON COLUMN mov_transazioni.transazione_imponibile_eur IS
'Importo netto (senza IVA) in EUR - editabile manualmente per correzioni arrotondamenti';

COMMENT ON COLUMN mov_transazioni.transazione_iva_eur IS
'Importo IVA in EUR - editabile manualmente per correzioni arrotondamenti';

COMMENT ON COLUMN mov_transazioni.transazione_lordo_eur IS
'Importo totale (imponibile + IVA) in EUR - deve coincidere con fattura cartacea al centesimo';

COMMENT ON COLUMN mov_transazioni.transazione_iva_modalita_input IS
'Modalità inserimento utente: LORDO (scorporo da totale) o NETTO (calcolo IVA su imponibile) - auto-determinata da ciclo causale';

-- =====================================================
-- STEP 4: Constraint di coerenza IVA
-- =====================================================
-- Garantisce che i campi IVA siano compilati "all or nothing"
-- Evita stati inconsistenti (es. aliquota presente ma importi NULL)

ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_iva_completeness CHECK (
    -- Opzione 1: Nessun campo IVA compilato (transazione pre-IVA o senza IVA)
    (transazione_aliquota_iva_fk IS NULL
        AND transazione_imponibile_eur IS NULL
        AND transazione_iva_eur IS NULL
        AND transazione_lordo_eur IS NULL)
    OR
    -- Opzione 2: Tutti i campi IVA compilati (transazione con IVA completa)
    (transazione_aliquota_iva_fk IS NOT NULL
        AND transazione_imponibile_eur IS NOT NULL
        AND transazione_iva_eur IS NOT NULL
        AND transazione_lordo_eur IS NOT NULL)
);

-- =====================================================
-- STEP 5: Constraint IVA solo su EUR
-- =====================================================
-- L'IVA italiana è applicabile solo su transazioni in EUR
-- Per valute estere (USD, ZAR, TND), l'IVA locale è considerata costo totale (Fuori Campo IVA art. 7-ter)
-- NOTA: Validazione gestita dal trigger fn_calcola_iva_transazione() (STEP 4)
--       perché PostgreSQL non permette subquery nei CHECK constraint

-- =====================================================
-- STEP 6: Constraint coerenza matematica (tolleranza 0.01€)
-- =====================================================
-- Verifica che Lordo = Imponibile + IVA (con tolleranza di 1 centesimo per arrotondamenti)
-- Tolleranza necessaria perché software contabili diversi arrotondano in modo diverso

ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_iva_matematica CHECK (
    (transazione_lordo_eur IS NULL)
    OR
    (ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) <= 0.01)
);

-- =====================================================
-- STEP 7: Migrazione dati esistenti (transazioni pre-IVA)
-- =====================================================
-- Le transazioni esistenti (pre-IVA) mantengono tutti i campi IVA a NULL
-- Questo rispetta il constraint chk_iva_completeness (all or nothing)
--
-- La colonna transazione_importo_eur_old preserva i valori originali per compatibilità
-- e può essere usata nei report per calcolare totali storici
--
-- Le transazioni esistenti continueranno a funzionare normalmente:
-- - I report useranno transazione_importo_eur_old per i dati storici
-- - Le nuove transazioni useranno transazione_lordo_eur
-- - Quando una transazione pre-IVA viene modificata, i campi IVA verranno popolati dal trigger
--
-- NESSUNA AZIONE AUTOMATICA NECESSARIA - i dati rimangono invariati

-- =====================================================
-- STEP 8: Indici per performance
-- =====================================================
-- Indice parziale solo su transazioni con IVA (ottimizza query reportistica)

CREATE INDEX idx_transazioni_iva ON mov_transazioni(transazione_aliquota_iva_fk)
WHERE transazione_aliquota_iva_fk IS NOT NULL;

-- =====================================================
-- COMMIT
-- =====================================================

COMMIT;

-- =====================================================
-- QUERY DI VERIFICA POST-MIGRAZIONE
-- =====================================================

-- Test 1: Verifica migrazione dati esistenti
-- Atteso: tutte le transazioni in EUR dovrebbero avere lordo_eur popolato
SELECT
    COUNT(*) AS totale_transazioni,
    COUNT(transazione_importo_eur_old) AS con_importo_old,
    COUNT(transazione_lordo_eur) AS con_lordo_nuovo,
    COUNT(transazione_aliquota_iva_fk) AS con_iva
FROM mov_transazioni;

-- Test 2: Verifica coerenza matematica
-- Atteso: 0 righe (nessuna incoerenza superiore a 0.01€)
SELECT transazione_id,
       transazione_imponibile_eur,
       transazione_iva_eur,
       transazione_lordo_eur,
       (transazione_imponibile_eur + transazione_iva_eur) AS somma_calcolata,
       ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) AS differenza
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) > 0.01;

-- Test 3: Verifica constraint IVA solo EUR
-- Atteso: 0 righe (IVA solo su transazioni in EUR)
SELECT transazione_id,
       transazione_aliquota_iva_fk,
       v.valuta_codice_iso
FROM mov_transazioni m
JOIN ana_valute v ON m.transazione_valuta_id = v.valuta_id
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND v.valuta_codice_iso != 'EUR';

-- Test 4: Verifica migrazione dati EUR
-- Verifica che tutte le transazioni EUR abbiano i nuovi campi popolati
SELECT
    v.valuta_codice_iso,
    COUNT(*) AS totale,
    COUNT(transazione_lordo_eur) AS con_lordo,
    COUNT(transazione_importo_eur_old) AS con_old
FROM mov_transazioni m
JOIN ana_valute v ON m.transazione_valuta_id = v.valuta_id
GROUP BY v.valuta_codice_iso
ORDER BY v.valuta_codice_iso;
