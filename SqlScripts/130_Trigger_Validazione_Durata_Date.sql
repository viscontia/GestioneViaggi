-- Funzione di validazione durata date viaggio
CREATE OR REPLACE FUNCTION fn_validate_date_viaggio_duration()
RETURNS TRIGGER AS $$
DECLARE
    v_numero_giorni INTEGER;
    v_durata_calcolata INTEGER;
BEGIN
    -- Recupera il numero di giorni previsto per il viaggio dalla testata
    SELECT viaggio_numero_giorni INTO v_numero_giorni
    FROM ana_viaggi
    WHERE viaggio_id = NEW.viaggio_id_fk;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Viaggio con ID % non trovato nell''anagrafica.', NEW.viaggio_id_fk;
    END IF;

    -- Calcola la durata dell''intervallo (Fine - Inizio + 1)
    v_durata_calcolata := (NEW.data_viaggio_data_fine - NEW.data_viaggio_data_inizio) + 1;

    -- Verifica se la durata coincide
    IF v_durata_calcolata <> v_numero_giorni THEN
        RAISE EXCEPTION 'La durata del viaggio (%) non corrisponde al numero di giorni previsto nell''anagrafica del viaggio (%).', 
            v_durata_calcolata, v_numero_giorni;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger su ana_date_viaggi
DROP TRIGGER IF EXISTS trg_validate_date_viaggio_duration ON ana_date_viaggi;

CREATE TRIGGER trg_validate_date_viaggio_duration
BEFORE INSERT OR UPDATE ON ana_date_viaggi
FOR EACH ROW
EXECUTE FUNCTION fn_validate_date_viaggio_duration();
