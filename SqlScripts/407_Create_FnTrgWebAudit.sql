CREATE OR REPLACE FUNCTION public.trg_web_audit()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.created_by IS NULL THEN
            NEW.created_by := COALESCE(current_setting('my.app_user', true), current_user, 'system');
        END IF;
        IF NEW.created IS NULL THEN
            NEW.created := CURRENT_TIMESTAMP;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated    := CURRENT_TIMESTAMP;
        NEW.updated_by := COALESCE(current_setting('my.app_user', true), current_user, 'system');
    END IF;
    RETURN NEW;
END;
$function$;
