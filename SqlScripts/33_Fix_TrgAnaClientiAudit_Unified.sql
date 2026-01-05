CREATE OR REPLACE FUNCTION public.trg_ana_clienti_audit_unified() RETURNS trigger LANGUAGE plpgsql AS $function$ BEGIN IF TG_OP = 'INSERT' THEN -- Auto-increment cliente_id se NULL
    IF NEW.cliente_id IS NULL THEN NEW.cliente_id := nextval('public.ana_clienti_seq');
END IF;
-- Popola created_by con priorità: my.app_user -> current_user -> 'system'
IF NEW.created_by IS NULL THEN NEW.created_by := COALESCE(
    current_setting('my.app_user', true),
    current_user,
    'system'
);
END IF;
-- Popola created se NULL
IF NEW.created IS NULL THEN NEW.created := CURRENT_TIMESTAMP;
END IF;
-- FIX: Removed setting of updated_by and updated on INSERT
-- They should remain NULL until the first update.
ELSIF TG_OP = 'UPDATE' THEN -- Aggiorna sempre updated con timestamp corrente
NEW.updated := CURRENT_TIMESTAMP;
-- FIX: Sovrascrive SEMPRE updated_by con l'utente corrente
-- Rimuoviamo il controllo "IF NEW.updated_by IS NULL" perché in un UPDATE 
-- il valore OLD persiste se non modificato esplicitamente.
NEW.updated_by := COALESCE(
    current_setting('my.app_user', true),
    current_user,
    'system'
);
END IF;
RETURN NEW;
END;
$function$