-- Blocco 11: get/set della lingua preferita del cliente (ana_clienti.cliente_lingua),
-- gestita come side-field nella scheda cliente (evita di toccare la grande ClienteRepository).
-- Il default lo scrive fn_lingua_da_comune (backfill 465); qui l'operatore la sovrascrive.

CREATE OR REPLACE FUNCTION fn_ana_clienti_get_lingua(p_cliente_id INTEGER)
RETURNS CHAR(2) LANGUAGE sql STABLE AS $$
    SELECT cliente_lingua FROM ana_clienti WHERE cliente_id = p_cliente_id;
$$;

CREATE OR REPLACE FUNCTION fn_ana_clienti_set_lingua(p_cliente_id INTEGER, p_lingua CHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_clienti
       SET cliente_lingua = NULLIF(upper(btrim(p_lingua)), '')::CHAR(2)
     WHERE cliente_id = p_cliente_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
