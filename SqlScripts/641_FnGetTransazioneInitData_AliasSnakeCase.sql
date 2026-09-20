-- ============================================================================
-- fn_get_transazione_init_data: alias in snake_case, uno stile solo
--
-- SINTOMO. Con il 640 in servizio, premendo la lente dell'aliquota IVA nel
-- dettaglio righe si apre una tendina **con le righe giuste ma tutte vuote**:
-- gli elementi ci sono (una riga per aliquota), ma non hanno testo.
--
-- CAUSA. Il JSON che esce da qui usa i nomi delle colonne — `iva_id`,
-- `iva_descrizione`, `viaggio_descrizione_breve` — mentre le classi C# hanno
-- `IvaId`, `IvaDescrizione`, `ViaggioDescrizioneBreve` e **nessuna annotazione**
-- che le colleghi. Il servizio deserializzava con il solo
-- `PropertyNameCaseInsensitive`, che ignora le maiuscole ma **non** gli
-- underscore: ogni oggetto veniva creato con tutti i campi ai valori di default.
-- Quindi non una lista vuota: una lista di oggetti vuoti.
--
-- ⚠️ Il difetto si è visto solo ora perché **prima del 640 queste liste non
-- arrivavano affatto** e ogni tendina si caricava per conto proprio. Rimessa in
-- funzione la lettura unica, il problema di conversione è saltato fuori.
--
-- LA PARTE CHE TOCCA IL DATABASE. La conversione automatica snake→Pascal si
-- attiva lato C#, ma funziona solo se **tutte** le chiavi sono snake_case. Qui
-- tre alias non lo erano: scritti come `AS AliquotaIvaCodice`, Postgres li
-- abbassa a `aliquotaivacodice` — senza underscore, quindi non convertibili.
-- Questo script li rinomina in `aliquota_iva_codice`, `aliquota_iva_descrizione`
-- e `aliquota_iva_percentuale`, così il JSON ha **uno stile solo**.
--
-- ℹ️ Gli altri alias (`controparte_ragione_sociale`, `valuta_codice_iso`,
-- `causale_descrizione`, `causale_segno`, `causale_ciclo`) erano già corretti.
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

    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT * FROM ana_controparti
        WHERE azienda_fk = p_azienda_id AND attivo = TRUE
        ORDER BY ragione_sociale
    ) t;

    SELECT json_agg(t) INTO v_viaggi FROM (
        SELECT * FROM ana_viaggi
        WHERE azienda_id = p_azienda_id
        ORDER BY viaggio_descrizione_breve
    ) t;

    SELECT COALESCE(rf.show_helper_calcolo, FALSE) INTO v_show_helper
    FROM ana_aziende a
    LEFT JOIN ana_regimi_fiscali rf ON a.regime_fiscale_fk = rf.regime_id
    WHERE a.azienda_id = p_azienda_id;

    IF p_transazione_id IS NOT NULL AND p_transazione_id > 0 THEN
        SELECT json_build_object(
            'transazione', t,
            'righe', (SELECT json_agg(r) FROM (
                -- ⚠️ Alias in snake_case: scritti in PascalCase, Postgres li
                -- appiattisce in minuscolo e la conversione lato C# non li riconosce.
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
    'Dati di apertura del dialog movimenti contabili in una chiamata sola. Tutte le chiavi del JSON sono in snake_case, alias compresi: il C# le converte con JsonNamingPolicy.SnakeCaseLower (script 641).';

COMMIT;

-- ============================================================================
-- Verifica: fra le chiavi delle righe devono comparire gli alias con underscore
-- e NON la versione appiattita.
--
--   SELECT jsonb_object_keys(
--       (fn_get_transazione_init_data(<azienda>, <transazione>)::jsonb)
--       ->'TransazioneJson'->'righe'->0);
--   -- atteso: aliquota_iva_codice, aliquota_iva_descrizione, aliquota_iva_percentuale
-- ============================================================================
