-- =====================================================
-- Script: 04_crea_causali_attivo.sql
-- Descrizione: Creazione causali per ciclo ATTIVO (clienti)
-- Data: 12/02/2026
-- =====================================================

-- Step 1: Verifica stato iniziale
SELECT 'Causali PASSIVO: ' || COUNT(*)::text as info
FROM ana_tipi_causali WHERE causale_ciclo = 'PASSIVO';

SELECT 'Causali ATTIVO: ' || COUNT(*)::text as info
FROM ana_tipi_causali WHERE causale_ciclo = 'ATTIVO';

-- Step 2: Inserimento causali ciclo ATTIVO per azienda_fk = 6
INSERT INTO public.ana_tipi_causali (
    azienda_fk,
    causale_codice,
    causale_descrizione,
    causale_segno,
    causale_is_documento,
    causale_ciclo,
    created_by
) VALUES
(6, 'FV', 'FATTURA ATTIVA / VENDITA', 1, true, 'ATTIVO', 'system'),
(6, 'IN', 'INCASSO / ACCONTO CLIENTE', -1, false, 'ATTIVO', 'system'),
(6, 'NCA', 'NOTA DI CREDITO EMESSA', -1, true, 'ATTIVO', 'system'),
(6, 'NDA', 'NOTA DI DEBITO EMESSA', 1, true, 'ATTIVO', 'system')
ON CONFLICT (azienda_fk, causale_codice) DO NOTHING;

-- Step 3: Inserimento causali ciclo ATTIVO per azienda_fk = 2
INSERT INTO public.ana_tipi_causali (
    azienda_fk,
    causale_codice,
    causale_descrizione,
    causale_segno,
    causale_is_documento,
    causale_ciclo,
    created_by
) VALUES
(2, 'FV', 'FATTURA ATTIVA / VENDITA', 1, true, 'ATTIVO', 'system'),
(2, 'IN', 'INCASSO / ACCONTO CLIENTE', -1, false, 'ATTIVO', 'system'),
(2, 'NCA', 'NOTA DI CREDITO EMESSA', -1, true, 'ATTIVO', 'system'),
(2, 'NDA', 'NOTA DI DEBITO EMESSA', 1, true, 'ATTIVO', 'system')
ON CONFLICT (azienda_fk, causale_codice) DO NOTHING;

-- Step 4: Verifica risultato finale
SELECT
    azienda_fk,
    causale_ciclo,
    COUNT(*) as numero_causali,
    STRING_AGG(causale_codice, ', ' ORDER BY causale_codice) as causali
FROM ana_tipi_causali
GROUP BY azienda_fk, causale_ciclo
ORDER BY azienda_fk, causale_ciclo;

-- Step 5: Dettaglio causali ATTIVO per verifica
SELECT
    causale_id,
    azienda_fk,
    causale_codice,
    causale_descrizione,
    causale_segno,
    causale_is_documento,
    causale_ciclo
FROM ana_tipi_causali
WHERE causale_ciclo = 'ATTIVO'
ORDER BY azienda_fk, causale_codice;

SELECT 'Causali ciclo ATTIVO create con successo!' as risultato;
