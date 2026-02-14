-- =====================================================
-- TRIGGER: Calcolo Automatico IVA su mov_transazioni
-- Scopo: Calcolo IVA metadata-driven con supporto correzioni manuali
-- Creato: 14/02/2026
-- Priorità: ESEGUIRE PRIMA di trg_validate_transazione_metadata
-- =====================================================

CREATE OR REPLACE FUNCTION fn_calcola_iva_transazione()
RETURNS TRIGGER AS $$
DECLARE
    v_causale ana_tipi_causali%ROWTYPE;
    v_aliquota ana_aliquote_iva%ROWTYPE;
    v_valuta ana_valute%ROWTYPE;
    v_percentuale NUMERIC(5,2);
BEGIN
    -- =========================================
    -- STEP 1: Recupera metadati causale
    -- =========================================
    SELECT * INTO v_causale
    FROM ana_tipi_causali
    WHERE causale_id = NEW.transazione_causale_tipo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Causale ID % non trovata in ana_tipi_causali', NEW.transazione_causale_tipo_id;
    END IF;

    -- =========================================
    -- STEP 2: Recupera metadati valuta
    -- =========================================
    SELECT * INTO v_valuta
    FROM ana_valute
    WHERE valuta_id = NEW.transazione_valuta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Valuta ID % non trovata in ana_valute', NEW.transazione_valuta_id;
    END IF;

    -- =========================================
    -- STEP 3: Se valuta != EUR, azzera IVA e esci
    -- =========================================
    IF v_valuta.valuta_codice_iso != 'EUR' THEN
        NEW.transazione_aliquota_iva_fk := NULL;
        NEW.transazione_imponibile_eur := NULL;
        NEW.transazione_iva_eur := NULL;
        NEW.transazione_lordo_eur := NULL;
        NEW.transazione_iva_modalita_input := NULL;

        -- IMPORTANTE: Esci subito, non processare logica IVA
        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 4: Se causale NON genera IVA, copia importo in lordo e azzera IVA
    -- =========================================
    IF v_causale.causale_genera_iva = FALSE THEN
        -- Es. PG (Pagamento), IN (Incasso), NC (Nota Credito)
        -- Queste causali non hanno IVA propria
        NEW.transazione_aliquota_iva_fk := NULL;
        NEW.transazione_imponibile_eur := NEW.transazione_importo;
        NEW.transazione_iva_eur := 0;
        NEW.transazione_lordo_eur := NEW.transazione_importo;
        NEW.transazione_iva_modalita_input := NULL;

        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 5: Validazione IVA obbligatoria
    -- =========================================
    IF v_causale.causale_richiede_iva = TRUE
       AND NEW.transazione_aliquota_iva_fk IS NULL THEN
        RAISE EXCEPTION 'La causale "%" richiede IVA obbligatoria. Selezionare un''aliquota IVA.',
            v_causale.causale_descrizione;
    END IF;

    -- =========================================
    -- STEP 6: Se IVA non presente (opzionale e non selezionata), esci
    -- =========================================
    IF NEW.transazione_aliquota_iva_fk IS NULL THEN
        -- Causale genera IVA ma non è obbligatoria, e utente non l'ha selezionata
        -- Es. FT con aliquota FC (Fuori Campo) = NULL
        NEW.transazione_imponibile_eur := NEW.transazione_importo;
        NEW.transazione_iva_eur := 0;
        NEW.transazione_lordo_eur := NEW.transazione_importo;
        NEW.transazione_iva_modalita_input := NULL;

        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 7: Recupera aliquota IVA
    -- =========================================
    SELECT * INTO v_aliquota
    FROM ana_aliquote_iva
    WHERE iva_id = NEW.transazione_aliquota_iva_fk;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aliquota IVA ID % non trovata in ana_aliquote_iva', NEW.transazione_aliquota_iva_fk;
    END IF;

    v_percentuale := v_aliquota.iva_percentuale;

    -- =========================================
    -- STEP 8: REGOLA 1 - CORREZIONE MANUALE (PRIORITÀ MASSIMA)
    -- =========================================
    -- Se TUTTI E TRE i campi IVA sono compilati, significa che l'utente ha inserito manualmente
    -- NON ricalcolare, ma VALIDA solo la coerenza matematica con tolleranza 0.01€
    IF NEW.transazione_imponibile_eur IS NOT NULL
       AND NEW.transazione_iva_eur IS NOT NULL
       AND NEW.transazione_lordo_eur IS NOT NULL THEN

        -- Validazione matematica con tolleranza 1 centesimo
        IF ABS(NEW.transazione_lordo_eur - (NEW.transazione_imponibile_eur + NEW.transazione_iva_eur)) > 0.01 THEN
            RAISE EXCEPTION 'Incoerenza IVA: Lordo (% EUR) != Imponibile (% EUR) + IVA (% EUR). Differenza: % EUR',
                NEW.transazione_lordo_eur,
                NEW.transazione_imponibile_eur,
                NEW.transazione_iva_eur,
                ABS(NEW.transazione_lordo_eur - (NEW.transazione_imponibile_eur + NEW.transazione_iva_eur));
        END IF;

        -- Tutto OK, non ricalcolare nulla, rispetta i valori inseriti dall'utente
        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 9: REGOLA 2 - AUTO-DETERMINA MODALITÀ INPUT
    -- =========================================
    -- Se utente non ha specificato modalità, deduci da ciclo causale
    IF NEW.transazione_iva_modalita_input IS NULL THEN
        IF v_causale.causale_ciclo = 'PASSIVO' THEN
            NEW.transazione_iva_modalita_input := 'LORDO';
        ELSIF v_causale.causale_ciclo = 'ATTIVO' THEN
            NEW.transazione_iva_modalita_input := 'NETTO';
        ELSE
            -- Fallback (causale senza ciclo, caso raro)
            NEW.transazione_iva_modalita_input := 'LORDO';
        END IF;
    END IF;

    -- =========================================
    -- STEP 10: REGOLA 3 - CALCOLO IVA
    -- =========================================
    IF NEW.transazione_iva_modalita_input = 'LORDO' THEN
        -- ----------------------------------------
        -- MODALITÀ LORDO (PASSIVO - Scorporo IVA)
        -- ----------------------------------------
        -- Utente ha inserito TOTALE con IVA inclusa (es. fattura fornitore 122€)
        -- Dobbiamo scorporare: Netto = Lordo / (1 + Aliquota%), IVA = Lordo - Netto

        NEW.transazione_lordo_eur := NEW.transazione_importo;

        IF v_percentuale > 0 THEN
            -- Scorporo IVA (es. 122 / 1.22 = 100.00)
            NEW.transazione_imponibile_eur := ROUND(NEW.transazione_importo / (1 + (v_percentuale / 100)), 2);
            NEW.transazione_iva_eur := NEW.transazione_lordo_eur - NEW.transazione_imponibile_eur;
        ELSE
            -- Aliquota 0% (FC, ES, NS)
            NEW.transazione_imponibile_eur := NEW.transazione_importo;
            NEW.transazione_iva_eur := 0;
        END IF;

    ELSIF NEW.transazione_iva_modalita_input = 'NETTO' THEN
        -- ----------------------------------------
        -- MODALITÀ NETTO (ATTIVO - Calcolo IVA)
        -- ----------------------------------------
        -- Utente ha inserito IMPONIBILE (es. viaggio venduto 1.000€ netto)
        -- Dobbiamo calcolare: IVA = Netto × Aliquota%, Lordo = Netto + IVA

        NEW.transazione_imponibile_eur := NEW.transazione_importo;

        IF v_percentuale > 0 THEN
            -- Calcolo IVA (es. 1000 × 0.22 = 220.00)
            NEW.transazione_iva_eur := ROUND(NEW.transazione_importo * (v_percentuale / 100), 2);
            NEW.transazione_lordo_eur := NEW.transazione_imponibile_eur + NEW.transazione_iva_eur;
        ELSE
            -- Aliquota 0%
            NEW.transazione_iva_eur := 0;
            NEW.transazione_lordo_eur := NEW.transazione_importo;
        END IF;
    ELSE
        -- Modalità non riconosciuta (non dovrebbe mai accadere per constraint CHECK)
        RAISE EXCEPTION 'Modalità IVA non valida: %. Ammessi: LORDO, NETTO', NEW.transazione_iva_modalita_input;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Creazione Trigger
DROP TRIGGER IF EXISTS trg_calcola_iva_transazione ON mov_transazioni;

CREATE TRIGGER trg_calcola_iva_transazione
BEFORE INSERT OR UPDATE ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_calcola_iva_transazione();

-- Commento
COMMENT ON FUNCTION fn_calcola_iva_transazione() IS
'Calcola automaticamente IVA su transazioni basandosi su: ciclo causale, modalità input (LORDO/NETTO), aliquota selezionata.
PRIORITÀ MASSIMA a correzioni manuali (se tutti e tre i campi IVA sono NOT NULL, non ricalcola).
Tolleranza arrotondamenti: 0.01 EUR.';

-- Disabilita Trigger Vecchio (sostituito)
-- ALTER TABLE mov_transazioni DISABLE TRIGGER trg_calcola_importo_eur;
-- COMMENT ON TRIGGER trg_calcola_importo_eur ON mov_transazioni IS 'DISABILITATO dal 14/02/2026 - Sostituito da trg_calcola_iva_transazione';
