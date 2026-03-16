-- ============================================================================
-- Script: 356_Create_AnaClienti_CRUD_Procedures.sql
-- Description: DB-First conversion - Create stored procedures for ana_clienti CRUD operations
-- Author: Claude Code
-- Date: 2026-03-16
-- ============================================================================

-- ============================================================================
-- 1. fn_get_cliente_by_id - Get cliente by ID with all joins
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_cliente_by_id(
    p_cliente_id INT,
    p_azienda_fk INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'ClienteId', c.cliente_id,
        'Titolo', c.cliente_titolo,
        'Cognome', c.cliente_cognome,
        'Nome', c.cliente_nome,
        'Sesso', c.cliente_sesso,
        'ComuneResidenzaFk', c.cliente_comune_residenza_fk,
        'IndirizzoResidenza', c.cliente_indirizzo_residenza,
        'ComuneNascitaFk', c.cliente_comune_nascita_fk,
        'DataNascita', c.cliente_data_nascita,
        'PrefTelInt', c.cliente_preftelint,
        'Telefono', c.cliente_telefono,
        'Email', c.cliente_email,
        'CodiceFiscale', c.cliente_codicefiscale,
        'Iban', c.cliente_iban,
        'Foto', encode(c.cliente_foto, 'base64'),
        'CartaIdentita', encode(c.cliente_carta_identita, 'base64'),
        'TipoDocIdentita', c.cliente_tipodoc_identita,
        'DocumentoNumero', c.cliente_documento_numero,
        'DocumentoRilasciatoDa', c.cliente_documento_rilasciato_da,
        'DocumentoRilasciatoData', c.cliente_documento_rilasciato_data,
        'DocumentoRilasciatoScadenza', c.cliente_documento_rilasciato_scadenza,
        'Note', c.cliente_note,
        'FotoMimeType', c.cliente_foto_mimetype,
        'FotoFilename', c.cliente_foto_filename,
        'FotoCharset', c.cliente_foto_charset,
        'FotoUpdDate', c.cliente_foto_upd_date,
        'DocumentoMimeType', c.cliente_documento_mimetype,
        'DocumentoFilename', c.cliente_documento_filename,
        'DocumentoCharset', c.cliente_documento_chartset,
        'DocumentoUpdDate', c.cliente_documento_upd_date,
        'Intolleranza', c.cliente_intolleranza,
        'AziendaFk', c.azienda_fk,
        'CreatedBy', c.created_by,
        'Created', c.created,
        'UpdatedBy', c.updated_by,
        'Updated', c.updated,
        'AziendaRagioneSociale', a.ragione_sociale
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    WHERE c.cliente_id = p_cliente_id
      AND c.azienda_fk = p_azienda_fk;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION fn_get_cliente_by_id IS 'DB-First: Get cliente by ID with all related data (azienda, comuni)';

-- ============================================================================
-- 2. fn_get_all_clienti - Get all clienti for azienda with optional year filter
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_all_clienti(
    p_azienda_fk INT DEFAULT NULL,
    p_filter_year INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'ClienteId', c.cliente_id,
            'Titolo', c.cliente_titolo,
            'Cognome', c.cliente_cognome,
            'Nome', c.cliente_nome,
            'Sesso', c.cliente_sesso,
            'ComuneResidenzaFk', c.cliente_comune_residenza_fk,
            'IndirizzoResidenza', c.cliente_indirizzo_residenza,
            'ComuneNascitaFk', c.cliente_comune_nascita_fk,
            'DataNascita', c.cliente_data_nascita,
            'PrefTelInt', c.cliente_preftelint,
            'Telefono', c.cliente_telefono,
            'Email', c.cliente_email,
            'CodiceFiscale', c.cliente_codicefiscale,
            'Iban', c.cliente_iban,
            'TipoDocIdentita', c.cliente_tipodoc_identita,
            'DocumentoNumero', c.cliente_documento_numero,
            'DocumentoRilasciatoDa', c.cliente_documento_rilasciato_da,
            'DocumentoRilasciatoData', c.cliente_documento_rilasciato_data,
            'DocumentoRilasciatoScadenza', c.cliente_documento_rilasciato_scadenza,
            'Note', c.cliente_note,
            'Intolleranza', c.cliente_intolleranza,
            'AziendaFk', c.azienda_fk,
            'CreatedBy', c.created_by,
            'Created', c.created,
            'UpdatedBy', c.updated_by,
            'Updated', c.updated,
            'AziendaRagioneSociale', a.ragione_sociale,
            'ViaggiFatti', COALESCE(viaggi_fatti.count, 0),
            'ViaggiDaFare', COALESCE(viaggi_futuri.count, 0),
            'ComuneNascita', CASE
                WHEN com_nas.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_nas.comune_descrizione,
                        'ProvinciaSigla', prov_nas.provincia_sigla,
                        'ProvinciaDescrizione', prov_nas.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_nas.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END,
            'ComuneResidenza', CASE
                WHEN com_res.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_res.comune_descrizione,
                        'ProvinciaSigla', prov_res.provincia_sigla,
                        'ProvinciaDescrizione', prov_res.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_res.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END
        ) ORDER BY c.cliente_cognome, c.cliente_nome
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    LEFT JOIN LATERAL (
        SELECT COUNT(*) as count
        FROM mov_clienti_viaggi mcv
        JOIN ana_date_viaggi adv ON mcv.data_viaggio_id_fk = adv.data_viaggio_id
        WHERE mcv.cliente_id_fk = c.cliente_id
          AND adv.data_viaggio_data_inizio < CURRENT_DATE
          AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM adv.data_viaggio_data_inizio) = p_filter_year)
    ) viaggi_fatti ON true
    LEFT JOIN LATERAL (
        SELECT COUNT(*) as count
        FROM mov_clienti_viaggi mcv
        JOIN ana_date_viaggi adv ON mcv.data_viaggio_id_fk = adv.data_viaggio_id
        WHERE mcv.cliente_id_fk = c.cliente_id
          AND adv.data_viaggio_data_inizio >= CURRENT_DATE
          AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM adv.data_viaggio_data_inizio) = p_filter_year)
    ) viaggi_futuri ON true
    WHERE (p_azienda_fk IS NULL OR c.azienda_fk = p_azienda_fk);

    RETURN COALESCE(v_result, '[]'::json);
