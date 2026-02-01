-- =============================================
-- Fix: Trigger functions per aggiornamento timestamp
-- =============================================
-- Problema: Il database usa DUE convenzioni diverse per i campi di audit:
-- 1. Schema VECCHIO: data_ultima_modifica (ana_aziende, ana_aziende_sedi, ana_aziende_contatti)
-- 2. Schema NUOVO: updated_at (ana_fornitori e altre tabelle)
--
-- Soluzione: Creare DUE funzioni separate per gestire entrambi gli schemi

-- =============================================
-- DROP delle funzioni esistenti
-- =============================================
DROP FUNCTION IF EXISTS fn_touch_updated_at() CASCADE;
DROP FUNCTION IF EXISTS fn_touch_data_ultima_modifica() CASCADE;

-- =============================================
-- Funzione 1: Per tabelle con campo 'updated_at' (schema nuovo)
-- =============================================
CREATE OR REPLACE FUNCTION fn_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Funzione 2: Per tabelle con campo 'data_ultima_modifica' (schema vecchio)
-- =============================================
CREATE OR REPLACE FUNCTION fn_touch_data_ultima_modifica()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_ultima_modifica = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Trigger per ana_aziende (usa data_ultima_modifica)
-- =============================================
DROP TRIGGER IF EXISTS trg_touch_updated_at_aziende ON ana_aziende;
CREATE TRIGGER trg_touch_updated_at_aziende
    BEFORE UPDATE ON ana_aziende
    FOR EACH ROW
    EXECUTE FUNCTION fn_touch_data_ultima_modifica();

-- =============================================
-- Trigger per ana_aziende_sedi (usa data_ultima_modifica)
-- =============================================
DROP TRIGGER IF EXISTS trg_touch_updated_at_sedi ON ana_aziende_sedi;
CREATE TRIGGER trg_touch_updated_at_sedi
    BEFORE UPDATE ON ana_aziende_sedi
    FOR EACH ROW
    EXECUTE FUNCTION fn_touch_data_ultima_modifica();

-- =============================================
-- Trigger per ana_aziende_contatti (usa data_ultima_modifica)
-- =============================================
DROP TRIGGER IF EXISTS trg_touch_updated_at_contatti ON ana_aziende_contatti;
CREATE TRIGGER trg_touch_updated_at_contatti
    BEFORE UPDATE ON ana_aziende_contatti
    FOR EACH ROW
    EXECUTE FUNCTION fn_touch_data_ultima_modifica();

-- =============================================
-- Trigger per ana_fornitori (usa updated_at)
-- =============================================
DROP TRIGGER IF EXISTS trg_touch_updated_at_fornitori ON ana_fornitori;
CREATE TRIGGER trg_touch_updated_at_fornitori
    BEFORE UPDATE ON ana_fornitori
    FOR EACH ROW
    EXECUTE FUNCTION fn_touch_updated_at();

-- =============================================
-- Verifica che tutti i trigger siano stati creati correttamente
-- =============================================
-- SELECT
--     t.tgname AS trigger_name,
--     c.relname AS table_name,
--     p.proname AS function_name
-- FROM pg_trigger t
-- JOIN pg_class c ON t.tgrelid = c.oid
-- JOIN pg_proc p ON t.tgfoid = p.oid
-- WHERE t.tgname LIKE 'trg_touch_updated_at%'
-- ORDER BY c.relname;
