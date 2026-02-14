-- =====================================================
-- CORREZIONE ALIQUOTE IVA - Natura FE e Autofattura
-- Scopo: Aggiustare Split Payment + Suddividere Autofattura
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Correzione Split Payment (SP)
-- =====================================================
-- Split Payment NON ha Natura FE perché si applica
-- l'IVA normale (22%/10%/4%) ma con scissione pagamenti

UPDATE ana_aliquote_iva
SET
    iva_natura = NULL,
    iva_descrizione = 'SPLIT PAYMENT ART. 17-TER DPR 633/72',
    updated_at = NOW(),
    updated_by = 'ADMIN'
WHERE iva_codice = 'SP'
  AND azienda_fk IN (2, 6);

-- =====================================================
-- STEP 2: Rimuovi Autofattura generica (AF)
-- =====================================================
-- Sarà sostituita da 3 codici specifici

DELETE FROM ana_aliquote_iva
WHERE iva_codice = 'AF'
  AND azienda_fk IN (2, 6);

-- =====================================================
-- STEP 3: Aggiungi Autofattura suddivisa - Azienda 6
-- =====================================================

INSERT INTO ana_aliquote_iva (
    azienda_fk,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento,
    created_at,
    created_by
) VALUES

-- 1. Autofattura servizi UE (es. consulenza Germania)
(
    6,
    'AF-UE',
    'AUTOFATTURA SERVIZI UE',
    0.00,
    'N2.1',                  -- Non soggette art. 7-ter
    FALSE,
    TRUE,
    15,
    NOW(),
    'ADMIN'
),

-- 2. Autofattura servizi extra-UE (es. Google, AWS, Meta)
(
    6,
    'AF-EX',
    'AUTOFATTURA SERVIZI EXTRA-UE',
    0.00,
    'N2.1',                  -- Operazione non soggetta territorialmente
    FALSE,
    TRUE,
    16,
    NOW(),
    'ADMIN'
),

-- 3. Acquisto beni intra-UE
(
    6,
    'AF-BENI-UE',
    'ACQUISTO BENI INTRACOMUNITARI',
    0.00,
    'N3.2',                  -- Acquisti intracomunitari
    FALSE,
    TRUE,
    17,
    NOW(),
    'ADMIN'
)

ON CONFLICT (azienda_fk, iva_codice) DO UPDATE SET
    iva_descrizione = EXCLUDED.iva_descrizione,
    iva_natura = EXCLUDED.iva_natura,
    ordinamento = EXCLUDED.ordinamento,
    updated_at = NOW(),
    updated_by = 'ADMIN';

-- =====================================================
-- STEP 4: Aggiungi Autofattura suddivisa - Azienda 2
-- =====================================================

INSERT INTO ana_aliquote_iva (
    azienda_fk,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento,
    created_at,
    created_by
) VALUES

-- 1. Autofattura servizi UE
(
    2,
    'AF-UE',
    'AUTOFATTURA SERVIZI UE',
    0.00,
    'N2.1',
    FALSE,
    TRUE,
    15,
    NOW(),
    'ADMIN'
),

-- 2. Autofattura servizi extra-UE
(
    2,
    'AF-EX',
    'AUTOFATTURA SERVIZI EXTRA-UE',
    0.00,
    'N2.1',
    FALSE,
    TRUE,
    16,
    NOW(),
    'ADMIN'
),

-- 3. Acquisto beni intra-UE
(
    2,
    'AF-BENI-UE',
    'ACQUISTO BENI INTRACOMUNITARI',
    0.00,
    'N3.2',
    FALSE,
    TRUE,
    17,
    NOW(),
    'ADMIN'
)

ON CONFLICT (azienda_fk, iva_codice) DO UPDATE SET
    iva_descrizione = EXCLUDED.iva_descrizione,
    iva_natura = EXCLUDED.iva_natura,
    ordinamento = EXCLUDED.ordinamento,
    updated_at = NOW(),
    updated_by = 'ADMIN';

-- =====================================================
-- STEP 5: Verifica risultato
-- =====================================================

DO $$
DECLARE
    v_count_az6 INTEGER;
    v_count_az2 INTEGER;
    v_sp_natura_az6 VARCHAR(10);
    v_sp_natura_az2 VARCHAR(10);
    v_count_af_generica INTEGER;
    v_count_af_ue_az6 INTEGER;
    v_count_af_ue_az2 INTEGER;
    v_count_af_ex_az6 INTEGER;
    v_count_af_ex_az2 INTEGER;
    v_count_af_beni_az6 INTEGER;
    v_count_af_beni_az2 INTEGER;
