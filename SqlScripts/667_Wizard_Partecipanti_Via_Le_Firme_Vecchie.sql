-- ============================================================================
-- 667 — Via le firme delle letture del wizard senza azienda
--
-- Seconda meta' del 663. Il 663 ha creato fn_wizard_get_client_data,
-- fn_wizard_get_partecipanti_details e fn_wizard_get_partecipanti con il
-- parametro p_azienda_id, ACCANTO alle vecchie, che leggono clienti di
-- qualunque azienda. Qui le vecchie si cancellano: finche' esistono, la porta
-- di L13 resta aperta a chi le chiama.
--
-- ⛔️ ORDINE: solo DOPO che il sito Flask nuovo gira in produzione ed e' stato
-- provato (un'iscrizione vera, il riepilogo, la mail di conferma). Il sito
-- vecchio chiama le firme vecchie: se questo script parte prima, riepilogo,
-- /api/partecipanti e mail di conferma si rompono (le mail in silenzio).
--
-- TORNARE INDIETRO: se il sito nuovo va ritirato DOPO questo script, le firme
-- vecchie si ricreano con il corpo che e' in Test_663 (pg_temp.vecchia_*),
-- nello schema public. Prima di questo script non serve niente: basta
-- rimettere il sito vecchio.
--
-- Test: Test_667_Wizard_Partecipanti_Via_Le_Firme_Vecchie.sql.
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS fn_wizard_get_client_data(integer);
DROP FUNCTION IF EXISTS fn_wizard_get_partecipanti_details(integer[]);
DROP FUNCTION IF EXISTS fn_wizard_get_partecipanti(integer[]);

COMMIT;
