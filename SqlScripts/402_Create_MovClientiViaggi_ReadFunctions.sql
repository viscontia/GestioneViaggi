-- 402_Create_MovClientiViaggi_ReadFunctions.sql
-- DESCRIZIONE: Funzioni di lettura per mov_clienti_viaggi (conversione da SQL inline a DB-First)
-- DATA: 2026-03-16
-- AUTORE: Antigravity

-- =================================================================================================
-- FUNCTION: fn_get_mov_clienti_viaggi_by_date
-- DESCRIZIONE: Recupera tutti i partecipanti per una specifica data viaggio
-- SOSTITUISCE: SQL inline in MovClientiViaggiService.GetByDateIdAsync (linee 136-152)
-- =================================================================================================
CREATE OR REPLACE FUNCTION fn_get_mov_clienti_viaggi_by_date(
    p_data_viaggio_id INT
)
RETURNS TABLE(
    viaggio_id_fk INT,
    data_viaggio_id_fk INT,
    cliente_id_fk INT,
    tipo_partecipante_id_fk INT,
    ana_mezzi_id_fk INT,
    mezzo_modello_id_fk INT,
    cliente_pilota_id_fk INT,
    mov_cliente_viaggio_scontoval_totale NUMERIC,
    mov_cliente_viaggio_targa_mezzo VARCHAR,
    mov_cliente_viaggio_cane_sino VARCHAR,
    mov_cliente_viaggio_note TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mcv.viaggio_id_fk,
        mcv.data_viaggio_id_fk,
        mcv.cliente_id_fk,
        mcv.tipo_partecipante_id_fk,
        mcv.ana_mezzi_id_fk,
        mcv.mezzo_modello_id_fk,
        mcv.cliente_pilota_id_fk,
        mcv.mov_cliente_viaggio_scontoval_totale,
        mcv.mov_cliente_viaggio_targa_mezzo,
        mcv.mov_cliente_viaggio_cane_sino,
        mcv.mov_cliente_viaggio_note
    FROM mov_clienti_viaggi mcv
    WHERE mcv.data_viaggio_id_fk = p_data_viaggio_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_mov_clienti_viaggi_by_date(INT) IS
'Recupera tutti i partecipanti iscritti a una specifica data viaggio. Usato per caricamento dati raw senza arricchimenti.';

-- =================================================================================================
-- FUNCTION: fn_get_participants_view
-- DESCRIZIONE: Recupera vista partecipanti arricchita con dati anagrafici, ruolo e mezzo
-- SOSTITUISCE: SQL inline in MovClientiViaggiService.GetParticipantsViewAsync (linee 168-199)
-- =================================================================================================
CREATE OR REPLACE FUNCTION fn_get_participants_view(
    p_data_viaggio_id INT
)
RETURNS TABLE(
    viaggio_id INT,
    data_id INT,
    cliente_id INT,
    nominativo VARCHAR,
    tipo_partecipante_id INT,
    ruolo VARCHAR,
    note TEXT,
    cane_sino VARCHAR,
    intolleranze TEXT,
    mezzo_dettagli TEXT,
    cliente_pilota_id INT,
    grouping_key INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.viaggio_id_fk AS viaggio_id,
        v.data_viaggio_id_fk AS data_id,
        v.cliente_id_fk AS cliente_id,
        (c.cliente_cognome || ' ' || c.cliente_nome)::VARCHAR AS nominativo,
        v.tipo_partecipante_id_fk AS tipo_partecipante_id,
        tp.tipo_partecipante_descrizione::VARCHAR AS ruolo,
        v.mov_cliente_viaggio_note AS note,
        v.mov_cliente_viaggio_cane_sino AS cane_sino,
        c.cliente_intolleranza AS intolleranze,
        get_mezzo_by_pilot(v.viaggio_id_fk, v.data_viaggio_id_fk, v.cliente_id_fk) AS mezzo_dettagli,
        v.cliente_pilota_id_fk AS cliente_pilota_id,
        CASE
            WHEN v.cliente_pilota_id_fk IS NOT NULL AND v.cliente_pilota_id_fk > 0 THEN v.cliente_pilota_id_fk
            WHEN tp.tipo_partecipante_pilota = true THEN v.cliente_id_fk
            ELSE 0
        END AS grouping_key
    FROM mov_clienti_viaggi v
    JOIN ana_clienti c ON v.cliente_id_fk = c.cliente_id
    JOIN ana_tipo_partecipante tp ON v.tipo_partecipante_id_fk = tp.tipo_partecipante_id
    WHERE v.data_viaggio_id_fk = p_data_viaggio_id
    ORDER BY
        CASE
            WHEN v.cliente_pilota_id_fk IS NOT NULL AND v.cliente_pilota_id_fk > 0 THEN v.cliente_pilota_id_fk
            WHEN tp.tipo_partecipante_pilota = true THEN v.cliente_id_fk
            ELSE 0
        END,
        c.cliente_cognome,
        c.cliente_nome;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_participants_view(INT) IS
'Vista arricchita partecipanti con dati anagrafici, ruolo, intolleranze e dettagli mezzo. Ordinata per equipaggio (pilota → passeggeri).';

-- =================================================================================================
-- FUNCTION: fn_get_trip_header_string
-- DESCRIZIONE: Genera intestazione viaggio formattata per UI (descrizione + range date)
-- SOSTITUISCE: SQL inline in MovClientiViaggiService.GetTripHeaderStringAsync (linee 235-242)
-- =================================================================================================
CREATE OR REPLACE FUNCTION fn_get_trip_header_string(
    p_viaggio_id INT,
    p_data_viaggio_id INT
)
RETURNS TEXT AS $$
DECLARE
    v_header TEXT;
BEGIN
    SELECT
        v.viaggio_descrizione_breve ||
        ' (Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'DD/MM/YYYY') ||
        ' al ' || TO_CHAR(d.data_viaggio_data_fine, 'DD/MM/YYYY') || ')'
    INTO v_header
    FROM ana_viaggi v
    JOIN ana_date_viaggi d ON d.viaggio_id_fk = v.viaggio_id
    WHERE v.viaggio_id = p_viaggio_id
      AND d.data_viaggio_id = p_data_viaggio_id;

    RETURN COALESCE(v_header, 'Intestazione non disponibile');
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_trip_header_string(INT, INT) IS
'Genera intestazione viaggio formattata: "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)". Usato per header UI.';