END;
$$;

COMMENT ON FUNCTION fn_get_all_clienti IS 'DB-First: Get all clienti with travel counts, optional azienda filter';

-- ============================================================================
-- 3. sp_ana_clienti_create - Create new cliente
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ana_clienti_create(
    p_cliente_titolo VARCHAR(10),
    p_cliente_cognome VARCHAR(50),
    p_cliente_nome VARCHAR(50),
    p_cliente_sesso VARCHAR(1),
    p_cliente_comune_residenza_fk INT,
    p_cliente_indirizzo_residenza VARCHAR(100),
    p_cliente_comune_nascita_fk INT,
    p_cliente_data_nascita DATE,
    p_cliente_preftelint VARCHAR(5),
    p_cliente_telefono VARCHAR(20),
    p_cliente_email VARCHAR(100),
    p_cliente_codicefiscale VARCHAR(16),
    p_cliente_iban VARCHAR(34),
    p_cliente_foto BYTEA,
    p_cliente_carta_identita BYTEA,
    p_cliente_tipodoc_identita VARCHAR(50),
    p_cliente_documento_numero VARCHAR(50),
    p_cliente_documento_rilasciato_da VARCHAR(100),
    p_cliente_documento_rilasciato_data DATE,
    p_cliente_documento_rilasciato_scadenza DATE,
    p_cliente_note TEXT,
    p_cliente_foto_mimetype VARCHAR(100),
    p_cliente_foto_filename VARCHAR(255),
    p_cliente_foto_charset VARCHAR(50),
    p_cliente_foto_upd_date TIMESTAMP,
    p_cliente_documento_mimetype VARCHAR(100),
    p_cliente_documento_filename VARCHAR(255),
    p_cliente_documento_chartset VARCHAR(50),
    p_cliente_documento_upd_date TIMESTAMP,
    p_cliente_intolleranza VARCHAR(255),
    p_azienda_fk INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id INT;
    v_result JSON;
BEGIN
    BEGIN
        -- Insert new cliente
        INSERT INTO ana_clienti (
        cliente_titolo,
        cliente_cognome,
        cliente_nome,
        cliente_sesso,
        cliente_comune_residenza_fk,
        cliente_indirizzo_residenza,
        cliente_comune_nascita_fk,
        cliente_data_nascita,
        cliente_preftelint,
        cliente_telefono,
        cliente_email,
        cliente_codicefiscale,
        cliente_iban,
        cliente_foto,
        cliente_carta_identita,
        cliente_tipodoc_identita,
        cliente_documento_numero,
        cliente_documento_rilasciato_da,
        cliente_documento_rilasciato_data,
        cliente_documento_rilasciato_scadenza,
        cliente_note,
        cliente_foto_mimetype,
        cliente_foto_filename,
        cliente_foto_charset,
        cliente_foto_upd_date,
        cliente_documento_mimetype,
        cliente_documento_filename,
        cliente_documento_chartset,
        cliente_documento_upd_date,
        cliente_intolleranza,
        azienda_fk,
        created_by,
        created
    )
    VALUES (
        p_cliente_titolo,
        p_cliente_cognome,
        p_cliente_nome,
        p_cliente_sesso,
        p_cliente_comune_residenza_fk,
        p_cliente_indirizzo_residenza,
        p_cliente_comune_nascita_fk,
        p_cliente_data_nascita,
        p_cliente_preftelint,
        p_cliente_telefono,
        p_cliente_email,
        p_cliente_codicefiscale,
        p_cliente_iban,
        p_cliente_foto,
        p_cliente_carta_identita,
        p_cliente_tipodoc_identita,
        p_cliente_documento_numero,
        p_cliente_documento_rilasciato_da,
        p_cliente_documento_rilasciato_data,
        p_cliente_documento_rilasciato_scadenza,
        p_cliente_note,
        p_cliente_foto_mimetype,
        p_cliente_foto_filename,
        p_cliente_foto_charset,
        p_cliente_foto_upd_date,
        p_cliente_documento_mimetype,
        p_cliente_documento_filename,
        p_cliente_documento_chartset,
        p_cliente_documento_upd_date,
        p_cliente_intolleranza,
        p_azienda_fk,
        current_setting('my.app_user', true),
        NOW()
    )
    RETURNING cliente_id INTO v_new_id;

        -- Return the newly created cliente
        SELECT fn_get_cliente_by_id(v_new_id, p_azienda_fk) INTO v_result;

        RETURN v_result;

    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'Errore: Cliente già esistente (email, codice fiscale o anagrafica duplicati)';
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'Errore: Riferimento non valido (comune o azienda non esistente)';
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Errore durante la creazione del cliente: %', SQLERRM;
    END;
END;
$$;

COMMENT ON FUNCTION sp_ana_clienti_create IS 'DB-First: Create new cliente and return full record';

-- ============================================================================
-- 4. sp_ana_clienti_update - Update existing cliente
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ana_clienti_update(
    p_cliente_id INT,
    p_cliente_titolo VARCHAR(10),
    p_cliente_cognome VARCHAR(50),
    p_cliente_nome VARCHAR(50),
    p_cliente_sesso VARCHAR(1),
    p_cliente_comune_residenza_fk INT,
    p_cliente_indirizzo_residenza VARCHAR(100),
    p_cliente_comune_nascita_fk INT,
    p_cliente_data_nascita DATE,
    p_cliente_preftelint VARCHAR(5),
    p_cliente_telefono VARCHAR(20),
    p_cliente_email VARCHAR(100),
    p_cliente_codicefiscale VARCHAR(16),
    p_cliente_iban VARCHAR(34),
    p_cliente_foto BYTEA,
    p_cliente_carta_identita BYTEA,
    p_cliente_tipodoc_identita VARCHAR(50),
    p_cliente_documento_numero VARCHAR(50),
    p_cliente_documento_rilasciato_da VARCHAR(100),
    p_cliente_documento_rilasciato_data DATE,
    p_cliente_documento_rilasciato_scadenza DATE,
    p_cliente_note TEXT,
    p_cliente_foto_mimetype VARCHAR(100),
    p_cliente_foto_filename VARCHAR(255),
    p_cliente_foto_charset VARCHAR(50),
    p_cliente_foto_upd_date TIMESTAMP,
    p_cliente_documento_mimetype VARCHAR(100),
    p_cliente_documento_filename VARCHAR(255),
    p_cliente_documento_chartset VARCHAR(50),
    p_cliente_documento_upd_date TIMESTAMP,
    p_cliente_intolleranza VARCHAR(255),
    p_azienda_fk INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSON;
    v_rows_affected INT;
BEGIN
    BEGIN
        -- Update cliente
        UPDATE ana_clienti
    SET
        cliente_titolo = p_cliente_titolo,
        cliente_cognome = p_cliente_cognome,
        cliente_nome = p_cliente_nome,
        cliente_sesso = p_cliente_sesso,
        cliente_comune_residenza_fk = p_cliente_comune_residenza_fk,
        cliente_indirizzo_residenza = p_cliente_indirizzo_residenza,
        cliente_comune_nascita_fk = p_cliente_comune_nascita_fk,
        cliente_data_nascita = p_cliente_data_nascita,
        cliente_preftelint = p_cliente_preftelint,
        cliente_telefono = p_cliente_telefono,
        cliente_email = p_cliente_email,
        cliente_codicefiscale = p_cliente_codicefiscale,
        cliente_iban = p_cliente_iban,
        cliente_foto = p_cliente_foto,
        cliente_carta_identita = p_cliente_carta_identita,
        cliente_tipodoc_identita = p_cliente_tipodoc_identita,
        cliente_documento_numero = p_cliente_documento_numero,
        cliente_documento_rilasciato_da = p_cliente_documento_rilasciato_da,
        cliente_documento_rilasciato_data = p_cliente_documento_rilasciato_data,
        cliente_documento_rilasciato_scadenza = p_cliente_documento_rilasciato_scadenza,
        cliente_note = p_cliente_note,
        cliente_foto_mimetype = p_cliente_foto_mimetype,
        cliente_foto_filename = p_cliente_foto_filename,
        cliente_foto_charset = p_cliente_foto_charset,
        cliente_foto_upd_date = p_cliente_foto_upd_date,
        cliente_documento_mimetype = p_cliente_documento_mimetype,
        cliente_documento_filename = p_cliente_documento_filename,
        cliente_documento_chartset = p_cliente_documento_chartset,
        cliente_documento_upd_date = p_cliente_documento_upd_date,
        cliente_intolleranza = p_cliente_intolleranza,
        updated_by = current_setting('my.app_user', true),
        updated = NOW()
    WHERE cliente_id = p_cliente_id
      AND azienda_fk = p_azienda_fk;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Cliente con id % non trovato o azienda errata', p_cliente_id;
    END IF;

        -- Return the updated cliente
        SELECT fn_get_cliente_by_id(p_cliente_id, p_azienda_fk) INTO v_result;

        RETURN v_result;

    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'Errore: Cliente già esistente (email, codice fiscale o anagrafica duplicati)';
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'Errore: Riferimento non valido (comune o azienda non esistente)';
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Errore durante l''aggiornamento del cliente: %', SQLERRM;
    END;
END;
$$;

COMMENT ON FUNCTION sp_ana_clienti_update IS 'DB-First: Update existing cliente and return full record';

-- ============================================================================
-- 5. sp_ana_clienti_delete - Delete cliente with referential integrity checks
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ana_clienti_delete(
    p_cliente_id INT,
    p_azienda_fk INT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_bookings BOOLEAN;
    v_has_accommodations BOOLEAN;
BEGIN
    BEGIN
        -- Check for active bookings
        SELECT EXISTS(
        SELECT 1 FROM mov_clienti_viaggi
        WHERE cliente_id_fk = p_cliente_id
    ) INTO v_has_bookings;

    IF v_has_bookings THEN
        RAISE EXCEPTION 'Impossibile eliminare il cliente con id % - ha prenotazioni viaggi attive', p_cliente_id;
    END IF;

    -- Check for accommodation assignments
    SELECT EXISTS(
        SELECT 1 FROM mov_clienti_alloggi
        WHERE cliente_id1_fk = p_cliente_id
           OR cliente_id2_fk = p_cliente_id
           OR cliente_id3_fk = p_cliente_id
           OR cliente_id4_fk = p_cliente_id
           OR cliente_id5_fk = p_cliente_id
           OR cliente_id6_fk = p_cliente_id
    ) INTO v_has_accommodations;

    IF v_has_accommodations THEN
        RAISE EXCEPTION 'Impossibile eliminare il cliente con id % - ha assegnazioni alloggio attive', p_cliente_id;
    END IF;

        -- Delete cliente
        DELETE FROM ana_clienti
        WHERE cliente_id = p_cliente_id
          AND azienda_fk = p_azienda_fk;

    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'Errore: Impossibile eliminare il cliente - ha riferimenti attivi nel database';
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Errore durante l''eliminazione del cliente: %', SQLERRM;
    END;
END;
$$;

COMMENT ON FUNCTION sp_ana_clienti_delete IS 'DB-First: Delete cliente with referential integrity checks';

-- ============================================================================
-- 6. fn_exists_cliente_email - Check email uniqueness
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_exists_cliente_email(
    p_email VARCHAR(100),
    p_exclude_cliente_id INT DEFAULT 0,
    p_azienda_fk INT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE LOWER(cliente_email) = LOWER(p_email)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$$;

COMMENT ON FUNCTION fn_exists_cliente_email IS 'DB-First: Check if email already exists for another cliente';

-- ============================================================================
-- 7. fn_exists_cliente_codice_fiscale - Check codice fiscale uniqueness
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_exists_cliente_codice_fiscale(
    p_codice_fiscale VARCHAR(16),
    p_exclude_cliente_id INT DEFAULT 0,
    p_azienda_fk INT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE UPPER(cliente_codicefiscale) = UPPER(p_codice_fiscale)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$$;

COMMENT ON FUNCTION fn_exists_cliente_codice_fiscale IS 'DB-First: Check if codice fiscale already exists for another cliente';

-- ============================================================================
-- 8. fn_exists_cliente_anagrafica - Check anagrafica uniqueness
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_exists_cliente_anagrafica(
    p_cognome VARCHAR(50),
    p_nome VARCHAR(50),
    p_data_nascita DATE,
    p_codice_fiscale VARCHAR(16),
    p_exclude_cliente_id INT DEFAULT 0,
    p_azienda_fk INT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM ana_clienti
        WHERE UPPER(cliente_cognome) = UPPER(p_cognome)
          AND UPPER(cliente_nome) = UPPER(p_nome)
          AND cliente_data_nascita = p_data_nascita
          AND UPPER(cliente_codicefiscale) = UPPER(p_codice_fiscale)
          AND cliente_id != p_exclude_cliente_id
          AND (p_azienda_fk IS NULL OR azienda_fk = p_azienda_fk)
    ) INTO v_exists;

    RETURN v_exists;
END;
$$;

COMMENT ON FUNCTION fn_exists_cliente_anagrafica IS 'DB-First: Check if cliente with same anagrafica data already exists';

-- ============================================================================
-- 9. fn_search_clienti - Full-text search clienti
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_search_clienti(
    p_azienda_fk INT,
    p_search_text VARCHAR(100)
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSON;
    v_search_pattern VARCHAR(102);
BEGIN
    v_search_pattern := '%' || UPPER(p_search_text) || '%';

    SELECT json_agg(
        json_build_object(
            'ClienteId', c.cliente_id,
            'Cognome', c.cliente_cognome,
            'Nome', c.cliente_nome,
            'Email', c.cliente_email,
            'Telefono', c.cliente_telefono,
            'CodiceFiscale', c.cliente_codicefiscale,
            'Sesso', c.cliente_sesso,
            'DataNascita', c.cliente_data_nascita,
            'PrefTelInt', c.cliente_preftelint,
            'IndirizzoResidenza', c.cliente_indirizzo_residenza,
            'Intolleranza', c.cliente_intolleranza,
            'AziendaFk', c.azienda_fk,
            'AziendaRagioneSociale', a.ragione_sociale,
            'ComuneNascita', CASE
                WHEN com_nas.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_nas.comune_descrizione,
                        'ProvinciaSigla', prov_nas.provincia_sigla,
                        'ProvinciaDescrizione', prov_nas.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_nas.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END,
            'ComuneResidenza', CASE
                WHEN com_res.comune_id IS NOT NULL THEN
                    json_build_object(
                        'Nome', com_res.comune_descrizione,
                        'ProvinciaSigla', prov_res.provincia_sigla,
                        'ProvinciaDescrizione', prov_res.provincia_descrizione,
                        'ComuneEstero', CASE WHEN com_res.comune_estero = 'Y' THEN true ELSE false END
                    )
                ELSE NULL
            END
        ) ORDER BY c.cliente_cognome, c.cliente_nome
    )
    INTO v_result
    FROM ana_clienti c
    LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    WHERE c.azienda_fk = p_azienda_fk
      AND (
          UPPER(c.cliente_cognome) LIKE v_search_pattern
          OR UPPER(c.cliente_nome) LIKE v_search_pattern
          OR UPPER(c.cliente_email) LIKE v_search_pattern
          OR UPPER(c.cliente_codicefiscale) LIKE v_search_pattern
          OR UPPER(c.cliente_telefono) LIKE v_search_pattern
      );

    RETURN COALESCE(v_result, '[]'::json);
END;
$$;

COMMENT ON FUNCTION fn_search_clienti IS 'DB-First: Full-text search clienti by cognome, nome, email, CF, telefono';

-- ============================================================================
-- 10. fn_count_clienti_by_azienda - Count clienti for azienda
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_count_clienti_by_azienda(
    p_azienda_fk INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM ana_clienti
    WHERE azienda_fk = p_azienda_fk;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION fn_count_clienti_by_azienda IS 'DB-First: Count total clienti for specific azienda';

-- ============================================================================
-- Grant permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION fn_get_cliente_by_id TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_get_all_clienti TO PUBLIC;
GRANT EXECUTE ON FUNCTION sp_ana_clienti_create TO PUBLIC;
GRANT EXECUTE ON FUNCTION sp_ana_clienti_update TO PUBLIC;
GRANT EXECUTE ON FUNCTION sp_ana_clienti_delete TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_exists_cliente_email TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_exists_cliente_codice_fiscale TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_exists_cliente_anagrafica TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_search_clienti TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_count_clienti_by_azienda TO PUBLIC;

-- ============================================================================
-- End of Script
-- ============================================================================
