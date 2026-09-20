-- ============================================================================
-- fn_get_transazione_init_data: i viaggi, con i nomi che il programma si aspetta
--
-- SINTOMO. Nella scheda dei movimenti la tendina **Viaggio** si apre su un
-- riquadro bianco: le righe ci sono, una per viaggio, ma sono tutte senza testo.
-- È lo stesso aspetto che aveva l'IVA prima dello script 641.
--
-- CAUSA. La classe `AnaViaggi` NON ripete il prefisso della tabella nei nomi
-- delle proprieta':
--
--     colonna in ana_viaggi          proprieta' C#        chiave cercata
--     viaggio_descrizione_breve  ->  DescrizioneBreve  -> descrizione_breve
--     viaggio_descrizione_estesa ->  DescrizioneEstesa -> descrizione_estesa
--     viaggio_numero_giorni      ->  NumeroGiorni      -> numero_giorni
--     viaggio_id                 ->  Id                -> id            (642)
--
-- Il `SELECT v.*` mandava quindi `viaggio_descrizione_breve`, una chiave che
-- nella classe non esiste: ogni viaggio arrivava con la descrizione vuota.
--
-- ⚠️ Perche' funziona dappertutto tranne qui: le altre schermate NON passano
-- dal JSON. `AnaViaggiService` legge il risultato con un `MapFromReader`
-- scritto a mano, colonna per colonna, che conosce i nomi veri. Il percorso
-- JSON e' l'unico che si affida alla conversione automatica dei nomi, ed e' per
-- questo che il disallineamento si vede solo nella scheda dei movimenti.
--
-- SOLUZIONE. La lista dei viaggi non viene piu' da `SELECT *` ma da un oggetto
-- costruito campo per campo, con le chiavi che il programma cerca. Due vantaggi
-- oltre alla correzione:
--
--   * si aggiunge `nazione_nome`, che la tendina mostra sotto al titolo e che
--     prima non arrivava affatto (la riga della nazione non compariva mai);
--   * **non viaggia piu' la mappa**. `viaggio_mappa` e' una colonna `bytea`:
--     con `SELECT *` finiva nel JSON convertita in testo, a ogni apertura
--     della scheda, per ogni viaggio in anagrafica. Nessuno la usava.
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

    -- Un oggetto per viaggio, con le chiavi della classe e non quelle della
    -- tabella. Solo cio' che la tendina usa davvero.
    SELECT json_agg(t ORDER BY t.descrizione_breve) INTO v_viaggi FROM (
        SELECT
            v.viaggio_id                  AS id,
            v.viaggio_id                  AS viaggio_id,
            v.azienda_id                  AS azienda_id,
            v.viaggio_descrizione_breve   AS descrizione_breve,
            v.viaggio_descrizione_estesa  AS descrizione_estesa,
            v.viaggio_numero_giorni       AS numero_giorni,
            v.viaggio_numero_notti        AS numero_notti,
            n.name::VARCHAR(255)          AS nazione_nome
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
    'Dati di apertura del dialog movimenti contabili in una chiamata sola. Le chiavi del JSON sono i nomi delle PROPRIETA'' C# in snake_case, non quelli delle colonne: per i viaggi serve descrizione_breve, non viaggio_descrizione_breve (script 643).';

COMMIT;

-- ============================================================================
-- Verifica: il primo viaggio deve avere una descrizione, non una chiave vuota.
--
--   SELECT (fn_get_transazione_init_data(2)::jsonb)->'Viaggi'->0;
--   -- atteso: {"id": .., "descrizione_breve": "...", "nazione_nome": "..."}
-- ============================================================================
