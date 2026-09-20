-- ============================================================================
-- fn_get_transazione_init_data: le modalità di pagamento nella scheda movimenti
--
-- La scheda deve poter proporre la modalità **appena si sceglie la controparte**,
-- e deve poterla far cambiare. Servono quindi due cose, entrambe nella lettura
-- unica di apertura — nessuna andata e ritorno in più al database:
--
--   * `ModalitaPagamento`: l'elenco delle modalità attive dell'azienda, per la
--     tendina;
--   * su ogni controparte, quale sia la sua. Questa arriva gia' da sola: le
--     controparti si leggono con `SELECT c.*`, e `modalita_pagamento_fk` e' una
--     colonna vera della tabella (script 645). Il nome combacia con la
--     proprieta' C# `ModalitaPagamentoFk`, quindi non serve alcun alias — al
--     contrario dei viaggi, che di alias ne hanno richiesti sei (script 643).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_get_transazione_init_data(
    p_azienda_id INT,
    p_transazione_id INT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_causali JSON;
    v_aliquote JSON;
    v_valute JSON;
    v_controparti JSON;
    v_viaggi JSON;
    v_modalita JSON;
    v_show_helper BOOLEAN;
    v_transazione JSON;
BEGIN
    SELECT json_agg(t) INTO v_causali FROM (
        SELECT * FROM ana_tipi_causali
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE
        ORDER BY causale_descrizione
    ) t;

    SELECT json_agg(t) INTO v_aliquote FROM (
        SELECT * FROM ana_aliquote_iva
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE
        ORDER BY ordinamento, iva_descrizione
    ) t;

    SELECT json_agg(t) INTO v_valute FROM (
        SELECT * FROM ana_valute
        WHERE valuta_attiva = TRUE
        ORDER BY valuta_codice_iso
    ) t;

    -- Termini e modalità di pagamento attivi: le chiavi della tabella e i nomi
    -- della classe coincidono, quindi `SELECT *` basta.
    SELECT json_agg(t) INTO v_modalita FROM (
        SELECT * FROM ana_modalita_pagamento
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE
        ORDER BY modpag_ordinamento, modpag_codice
    ) t;

    -- `id` oltre a `controparte_id`: la classe eredita Id da BaseEntity (642).
    -- `c.*` porta anche modalita_pagamento_fk, che e' la proposta di questa scheda.
    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT c.*, c.controparte_id AS id
        FROM ana_controparti c
        WHERE c.azienda_fk = p_azienda_id AND c.attivo = TRUE
        ORDER BY c.ragione_sociale
    ) t;

    -- Le chiavi sono i nomi delle PROPRIETA' C#, non quelli delle colonne (643),
    -- piu' le due date su cui poggia il filtro gia' effettuati / da effettuare (644).
    SELECT json_agg(t ORDER BY t.descrizione_breve) INTO v_viaggi FROM (
        SELECT
            v.viaggio_id                  AS id,
            v.viaggio_id                  AS viaggio_id,
            v.azienda_id                  AS azienda_id,
            v.viaggio_descrizione_breve   AS descrizione_breve,
            v.viaggio_descrizione_estesa  AS descrizione_estesa,
            v.viaggio_numero_giorni       AS numero_giorni,
            v.viaggio_numero_notti        AS numero_notti,
            n.name::VARCHAR(255)          AS nazione_nome,
            (SELECT MAX(dv.data_viaggio_data_fine)
               FROM ana_date_viaggi dv
              WHERE dv.viaggio_id_fk = v.viaggio_id
                AND dv.data_viaggio_data_fine < CURRENT_DATE)   AS ultima_partenza,
            (SELECT MIN(dv.data_viaggio_data_inizio)
               FROM ana_date_viaggi dv
              WHERE dv.viaggio_id_fk = v.viaggio_id
                AND dv.data_viaggio_data_fine >= CURRENT_DATE)  AS prossima_partenza
        FROM ana_viaggi v
        LEFT JOIN eba_countries n ON v.viaggio_nazione_fk = n.country_id
        WHERE v.azienda_id = p_azienda_id
    ) t;

    SELECT COALESCE(rf.show_helper_calcolo, FALSE) INTO v_show_helper
    FROM ana_aziende a
    LEFT JOIN ana_regimi_fiscali rf ON a.regime_fiscale_fk = rf.regime_id
    WHERE a.azienda_id = p_azienda_id;

    IF p_transazione_id IS NOT NULL AND p_transazione_id > 0 THEN
        SELECT json_build_object(
            'transazione', t,
            'righe', (SELECT json_agg(r) FROM (
                SELECT r.*,
                       a.iva_codice      AS aliquota_iva_codice,
                       a.iva_descrizione AS aliquota_iva_descrizione,
                       a.iva_percentuale AS aliquota_iva_percentuale
                FROM mov_transazioni_righe r
                LEFT JOIN ana_aliquote_iva a ON r.riga_aliquota_iva_fk = a.iva_id
                WHERE r.transazione_fk = p_transazione_id
                ORDER BY r.riga_numero
            ) r)
        ) INTO v_transazione
        FROM (
            SELECT
                trans.*,
                c.ragione_sociale       AS controparte_ragione_sociale,
                v.valuta_codice_iso     AS valuta_codice_iso,
                tc.causale_descrizione  AS causale_descrizione,
                tc.causale_segno        AS causale_segno,
                tc.causale_ciclo        AS causale_ciclo,
                aiva.iva_descrizione    AS aliquota_iva_descrizione,
                aiva.iva_percentuale    AS aliquota_iva_percentuale,
                aiva.iva_codice         AS aliquota_iva_codice
            FROM mov_transazioni trans
            JOIN ana_controparti c   ON trans.transazione_controparte_id = c.controparte_id
            JOIN ana_valute v        ON trans.transazione_valuta_id = v.valuta_id
            JOIN ana_tipi_causali tc ON trans.transazione_causale_tipo_id = tc.causale_id
            LEFT JOIN ana_aliquote_iva aiva ON trans.transazione_aliquota_iva_fk = aiva.iva_id
            WHERE trans.transazione_id = p_transazione_id
        ) t;
    END IF;

    RETURN json_build_object(
        'Causali',           COALESCE(v_causali, '[]'::json),
        'AliquoteIva',       COALESCE(v_aliquote, '[]'::json),
        'Valute',            COALESCE(v_valute, '[]'::json),
        'Controparti',       COALESCE(v_controparti, '[]'::json),
        'Viaggi',            COALESCE(v_viaggi, '[]'::json),
        'ModalitaPagamento', COALESCE(v_modalita, '[]'::json),
        'ShowHelperCalcolo', v_show_helper,
        'TransazioneJson',   v_transazione
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_transazione_init_data(INT, INT) IS
    'Dati di apertura del dialog movimenti contabili in una chiamata sola. Le chiavi del JSON sono i nomi delle PROPRIETA'' C# in snake_case (643). I viaggi portano ultima_partenza e prossima_partenza per il filtro gia'' effettuati / da effettuare (644); le controparti portano modalita_pagamento_fk e l''elenco ModalitaPagamento serve alla tendina dei termini (648).';

COMMIT;

-- ============================================================================
-- Verifica:
--   SELECT jsonb_array_length((fn_get_transazione_init_data(2)::jsonb)->'ModalitaPagamento');
--   SELECT (fn_get_transazione_init_data(2)::jsonb)->'ModalitaPagamento'->0;
-- ============================================================================
