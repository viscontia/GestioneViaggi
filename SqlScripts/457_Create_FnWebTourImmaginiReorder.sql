-- Riordino atomico delle immagini di un viaggio (Blocco 7 estensione web).
-- UNNEST(...) WITH ORDINALITY: la posizione nell'array (1..N) diventa il nuovo ordine.
-- web_tour_immagini NON ha unique su ordine -> nessun rischio di violazione transitoria,
-- niente vincolo deferrable (a differenza delle giornate, Blocco 6). Scoped per azienda+viaggio.
-- Convenzione: vedi 435_Create_FnWebTourImmagini_Crud.sql.
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_reorder(
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER,
    p_ids BIGINT[])
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini i
       SET ordine = x.nuovo_ordine::INTEGER
      FROM unnest(p_ids) WITH ORDINALITY AS x(id, nuovo_ordine)
     WHERE i.web_tour_immagini_id = x.id
       AND i.viaggio_id_fk = p_viaggio_id_fk
       AND i.azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
