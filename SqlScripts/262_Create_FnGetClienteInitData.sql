-- FUNZIONE: fn_get_cliente_init_data
-- DESCRIZIONE: Recupera lookups comuni, aziende e dettagli geografici cliente in un'unica chiamata JSON.
-- AUTORE: Antigravity
-- DATA: 2026-03-14

CREATE OR REPLACE FUNCTION fn_get_cliente_init_data(p_cliente_id INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_nascita_id INT;
    v_residenza_id INT;
BEGIN
    IF p_cliente_id IS NOT NULL THEN
        SELECT cliente_comune_nascita_fk, cliente_comune_residenza_fk 
        INTO v_nascita_id, v_residenza_id
        FROM ana_clienti 
        WHERE cliente_id = p_cliente_id;
    END IF;

    SELECT json_build_object(
        'Comuni', (
            SELECT json_agg(json_build_object(
                'Id', c.comune_id,
                'Nome', c.comune_descrizione,
                'Cap', c.comune_cap,
                'ProvinciaSigla', p.provincia_sigla,
                'RegioneDescrizione', r.regione_descrizione,
                'ComuneEstero', (c.comune_estero = 'Y')
            ) ORDER BY c.comune_descrizione)
            FROM ana_geo_comuni c
            LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
            LEFT JOIN ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
        ),
        'Aziende', (SELECT json_agg(json_build_object('Id', azienda_id, 'RagioneSociale', ragione_sociale) ORDER BY ragione_sociale) FROM ana_aziende),
        'ComuneNascita', (
            SELECT json_build_object(
                'Id', c.comune_id,
                'Nome', c.comune_descrizione,
                'Cap', c.comune_cap,
                'ProvinciaSigla', p.provincia_sigla,
                'RegioneDescrizione', r.regione_descrizione,
                'ComuneEstero', (c.comune_estero = 'Y')
            )
            FROM ana_geo_comuni c
            LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
            LEFT JOIN ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
            WHERE c.comune_id = v_nascita_id
        ),
        'ComuneResidenza', (
            SELECT json_build_object(
                'Id', c.comune_id,
                'Nome', c.comune_descrizione,
                'Cap', c.comune_cap,
                'ProvinciaSigla', p.provincia_sigla,
                'RegioneDescrizione', r.regione_descrizione,
                'ComuneEstero', (c.comune_estero = 'Y')
            )
            FROM ana_geo_comuni c
            LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
            LEFT JOIN ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
            WHERE c.comune_id = v_residenza_id
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
