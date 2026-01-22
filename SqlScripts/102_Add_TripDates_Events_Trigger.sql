
-- Trigger Function: Log Date Viaggi Events
CREATE OR REPLACE FUNCTION public.trg_log_date_viaggi_events() RETURNS trigger AS $$
DECLARE
    v_user varchar;
    v_desc text;
    v_viaggio_desc varchar;
    v_start_date date;
    v_end_date date;
BEGIN
    v_user := COALESCE(NEW.updated_by, NEW.created_by, current_user);
    
    -- Retrieve Trip Description
    SELECT viaggio_descrizione_breve INTO v_viaggio_desc
    FROM ana_viaggi 
    WHERE viaggio_id = COALESCE(NEW.viaggio_id_fk, OLD.viaggio_id_fk);

    IF (TG_OP = 'INSERT') THEN
        v_desc := 'Aggiunta Partenza (dal ' || TO_CHAR(NEW.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(NEW.data_viaggio_data_fine, 'DD/MM/YYYY') || ') del viaggio: ' || v_viaggio_desc;
        PERFORM public.fn_log_business_event('DATA_VIAGGIO_CREATED', v_desc, 'ana_date_viaggi', NEW.data_viaggio_id, NEW.azienda_id, v_user);
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (NEW.data_viaggio_data_inizio <> OLD.data_viaggio_data_inizio OR 
            NEW.data_viaggio_data_fine <> OLD.data_viaggio_data_fine OR
            NEW.data_viaggio_effettuato_sino IS DISTINCT FROM OLD.data_viaggio_effettuato_sino) THEN
            
            v_desc := 'Modificata Partenza (dal ' || TO_CHAR(NEW.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(NEW.data_viaggio_data_fine, 'DD/MM/YYYY') || ') del viaggio: ' || v_viaggio_desc;
            PERFORM public.fn_log_business_event('DATA_VIAGGIO_UPDATED', v_desc, 'ana_date_viaggi', NEW.data_viaggio_id, NEW.azienda_id, v_user);
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        BEGIN
            v_user := current_setting('my.app_user', true);
        EXCEPTION WHEN OTHERS THEN
            v_user := NULL;
        END;
        
        v_user := COALESCE(v_user, current_user);

        v_desc := 'Eliminata Partenza (dal ' || TO_CHAR(OLD.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(OLD.data_viaggio_data_fine, 'DD/MM/YYYY') || ') del viaggio: ' || v_viaggio_desc;
        PERFORM public.fn_log_business_event('DATA_VIAGGIO_DELETED', v_desc, 'ana_date_viaggi', OLD.data_viaggio_id, OLD.azienda_id, v_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach Trigger to ana_date_viaggi
DROP TRIGGER IF EXISTS trg_audit_date_viaggi_events ON public.ana_date_viaggi;
CREATE TRIGGER trg_audit_date_viaggi_events
AFTER INSERT OR UPDATE OR DELETE ON public.ana_date_viaggi
FOR EACH ROW EXECUTE FUNCTION public.trg_log_date_viaggi_events();
