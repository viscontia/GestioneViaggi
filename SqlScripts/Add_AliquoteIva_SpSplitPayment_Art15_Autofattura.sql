-- =====================================================
-- AGGIUNGI ALIQUOTE IVA SPECIALI
-- Scopo: Split Payment, Art. 15, Autofattura
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Inserisci aliquote per Azienda 6
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
-- 1. Split Payment (Scissione dei pagamenti) - PA
(
    6,
    'SP',
    'SPLIT PAYMENT ART. 17-TER',
    0.00,
    'N6',                    -- N6 = Reverse charge / Split payment
    FALSE,
    TRUE,
    13,                      -- Dopo NS (12)
    NOW(),
    'ADMIN'
),

-- 2. Art. 15 (Spese anticipate)
(
    6,
    'A15',
    'ESCLUSE EX ART. 15 DPR 633/72',
    0.00,
    'N1',                    -- N1 = Escluso ex art. 15
    FALSE,
    TRUE,
    14,
    NOW(),
    'ADMIN'
),

-- 3. Autofattura (Acquisti esteri)
(
    6,
    'AF',
    'AUTOFATTURA PER ACQUISTI ESTERI',
    0.00,
    'N6.6',                  -- N6.6 = Reverse charge acquisti esteri
    FALSE,
    TRUE,
    15,
    NOW(),
    'ADMIN'
)

ON CONFLICT (azienda_fk, iva_codice) DO NOTHING;

-- =====================================================
-- STEP 2: Inserisci aliquote per Azienda 2
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
-- 1. Split Payment (Scissione dei pagamenti) - PA
(
    2,
    'SP',
    'SPLIT PAYMENT ART. 17-TER',
    0.00,
    'N6',
    FALSE,
    TRUE,
    13,
    NOW(),
    'ADMIN'
),

-- 2. Art. 15 (Spese anticipate)
(
    2,
    'A15',
    'ESCLUSE EX ART. 15 DPR 633/72',
    0.00,
    'N1',
    FALSE,
    TRUE,
    14,
    NOW(),
    'ADMIN'
),

-- 3. Autofattura (Acquisti esteri)
(
    2,
    'AF',
    'AUTOFATTURA PER ACQUISTI ESTERI',
    0.00,
    'N6.6',
    FALSE,
    TRUE,
    15,
    NOW(),
    'ADMIN'
)

ON CONFLICT (azienda_fk, iva_codice) DO NOTHING;

-- =====================================================
-- STEP 3: Verifica risultato
-- =====================================================

DO $$
DECLARE
    v_count_az6 INTEGER;
    v_count_az2 INTEGER;
    v_count_sp_az6 INTEGER;
    v_count_sp_az2 INTEGER;
    v_count_a15_az6 INTEGER;
    v_count_a15_az2 INTEGER;
    v_count_af_az6 INTEGER;
    v_count_af_az2 INTEGER;
BEGIN
    -- Conta totali
    SELECT COUNT(*) INTO v_count_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6;
    SELECT COUNT(*) INTO v_count_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2;

    -- Conta nuove aliquote
    SELECT COUNT(*) INTO v_count_sp_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'SP';
    SELECT COUNT(*) INTO v_count_sp_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'SP';

    SELECT COUNT(*) INTO v_count_a15_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'A15';
    SELECT COUNT(*) INTO v_count_a15_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'A15';

    SELECT COUNT(*) INTO v_count_af_az6 FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = 'AF';
    SELECT COUNT(*) INTO v_count_af_az2 FROM ana_aliquote_iva WHERE azienda_fk = 2 AND iva_codice = 'AF';

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'TOTALI:';
    RAISE NOTICE '✓ Azienda 6: % aliquote totali', v_count_az6;
    RAISE NOTICE '✓ Azienda 2: % aliquote totali', v_count_az2;
    RAISE NOTICE '';
    RAISE NOTICE 'NUOVE ALIQUOTE:';
    RAISE NOTICE '✓ Split Payment (SP) - Az.6: %  Az.2: %', v_count_sp_az6, v_count_sp_az2;
    RAISE NOTICE '✓ Art. 15 (A15)      - Az.6: %  Az.2: %', v_count_a15_az6, v_count_a15_az2;
    RAISE NOTICE '✓ Autofattura (AF)   - Az.6: %  Az.2: %', v_count_af_az6, v_count_af_az2;
    RAISE NOTICE '==============================================';

    IF v_count_az6 < 10 OR v_count_az2 < 10 THEN
        RAISE WARNING '⚠ Attenzione: Attese almeno 10 aliquote per azienda';
    END IF;
END $$;

COMMIT;

-- =====================================================
-- STEP 4: Query di visualizzazione finale
-- =====================================================

-- Visualizza tutte le aliquote per entrambe le aziende
SELECT
    CASE
        WHEN azienda_fk = 6 THEN 'Azienda 6'
        WHEN azienda_fk = 2 THEN 'Azienda 2'
    END AS azienda,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    ordinamento
FROM ana_aliquote_iva
WHERE azienda_fk IN (2, 6)
ORDER BY azienda_fk, ordinamento, iva_codice;

-- Riepilogo per codice
SELECT
    iva_codice,
    iva_descrizione,
    iva_natura,
    COUNT(*) AS num_aziende
FROM ana_aliquote_iva
WHERE azienda_fk IN (2, 6)
GROUP BY iva_codice, iva_descrizione, iva_natura
ORDER BY MIN(ordinamento);

-- =====================================================
-- FINE SCRIPT
-- =====================================================

-- Note Implementative:
-- 1. Split Payment (SP) - Natura N6
--    Usato per fatture a Pubbliche Amministrazioni soggette a scissione pagamenti
--    L'IVA viene versata direttamente dalla PA, non dal fornitore
--
-- 2. Art. 15 (A15) - Natura N1
--    Spese anticipate in nome e per conto del cliente
--    Es: Marche da bollo, diritti camerali, spese di spedizione rimborsate
--    Non concorrono alla formazione della base imponibile IVA
--
-- 3. Autofattura (AF) - Natura N6.6
--    Reverse charge per acquisti di servizi da fornitori extra-UE
--    Es: Google Ads, Meta Ads, AWS, servizi digitali esteri
--    Il committente italiano emette autofattura e versa IVA
--
-- Riferimenti normativi:
-- - DPR 633/1972 art. 15: Esclusioni dalla base imponibile
-- - DPR 633/1972 art. 17-ter: Split payment (DL 50/2017)
-- - Reverse charge: art. 17 DPR 633/72 e Direttiva 2006/112/CE
