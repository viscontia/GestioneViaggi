-- Function: fn_get_transazione_init_data
-- Description: Recupera in un'unica chiamata JSON tutti i dati necessari per l'inizializzazione del dialog MovTransazioni.
--              Include lookup (Causali, IVA, Valute), liste (Controparti, Viaggi), flag helper calcolo e dati transazione (se in edit).

CREATE OR REPLACE FUNCTION fn_get_transazione_init_data(p_azienda_id INT, p_transazione_id INT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    v_causali JSON;
    v_aliquote JSON;
    v_valute JSON;
    v_controparti JSON;
    v_viaggi JSON;
    v_show_helper BOOLEAN;
    v_transazione JSON;
BEGIN
    -- Causali
    SELECT json_agg(t) INTO v_causali FROM (
        SELECT * FROM ana_tipi_causali 
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE 
        ORDER BY causale_descrizione
    ) t;

    -- Aliquote IVA
    SELECT json_agg(t) INTO v_aliquote FROM (
        SELECT * FROM ana_aliquote_iva 
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE 
        ORDER BY ordinamento, iva_descrizione
    ) t;

    -- Valute
    SELECT json_agg(t) INTO v_valute FROM (
        SELECT * FROM ana_valute 
        WHERE valuta_attiva = TRUE
        ORDER BY valuta_codice_iso
    ) t;

    -- Controparti (Solo attive e dell'azienda)
    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT * FROM ana_controparti 
        WHERE azienda_id_fk = p_azienda_id AND is_active = TRUE 
        ORDER BY ragione_sociale
    ) t;

    -- Viaggi (Solo attivi e dell'azienda)
    SELECT json_agg(t) INTO v_viaggi FROM (
        SELECT * FROM ana_viaggi 
        WHERE azienda_id_fk = p_azienda_id AND is_active = TRUE 
        ORDER BY viaggio_data_inizio DESC
    ) t;

    -- Show Helper Calcolo (da regime fiscale azienda)
    SELECT COALESCE(rf.show_helper_calcolo, FALSE) INTO v_show_helper
    FROM ana_aziende a
    LEFT JOIN ana_regimi_fiscali rf ON a.regime_fiscale_fk = rf.regime_id
    WHERE a.azienda_id = p_azienda_id;

    -- Transazione (se in edit)
    IF p_transazione_id IS NOT NULL AND p_transazione_id > 0 THEN
        SELECT json_build_object(
            'transazione', t,
            'righe', (SELECT json_agg(r) FROM (
                SELECT r.*, a.iva_codice as AliquotaIvaCodice, a.iva_descrizione as AliquotaIvaDescrizione, a.iva_percentuale as AliquotaIvaPercentuale
                FROM mov_transazioni_righe r
                LEFT JOIN ana_aliquote_iva a ON r.riga_aliquota_iva_fk = a.iva_id
                WHERE r.transazione_fk = p_transazione_id
                ORDER BY r.riga_numero
            ) r)
        ) INTO v_transazione
        FROM (
            SELECT
                trans.*,
                c.ragione_sociale as controparte_ragione_sociale,
                v.valuta_codice_iso as valuta_codice_iso,
                tc.causale_descrizione as causale_descrizione,
                tc.causale_segno as causale_segno,
                tc.causale_ciclo as causale_ciclo,
                aiva.iva_descrizione as AliquotaIvaDescrizione,
                aiva.iva_percentuale as AliquotaIvaPercentuale,
                aiva.iva_codice as AliquotaIvaCodice
            FROM mov_transazioni trans
            JOIN ana_controparti c ON trans.transazione_controparte_id = c.controparte_id
            JOIN ana_valute v ON trans.transazione_valuta_id = v.valuta_id
            JOIN ana_tipi_causali tc ON trans.transazione_causale_tipo_id = tc.causale_id
            LEFT JOIN ana_aliquote_iva aiva ON trans.transazione_aliquota_iva_fk = aiva.iva_id
            WHERE trans.transazione_id = p_transazione_id
        ) t;
    END IF;

    RETURN json_build_object(
        'Causali', COALESCE(v_causali, '[]'::json),
        'AliquoteIva', COALESCE(v_aliquote, '[]'::json),
        'Valute', COALESCE(v_valute, '[]'::json),
        'Controparti', COALESCE(v_controparti, '[]'::json),
        'Viaggi', COALESCE(v_viaggi, '[]'::json),
        'ShowHelperCalcolo', v_show_helper,
        'TransazioneJson', v_transazione
    );
END;
$$ LANGUAGE plpgsql;
