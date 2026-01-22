
-- 1. Create Business Events Table
CREATE TABLE IF NOT EXISTS public.ana_business_events (
    event_id serial PRIMARY KEY,
    event_type varchar(50) NOT NULL, -- 'VIAGGIO_CREATED', 'VIAGGIO_UPDATED', 'PARTECIPANTE_ADDED', 'PARTECIPANTE_REMOVED'
    description text NOT NULL,
    entity_table varchar(100) NOT NULL,
    entity_id integer NOT NULL,
    azienda_id integer NULL, -- Nullable for system events or cross-company
    created_at timestamp DEFAULT now(),
    created_by varchar(100)
);

-- Index for fast retrieval by azienda and date
CREATE INDEX IF NOT EXISTS idx_ana_business_events_azienda_date 
    ON public.ana_business_events (azienda_id, created_at DESC);

-- 2. Function to Log Events
CREATE OR REPLACE FUNCTION public.fn_log_business_event(
    p_event_type varchar,
    p_description text,
    p_entity_table varchar,
    p_entity_id integer,
    p_azienda_id integer,
    p_created_by varchar
) RETURNS void AS $$
BEGIN
    INSERT INTO public.ana_business_events (
        event_type, description, entity_table, entity_id, azienda_id, created_by, created_at
    ) VALUES (
        p_event_type, p_description, p_entity_table, p_entity_id, p_azienda_id, COALESCE(p_created_by, 'system'), now()
    );
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger Function: Log Viaggi Events
CREATE OR REPLACE FUNCTION public.trg_log_viaggi_events() RETURNS trigger AS $$
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
        v_desc := 'Creato nuovo viaggio: ' || NEW.viaggio_descrizione_breve;
        PERFORM public.fn_log_business_event('VIAGGIO_CREATED', v_desc, 'ana_viaggi', NEW.viaggio_id, NEW.azienda_id, v_user);
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Avoid logging trivial updates (like just updated_by changed)
        IF (NEW.viaggio_descrizione_breve <> OLD.viaggio_descrizione_breve OR 
            NEW.viaggio_nazione_fk <> OLD.viaggio_nazione_fk) THEN
            
            v_desc := 'Modificato viaggio: ' || NEW.viaggio_descrizione_breve;
            PERFORM public.fn_log_business_event('VIAGGIO_UPDATED', v_desc, 'ana_viaggi', NEW.viaggio_id, NEW.azienda_id, v_user);
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- v_user is already set from session above
        v_desc := 'Eliminato viaggio: ' || OLD.viaggio_descrizione_breve;
        PERFORM public.fn_log_business_event('VIAGGIO_DELETED', v_desc, 'ana_viaggi', OLD.viaggio_id, OLD.azienda_id, v_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 4. Trigger Function: Log Partecipanti Events
CREATE OR REPLACE FUNCTION public.trg_log_partecipanti_events() RETURNS trigger AS $$
DECLARE
    v_viaggio_desc varchar;
    v_user varchar;
    v_azienda_id integer;
    v_nominativo varchar;
BEGIN
    -- Get Trip Info
    SELECT viaggio_descrizione_breve, azienda_id INTO v_viaggio_desc, v_azienda_id
    FROM ana_viaggi WHERE viaggio_id = COALESCE(NEW.viaggio_id_fk, OLD.viaggio_id_fk);

    -- Get Client Name
    SELECT COALESCE(cliente_nome || ' ' || cliente_cognome, 'Cliente ' || cliente_id) INTO v_nominativo
    FROM ana_clienti WHERE cliente_id = COALESCE(NEW.cliente_id_fk, OLD.cliente_id_fk);

    BEGIN
        v_user := current_setting('my.app_user', true);
    EXCEPTION WHEN OTHERS THEN
        v_user := NULL;
    END;
    v_user := COALESCE(v_user, NEW.updated_by, NEW.created_by, current_user);

    IF (TG_OP = 'INSERT') THEN
        PERFORM public.fn_log_business_event(
            'PARTECIPANTE_ADDED', 
            'Iscritto ' || v_nominativo || ' al viaggio "' || v_viaggio_desc || '"', 
            'mov_clienti_viaggi', 
            NEW.cliente_id_fk, -- Using ClientID as EntityID as table has composite PK
            v_azienda_id, 
            v_user
        );
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Changed participant details (e.g. notes, type, vehicle)
         PERFORM public.fn_log_business_event(
            'PARTECIPANTE_UPDATED', 
            'Modificato iscrizione di ' || v_nominativo || ' per il viaggio "' || v_viaggio_desc || '"', 
            'mov_clienti_viaggi', 
            NEW.cliente_id_fk, 
            v_azienda_id, 
            v_user
        );
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
         -- On delete we rely on session user as we might not have it in OLD
         PERFORM public.fn_log_business_event(
            'PARTECIPANTE_REMOVED', 
            'Rimosso ' || v_nominativo || ' dal viaggio "' || v_viaggio_desc || '"', 
            'mov_clienti_viaggi', 
            OLD.cliente_id_fk, 
            v_azienda_id, 
            v_user
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Attach Triggers
DROP TRIGGER IF EXISTS trg_audit_viaggi_events ON public.ana_viaggi;
CREATE TRIGGER trg_audit_viaggi_events
AFTER INSERT OR UPDATE OR DELETE ON public.ana_viaggi
FOR EACH ROW EXECUTE FUNCTION public.trg_log_viaggi_events();

DROP TRIGGER IF EXISTS trg_audit_partecipanti_events ON public.mov_clienti_viaggi;
CREATE TRIGGER trg_audit_partecipanti_events
AFTER INSERT OR UPDATE OR DELETE ON public.mov_clienti_viaggi
FOR EACH ROW EXECUTE FUNCTION public.trg_log_partecipanti_events();