BEGIN
    -- Conta totali
    SELECT COUNT(*) INTO v_count_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6;
    SELECT COUNT(*) INTO v_count_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2;

    -- Verifica Split Payment (deve avere natura NULL)
    SELECT iva_natura INTO v_sp_natura_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'SP';
    SELECT iva_natura INTO v_sp_natura_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'SP';

    -- Verifica rimozione AF generica
    SELECT COUNT(*) INTO v_count_af_generica FROM ana_aliquote_iva WHERE iva_codice = 'AF' AND azienda_fk IN (2, 6);

    -- Conta nuove autofatture
    SELECT COUNT(*) INTO v_count_af_ue_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'AF-UE';
    SELECT COUNT(*) INTO v_count_af_ue_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'AF-UE';

    SELECT COUNT(*) INTO v_count_af_ex_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'AF-EX';
    SELECT COUNT(*) INTO v_count_af_ex_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'AF-EX';

    SELECT COUNT(*) INTO v_count_af_beni_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'AF-BENI-UE';
    SELECT COUNT(*) INTO v_count_af_beni_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'AF-BENI-UE';

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'TOTALI:';
    RAISE NOTICE '✓ Azienda 6: % aliquote totali', v_count_az6;
    RAISE NOTICE '✓ Azienda 2: % aliquote totali', v_count_az2;
    RAISE NOTICE '';
    RAISE NOTICE 'SPLIT PAYMENT:';
    RAISE NOTICE '✓ Split Payment (SP) Natura Az.6: % (atteso: NULL)', COALESCE(v_sp_natura_az6, 'NULL');
    RAISE NOTICE '✓ Split Payment (SP) Natura Az.2: % (atteso: NULL)', COALESCE(v_sp_natura_az2, 'NULL');
    RAISE NOTICE '';
    RAISE NOTICE 'AUTOFATTURA GENERICA (deve essere 0):';
    RAISE NOTICE '✓ AF generica residua: %', v_count_af_generica;
    RAISE NOTICE '';
    RAISE NOTICE 'AUTOFATTURA SUDDIVISA:';
    RAISE NOTICE '✓ AF-UE (Servizi UE)       - Az.6: %  Az.2: %', v_count_af_ue_az6, v_count_af_ue_az2;
    RAISE NOTICE '✓ AF-EX (Servizi extra-UE) - Az.6: %  Az.2: %', v_count_af_ex_az6, v_count_af_ex_az2;
    RAISE NOTICE '✓ AF-BENI-UE (Beni UE)     - Az.6: %  Az.2: %', v_count_af_beni_az6, v_count_af_beni_az2;
    RAISE NOTICE '==============================================';

    IF v_count_af_generica > 0 THEN
        RAISE WARNING '⚠ Attenzione: Trovate % aliquote AF generiche (dovrebbero essere 0)', v_count_af_generica;
    END IF;

    IF v_sp_natura_az6 IS NOT NULL OR v_sp_natura_az2 IS NOT NULL THEN
        RAISE WARNING '⚠ Attenzione: Split Payment ha natura FE (dovrebbe essere NULL)';
    END IF;

    IF v_count_az6 < 12 OR v_count_az2 < 12 THEN
        RAISE WARNING '⚠ Attenzione: Attese almeno 12 aliquote per azienda';
    END IF;
END $$;

COMMIT;

-- =====================================================
-- STEP 6: Query di visualizzazione finale
-- =====================================================

-- Visualizza aliquote ordinate per entrambe le aziende
SELECT
    CASE
        WHEN azienda_fk = 6 THEN 'Azienda 6'
        WHEN azienda_fk = 2 THEN 'Azienda 2'
    END AS azienda,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    COALESCE(iva_natura, '-') AS natura_fe,
    is_default,
    ordinamento
FROM ana_aliquote_iva
WHERE azienda_fk IN (2, 6)
ORDER BY azienda_fk, ordinamento, iva_codice;

-- Riepilogo per tipo
SELECT
    iva_codice,
    iva_descrizione,
    COALESCE(iva_natura, 'NESSUNA') AS natura_fe,
    COUNT(*) AS num_aziende,
    STRING_AGG(azienda_fk::text, ', ' ORDER BY azienda_fk) AS aziende
FROM ana_aliquote_iva
WHERE azienda_fk IN (2, 6)
GROUP BY iva_codice, iva_descrizione, iva_natura
ORDER BY MIN(ordinamento), iva_codice;

-- =====================================================
-- FINE SCRIPT
-- =====================================================

-- Note Implementative Finali:
--
-- 🏛️ Split Payment (SP) - NESSUNA Natura FE
--    - L'IVA si applica normalmente (22%, 10%, 4%)
--    - Il pagamento è scisso: PA paga solo imponibile al fornitore
--    - PA versa IVA direttamente all'Erario
--    - In fattura elettronica: campo <EsigibilitaIVA> = S (Split Payment)
--
-- 📋 Art. 15 (A15) - Natura N1
--    - Spese anticipate in nome e per conto
--    - Non concorrono alla base imponibile
--    - Es: Marche da bollo, diritti camerali, spese di spedizione
--
-- 🌍 Autofattura - 3 casistiche distinte:
--
--    1️⃣ AF-UE (Servizi UE) - Natura N2.1
--       - Consulenza da Francia, Germania, ecc.
--       - Reverse charge art. 7-ter
--       - Es: Consulente fiscale tedesco
--
--    2️⃣ AF-EX (Servizi extra-UE) - Natura N2.1
--       - Google Ads (Irlanda), Meta Ads, AWS (USA)
--       - Operazione non soggetta territorialmente
--       - Reverse charge interno
--
--    3️⃣ AF-BENI-UE (Beni intra-UE) - Natura N3.2
--       - Acquisto merci da altro Paese UE
--       - Es: Computer da fornitore tedesco
--       - Integrazione IVA con reverse charge
--
-- Riferimenti normativi:
-- - DPR 633/1972 art. 15: Esclusioni base imponibile
-- - DPR 633/1972 art. 17-ter: Split payment (DL 50/2017)
-- - DPR 633/1972 art. 7-ter: Territorialità servizi
-- - DPR 633/1972 art. 46: Acquisti intracomunitari
-- - Circolare ADE 1/E/2018: Codici Natura FE
