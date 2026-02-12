-- =====================================================
-- Script: 02_migra_fornitori_a_controparti.sql
-- Descrizione: Migrazione dati da ana_fornitori a ana_controparti
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Verifica stato iniziale
SELECT 'Fornitori da migrare: ' || COUNT(*)::text as info FROM ana_fornitori;
SELECT 'Controparti già presenti: ' || COUNT(*)::text as info FROM ana_controparti;

-- Step 2: Migrazione dati
-- NOTA: Impostiamo is_fornitore=TRUE, is_cliente=FALSE per tutti i fornitori esistenti
INSERT INTO ana_controparti (
    controparte_id,
    azienda_fk,
    ragione_sociale,
    nome_breve,
    is_fornitore,
    is_cliente,
    partita_iva,
    codice_fiscale,
    codice_destinatario_sdi,
    indirizzo,
    comune_fk,
    telefono_prefisso,
    telefono_numero,
    email,
    pec,
    sito_web,
    tipo_fornitore_fk,
    fornitore_estero,
    attivo,
    priorita,
    note,
    created_at,
    created_by,
    updated_at,
    updated_by
)
SELECT
    fornitore_id,                    -- Manteniamo l'ID originale
    azienda_fk,
    ragione_sociale,
    nome_breve,
    TRUE as is_fornitore,            -- Tutti i fornitori sono is_fornitore=TRUE
    FALSE as is_cliente,             -- Inizialmente nessuno è cliente
    partita_iva,
    codice_fiscale,
    codice_destinatario_sdi,
    indirizzo,
    comune_fk,
    telefono_prefisso,
    telefono_numero,
    email,
    pec,
    sito_web,
    tipo_fornitore_fk,
    fornitore_estero,
    attivo,
    priorita,
    note,
    created_at,
    created_by,
    updated_at,
    updated_by
FROM ana_fornitori
ON CONFLICT (controparte_id) DO NOTHING;  -- Evita duplicati se rieseguito

-- Step 3: Aggiorna sequence per controparte_id
-- In modo che i prossimi inserimenti non vadano in conflitto
SELECT setval('ana_controparti_controparte_id_seq',
    (SELECT COALESCE(MAX(controparte_id), 0) + 1 FROM ana_controparti)
);

-- Step 4: Verifica migrazione
SELECT 'Controparti dopo migrazione: ' || COUNT(*)::text as info FROM ana_controparti;
SELECT 'Controparti fornitori: ' || COUNT(*)::text as info
FROM ana_controparti WHERE is_fornitore = TRUE;
SELECT 'Controparti clienti: ' || COUNT(*)::text as info
FROM ana_controparti WHERE is_cliente = TRUE;

-- Step 5: Verifica integrità referenziale
-- Controlla che non ci siano fornitori senza corrispondente controparte
SELECT 'Fornitori senza controparte: ' || COUNT(*)::text as info
FROM ana_fornitori f
LEFT JOIN ana_controparti c ON f.fornitore_id = c.controparte_id
WHERE c.controparte_id IS NULL;

SELECT 'Migrazione completata con successo!' as risultato;
