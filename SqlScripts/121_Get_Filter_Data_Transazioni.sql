-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS fn_get_viaggi_with_transazioni(integer);
DROP FUNCTION IF EXISTS fn_get_date_viaggi_with_transazioni(integer);

-- Function to get distinct trips that have transactions for a specific company (or all if NULL)
CREATE FUNCTION fn_get_viaggi_with_transazioni(p_azienda_id integer)
RETURNS TABLE (
    "Id" integer,
    "DescrizioneBreve" character varying(100),
    "DescrizioneEstesa" text,
    "NazioneNome" character varying(100),
    "NumeroGiorni" integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        v.viaggio_id AS "Id",
        v.viaggio_descrizione_breve AS "DescrizioneBreve",
        v.viaggio_descrizione_estesa AS "DescrizioneEstesa",
        c.name AS "NazioneNome",
        v.viaggio_numero_giorni AS "NumeroGiorni"
    FROM ana_viaggi v
    JOIN mov_transazioni t ON v.viaggio_id = t.transazione_viaggio_id
    JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
    WHERE (p_azienda_id IS NULL OR t.transazione_azienda_id = p_azienda_id)
    ORDER BY v.viaggio_descrizione_breve;
END;
$$;

-- Function to get distinct trip dates that have transactions for a specific trip
CREATE FUNCTION fn_get_date_viaggi_with_transazioni(p_viaggio_id integer)
RETURNS TABLE (
    "DataViaggioId" integer,
    "ViaggioIdFk" integer,
    "DataInizio" date,
    "DataFine" date,
    "Effettuato" character(1)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        d.data_viaggio_id AS "DataViaggioId",
        d.viaggio_id_fk AS "ViaggioIdFk",
        d.data_viaggio_data_inizio AS "DataInizio",
        d.data_viaggio_data_fine AS "DataFine",
        d.data_viaggio_effettuato_sino AS "Effettuato"
    FROM ana_date_viaggi d
    JOIN mov_transazioni t ON d.data_viaggio_id = t.transazione_data_viaggio_id
    WHERE t.transazione_viaggio_id = p_viaggio_id
    ORDER BY d.data_viaggio_data_inizio DESC;
END;
$$;

-- Grant permissions (only to roles that exist)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_superadmin') THEN
        GRANT EXECUTE ON FUNCTION fn_get_viaggi_with_transazioni(integer) TO app_superadmin;
        GRANT EXECUTE ON FUNCTION fn_get_date_viaggi_with_transazioni(integer) TO app_superadmin;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        GRANT EXECUTE ON FUNCTION fn_get_viaggi_with_transazioni(integer) TO app_user;
        GRANT EXECUTE ON FUNCTION fn_get_date_viaggi_with_transazioni(integer) TO app_user;
    END IF;
END $$;
