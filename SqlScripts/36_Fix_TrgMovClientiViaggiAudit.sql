CREATE OR REPLACE FUNCTION public.trg_mov_clienti_viaggi_audit() RETURNS trigger LANGUAGE plpgsql AS $function$ BEGIN IF TG_OP = 'INSERT' THEN -- Popola created_by con priorità: my.app_user -> current_user -> 'system'
    IF NEW.created_by IS NULL THEN NEW.created_by := COALESCE(
        current_setting('my.app_user', true),
        current_user,
        'system'
    );
END IF;
-- Popola created se NULL
IF NEW.created IS NULL THEN NEW.created := CURRENT_TIMESTAMP;
END IF;
-- FIX: Ensure updated_by and updated are NULL on INSERT
-- They should remain NULL until the first update.
-- Explicitly setting them to NULL just in case they were passed with values
-- (Optional, but safe if we want to enforce "created only")
-- However, usually we just don't set them if they are null.
-- Given the pattern, we just don't touch them.
ELSIF TG_OP = 'UPDATE' THEN -- Aggiorna sempre updated con timestamp corrente
NEW.updated := CURRENT_TIMESTAMP;
-- FIX: Sovrascrive SEMPRE updated_by con l'utente corrente
NEW.updated_by := COALESCE(
    current_setting('my.app_user', true),
    current_user,
    'system'
);
END IF;
RETURN NEW;
END;
$function$