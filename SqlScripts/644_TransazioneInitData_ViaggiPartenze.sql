-- ============================================================================
-- fn_get_transazione_init_data: i viaggi sanno quando sono stati fatti
--
-- PERCHE'. Una fattura attiva si emette quasi sempre su un viaggio **gia'
-- concluso**, e l'anagrafica di SFT ne contiene una ventina buona che crescera'
-- ogni anno. Scorrere un elenco alfabetico per trovare quello appena finito non
-- e' il modo di lavorare di chi fattura: serve poter dire «fammi vedere solo
-- quelli gia' effettuati», e trovarsi il piu' recente in cima.
--
-- COSA CAMBIA. La lista dei viaggi porta due date in piu', calcolate sulle
-- partenze (`ana_date_viaggi`), non su un indicatore da aggiornare a mano:
--
--   ultima_partenza   la piu' recente partenza gia' CONCLUSA (data fine < oggi)
--   prossima_partenza la prima partenza ancora in corso o futura
--
-- Con queste due il programma sa tutto quello che gli serve senza tornare al
-- database a ogni cambio di filtro:
--   * ha una `ultima_partenza`   -> e' un viaggio GIA' EFFETTUATO
--   * ha una `prossima_partenza` -> e' un viaggio DA EFFETTUARE
--   * un viaggio che si ripete puo' essere **entrambe le cose**, ed e' giusto
--     che compaia in tutti e due gli elenchi;
--   * un viaggio senza alcuna partenza in calendario non e' ne' l'uno ne'
--     l'altro: si trova solo sotto «Tutti».
--
-- ⚠️ Volutamente NON si usa `data_viaggio_effettuato_sino`: e' un indicatore che
-- qualcuno deve ricordarsi di spuntare, e un viaggio dimenticato sparirebbe
-- dall'elenco delle fatture da emettere. Il calendario e' un fatto, la spunta e'
-- un'opinione.
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

    -- `id` oltre a `controparte_id`: la classe eredita Id da BaseEntity (642)
    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT c.*, c.controparte_id AS id
        FROM ana_controparti c
        WHERE c.azienda_fk = p_azienda_id AND c.attivo = TRUE
        ORDER BY c.ragione_sociale
    ) t;

    -- Le chiavi sono i nomi delle PROPRIETA' C#, non quelli delle colonne (643)
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
        -- Stessa JOIN di fn_ana_viaggi_get_all: la nazione sta in eba_countries
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
        'ShowHelperCalcolo', v_show_helper,
        'TransazioneJson',   v_transazione
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_get_transazione_init_data(INT, INT) IS
    'Dati di apertura del dialog movimenti contabili in una chiamata sola. Le chiavi del JSON sono i nomi delle PROPRIETA'' C# in snake_case (643). I viaggi portano ultima_partenza e prossima_partenza, su cui la scheda filtra fra gia'' effettuati e da effettuare senza tornare al database (644).';

COMMIT;

-- ============================================================================
-- Verifica: un viaggio che si ripete deve avere ENTRAMBE le date.
--
--   SELECT x->>'descrizione_breve' AS viaggio,
--          x->>'ultima_partenza'   AS gia_fatto,
--          x->>'prossima_partenza' AS da_fare
--     FROM jsonb_array_elements((fn_get_transazione_init_data(2)::jsonb)->'Viaggi') x
--    ORDER BY 2 DESC NULLS LAST;
-- ============================================================================
