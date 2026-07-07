-- Riordino atomico dei passi di UNA giornata (Blocco 6 estensione web).
-- Un solo statement via UNNEST(...) WITH ORDINALITY: la posizione nell'array (1..N)
-- diventa il nuovo ordine; ogni id viene (ri)assegnato a p_itinerario_id_fk -> gestisce
-- lo spostamento cross-giornata (drag di un passo da un'altra giornata verso questa zona).
-- Atomico (transazione implicita). Scoped per azienda (confine multi-tenant).
-- Chiamare per la zona di ARRIVO e per quella di PARTENZA su un cross-day.
-- Convenzione: vedi 434_Create_FnWebTourItinerarioPassaggi_Crud.sql.
CREATE OR REPLACE FUNCTION fn_web_tour_itinerario_passaggi_reorder(
    p_azienda_id INTEGER,
    p_itinerario_id_fk BIGINT,
    p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_itinerario_passaggi p
       SET itinerario_id_fk = p_itinerario_id_fk,
           ordine           = x.nuovo_ordine::INTEGER
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE p.web_tour_itinerario_passaggi_id = x.id
       AND p.azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
