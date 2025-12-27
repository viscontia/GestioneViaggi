-- Fix ana_aziende_banche: Rimuovi trigger che cerca campo inesistente
-- Errore: 42703: record "new" has no field "data_ultima_modifica"
-- La tabella ana_aziende_banche non ha campi di audit e non li deve avere

-- Rimuovi il trigger che cerca di aggiornare data_ultima_modifica
DROP TRIGGER IF EXISTS trg_touch_updated_at_banche ON ana_aziende_banche;

-- Verifica che il trigger sia stato rimosso
-- SELECT tgname FROM pg_trigger WHERE tgrelid = 'ana_aziende_banche'::regclass;
