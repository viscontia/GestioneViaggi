-- FUNZIONE PER IL RECUPERO CENTRALIZZATO DEI CONTEGGI BADGE AZIENDA
-- Scopo: Ridurre le sessioni parallele all'apertura del dialog Azienda
-- Creato il: 2026-03-14

CREATE OR REPLACE FUNCTION fn_get_azienda_badge_counts(p_azienda_id INT)
RETURNS TABLE (
    sedi INT, 
    contatti INT, 
    banche INT, 
    email INT, 
    reparti INT, 
    smtp INT, 
    logo INT
) AS $$
BEGIN
    RETURN QUERY SELECT 
        (SELECT COUNT(*)::INT FROM ana_aziende_sedi WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM ana_aziende_contatti WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM ana_aziende_banche WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM ana_aziende_email WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM reparti_aziendali WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM ana_aziende_smtp WHERE azienda_fk = p_azienda_id),
        (SELECT COUNT(*)::INT FROM ana_aziende_logo WHERE azienda_fk = p_azienda_id);
END; $$ LANGUAGE plpgsql;
