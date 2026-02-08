-- =============================================
-- Migration: Update fn_calcola_importo_eur to use Data Documento
-- Data Creazione: 2026-02-08
-- Autore: Antigravity
-- Descrizione: Modifica il trigger per usare la data_documento invece della data_transazione
--              e memorizzare il tasso applicato, la fonte e la data di validità
-- =============================================

-- Drop del trigger esistente
DROP TRIGGER IF EXISTS trg_calcola_importo_eur ON mov_transazioni;

-- Modifica della funzione trigger
CREATE OR REPLACE FUNCTION fn_calcola_importo_eur()
RETURNS TRIGGER AS $$
DECLARE
    v_valuta_base_id INTEGER;
    v_tasso NUMERIC(15,6);
    v_data_per_tasso DATE;
    v_tasso_fonte VARCHAR(50);
    v_tasso_data_validita DATE;
    v_is_tasso_esatto BOOLEAN := FALSE;
BEGIN
    -- Ottieni ID valuta base (EUR)
    SELECT valuta_id INTO v_valuta_base_id
    FROM ana_valute
    WHERE valuta_is_base = TRUE
    LIMIT 1;

    -- Se la valuta è già quella base, imposta tutto a 1 o NULL
    IF NEW.transazione_valuta_id = v_valuta_base_id THEN
        NEW.transazione_importo_eur := NEW.transazione_importo;
        NEW.transazione_tasso_cambio_applicato := 1.0;
        NEW.transazione_tasso_fonte := 'EUR_BASE';
        NEW.transazione_tasso_data_validita := NEW.transazione_data_documento;
    ELSE
        -- =============================================
        -- Usa TRANSAZIONE_DATA_DOCUMENTO per il tasso di cambio
        -- =============================================
        v_data_per_tasso := NEW.transazione_data_documento;

        -- Cerca il tasso ESATTO per la data documento
        SELECT
            tasso_valore,
            tasso_fonte,
            tasso_data_validita
        INTO v_tasso, v_tasso_fonte, v_tasso_data_validita
        FROM ana_tassi_cambio
        WHERE tasso_valuta_da_fk = NEW.transazione_valuta_id
          AND tasso_valuta_a_fk = v_valuta_base_id
          AND tasso_data_validita = v_data_per_tasso
        LIMIT 1;

        IF v_tasso IS NOT NULL THEN
            v_is_tasso_esatto := TRUE;
        ELSE
            -- Se non trovato esatto, cerca il più recente PRIMA della data documento (FALLBACK)
            SELECT
                tasso_valore,
                tasso_fonte,
                tasso_data_validita
            INTO v_tasso, v_tasso_fonte, v_tasso_data_validita
            FROM ana_tassi_cambio
            WHERE tasso_valuta_da_fk = NEW.transazione_valuta_id
              AND tasso_valuta_a_fk = v_valuta_base_id
              AND tasso_data_validita <= v_data_per_tasso
            ORDER BY tasso_data_validita DESC
            LIMIT 1;

            IF v_tasso IS NOT NULL THEN
                -- Marca come FALLBACK
                v_tasso_fonte := 'FALLBACK_DB: ' || COALESCE(v_tasso_fonte, 'UNKNOWN');
                v_is_tasso_esatto := FALSE;
            END IF;
        END IF;

        -- Se ancora NULL, prova il tasso inverso
        IF v_tasso IS NULL THEN
            -- Cerca tasso inverso esatto
            SELECT
                (1.0 / tasso_valore),
                tasso_fonte,
                tasso_data_validita
            INTO v_tasso, v_tasso_fonte, v_tasso_data_validita
            FROM ana_tassi_cambio
            WHERE tasso_valuta_da_fk = v_valuta_base_id -- Invertito
              AND tasso_valuta_a_fk = NEW.transazione_valuta_id -- Invertito
              AND tasso_data_validita = v_data_per_tasso
            LIMIT 1;

            IF v_tasso IS NOT NULL THEN
                v_is_tasso_esatto := TRUE;
                v_tasso_fonte := 'INVERSO: ' || COALESCE(v_tasso_fonte, 'UNKNOWN');
            ELSE
                -- Cerca tasso inverso fallback
                SELECT
                    (1.0 / tasso_valore),
                    tasso_fonte,
                    tasso_data_validita
                INTO v_tasso, v_tasso_fonte, v_tasso_data_validita
                FROM ana_tassi_cambio
                WHERE tasso_valuta_da_fk = v_valuta_base_id -- Invertito
                  AND tasso_valuta_a_fk = NEW.transazione_valuta_id -- Invertito
                  AND tasso_data_validita <= v_data_per_tasso
                ORDER BY tasso_data_validita DESC
                LIMIT 1;

                IF v_tasso IS NOT NULL THEN
                    v_tasso_fonte := 'FALLBACK_DB_INVERSO: ' || COALESCE(v_tasso_fonte, 'UNKNOWN');
                    v_is_tasso_esatto := FALSE;
                END IF;
            END IF;
        END IF;

        -- Memorizza il tasso applicato e i metadata
        NEW.transazione_tasso_cambio_applicato := v_tasso;
        NEW.transazione_tasso_fonte := v_tasso_fonte;
        NEW.transazione_tasso_data_validita := v_tasso_data_validita;

        -- Calcola l'importo EUR se il tasso è disponibile
        IF v_tasso IS NOT NULL THEN
            NEW.transazione_importo_eur := ROUND((NEW.transazione_importo * v_tasso), 2);
        ELSE
            -- Tasso non trovato: importo EUR rimane NULL
            NEW.transazione_importo_eur := NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ricreazione del trigger
CREATE TRIGGER trg_calcola_importo_eur
BEFORE INSERT OR UPDATE OF transazione_importo, transazione_valuta_id, transazione_data_documento
ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_calcola_importo_eur();

-- =============================================
-- Commenti
-- =============================================
COMMENT ON FUNCTION fn_calcola_importo_eur() IS
    'Calcola automaticamente transazione_importo_eur usando il tasso di cambio alla data_documento. '
    'Memorizza anche il tasso applicato, la fonte (API/FALLBACK) e la data di validità del tasso.';

-- =============================================
-- Messaggio di conferma
-- =============================================
DO $$
BEGIN
    RAISE NOTICE 'Migration completata: trigger fn_calcola_importo_eur aggiornato per usare data_documento';
END $$;
