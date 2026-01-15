CREATE OR REPLACE FUNCTION get_viaggio_partecipanti_summary(
    p_data_viaggio_id INT
) RETURNS TEXT AS $$
DECLARE
    v_piloti INT;
    v_passeggeri INT;
    v_totale INT;
    v_result TEXT;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE tp.tipo_partecipante_pilota = true),
        COUNT(*) FILTER (WHERE tp.tipo_partecipante_pilota = false)
    INTO v_piloti, v_passeggeri
    FROM mov_clienti_viaggi v
    JOIN ana_tipo_partecipante tp ON v.tipo_partecipante_id_fk = tp.tipo_partecipante_id
    WHERE v.data_viaggio_id_fk = p_data_viaggio_id;

    v_totale := COALESCE(v_piloti, 0) + COALESCE(v_passeggeri, 0);

    RETURN v_piloti || ' piloti, ' || v_passeggeri || ' passeggeri ==> Totale ' || v_totale || ' persone';
END;
$$ LANGUAGE plpgsql;
