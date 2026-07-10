-- ========================================
-- Script: 467_Blocco13_AnaViaggi_Difficolta.sql
-- Blocco 13 — difficoltà come attributo del VIAGGIO (non del contenuto web).
-- Aggiunge ana_viaggi.viaggio_difficolta e la propaga a create/update/get.
-- La difficoltà viene letta live dal web (anteprima + strato pubblico), non editabile lato contenuto.
-- ========================================

-- 1. Colonna + CHECK (nullable)
ALTER TABLE ana_viaggi ADD COLUMN IF NOT EXISTS viaggio_difficolta VARCHAR(20);
ALTER TABLE ana_viaggi DROP CONSTRAINT IF EXISTS chk_ana_viaggi_difficolta;
ALTER TABLE ana_viaggi ADD CONSTRAINT chk_ana_viaggi_difficolta
    CHECK (viaggio_difficolta IS NULL OR viaggio_difficolta IN ('turistica','media','medio_alta','alta'));

-- 2. sp_ana_viaggi_create (drop vecchia firma + ricrea con p_viaggio_difficolta)
DROP FUNCTION IF EXISTS sp_ana_viaggi_create(
    VARCHAR, TEXT, INTEGER, INTEGER, CHAR, INTEGER, INTEGER, TEXT, VARCHAR, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, TIMESTAMPTZ, VARCHAR, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION sp_ana_viaggi_create(
    p_viaggio_descrizione_breve VARCHAR(255),
    p_viaggio_descrizione_estesa TEXT,
    p_viaggio_numero_giorni INTEGER,
    p_viaggio_numero_notti INTEGER,
    p_viaggio_pasti_al_sacco CHAR(1),
    p_viaggio_num_km INTEGER,
    p_viaggio_difficolta VARCHAR(20),
    p_viaggio_tipo_avvicinamento_fk INTEGER,
    p_viaggio_note TEXT,
    p_viaggio_link VARCHAR(500),
    p_viaggio_nazione_fk INTEGER,
    p_viaggio_tipo_viaggio_fk INTEGER,
    p_viaggio_tipo_trattamento_fk INTEGER,
    p_viaggio_tipo_pernottamento_fk INTEGER,
    p_azienda_id INTEGER,
    p_created_by VARCHAR(50),
    p_created TIMESTAMP WITH TIME ZONE,
    p_updated_by VARCHAR(50),
    p_updated TIMESTAMP WITH TIME ZONE
) RETURNS INTEGER AS $$
DECLARE
    v_viaggio_id INTEGER;
BEGIN
    INSERT INTO ana_viaggi (
        viaggio_descrizione_breve, viaggio_descrizione_estesa,
        viaggio_numero_giorni, viaggio_numero_notti, viaggio_pasti_al_sacco,
        viaggio_num_km, viaggio_difficolta, viaggio_tipo_avvicinamento_fk,
        viaggio_note, viaggio_link, viaggio_nazione_fk, viaggio_tipo_viaggio_fk,
        viaggio_tipo_trattamento_fk, viaggio_tipo_pernottamento_fk,
        azienda_id, created_by, created, updated_by, updated
    ) VALUES (
        p_viaggio_descrizione_breve, p_viaggio_descrizione_estesa,
        p_viaggio_numero_giorni, p_viaggio_numero_notti, p_viaggio_pasti_al_sacco,
        p_viaggio_num_km, p_viaggio_difficolta, p_viaggio_tipo_avvicinamento_fk,
        p_viaggio_note, p_viaggio_link, p_viaggio_nazione_fk, p_viaggio_tipo_viaggio_fk,
        p_viaggio_tipo_trattamento_fk, p_viaggio_tipo_pernottamento_fk,
        p_azienda_id, p_created_by, p_created, p_updated_by, p_updated
    )
    RETURNING viaggio_id INTO v_viaggio_id;
    RETURN v_viaggio_id;
END;
$$ LANGUAGE plpgsql;

-- 3. sp_ana_viaggi_update (drop vecchia firma + ricrea con p_viaggio_difficolta)
DROP FUNCTION IF EXISTS sp_ana_viaggi_update(
    INTEGER, VARCHAR, TEXT, INTEGER, INTEGER, CHAR, INTEGER, INTEGER, TEXT, VARCHAR,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION sp_ana_viaggi_update(
    p_viaggio_id INTEGER,
    p_viaggio_descrizione_breve VARCHAR(255),
    p_viaggio_descrizione_estesa TEXT,
    p_viaggio_numero_giorni INTEGER,
    p_viaggio_numero_notti INTEGER,
    p_viaggio_pasti_al_sacco CHAR(1),
    p_viaggio_num_km INTEGER,
    p_viaggio_difficolta VARCHAR(20),
    p_viaggio_tipo_avvicinamento_fk INTEGER,
    p_viaggio_note TEXT,
    p_viaggio_link VARCHAR(500),
    p_viaggio_nazione_fk INTEGER,
    p_viaggio_tipo_viaggio_fk INTEGER,
    p_viaggio_tipo_trattamento_fk INTEGER,
    p_viaggio_tipo_pernottamento_fk INTEGER,
    p_azienda_id INTEGER,
    p_updated_by VARCHAR(50),
    p_updated TIMESTAMP WITH TIME ZONE
) RETURNS VOID AS $$
BEGIN
    UPDATE ana_viaggi SET
        viaggio_descrizione_breve = p_viaggio_descrizione_breve,
        viaggio_descrizione_estesa = p_viaggio_descrizione_estesa,
        viaggio_numero_giorni = p_viaggio_numero_giorni,
        viaggio_numero_notti = p_viaggio_numero_notti,
        viaggio_pasti_al_sacco = p_viaggio_pasti_al_sacco,
        viaggio_num_km = p_viaggio_num_km,
        viaggio_difficolta = p_viaggio_difficolta,
        viaggio_tipo_avvicinamento_fk = p_viaggio_tipo_avvicinamento_fk,
        viaggio_note = p_viaggio_note,
        viaggio_link = p_viaggio_link,
        viaggio_nazione_fk = p_viaggio_nazione_fk,
        viaggio_tipo_viaggio_fk = p_viaggio_tipo_viaggio_fk,
        viaggio_tipo_trattamento_fk = p_viaggio_tipo_trattamento_fk,
        viaggio_tipo_pernottamento_fk = p_viaggio_tipo_pernottamento_fk,
        azienda_id = p_azienda_id,
        updated_by = p_updated_by,
        updated = p_updated
    WHERE viaggio_id = p_viaggio_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Viaggio con ID % non trovato', p_viaggio_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 4. fn_ana_viaggi_get_all (drop + ricrea con viaggio_difficolta nella TABLE/SELECT)
DROP FUNCTION IF EXISTS fn_ana_viaggi_get_all(INTEGER, INTEGER, BOOLEAN, BOOLEAN);

CREATE OR REPLACE FUNCTION fn_ana_viaggi_get_all(
    p_azienda_id INTEGER DEFAULT NULL,
    p_filter_year INTEGER DEFAULT NULL,
    p_only_completed BOOLEAN DEFAULT NULL,
    p_future_only BOOLEAN DEFAULT NULL
) RETURNS TABLE (
    viaggio_id INTEGER,
    viaggio_descrizione_breve VARCHAR(255),
    viaggio_descrizione_estesa TEXT,
    viaggio_numero_giorni INTEGER,
    viaggio_numero_notti INTEGER,
    viaggio_pasti_al_sacco CHAR(1),
    viaggio_num_km INTEGER,
    viaggio_difficolta VARCHAR(20),
    viaggio_note TEXT,
    viaggio_tipo_viaggio_fk INTEGER,
    viaggio_tipo_trattamento_fk INTEGER,
    viaggio_nazione_fk INTEGER,
    viaggio_tipo_pernottamento_fk INTEGER,
    created_by VARCHAR(50),
    created TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    updated TIMESTAMP WITH TIME ZONE,
    viaggio_link VARCHAR(500),
    viaggio_mappa BYTEA,
    viaggio_mappa_mimetype VARCHAR(50),
    viaggio_mappa_filename VARCHAR(255),
    viaggio_mappa_charset VARCHAR(20),
    viaggio_mappa_upd_date DATE,
    azienda_id INTEGER,
    viaggio_tipo_avvicinamento_fk INTEGER,
    nazione_nome VARCHAR(255),
    tipo_viaggi_descrizione VARCHAR(255),
    tipo_trattamento_descrizione VARCHAR(255),
    ana_tipo_pernottamento_descrizione VARCHAR(255),
    tipo_avvicinamento_descrizione VARCHAR(255),
    azienda_nome VARCHAR(255),
    matching_dates_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.viaggio_id, v.viaggio_descrizione_breve, v.viaggio_descrizione_estesa,
        v.viaggio_numero_giorni, v.viaggio_numero_notti, v.viaggio_pasti_al_sacco,
        v.viaggio_num_km, v.viaggio_difficolta, v.viaggio_note,
        v.viaggio_tipo_viaggio_fk, v.viaggio_tipo_trattamento_fk, v.viaggio_nazione_fk,
        v.viaggio_tipo_pernottamento_fk, v.created_by, v.created, v.updated_by, v.updated,
        v.viaggio_link, v.viaggio_mappa, v.viaggio_mappa_mimetype, v.viaggio_mappa_filename,
        v.viaggio_mappa_charset, v.viaggio_mappa_upd_date, v.azienda_id, v.viaggio_tipo_avvicinamento_fk,
        c.name::VARCHAR(255) as nazione_nome,
        t.tipo_viaggi_descrizione::VARCHAR(255),
        tr.tipo_trattamento_descrizione::VARCHAR(255),
        p.ana_tipo_pernottamento_descrizione::VARCHAR(255),
        a.tipo_avvicinamento_descrizione::VARCHAR(255),
        az.ragione_sociale::VARCHAR(255) as azienda_nome,
        (
            SELECT COUNT(1) FROM ana_date_viaggi d
            WHERE d.viaggio_id_fk = v.viaggio_id
            AND (p_filter_year IS NULL OR EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = p_filter_year)
            AND (p_only_completed IS NULL
                OR (p_only_completed = TRUE AND d.data_viaggio_effettuato_sino = 'Y')
                OR (p_only_completed = FALSE AND d.data_viaggio_effettuato_sino = 'N'))
            AND (p_future_only IS NULL OR (p_future_only = TRUE AND d.data_viaggio_data_inizio >= CURRENT_DATE))
        )::BIGINT as matching_dates_count
    FROM ana_viaggi v
    LEFT JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
    LEFT JOIN ana_tipo_viaggi t ON v.viaggio_tipo_viaggio_fk = t.tipo_viaggi_id
    LEFT JOIN ana_tipo_trattamento tr ON v.viaggio_tipo_trattamento_fk = tr.tipo_trattamento_id
    LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
    LEFT JOIN ana_tipo_avvicinamento a ON v.viaggio_tipo_avvicinamento_fk = a.tipo_avvicinamento_id
    LEFT JOIN ana_aziende az ON v.azienda_id = az.azienda_id
    WHERE (p_azienda_id IS NULL OR p_azienda_id = 0 OR v.azienda_id = p_azienda_id)
    AND (p_filter_year IS NULL OR EXISTS (
        SELECT 1 FROM ana_date_viaggi d
        WHERE d.viaggio_id_fk = v.viaggio_id
        AND EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = p_filter_year
        AND (p_only_completed IS NULL
            OR (p_only_completed = TRUE AND d.data_viaggio_effettuato_sino = 'Y')
            OR (p_only_completed = FALSE AND d.data_viaggio_effettuato_sino = 'N'))
        AND (p_future_only IS NULL OR (p_future_only = TRUE AND d.data_viaggio_data_inizio >= CURRENT_DATE))
    ))
    ORDER BY c.name, t.tipo_viaggi_descrizione, v.viaggio_descrizione_breve;
END;
$$ LANGUAGE plpgsql;

-- 5. fn_ana_viaggi_get_by_id (drop + ricrea con viaggio_difficolta)
DROP FUNCTION IF EXISTS fn_ana_viaggi_get_by_id(INTEGER);

CREATE OR REPLACE FUNCTION fn_ana_viaggi_get_by_id(
    p_viaggio_id INTEGER
) RETURNS TABLE (
    viaggio_id INTEGER,
    viaggio_descrizione_breve VARCHAR(255),
    viaggio_descrizione_estesa TEXT,
    viaggio_numero_giorni INTEGER,
    viaggio_numero_notti INTEGER,
    viaggio_pasti_al_sacco CHAR(1),
    viaggio_num_km INTEGER,
    viaggio_difficolta VARCHAR(20),
    viaggio_note TEXT,
    viaggio_tipo_viaggio_fk INTEGER,
    viaggio_tipo_trattamento_fk INTEGER,
    viaggio_nazione_fk INTEGER,
    viaggio_tipo_pernottamento_fk INTEGER,
    created_by VARCHAR(50),
    created TIMESTAMP WITH TIME ZONE,
    updated_by VARCHAR(50),
    updated TIMESTAMP WITH TIME ZONE,
    viaggio_link VARCHAR(500),
    viaggio_mappa BYTEA,
    viaggio_mappa_mimetype VARCHAR(50),
    viaggio_mappa_filename VARCHAR(255),
    viaggio_mappa_charset VARCHAR(20),
    viaggio_mappa_upd_date DATE,
    azienda_id INTEGER,
    viaggio_tipo_avvicinamento_fk INTEGER,
    nazione_nome VARCHAR(255),
    tipo_viaggi_descrizione VARCHAR(255),
    tipo_trattamento_descrizione VARCHAR(255),
    ana_tipo_pernottamento_descrizione VARCHAR(255),
    tipo_avvicinamento_descrizione VARCHAR(255),
    azienda_nome VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.viaggio_id, v.viaggio_descrizione_breve, v.viaggio_descrizione_estesa,
        v.viaggio_numero_giorni, v.viaggio_numero_notti, v.viaggio_pasti_al_sacco,
        v.viaggio_num_km, v.viaggio_difficolta, v.viaggio_note,
        v.viaggio_tipo_viaggio_fk, v.viaggio_tipo_trattamento_fk, v.viaggio_nazione_fk,
        v.viaggio_tipo_pernottamento_fk, v.created_by, v.created, v.updated_by, v.updated,
        v.viaggio_link, v.viaggio_mappa, v.viaggio_mappa_mimetype, v.viaggio_mappa_filename,
        v.viaggio_mappa_charset, v.viaggio_mappa_upd_date, v.azienda_id, v.viaggio_tipo_avvicinamento_fk,
        c.name::VARCHAR(255) as nazione_nome,
        t.tipo_viaggi_descrizione::VARCHAR(255),
        tr.tipo_trattamento_descrizione::VARCHAR(255),
        p.ana_tipo_pernottamento_descrizione::VARCHAR(255),
        a.tipo_avvicinamento_descrizione::VARCHAR(255),
        az.ragione_sociale::VARCHAR(255) as azienda_nome
    FROM ana_viaggi v
    LEFT JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
    LEFT JOIN ana_tipo_viaggi t ON v.viaggio_tipo_viaggio_fk = t.tipo_viaggi_id
    LEFT JOIN ana_tipo_trattamento tr ON v.viaggio_tipo_trattamento_fk = tr.tipo_trattamento_id
    LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
    LEFT JOIN ana_tipo_avvicinamento a ON v.viaggio_tipo_avvicinamento_fk = a.tipo_avvicinamento_id
    LEFT JOIN ana_aziende az ON v.azienda_id = az.azienda_id
    WHERE v.viaggio_id = p_viaggio_id;
END;
$$ LANGUAGE plpgsql;
