-- FUNZIONE FAT INIT PER ANAGRAFICA CONTROPARTI
-- Consolida: 
-- 1. Lista Comuni (per ComuneSelect)
-- 2. Lista Aziende (per SuperAdmin)
-- 3. Lista Tipi Fornitore
-- 4. Dettaglio Comune della controparte (se p_controparte_id fornito)

CREATE OR REPLACE FUNCTION fn_get_controparte_init_data(p_controparte_id INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    v_comuni JSON;
    v_aziende JSON;
    v_tipi_fornitore JSON;
    v_comune_dettaglio JSON;
    v_result JSON;
BEGIN
    -- 1. Caricamento Comuni (formattati per il DTO C#)
    SELECT json_agg(t) INTO v_comuni
    FROM (
        SELECT 
            c.comune_id as "Id",
            c.comune as "Nome",
            c.cap as "Cap",
            p.provincia_sigla as "ProvinciaSigla",
            r.regione_descrizione as "RegioneDescrizione",
            c.comune_estero as "ComuneEstero"
        FROM ana_geo_comuni c
        LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
        LEFT JOIN ana_geo_regioni_ita r ON p.provincia_regione_fk = r.regione_id
        ORDER BY c.comune ASC
    ) t;

    -- 2. Caricamento Aziende (solo ID e Ragione Sociale)
    SELECT json_agg(t) INTO v_aziende
    FROM (
        SELECT 
            azienda_id as "Id",
            ragione_sociale as "RagioneSociale"
        FROM ana_aziende
        WHERE attivo = TRUE
        ORDER BY ragione_sociale ASC
    ) t;

    -- 3. Caricamento Tipi Fornitore
    SELECT json_agg(t) INTO v_tipi_fornitore
    FROM (
        SELECT 
            tipo_fornitore_id as "Id",
            descrizione as "Descrizione"
        FROM ana_tipo_fornitore
        ORDER BY descrizione ASC
    ) t;

    -- 4. Caricamento Dettaglio Comune della controparte (se in Edit Mode)
    IF p_controparte_id IS NOT NULL THEN
        SELECT json_build_object(
            'Id', c.comune_id,
            'Nome', c.comune,
            'Cap', c.cap,
            'ProvinciaSigla', p.provincia_sigla,
            'RegioneDescrizione', r.regione_descrizione,
            'ComuneEstero', c.comune_estero
        ) INTO v_comune_dettaglio
        FROM ana_controparti cont
        JOIN ana_geo_comuni c ON cont.comune_fk = c.comune_id
        LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
        LEFT JOIN ana_geo_regioni_ita r ON p.provincia_regione_fk = r.regione_id
        WHERE cont.controparte_id = p_controparte_id;
    END IF;

    -- Composizione Risultato Finale
    v_result := json_build_object(
        'Comuni', COALESCE(v_comuni, '[]'::json),
        'Aziende', COALESCE(v_aziende, '[]'::json),
        'TipiFornitore', COALESCE(v_tipi_fornitore, '[]'::json),
        'Comune', v_comune_dettaglio
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
