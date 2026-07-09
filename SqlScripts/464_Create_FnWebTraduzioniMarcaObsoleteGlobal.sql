-- Blocco 10: marca obsolete le traduzioni di un campo di un'entità GLOBALE (senza azienda_id),
-- es. web_tipi_viaggio_descrizioni.descrizione_web. L'unique di web_traduzioni è
-- (entita, entita_id, campo, lingua) SENZA azienda: la traduzione è unica a prescindere
-- da quale azienda l'abbia prodotta, quindi qui NON si filtra per azienda.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_marca_obsolete_global(
    p_entita VARCHAR,
    p_entita_id BIGINT,
    p_campo VARCHAR)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_traduzioni
       SET obsoleto = TRUE
     WHERE entita = p_entita AND entita_id = p_entita_id AND campo = p_campo;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
