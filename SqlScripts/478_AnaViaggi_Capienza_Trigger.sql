-- ============================================================================
-- §A.2 Capienza / "posti rimasti" (DB-first).
-- Capienza a livello VIAGGIO (uguale per tutte le edizioni), come difficoltà:
--   ana_viaggi.viaggio_capienza_max   = posti totali (in EQUIPAGGI/MEZZI)
--   ana_viaggi.viaggio_capienza_alert = soglia: sotto questo residuo il sito
--                                       scrive "Rimangono solo N posti".
-- NULL su capienza_max = capienza NON gestita (il sito non mostra alcun badge).
--
-- Occupazione per EDIZIONE/DATA (gli iscritti sono per data). Deciso con Adriano:
-- 1 posto = 1 EQUIPAGGIO/MEZZO = 1 PILOTA. Quindi occupati(data) = numero di
-- piloti (tipo_partecipante 4 'PILOTA MEZZO PROPRIO', 5 'PILOTA MEZZO NOLEGGIATO').
-- Passeggeri e staff (guide 21/22) NON contano.
--
-- SCELTA IMPLEMENTATIVA (rispetto alla bozza "cache su ana_date_viaggi"):
--   * NIENTE colonna cache. L'occupazione è letta LIVE via funzione dedicata
--     `fn_web_mezzi_occupati_data` (script 479, SECURITY DEFINER: ritorna solo un
--     intero, nessun dato personale). Motivi:
--       - mov_clienti_viaggi sono dati PRIVATI: anon non deve poterli leggere;
--         SECURITY DEFINER espone solo il conteggio, non le prenotazioni.
--       - una cache via UPDATE su ana_date_viaggi farebbe scattare il trigger
--         di validazione durata (trg_validate_date_viaggio_duration) ad ogni
--         prenotazione, rompendo l'inserimento su date con dati storici incoerenti.
--   * Il trigger su mov_clienti_viaggi resta, ma fa SOLO pg_notify (revalidation
--     Fase 3): nessuna scrittura su ana_date_viaggi, nessuna collisione.
-- ============================================================================

BEGIN;

-- 1. Colonne capienza sul viaggio
ALTER TABLE ana_viaggi ADD COLUMN IF NOT EXISTS viaggio_capienza_max   INTEGER;
ALTER TABLE ana_viaggi ADD COLUMN IF NOT EXISTS viaggio_capienza_alert INTEGER;

-- 2. Trigger su mov_clienti_viaggi: SOLO segnale di ripubblicazione al sito
--    (pg_notify, canale 'web_tour_revalidate'). Hook di revalidation on-demand
--    della Fase 3 (Next.js): senza listener è un no-op innocuo. Nessuna scrittura
--    su altre tabelle → non interferisce con i trigger di validazione esistenti.
--    Payload JSON {viaggio_id, data_viaggio_id}.
CREATE OR REPLACE FUNCTION trg_mov_clienti_viaggi_posti_func()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM pg_notify('web_tour_revalidate',
            json_build_object('viaggio_id', NEW.viaggio_id_fk,
                              'data_viaggio_id', NEW.data_viaggio_id_fk)::text);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND OLD.data_viaggio_id_fk IS DISTINCT FROM NEW.data_viaggio_id_fk) THEN
        PERFORM pg_notify('web_tour_revalidate',
            json_build_object('viaggio_id', OLD.viaggio_id_fk,
                              'data_viaggio_id', OLD.data_viaggio_id_fk)::text);
    END IF;
    RETURN NULL;  -- AFTER trigger: valore ignorato
END;
$$;

DROP TRIGGER IF EXISTS trg_mov_clienti_viaggi_posti ON mov_clienti_viaggi;
CREATE TRIGGER trg_mov_clienti_viaggi_posti
    AFTER INSERT OR UPDATE OR DELETE ON mov_clienti_viaggi
    FOR EACH ROW EXECUTE FUNCTION trg_mov_clienti_viaggi_posti_func();

