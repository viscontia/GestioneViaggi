CREATE OR REPLACE FUNCTION get_mezzo_by_pilot(
    p_viaggio_id INT, 
    p_data_viaggio_id INT, 
    p_cliente_id INT
) RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    SELECT 
        TRIM(
            COALESCE(m.ana_mezzi_descrizione, '') || ' ' || 
            COALESCE(mod_v.mezzo_modello_descrizione, '') || 
            CASE WHEN v.mov_cliente_viaggio_targa_mezzo IS NOT NULL AND v.mov_cliente_viaggio_targa_mezzo <> '' 
                 THEN ' - ' || v.mov_cliente_viaggio_targa_mezzo 
                 ELSE '' 
            END
        )
    INTO v_result
    FROM mov_clienti_viaggi v
    LEFT JOIN ana_mezzi m ON v.ana_mezzi_id_fk = m.ana_mezzi_id
    LEFT JOIN ana_mezzi_modelli mod_v ON v.mezzo_modello_id_fk = mod_v.mezzo_modello_id
    WHERE v.viaggio_id_fk = p_viaggio_id
      AND v.data_viaggio_id_fk = p_data_viaggio_id
      AND v.cliente_id_fk = p_cliente_id;

    RETURN v_result;

END;
$$ LANGUAGE plpgsql;
