-- ============================================================================
-- 674 — La rooming list dice chi porta il cane
--
-- Il cane al seguito (mov_clienti_viaggi.mov_cliente_viaggio_cane_sino) usciva
-- nella stampa del viaggio ma non nella rooming list: proprio il foglio che va
-- all'albergo, che del cane deve sapere. get_rooming_list_data (script 120)
-- restituisce ora anche `con_cane`; fn_get_rooming_list_print_data (300) la
-- passa senza modifiche, perche' prende tutte le colonne con SELECT *.
--
-- Cambiano le colonne restituite: serve DROP + CREATE, non basta REPLACE.
-- Le funzioni nuove nascono gia' chiuse a PUBLIC (659); la revoca esplicita
-- in fondo e' per non dipendere da quello. Rigiocabile.
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_rooming_list_data(integer);

CREATE OR REPLACE FUNCTION get_rooming_list_data(p_data_viaggio_id integer)
RETURNS TABLE(
    -- Identificatori
    cliente_id integer,
    room_id integer,

    -- Dati anagrafici base
    nominativo text,
    eta integer,
    data_nascita date,
    luogo_nascita text,

    -- Residenza
    indirizzo_residenza text,
    citta_residenza text,
    residenza_completa text,

    -- Nazionalità
    country_code text,
    country_name text,
    nationality text,

    -- Documento
    tipo_documento text,
    numero_documento text,
    ente_rilascio text,
    data_rilascio date,
    data_scadenza date,

    -- Intolleranze
    intolleranze text,

    -- Cane al seguito (674): deciso qui, il PDF lo stampa e basta
    con_cane boolean,

    -- Tipo Camera
    tipo_alloggio_id integer,
    tipo_alloggio_descrizione text,
    max_occupanti integer,

    -- Ordine per stampa
    sort_order integer,

    -- Nuovi campi per ordinamento pilota/passeggeri
    position_number integer,
    is_pilot boolean
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH room_assignments AS (
        -- Slot 1: PILOTA (primo occupante della camera)
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id1_fk AS cliente_id,
            1 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id1_fk IS NOT NULL
          AND mca.cliente_id1_fk > 0

        UNION ALL

        -- Slot 2: Passeggero
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id2_fk AS cliente_id,
            2 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id2_fk IS NOT NULL
          AND mca.cliente_id2_fk > 0

        UNION ALL

        -- Slot 3: Passeggero
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id3_fk AS cliente_id,
            3 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id3_fk IS NOT NULL
          AND mca.cliente_id3_fk > 0

        UNION ALL

        -- Slot 4: Passeggero
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id4_fk AS cliente_id,
            4 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id4_fk IS NOT NULL
          AND mca.cliente_id4_fk > 0

        UNION ALL

        -- Slot 5: Passeggero
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id5_fk AS cliente_id,
            5 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id5_fk IS NOT NULL
          AND mca.cliente_id5_fk > 0

        UNION ALL

        -- Slot 6: Passeggero
        SELECT
            mca.mov_clienti_alloggio_pk AS room_id,
            mca.tipo_alloggio_id_fk,
            mca.cliente_id6_fk AS cliente_id,
            6 AS position_number
        FROM mov_clienti_alloggi mca
        WHERE mca.data_viaggio_id_fk = p_data_viaggio_id
          AND mca.cliente_id6_fk IS NOT NULL
          AND mca.cliente_id6_fk > 0
    ),
    pilot_surnames AS (
        -- Per ogni camera, estrai il cognome del pilota (basato su tipo_partecipante_pilota = TRUE)
        SELECT DISTINCT
            ra.room_id,
            c.cliente_cognome AS pilot_surname
        FROM room_assignments ra
        JOIN ana_clienti c ON ra.cliente_id = c.cliente_id
        JOIN mov_clienti_viaggi mcv ON c.cliente_id = mcv.cliente_id_fk
            AND mcv.data_viaggio_id_fk = p_data_viaggio_id
        JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
        WHERE tp.tipo_partecipante_pilota = TRUE
    )
    SELECT
        c.cliente_id::integer,
        COALESCE(ra.room_id, 0)::integer,

        -- Nominativo
        (UPPER(c.cliente_cognome) || ' ' || UPPER(c.cliente_nome))::text AS nominativo,

        -- Età calcolata
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.cliente_data_nascita))::integer AS eta,

        -- Data e luogo nascita
        c.cliente_data_nascita,
        (com_nas.comune_descrizione || COALESCE(' (' || prov_nas.provincia_sigla || ')', ''))::text AS luogo_nascita,

        -- Residenza
        COALESCE(c.cliente_indirizzo_residenza, '')::text AS indirizzo_residenza,
        COALESCE(com_res.comune_descrizione, '')::text AS citta_residenza,
        CONCAT_WS(' in ',
            COALESCE(com_res.comune_descrizione, ''),
            NULLIF(c.cliente_indirizzo_residenza, '')
        )::text AS residenza_completa,

        -- Nazionalità
        COALESCE(ec.iso_alpha2, 'IT')::text AS country_code,
        COALESCE(UPPER(ec.name), 'ITALY')::text AS country_name,
        COALESCE(UPPER(ec.nationality), 'ITALIAN')::text AS nationality,

        -- Documento
        COALESCE(UPPER(c.cliente_tipodoc_identita), '')::text AS tipo_documento,
        COALESCE(c.cliente_documento_numero, '')::text AS numero_documento,
        COALESCE(UPPER(c.cliente_documento_rilasciato_da), '')::text AS ente_rilascio,
        c.cliente_documento_rilasciato_data,
        c.cliente_documento_rilasciato_scadenza,

        -- Intolleranze
        COALESCE(c.cliente_intolleranza, '')::text AS intolleranze,

        -- Cane al seguito: il flag e' del partecipante su QUESTA data di viaggio.
        -- 'S' oltre a 'Y' perche' i dati migrati da Oracle li hanno tutti e due
        -- (stesso criterio della stampa del viaggio, ViaggiPrinter).
        COALESCE(UPPER(mcv.mov_cliente_viaggio_cane_sino) IN ('Y', 'S'), FALSE)::boolean AS con_cane,

        -- Tipo Camera
        COALESCE(ta.tipo_alloggio_id, 0)::integer AS tipo_alloggio_id,
        COALESCE(UPPER(ta.tipo_alloggio_descrizione), 'NESSUNA CAMERA ASSEGNATA')::text AS tipo_alloggio_descrizione,
        COALESCE(ta.tipo_alloggio_numero_occupanti, 0)::integer AS max_occupanti,

        -- Ordine: prima per tipo alloggio, poi per cognome
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(ta.tipo_alloggio_id, 0)
            ORDER BY c.cliente_cognome, c.cliente_nome
        )::integer AS sort_order,

        -- Ordinamento pilota/passeggeri
        COALESCE(ra.position_number, 999)::integer AS position_number,
        COALESCE(tp.tipo_partecipante_pilota, FALSE)::boolean AS is_pilot

    FROM (
        SELECT r_cte.cliente_id FROM room_assignments r_cte
        UNION
        SELECT mcv.cliente_id_fk AS cliente_id FROM mov_clienti_viaggi mcv WHERE mcv.data_viaggio_id_fk = p_data_viaggio_id
    ) all_p
    JOIN ana_clienti c ON all_p.cliente_id = c.cliente_id
    LEFT JOIN mov_clienti_viaggi mcv ON c.cliente_id = mcv.cliente_id_fk AND mcv.data_viaggio_id_fk = p_data_viaggio_id
    LEFT JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
    LEFT JOIN room_assignments ra ON c.cliente_id = ra.cliente_id
    LEFT JOIN pilot_surnames ps ON ra.room_id = ps.room_id
    LEFT JOIN ana_tipo_alloggio ta ON ra.tipo_alloggio_id_fk = ta.tipo_alloggio_id
    LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
    LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
    LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
    LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
    LEFT JOIN ana_geo_regioni_ita reg_nas ON prov_nas.regione_id_fk = reg_nas.regione_id
    LEFT JOIN eba_countries ec ON reg_nas.country_id_fk = ec.country_id
    ORDER BY
        -- 1. Tipo alloggio (camere assegnate prima, poi partecipanti senza camera)
        COALESCE(ta.tipo_alloggio_id, 999999),

        -- 2. Descrizione tipo camera
        ta.tipo_alloggio_descrizione,

        -- 3. All'interno di ogni tipo, ordina camere per cognome PILOTA
        COALESCE(ps.pilot_surname, 'ZZZZZZZ'),

        -- 4. Camera ID (stabilità ordinamento)
        ra.room_id,

        -- 5. All'interno della camera: pilota prima (0), poi passeggeri (1)
        CASE WHEN tp.tipo_partecipante_pilota = TRUE THEN 0 ELSE 1 END,

        -- 6. Passeggeri ordinati alfabeticamente (non influenza il pilota che ha già priorità)
        c.cliente_cognome,
        c.cliente_nome;
END;
$function$;

REVOKE EXECUTE ON FUNCTION get_rooming_list_data(integer) FROM PUBLIC;

COMMIT;

-- ============================================================================
-- Verifica
--
-- 1. La colonna c'e' (atteso: una riga, boolean)
SELECT parameter_name, data_type
  FROM information_schema.parameters
 WHERE specific_name LIKE 'get_rooming_list_data%' AND parameter_name = 'con_cane';
--
-- 2. Nessuno a PUBLIC (atteso: {postgres=X/postgres})
SELECT proacl FROM pg_proc WHERE proname = 'get_rooming_list_data';
-- ============================================================================
