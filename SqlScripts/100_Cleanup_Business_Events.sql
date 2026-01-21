
-- Function to clean up old business events
CREATE OR REPLACE FUNCTION public.cleanup_business_events(p_days_to_keep integer)
 RETURNS integer
 LANGUAGE plpgsql
 AS $function$
DECLARE
    v_rows_deleted int;
BEGIN
    DELETE FROM public.ana_business_events
    WHERE created_at < (now() - (p_days_to_keep || ' days')::interval);
    
    GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
    
    RETURN v_rows_deleted;
END;
$function$;
