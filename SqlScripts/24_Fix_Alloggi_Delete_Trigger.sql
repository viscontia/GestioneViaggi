-- Fix Trigger Function for Client Deletion (Alloggi)
-- Ensures reference is to existing table 'mov_clienti_alloggi'
-- Removes any potential legacy reference to 'ana_iscrizioni'
CREATE OR REPLACE FUNCTION trg_prevent_client_delete_alloggi_func() RETURNS TRIGGER AS $$
DECLARE v_count INTEGER;
BEGIN
SELECT COUNT(*) INTO v_count
FROM public.mov_clienti_alloggi
WHERE cliente_id1_fk = OLD.cliente_id
    OR cliente_id2_fk = OLD.cliente_id
    OR cliente_id3_fk = OLD.cliente_id
    OR cliente_id4_fk = OLD.cliente_id
    OR cliente_id5_fk = OLD.cliente_id
    OR cliente_id6_fk = OLD.cliente_id;
IF v_count > 0 THEN RAISE EXCEPTION 'Impossibile cancellare il cliente: ha % alloggi associati',
v_count;
END IF;
RETURN OLD;
END;
$$ LANGUAGE plpgsql;
-- Ensure the trigger uses this function
DROP TRIGGER IF EXISTS trg_prevent_client_delete_alloggi ON ana_clienti;
CREATE TRIGGER trg_prevent_client_delete_alloggi BEFORE DELETE ON ana_clienti FOR EACH ROW EXECUTE FUNCTION trg_prevent_client_delete_alloggi_func();