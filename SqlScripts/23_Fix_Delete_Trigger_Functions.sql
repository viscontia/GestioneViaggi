-- Fix Trigger Functions for Client Deletion
-- Ensures references are to existing tables (mov_clienti_viaggi, mov_clienti_alloggi)
-- Removes potential references to non-existent 'ana_iscrizioni'
CREATE OR REPLACE FUNCTION trg_prevent_client_delete_func() RETURNS TRIGGER AS $$
DECLARE v_count INTEGER;
BEGIN -- Check if client has associated trips (using correct table name)
SELECT COUNT(*) INTO v_count
FROM public.mov_clienti_viaggi
WHERE cliente_id_fk = OLD.cliente_id;
IF v_count > 0 THEN RAISE EXCEPTION 'Impossibile cancellare il cliente: ha % viaggi associati',
v_count;
END IF;
RETURN OLD;
END;
$$ LANGUAGE plpgsql;
-- Ensure the trigger uses this function
DROP TRIGGER IF EXISTS trg_prevent_client_delete ON ana_clienti;
CREATE TRIGGER trg_prevent_client_delete BEFORE DELETE ON ana_clienti FOR EACH ROW EXECUTE FUNCTION trg_prevent_client_delete_func();