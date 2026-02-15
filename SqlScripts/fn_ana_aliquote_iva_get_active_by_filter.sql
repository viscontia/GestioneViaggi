-- ============================================================================
-- fn_ana_aliquote_iva_get_active_by_filter
-- Recupera le aliquote IVA attive con filtro opzionale per "Solo con IVA"
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_ana_aliquote_iva_get_active_by_filter(
    p_azienda_id INTEGER,
    p_solo_con_iva BOOLEAN DEFAULT NULL
)
RETURNS SETOF ana_aliquote_iva
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT *
    FROM ana_aliquote_iva
    WHERE azienda_fk = p_azienda_id
      AND is_active = TRUE
      AND (
          p_solo_con_iva IS NULL 
          OR (p_solo_con_iva = TRUE AND iva_percentuale > 0)
          OR (p_solo_con_iva = FALSE AND iva_percentuale = 0)
      )
    ORDER BY ordinamento, iva_descrizione;
END;
$function$;
