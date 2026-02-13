-- Migration: Remove incorrect payment constraint
-- Date: 2026-02-12
-- Description: Removes the chk_pagamento_dopo_scadenza constraint which incorrectly
--              prevents early payments (payments made before the due date)
--
-- Issue: The constraint required data_pagamento >= data_scadenza, but in reality
--        invoices can and should be paid before their due date.
--
-- Solution: Remove the constraint. The chk_pagamento_dopo_documento constraint
--           already ensures that data_pagamento >= data_documento, which is the
--           correct validation.

ALTER TABLE mov_transazioni
DROP CONSTRAINT IF EXISTS chk_pagamento_dopo_scadenza;
