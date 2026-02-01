-- =============================================
-- 4. Dati iniziali Tassi di Cambio
-- Data Riferimento: 29 Gennaio 2026 (Web Search)
-- =============================================

-- Funzione helper temporanea per inserimento sicuro
DO $$
DECLARE
    v_eur_id INTEGER;
    v_date DATE := '2026-01-29';
BEGIN
    -- Recupera ID Euro
    SELECT valuta_id INTO v_eur_id FROM ana_valute WHERE valuta_codice_iso = 'EUR';
    
    IF v_eur_id IS NULL THEN
        RAISE EXCEPTION 'Valuta EUR non trovata!';
    END IF;

    -- Inserimento Tassi (Valuta Estera -> EUR)
    
    -- USD (Dollaro USA)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.835100, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'USD'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- GBP (Sterlina)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 1.151400, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'GBP'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- JPY (Yen)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.005470, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'JPY'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- CAD (Dollaro Canadese)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.615700, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'CAD'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- AUD (Dollaro Australiano)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.584600, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'AUD'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- CHF (Franco Svizzero)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 1.088400, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'CHF'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- CNY (Renminbi)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.120200, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'CNY'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- ZAR (Rand)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.052580, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'ZAR'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- BWP (Pula)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.062700, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'BWP'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- NAD (Dollaro Namibiano)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.051890, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'NAD'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- MZN (Metical)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.013200, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'MZN'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- KES (Scellino Keniota)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.006500, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'KES'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;
    
    -- TZS (Scellino Tanzaniano)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.000300, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'TZS'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;

    -- ZMW (Kwacha Zambia)
    INSERT INTO ana_tassi_cambio (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita, tasso_valore, tasso_fonte)
    SELECT valuta_id, v_eur_id, v_date, 0.043000, 'WEB_SEARCH_2026'
    FROM ana_valute WHERE valuta_codice_iso = 'ZMW'
    ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita) DO UPDATE SET tasso_valore = EXCLUDED.tasso_valore;
    
END $$;