-- 3. CRUD ana_viaggi: aggiungo capienza_max/alert a create/update/get (dopo escluso).
DROP FUNCTION IF EXISTS sp_ana_viaggi_create(
    VARCHAR, TEXT, INTEGER, INTEGER, CHAR, INTEGER, VARCHAR, TEXT, TEXT, INTEGER, TEXT, VARCHAR,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, TIMESTAMPTZ, VARCHAR, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION sp_ana_viaggi_create(
    p_viaggio_descrizione_breve VARCHAR(255),
    p_viaggio_descrizione_estesa TEXT,
    p_viaggio_numero_giorni INTEGER,
    p_viaggio_numero_notti INTEGER,
    p_viaggio_pasti_al_sacco CHAR(1),
    p_viaggio_num_km INTEGER,
    p_viaggio_difficolta VARCHAR(20),
    p_viaggio_incluso TEXT,
    p_viaggio_escluso TEXT,
    p_viaggio_capienza_max INTEGER,
    p_viaggio_capienza_alert INTEGER,
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
        viaggio_num_km, viaggio_difficolta, viaggio_incluso, viaggio_escluso,
        viaggio_capienza_max, viaggio_capienza_alert, viaggio_tipo_avvicinamento_fk,
        viaggio_note, viaggio_link, viaggio_nazione_fk, viaggio_tipo_viaggio_fk,
        viaggio_tipo_trattamento_fk, viaggio_tipo_pernottamento_fk,
        azienda_id, created_by, created, updated_by, updated
    ) VALUES (
        p_viaggio_descrizione_breve, p_viaggio_descrizione_estesa,
        p_viaggio_numero_giorni, p_viaggio_numero_notti, p_viaggio_pasti_al_sacco,
        p_viaggio_num_km, p_viaggio_difficolta, p_viaggio_incluso, p_viaggio_escluso,
        p_viaggio_capienza_max, p_viaggio_capienza_alert, p_viaggio_tipo_avvicinamento_fk,
        p_viaggio_note, p_viaggio_link, p_viaggio_nazione_fk, p_viaggio_tipo_viaggio_fk,
        p_viaggio_tipo_trattamento_fk, p_viaggio_tipo_pernottamento_fk,
        p_azienda_id, p_created_by, p_created, p_updated_by, p_updated
    )
    RETURNING viaggio_id INTO v_viaggio_id;
    RETURN v_viaggio_id;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS sp_ana_viaggi_update(
    INTEGER, VARCHAR, TEXT, INTEGER, INTEGER, CHAR, INTEGER, VARCHAR, TEXT, TEXT, INTEGER, TEXT, VARCHAR,
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
    p_viaggio_incluso TEXT,
    p_viaggio_escluso TEXT,
    p_viaggio_capienza_max INTEGER,
    p_viaggio_capienza_alert INTEGER,
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
        viaggio_incluso = p_viaggio_incluso,
        viaggio_escluso = p_viaggio_escluso,
        viaggio_capienza_max = p_viaggio_capienza_max,
        viaggio_capienza_alert = p_viaggio_capienza_alert,
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
    viaggio_incluso TEXT,
    viaggio_escluso TEXT,
    viaggio_capienza_max INTEGER,
    viaggio_capienza_alert INTEGER,
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
        v.viaggio_num_km, v.viaggio_difficolta, v.viaggio_incluso, v.viaggio_escluso,
        v.viaggio_capienza_max, v.viaggio_capienza_alert, v.viaggio_note,
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
    viaggio_incluso TEXT,
    viaggio_escluso TEXT,
    viaggio_capienza_max INTEGER,
    viaggio_capienza_alert INTEGER,
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
        v.viaggio_num_km, v.viaggio_difficolta, v.viaggio_incluso, v.viaggio_escluso,
        v.viaggio_capienza_max, v.viaggio_capienza_alert, v.viaggio_note,
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

COMMIT;
