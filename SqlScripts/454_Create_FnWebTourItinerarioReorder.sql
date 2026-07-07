-- Riordino atomico delle giornate di un viaggio (Blocco 6 estensione web).
-- Un solo statement via UNNEST(...) WITH ORDINALITY: la posizione nell'array (1..N)
-- diventa il nuovo giorno_numero/ordine. Atomico (transazione implicita): tutto o niente.
-- Scoped per azienda + viaggio (confine multi-tenant). Ritorna il numero di righe aggiornate.
-- Convenzione: vedi 433_Create_FnWebTourItinerario_Crud.sql (SECURITY INVOKER, audit via trg_web_audit).
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_reorder(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario g
       SET giorno_numero = x.nuovo_ordine::INTEGER,
           ordine        = x.nuovo_ordine::INTEGER
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE g.web_tour_itinerario_id = x.id
       AND g.viaggio_id_fk = p_viaggio_id_fk
       AND g.azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
