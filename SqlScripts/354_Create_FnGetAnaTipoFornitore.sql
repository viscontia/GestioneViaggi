-- =====================================================
-- Function: fn_get_ana_tipo_fornitore
-- Description: Recupera i tipi fornitore filtrati per azienda
-- Parameters:
--   p_azienda_id: ID azienda (NULL per SuperAdmin = tutti i record)
-- Returns: TABLE con tutti i campi di ana_tipo_fornitore
-- =====================================================

CREATE OR REPLACE FUNCTION fn_get_ana_tipo_fornitore(
    p_azienda_id INT DEFAULT NULL
)
RETURNS TABLE (
    tipo_fornitore_id INTEGER,
    azienda_fk INTEGER,
    descrizione VARCHAR(50),
    categoria VARCHAR(20),
    conto_contabile_default VARCHAR(20),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.tipo_fornitore_id,
        t.azienda_fk,
        t.descrizione,
        t.categoria,
        t.conto_contabile_default,
        t.created_at,
        t.updated_at
    FROM ana_tipo_fornitore t
    WHERE
        -- Se p_azienda_id è NULL (SuperAdmin "Tutte"), mostra tutti
        -- Altrimenti filtra per azienda specifica
        (p_azienda_id IS NULL OR t.azienda_fk = p_azienda_id)
    ORDER BY t.descrizione ASC;
END;
$$;

-- Commento per documentazione
COMMENT ON FUNCTION fn_get_ana_tipo_fornitore(INT) IS
'Recupera i tipi fornitore filtrati per azienda. Se p_azienda_id è NULL, restituisce tutti i record (SuperAdmin).';
