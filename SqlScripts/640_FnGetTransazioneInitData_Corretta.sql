-- ============================================================================
-- fn_get_transazione_init_data — la funzione che il dialog dei movimenti
-- chiama da sempre, e che nel database non è mai esistita
--
-- SINTOMO. In «Nuova Transazione» la tendina **Viaggio** non si apre: resta
-- vuota, senza messaggi. Gli altri campi (causale, controparte, valuta) si
-- vedono pieni, e questo ha nascosto il problema per mesi.
--
-- CATENA. `MovTransazioniService.GetTransazioneInitDataAsync` chiama questa
-- funzione; la funzione non esiste; l'eccezione viene raccolta, scritta nel log
-- e il metodo restituisce `new TransazioneInitData()` — un oggetto **vuoto ma
-- non nullo**. `ViaggioSelect` riceve quindi un `CustomItems` non-null e prende
-- il ramo `if (CustomItems != null) _allViaggi = CustomItems.ToList();`, cioè
-- **rinuncia a caricare i viaggi per conto suo**. Gli altri select ricadono
-- invece sul proprio caricamento autonomo, ed è per questo che sembrano sani.
--
-- ⚠️ Verificato il 2026-09-20: la funzione manca **anche in produzione**.
--
-- PERCHÉ NON C'ERA. Lo script `270` che la crea usa nomi di colonne che lo
-- schema non ha più:
--   * `ana_controparti` → `azienda_fk` e `attivo` (non `azienda_id_fk`/`is_active`)
--   * `ana_viaggi`      → `azienda_id`, e **non ha** né `is_active` né
--                         `viaggio_data_inizio` (le date stanno in ana_date_viaggi)
-- Applicandolo, la funzione si crea ma alla prima chiamata risponde
-- `column "azienda_id_fk" does not exist`. Non è mai stata messa in servizio.
--
-- Questo script la ricrea allineata allo schema di oggi. ⛔️ Lo `270` resta come
-- storia ma **non va applicato**: creerebbe di nuovo la versione rotta.
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
    -- Causali dell'azienda
    SELECT json_agg(t) INTO v_causali FROM (
        SELECT * FROM ana_tipi_causali
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE
        ORDER BY causale_descrizione
    ) t;

    -- Aliquote IVA dell'azienda
    SELECT json_agg(t) INTO v_aliquote FROM (
        SELECT * FROM ana_aliquote_iva
        WHERE azienda_fk = p_azienda_id AND is_active = TRUE
        ORDER BY ordinamento, iva_descrizione
    ) t;

    -- Valute: tabella di sistema, non per azienda
    SELECT json_agg(t) INTO v_valute FROM (
        SELECT * FROM ana_valute
        WHERE valuta_attiva = TRUE
        ORDER BY valuta_codice_iso
    ) t;

    -- Controparti attive dell'azienda.
    -- ⚠️ `azienda_fk` e `attivo`: i nomi usati dallo script 270 non esistono.
    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT * FROM ana_controparti
        WHERE azienda_fk = p_azienda_id AND attivo = TRUE
        ORDER BY ragione_sociale
    ) t;

    -- Viaggi dell'azienda.
    -- ⚠️ `ana_viaggi` non ha né `is_active` né una data: le partenze stanno in
    -- `ana_date_viaggi`, e il viaggio è un modello che non si disattiva.
    -- L'ordine è alfabetico, lo stesso con cui la tendina li mostra.
    SELECT json_agg(t) INTO v_viaggi FROM (
        SELECT * FROM ana_viaggi
        WHERE azienda_id = p_azienda_id
        ORDER BY viaggio_descrizione_breve
    ) t;

    -- Il pulsante «Applica Calcolo Regime» compare solo se il regime lo prevede
    SELECT COALESCE(rf.show_helper_calcolo, FALSE) INTO v_show_helper
    FROM ana_aziende a
    LEFT JOIN ana_regimi_fiscali rf ON a.regime_fiscale_fk = rf.regime_id
    WHERE a.azienda_id = p_azienda_id;

    -- Transazione e sue righe, solo in modifica
    IF p_transazione_id IS NOT NULL AND p_transazione_id > 0 THEN
        SELECT json_build_object(
            'transazione', t,
            'righe', (SELECT json_agg(r) FROM (
                SELECT r.*,
                       a.iva_codice        AS AliquotaIvaCodice,
                       a.iva_descrizione   AS AliquotaIvaDescrizione,
                       a.iva_percentuale   AS AliquotaIvaPercentuale
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
                aiva.iva_descrizione    AS AliquotaIvaDescrizione,
                aiva.iva_percentuale    AS AliquotaIvaPercentuale,
                aiva.iva_codice         AS AliquotaIvaCodice
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
    'Dati di apertura del dialog movimenti contabili in una chiamata sola: causali, aliquote, valute, controparti, viaggi, flag del calcolo regime e la transazione in modifica. Sostituisce la versione dello script 270, che usava colonne non più esistenti (script 640).';

COMMIT;

-- ============================================================================
-- Verifica: nessuna delle liste deve essere vuota per un'azienda con dati.
--
--   SELECT jsonb_array_length((fn_get_transazione_init_data(2)::jsonb)->'Viaggi')      AS viaggi,
--          jsonb_array_length((fn_get_transazione_init_data(2)::jsonb)->'Causali')     AS causali,
--          jsonb_array_length((fn_get_transazione_init_data(2)::jsonb)->'Controparti') AS controparti,
--          jsonb_array_length((fn_get_transazione_init_data(2)::jsonb)->'Valute')      AS valute;
-- ============================================================================
