-- =====================================================
-- COPIA ALIQUOTE IVA: Azienda 6 -> Azienda 2
-- Scopo: Replica configurazione aliquote IVA
-- Creato: 14/02/2026
-- Autore: Adriano Visconti
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Verifica esistenza aziende
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ana_aziende WHERE azienda_id = 6) THEN
        RAISE EXCEPTION 'Azienda sorgente (ID 6) non trovata';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ana_aziende WHERE azienda_id = 2) THEN
        RAISE EXCEPTION 'Azienda destinazione (ID 2) non trovata';
    END IF;

    RAISE NOTICE '✓ Entrambe le aziende esistono';
END $$;

-- =====================================================
-- STEP 2: Copia aliquote da azienda 6 ad azienda 2
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
    created_by,
    updated_at,
    updated_by
)
SELECT
    2 AS azienda_fk,                    -- Cambia azienda da 6 a 2
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento,
    NOW() AS created_at,
    'SYSTEM_MIGRATION' AS created_by,
    NOW() AS updated_at,
    'SYSTEM_MIGRATION' AS updated_by
FROM ana_aliquote_iva
WHERE azienda_fk = 6
ON CONFLICT (azienda_fk, iva_codice)
DO UPDATE SET
    iva_descrizione = EXCLUDED.iva_descrizione,
    iva_percentuale = EXCLUDED.iva_percentuale,
    iva_natura = EXCLUDED.iva_natura,
    is_default = EXCLUDED.is_default,
    is_active = EXCLUDED.is_active,
    ordinamento = EXCLUDED.ordinamento,
    updated_at = NOW(),
    updated_by = 'SYSTEM_MIGRATION';

-- =====================================================
-- STEP 3: Verifica risultato
-- =====================================================
DO $$
DECLARE
    v_count_source INTEGER;
    v_count_target INTEGER;
    v_default_count INTEGER;
BEGIN
    -- Conta aliquote azienda 6
    SELECT COUNT(*) INTO v_count_source
    FROM ana_aliquote_iva
    WHERE azienda_fk = 6;

    -- Conta aliquote azienda 2
    SELECT COUNT(*) INTO v_count_target
    FROM ana_aliquote_iva
    WHERE azienda_fk = 2;

    -- Conta aliquote default azienda 2
    SELECT COUNT(*) INTO v_default_count
    FROM ana_aliquote_iva
    WHERE azienda_fk = 2 AND is_default = TRUE;

    RAISE NOTICE '✓ Azienda 6: % aliquote', v_count_source;
    RAISE NOTICE '✓ Azienda 2: % aliquote', v_count_target;
    RAISE NOTICE '✓ Aliquote default azienda 2: %', v_default_count;

    IF v_count_target = 0 THEN
        RAISE EXCEPTION '✗ Errore: Nessuna aliquota copiata per azienda 2';
    END IF;

    IF v_default_count > 1 THEN
        RAISE EXCEPTION '✗ Errore: Azienda 2 ha % aliquote default (attesa: 1)', v_default_count;
    END IF;

    IF v_default_count = 0 THEN
        RAISE WARNING '⚠ Attenzione: Azienda 2 non ha aliquota default';
    END IF;
END $$;

COMMIT;

-- =====================================================
-- STEP 4: Query di verifica finale
-- =====================================================

-- Visualizza aliquote copiate per azienda 2
SELECT
    iva_id,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    iva_natura,
    is_default,
    is_active,
    ordinamento,
    created_by
FROM ana_aliquote_iva
WHERE azienda_fk = 2
ORDER BY ordinamento, iva_codice;

-- Confronto tra azienda 6 e 2
SELECT
    'Azienda 6' AS azienda,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    is_default,
    ordinamento
FROM ana_aliquote_iva
WHERE azienda_fk = 6

UNION ALL

SELECT
    'Azienda 2' AS azienda,
    iva_codice,
    iva_descrizione,
    iva_percentuale,
    is_default,
    ordinamento
FROM ana_aliquote_iva
WHERE azienda_fk = 2

ORDER BY iva_codice, azienda;

-- =====================================================
-- FINE SCRIPT
-- =====================================================

-- Note:
-- 1. Se aliquote già esistono per azienda 2, vengono aggiornate (ON CONFLICT DO UPDATE)
-- 2. Il trigger fn_check_single_default_iva garantisce che solo 1 aliquota sia default
-- 3. Se entrambe le aziende avevano aliquote default diverse, l'ultima INSERT vince
-- 4. I campi audit sono impostati a 'SYSTEM_MIGRATION' per tracciabilità
