-- Fix per trigger fn_calcola_importo_eur
-- Gestisce automaticamente la valuta base (EUR, ID 2) senza cercare tassi cambio.

CREATE OR REPLACE FUNCTION fn_calcola_importo_eur()
RETURNS TRIGGER AS $$
DECLARE
    v_tasso NUMERIC;
    v_valuta_base_id INTEGER := 2; -- ID per Euro
BEGIN
    -- Se la valuta è già EUR, importo_eur = importo
    IF NEW.transazione_valuta_id = v_valuta_base_id THEN
        NEW.transazione_lordo_eur := NEW.transazione_importo;
        RETURN NEW;
    END IF;

    -- Altrimenti cerca il tasso cambio
    -- Logica esistente deve essere mantenuta...
    -- Cerco tasso valido alla data documento
    SELECT tasso_valore INTO v_tasso
    FROM ana_tassi_cambio
    WHERE tasso_valuta_da_fk = NEW.transazione_valuta_id
      AND tasso_valuta_a_fk = v_valuta_base_id
      AND tasso_data_validita <= NEW.transazione_data_documento
    ORDER BY tasso_data_validita DESC
    LIMIT 1;

    IF found THEN
        NEW.transazione_lordo_eur := ROUND((NEW.transazione_importo * v_tasso), 2);
    ELSE
        -- Tasso non trovato: importo EUR rimane NULL
        NEW.transazione_lordo_eur := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
