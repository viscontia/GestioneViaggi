-- 403_Create_MovClientiAlloggi_ReadFunction.sql
-- DESCRIZIONE: Funzione di lettura per mov_clienti_alloggi (conversione da SQL inline a DB-First)
-- DATA: 2026-03-16
-- AUTORE: Antigravity

-- =================================================================================================
-- FUNCTION: fn_get_mov_clienti_alloggi_by_date
-- DESCRIZIONE: Recupera tutti gli alloggi assegnati per una specifica data viaggio
-- SOSTITUISCE: SQL inline in MovClientiAlloggiService.GetByDateIdAsync (linee 149-180)
-- =================================================================================================
CREATE OR REPLACE FUNCTION fn_get_mov_clienti_alloggi_by_date(
    p_data_viaggio_id INT
)
RETURNS TABLE(
    mov_clienti_alloggio_pk INT,
    viaggio_id_fk INT,
    data_viaggio_id_fk INT,
    tipo_alloggio_id_fk INT,
    cliente_id1_fk INT,
    cliente_id2_fk INT,
    cliente_id3_fk INT,
    cliente_id4_fk INT,
    cliente_id5_fk INT,
    cliente_id6_fk INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mca.mov_clienti_alloggio_pk,
        mca.viaggio_id_fk,
        mca.data_viaggio_id_fk,
        mca.tipo_alloggio_id_fk,
        mca.cliente_id1_fk,
        mca.cliente_id2_fk,
        mca.cliente_id3_fk,
        mca.cliente_id4_fk,
        mca.cliente_id5_fk,
        mca.cliente_id6_fk
    FROM mov_clienti_alloggi mca
    WHERE mca.data_viaggio_id_fk = p_data_viaggio_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_mov_clienti_alloggi_by_date(INT) IS
'Recupera tutti gli alloggi (camere) assegnati per una specifica data viaggio. Restituisce dati raw con i 6 slot clienti (ClienteId1Fk...ClienteId6Fk).';
