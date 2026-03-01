-- ============================================================
-- 211: Aggiunta colonna regime_fiscale_fk a ana_aziende
-- FK verso ana_regimi_fiscali + backfill dati esistenti
-- ============================================================

BEGIN;

-- 1. Aggiungere colonna (nullable inizialmente per permettere backfill)
ALTER TABLE ana_aziende
ADD COLUMN IF NOT EXISTS regime_fiscale_fk INTEGER REFERENCES ana_regimi_fiscali(regime_id);

COMMENT ON COLUMN ana_aziende.regime_fiscale_fk IS 'Regime fiscale dell''azienda. Determina comportamento UI e calcoli IVA.';

-- 2. Backfill: tutte le aziende -> ORDINARIO (default)
UPDATE ana_aziende
SET regime_fiscale_fk = (
    SELECT regime_id FROM ana_regimi_fiscali WHERE regime_codice = 'ORDINARIO'
)
WHERE regime_fiscale_fk IS NULL;

-- 3. Backfill: aziende 2 e 6 (note come forfettarie) -> FORFETTARIO
UPDATE ana_aziende
SET regime_fiscale_fk = (
    SELECT regime_id FROM ana_regimi_fiscali WHERE regime_codice = 'FORFETTARIO'
)
WHERE azienda_id IN (2, 6);

-- 4. Rendere NOT NULL dopo backfill
ALTER TABLE ana_aziende ALTER COLUMN regime_fiscale_fk SET NOT NULL;

-- 5. Nota: il default per nuove aziende (ORDINARIO) viene gestito a livello applicativo
-- in AziendaDialog.razor, perche PostgreSQL non supporta subquery nei DEFAULT.

COMMIT;
