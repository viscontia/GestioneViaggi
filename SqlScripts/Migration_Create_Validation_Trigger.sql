-- =============================================
-- Migration: Create Metadata-Driven Validation Trigger
-- Date: 2026-02-12
-- Description: Dynamic validation based on ana_tipi_causali metadata
--              Enforces: scadenza requirements, auto-generation, stato consistency
-- =============================================

CREATE OR REPLACE FUNCTION fn_validate_transazione_metadata()
RETURNS TRIGGER AS $$
DECLARE
    v_causale RECORD;
BEGIN
    -- Fetch causale metadata
    SELECT
        causale_codice,
        causale_descrizione,
        causale_is_documento,
        causale_richiede_scadenza,
        causale_giorni_scadenza_default,
        causale_genera_scadenza_auto,
        causale_ciclo
    INTO v_causale
    FROM ana_tipi_causali
    WHERE causale_id = NEW.transazione_causale_tipo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Causale con ID % non trovata', NEW.transazione_causale_tipo_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    -- =============================================
    -- RULE 1: Scadenza obbligatoria per documenti (metadata-driven)
    -- =============================================
    IF v_causale.causale_richiede_scadenza = TRUE
       AND NEW.transazione_data_scadenza IS NULL THEN
        RAISE EXCEPTION 'ERRORE VALIDAZIONE: La causale "%" richiede la Data Scadenza obbligatoria. '
                        'Impossibile procedere senza questo dato.',
                        v_causale.causale_descrizione
            USING ERRCODE = 'check_violation',
                  HINT = 'Inserire la data scadenza o selezionare una causale che non la richiede';
    END IF;

    -- =============================================
    -- RULE 2: Auto-generate scadenza if metadata says so
    -- =============================================
    IF v_causale.causale_genera_scadenza_auto = TRUE
       AND NEW.transazione_data_scadenza IS NULL
       AND v_causale.causale_giorni_scadenza_default IS NOT NULL THEN

        -- Use data_documento as base, fallback to transazione_data
        IF NEW.transazione_data_documento IS NOT NULL THEN
            NEW.transazione_data_scadenza :=
                NEW.transazione_data_documento + v_causale.causale_giorni_scadenza_default;
        ELSE
            NEW.transazione_data_scadenza :=
                NEW.transazione_data + v_causale.causale_giorni_scadenza_default;
        END IF;

        RAISE NOTICE 'Data scadenza generata automaticamente: % (base: %, +% giorni)',
            NEW.transazione_data_scadenza,
            COALESCE(NEW.transazione_data_documento, NEW.transazione_data),
            v_causale.causale_giorni_scadenza_default;
    END IF;

    -- =============================================
    -- RULE 3: Coerenza stato PAGATO vs data_pagamento
    -- =============================================
    IF NEW.transazione_stato = 'PAGATO' AND NEW.transazione_data_pagamento IS NULL THEN
        RAISE EXCEPTION 'ERRORE VALIDAZIONE: Se lo stato è PAGATO, la Data Pagamento è obbligatoria.'
            USING ERRCODE = 'check_violation',
                  HINT = 'Inserire la data di pagamento o cambiare lo stato';
    END IF;

    -- =============================================
    -- RULE 4: Prevent data_pagamento for DA_PAGARE (cleanup)
    -- =============================================
    IF NEW.transazione_stato = 'DA_PAGARE' AND NEW.transazione_data_pagamento IS NOT NULL THEN
        RAISE WARNING 'Attenzione: stato DA_PAGARE ma data_pagamento presente. Verrà rimossa.';
        NEW.transazione_data_pagamento := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if present
DROP TRIGGER IF EXISTS trg_validate_transazione_metadata ON mov_transazioni;

-- Create trigger (execute BEFORE INSERT/UPDATE)
CREATE TRIGGER trg_validate_transazione_metadata
BEFORE INSERT OR UPDATE OF
    transazione_causale_tipo_id,
    transazione_stato,
    transazione_data_scadenza,
    transazione_data_pagamento,
    transazione_data_documento,
    transazione_data
ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_validate_transazione_metadata();

-- Add comments for documentation
COMMENT ON FUNCTION fn_validate_transazione_metadata() IS
    'Validates transactions based on metadata from ana_tipi_causali. '
    'Enforces: scadenza requirements (RULE 1), auto-generation (RULE 2), '
    'stato consistency (RULE 3-4). All rules are data-driven, no hardcoding.';

COMMENT ON TRIGGER trg_validate_transazione_metadata ON mov_transazioni IS
    'Metadata-driven validation trigger - reads rules from ana_tipi_causali. '
    'Executed BEFORE INSERT/UPDATE to enforce business rules dynamically.';
