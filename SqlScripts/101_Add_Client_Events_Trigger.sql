
-- Trigger Function: Log Clienti Events
CREATE OR REPLACE FUNCTION public.trg_log_clienti_events() RETURNS trigger AS $$
DECLARE
    v_user varchar;
    v_desc text;
BEGIN
    BEGIN
        v_user := current_setting('my.app_user', true);
    EXCEPTION WHEN OTHERS THEN
        v_user := NULL;
    END;
    v_user := COALESCE(v_user, NEW.updated_by, NEW.created_by, current_user);
    
    IF (TG_OP = 'INSERT') THEN
        v_desc := 'Creato nuovo cliente: ' || NEW.cliente_nome || ' ' || NEW.cliente_cognome;
        PERFORM public.fn_log_business_event('CLIENTE_CREATED', v_desc, 'ana_clienti', NEW.cliente_id, NEW.azienda_fk, v_user);
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Log significant updates
        IF (NEW.cliente_nome <> OLD.cliente_nome OR 
            NEW.cliente_cognome <> OLD.cliente_cognome OR
            NEW.cliente_email <> OLD.cliente_email) THEN
            
            v_desc := 'Modificato cliente: ' || NEW.cliente_nome || ' ' || NEW.cliente_cognome;
            PERFORM public.fn_log_business_event('CLIENTE_UPDATED', v_desc, 'ana_clienti', NEW.cliente_id, NEW.azienda_fk, v_user);
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        -- v_user is set from session
        v_desc := 'Eliminato cliente: ' || OLD.cliente_nome || ' ' || OLD.cliente_cognome;
        PERFORM public.fn_log_business_event('CLIENTE_DELETED', v_desc, 'ana_clienti', OLD.cliente_id, OLD.azienda_fk, v_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach Trigger to ana_clienti
DROP TRIGGER IF EXISTS trg_audit_clienti_events ON public.ana_clienti;
CREATE TRIGGER trg_audit_clienti_events
AFTER INSERT OR UPDATE OR DELETE ON public.ana_clienti
FOR EACH ROW EXECUTE FUNCTION public.trg_log_clienti_events();
