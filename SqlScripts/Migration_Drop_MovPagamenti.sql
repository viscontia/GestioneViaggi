-- =============================================
-- Migration: Drop mov_pagamenti table and related objects
-- Date: 2026-02-13
-- Description: Removes mov_pagamenti table which was not used by the application.
--              All payment tracking is done via PG/IN transactions with transazione_fattura_fk.
-- =============================================

-- Step 1: Drop triggers first
DROP TRIGGER IF EXISTS trg_aggiorna_stato_dopo_pagamento ON mov_pagamenti;
DROP TRIGGER IF EXISTS trg_touch_updated_at_pagamenti ON mov_pagamenti;

-- Step 2: Drop functions used by triggers
DROP FUNCTION IF EXISTS fn_aggiorna_stato_transazione();

-- Step 3: Drop the table
DROP TABLE IF EXISTS mov_pagamenti CASCADE;

-- Step 4: Verify removal
SELECT 'Tabella mov_pagamenti eliminata con successo!' as risultato;

-- Verify no orphaned objects
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mov_pagamenti';
-- Should return 0 rows

COMMENT ON SCHEMA public IS
    'mov_pagamenti table removed on 2026-02-13. Payment tracking now uses transazione_fattura_fk in mov_transazioni.';
