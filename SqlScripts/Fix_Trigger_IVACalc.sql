-- Fix per trigger fn_calcola_iva_transazione
-- Calcola automaticamente Imponibile e IVA partendo dal Lordo se mancano.

CREATE OR REPLACE FUNCTION fn_calcola_iva_transazione()
RETURNS TRIGGER AS $$
DECLARE
    v_percentuale NUMERIC;
BEGIN
    -- Se manca l'aliquota, non posso calcolare nulla.
    IF NEW.transazione_aliquota_iva_fk IS NULL THEN
        RETURN NEW;
    END IF;

    -- Recupero la percentuale IVA
    SELECT iva_percentuale INTO v_percentuale
    FROM ana_aliquote_iva
    WHERE iva_id = NEW.transazione_aliquota_iva_fk;

    IF v_percentuale IS NULL THEN
        RETURN NEW; -- Aliquota non trovata
    END IF;

    -- Caso 1: Ho Imponibile, calcolo IVA e Lordo
    IF NEW.transazione_imponibile_eur IS NOT NULL AND NEW.transazione_iva_eur IS NULL THEN
        NEW.transazione_iva_eur := ROUND(NEW.transazione_imponibile_eur * v_percentuale / 100, 2);
        NEW.transazione_lordo_eur := NEW.transazione_imponibile_eur + NEW.transazione_iva_eur;
    
    -- Caso 2: Ho Lordo ma mancano Imponibile o IVA (Scorporo)
    ELSIF NEW.transazione_lordo_eur IS NOT NULL AND (NEW.transazione_imponibile_eur IS NULL OR NEW.transazione_iva_eur IS NULL) THEN
        -- Imponibile = Lordo / (1 + %/100)
        NEW.transazione_imponibile_eur := ROUND(NEW.transazione_lordo_eur / (1 + v_percentuale / 100), 2);
        NEW.transazione_iva_eur := NEW.transazione_lordo_eur - NEW.transazione_imponibile_eur;
    
    -- Caso 3: Ho Imponibile e IVA, ricalcolo Lordo per coerenza (opzionale, ma sicuro)
    ELSIF NEW.transazione_imponibile_eur IS NOT NULL AND NEW.transazione_iva_eur IS NOT NULL THEN
        NEW.transazione_lordo_eur := NEW.transazione_imponibile_eur + NEW.transazione_iva_eur;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
