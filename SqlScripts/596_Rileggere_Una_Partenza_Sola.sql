-- =============================================================================
-- 596 — Rileggere UNA partenza, com'è adesso
-- =============================================================================
--
-- Stessa ragione dello script 595, applicata alle date dei viaggi: la scheda di un
-- viaggio resta aperta a lungo, e nel frattempo una partenza può essere cambiata da
-- un collega. ⚠️ Qui il rischio è concreto perché su una partenza si toccano i
-- COSTI — pilota, passeggero, bambini — e le note: risalvarci sopra valori vecchi
-- non fa perdere un dato, fa partire un preventivo sbagliato.
--
-- ⚠️ Serviva una lettura della RIGA INTERA. Il servizio aveva solo
-- `GetByViaggioIdAsync`, che restituisce un DTO di sei campi mentre l'entità ne ha
-- diciannove: usarlo per riaprire la scheda avrebbe azzerato i costi e le note —
-- un rimedio molto peggiore del problema. Provato e scartato.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_date_viaggi_get_by_id(p_data_viaggio_id INTEGER)
RETURNS SETOF ana_date_viaggi
LANGUAGE sql
STABLE
AS $$
    SELECT * FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id;
$$;

COMMENT ON FUNCTION fn_ana_date_viaggi_get_by_id(INTEGER) IS
'Una partenza sola, riga intera, per riaprirla in modifica com''e'' adesso e non com''era
quando la scheda del viaggio e'' stata aperta. Riga intera e non il DTO di riepilogo:
quello ha sei campi su diciannove, e riscriverci sopra azzererebbe costi e note.';
