-- ============================================================================
-- fn_get_transazione_init_data: la chiave di controparti e viaggi
--
-- SINTOMO. Dopo il 641 le tendine mostrano il testo, ma **le controparti
-- spariscono**: l'elenco si apre e non contiene la controparte selezionata.
--
-- CAUSA. Due classi su cinque non hanno una chiave "parlante": `AnaControparte`
-- e `AnaViaggi` ereditano da BaseEntity una proprieta' che si chiama
-- semplicemente `Id`, mentre le colonne sono `controparte_id` e `viaggio_id`.
-- La conversione snake->Pascal cerca quindi una chiave `id` che nel JSON non
-- c'e', e ogni elemento arriva con **Id = 0**: il testo si vede, ma il
-- componente non riesce piu' ad agganciare la voce selezionata.
--
--   AnaTipoCausale  CausaleId  <- causale_id   OK
--   AnaAliquotaIva  IvaId      <- iva_id       OK
--   AnaValute       ValutaId   <- valuta_id    OK
--   AnaControparte  Id         <- controparte_id   ⛔️
--   AnaViaggi       Id         <- viaggio_id       ⛔️
--
-- ⚠️ Il caso dei VIAGGI non era ancora stato notato: la tendina mostrava i nomi
-- e sembrava sana, ma ogni voce portava Id = 0. Corretto insieme, perche' e' lo
-- stesso difetto e trovarlo dopo sarebbe costato un altro giro.
--
-- SOLUZIONE. Le due liste espongono anche `id`, accanto alla colonna originale
-- che resta per chi la usa. Nessun rename: solo un alias in piu'.
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

    -- `id` oltre a `controparte_id`: la classe eredita Id da BaseEntity
    SELECT json_agg(t) INTO v_controparti FROM (
        SELECT c.*, c.controparte_id AS id
        FROM ana_controparti c
        WHERE c.azienda_fk = p_azienda_id AND c.attivo = TRUE
        ORDER BY c.ragione_sociale
    ) t;

    -- idem per i viaggi: AnaViaggi usa Id, la colonna e' viaggio_id
    SELECT json_agg(t) INTO v_viaggi FROM (
        SELECT v.*, v.viaggio_id AS id
        FROM ana_viaggi v
        WHERE v.azienda_id = p_azienda_id
        ORDER BY v.viaggio_descrizione_breve
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
    'Dati di apertura del dialog movimenti contabili. Chiavi in snake_case (641) e alias `id` per controparti e viaggi, le cui classi ereditano Id da BaseEntity (642).';

COMMIT;
