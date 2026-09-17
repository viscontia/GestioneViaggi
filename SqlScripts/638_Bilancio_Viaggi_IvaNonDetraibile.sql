-- ============================================================================
-- Bilancio viaggi: il costo di chi NON detrae l'IVA è il LORDO
--
-- PROBLEMA. Le due funzioni del bilancio espongono `importo_netto_eur`
-- (l'imponibile) e la stampa lo somma sia per i ricavi sia per i costi. Per un
-- regime ORDINARIO è corretto: l'IVA sugli acquisti si recupera, quindi non è
-- un costo. Per un regime FORFETTARIO no — l'IVA sugli acquisti non è
-- detraibile ed è costo a tutti gli effetti: il margine risultava più alto del
-- vero esattamente di quell'importo, senza che nulla lo segnalasse.
--
-- Il flag esiste da sempre: `ana_regimi_fiscali.is_iva_detraibile`, creato
-- dallo script 210 proprio per questo. Il follow-up era annotato in
-- EvoluzioneContabile.md ma puntava a `vw_margini_viaggi`, una vista che non
-- esiste più: il promemoria era agganciato a un oggetto sparito, ed è per
-- questo che non è mai stato ripreso.
--
-- SOLUZIONE. Una colonna nuova, `importo_effettivo_eur`, che vale:
--   * per i RICAVI            -> sempre il netto (un forfettario non addebita
--                                IVA in fattura: netto e lordo coincidono);
--   * per i COSTI, IVA detraibile     -> il netto (comportamento invariato);
--   * per i COSTI, IVA NON detraibile -> il LORDO.
--
-- Perché una colonna nuova e non la modifica di `importo_netto_eur`: quel nome
-- dice "imponibile" e c'è chi lo legge come tale. Cambiargli significato sotto
-- silenzio sposterebbe il problema invece di chiuderlo.
--
-- Il flag si legge UNA VOLTA per chiamata in una variabile, non con una JOIN
-- riga per riga: l'azienda è un parametro della funzione, non cambia fra le
-- righe del risultato.
--
-- ⚠️ DROP + CREATE e non CREATE OR REPLACE: cambia il tipo del risultato
-- (una colonna in più), e REPLACE non può farlo. Le firme si eliminano per
-- signature esatta, perché di queste funzioni esistono altri overload non più
-- richiamati da nessuno (vedi nota in coda).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 0) Via le firme morte — ⛔️ e non è pulizia estetica: la stampa NON funziona
--
-- Di queste due funzioni esistevano altre firme, non richiamate da nessuna
-- parte del codice, che avevano parametri con DEFAULT. Il risultato è che la
-- chiamata a 5 argomenti fatta da fn_get_bilancio_viaggio_print_data diventava
-- AMBIGUA e il database la rifiutava:
--
--     ERROR: function fn_get_bilancio_viaggio(integer,integer,integer,date,date)
--            is not unique
--
-- Cioè: la Stampa Bilancio Viaggio e la Stampa Bilancio Annuale **erano
-- entrambe rotte**, e lo erano da prima di questo script. Verificato in locale
-- il 2026-09-17 chiamando direttamente fn_get_bilancio_viaggio_print_data.
--
-- È lo stesso difetto che lo script 524 aveva già ripulito altrove: CREATE OR
-- REPLACE non sostituisce una funzione se cambia il numero di parametri, e le
-- firme superate restano lì a rendere ambigua ogni chiamata che non le elenchi
-- tutte.
-- ============================================================================
DROP FUNCTION IF EXISTS fn_get_bilancio_viaggio(integer, integer[], date, date);
DROP FUNCTION IF EXISTS fn_get_bilancio_viaggio(integer, integer, integer, date, date, integer);
DROP FUNCTION IF EXISTS fn_get_bilancio_annuale_viaggi(integer, integer, integer);

-- ============================================================================
-- 1) Bilancio di UN viaggio (usata da fn_get_bilancio_viaggio_print_data)
-- ============================================================================
DROP FUNCTION IF EXISTS fn_get_bilancio_viaggio(integer, integer, integer, date, date);

CREATE OR REPLACE FUNCTION public.fn_get_bilancio_viaggio(
    p_azienda_id integer,
    p_viaggio_id integer,
    p_data_viaggio_id integer DEFAULT NULL::integer,
    p_data_da date DEFAULT NULL::date,
    p_data_a date DEFAULT NULL::date
)
RETURNS TABLE(
    viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date,
    viaggio_numero_partecipanti integer, viaggio_numero_mezzi integer,
    transazione_id integer, data_documento date, data_registrazione date,
    numero_documento character varying, transazione_descrizione text,
    controparte_ragione_sociale character varying, categoria_nome character varying,
    categoria_tipo character varying,
    importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric,
    importo_effettivo_eur numeric,
    importo_pagato_eur numeric, stato_pagamento character varying
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_iva_detraibile BOOLEAN;
BEGIN
    -- Regime dell'azienda. COALESCE a TRUE: un'azienda senza regime configurato
    -- si comporta come prima di questa modifica, invece di vedersi gonfiare i costi.
    SELECT COALESCE(rf.is_iva_detraibile, TRUE)
      INTO v_iva_detraibile
      FROM ana_aziende a
      LEFT JOIN ana_regimi_fiscali rf ON rf.regime_id = a.regime_fiscale_fk
     WHERE a.azienda_id = p_azienda_id;

    v_iva_detraibile := COALESCE(v_iva_detraibile, TRUE);

    RETURN QUERY
    SELECT
        v.viaggio_id,
        (v.viaggio_descrizione_breve)::TEXT as viaggio_descrizione,

        CASE
            WHEN p_data_viaggio_id IS NOT NULL THEN (SELECT data_viaggio_data_inizio FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id)
            ELSE (SELECT MIN(data_viaggio_data_inizio) FROM ana_date_viaggi WHERE viaggio_id_fk = v.viaggio_id)
        END as viaggio_data_inizio,

        CASE
            WHEN p_data_viaggio_id IS NOT NULL THEN (SELECT data_viaggio_data_fine FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id)
            ELSE (SELECT MAX(data_viaggio_data_fine) FROM ana_date_viaggi WHERE viaggio_id_fk = v.viaggio_id)
        END as viaggio_data_fine,

        COALESCE((
            SELECT COUNT(mcv.cliente_id_fk)::INT
            FROM ana_date_viaggi d
            JOIN mov_clienti_viaggi mcv ON mcv.data_viaggio_id_fk = d.data_viaggio_id
            WHERE d.viaggio_id_fk = v.viaggio_id
              AND (p_data_viaggio_id IS NULL OR d.data_viaggio_id = p_data_viaggio_id)
        ), 0) as viaggio_numero_partecipanti,

        COALESCE((
            SELECT COUNT(DISTINCT
                CASE
                    WHEN mcv.cliente_pilota_id_fk IS NOT NULL AND mcv.cliente_pilota_id_fk > 0 THEN mcv.cliente_pilota_id_fk
                    WHEN tp.tipo_partecipante_pilota = true THEN mcv.cliente_id_fk
                    ELSE NULL
                END
            )::INT
            FROM ana_date_viaggi d
            JOIN mov_clienti_viaggi mcv ON mcv.data_viaggio_id_fk = d.data_viaggio_id
            JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
            WHERE d.viaggio_id_fk = v.viaggio_id
              AND (p_data_viaggio_id IS NULL OR d.data_viaggio_id = p_data_viaggio_id)
        ), 0) as viaggio_numero_mezzi,

        t.transazione_id,
        COALESCE(t.transazione_data_documento, t.transazione_data) as data_documento,
        t.transazione_data as data_registrazione,
        COALESCE(t.transazione_numero_documento, '-')::VARCHAR as numero_documento,
        COALESCE(t.transazione_note, tc.causale_descrizione)::TEXT as transazione_descrizione,

        c.ragione_sociale as controparte_ragione_sociale,

        CASE
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'VENDITE'::VARCHAR
            ELSE COALESCE(UPPER(tf.descrizione), 'ALTRO/VARIE')::VARCHAR
        END as categoria_nome,

        CASE
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'RICAVO'::VARCHAR
            ELSE 'COSTO'::VARCHAR
        END as categoria_tipo,

        (ABS(COALESCE(t.transazione_imponibile_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_netto_eur,
        (ABS(COALESCE(t.transazione_iva_eur, 0)) * tc.causale_segno)::NUMERIC as importo_iva_eur,
        (ABS(COALESCE(t.transazione_lordo_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_lordo_eur,

        -- Il valore su cui si fa il margine: lordo solo sui costi di chi non detrae.
        (ABS(
            CASE
                WHEN tc.causale_ciclo = 'PASSIVO' AND NOT v_iva_detraibile
                    THEN COALESCE(t.transazione_lordo_eur, t.transazione_importo)
                ELSE COALESCE(t.transazione_imponibile_eur, t.transazione_importo)
            END
        ) * tc.causale_segno)::NUMERIC as importo_effettivo_eur,

        (COALESCE((
            SELECT SUM(pg.transazione_importo)
            FROM mov_transazioni pg
            WHERE pg.transazione_fattura_fk = t.transazione_id
              AND pg.transazione_stato != 'ANNULLATO'
        ), 0))::NUMERIC as importo_pagato_eur,

        t.transazione_stato::VARCHAR as stato_pagamento

    FROM mov_transazioni t
    JOIN ana_viaggi v ON t.transazione_viaggio_id = v.viaggio_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id

    WHERE t.transazione_azienda_id = p_azienda_id
      AND t.transazione_viaggio_id = p_viaggio_id
      AND (p_data_viaggio_id IS NULL OR t.transazione_data_viaggio_id = p_data_viaggio_id)
      AND t.transazione_stato != 'ANNULLATO'
      AND tc.causale_is_documento = TRUE
      AND (p_data_da IS NULL OR t.transazione_data >= p_data_da)
      AND (p_data_a IS NULL OR t.transazione_data <= p_data_a)

    ORDER BY
        v.viaggio_id,
        tc.causale_ciclo DESC,
        categoria_nome ASC,
        t.transazione_data ASC;
END;
$function$;

COMMENT ON FUNCTION fn_get_bilancio_viaggio(integer, integer, integer, date, date) IS
    'Righe del bilancio di un viaggio. importo_effettivo_eur è il valore da usare per il margine: il netto, tranne sui costi di un''azienda che non detrae l''IVA, dove è il lordo.';

-- ============================================================================
-- 2) Bilancio ANNUALE (stessa regola)
-- ============================================================================
DROP FUNCTION IF EXISTS fn_get_bilancio_annuale_viaggi(integer, integer);

CREATE OR REPLACE FUNCTION public.fn_get_bilancio_annuale_viaggi(
    p_azienda_id integer,
    p_anno integer
)
RETURNS TABLE(
    viaggio_id integer, viaggio_descrizione text,
    data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date,
    data_viaggio_numero_partecipanti integer, data_viaggio_numero_mezzi integer,
    transazione_id integer, data_documento date, data_registrazione date,
    numero_documento character varying, transazione_descrizione text,
    controparte_ragione_sociale character varying, categoria_nome character varying,
    categoria_tipo character varying,
    importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric,
    importo_effettivo_eur numeric,
    importo_pagato_eur numeric, stato_pagamento character varying
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_iva_detraibile BOOLEAN;
BEGIN
    SELECT COALESCE(rf.is_iva_detraibile, TRUE)
      INTO v_iva_detraibile
      FROM ana_aziende a
      LEFT JOIN ana_regimi_fiscali rf ON rf.regime_id = a.regime_fiscale_fk
     WHERE a.azienda_id = p_azienda_id;

    v_iva_detraibile := COALESCE(v_iva_detraibile, TRUE);

    RETURN QUERY
    SELECT
        v.viaggio_id,
        (v.viaggio_descrizione_breve)::TEXT as viaggio_descrizione,
        dv.data_viaggio_id,
        dv.data_viaggio_data_inizio,
        dv.data_viaggio_data_fine,

        COALESCE((
            SELECT COUNT(mcv.cliente_id_fk)::INT
            FROM mov_clienti_viaggi mcv
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) as data_viaggio_numero_partecipanti,

        COALESCE((
            SELECT COUNT(DISTINCT
                CASE
                    WHEN mcv.cliente_pilota_id_fk IS NOT NULL AND mcv.cliente_pilota_id_fk > 0 THEN mcv.cliente_pilota_id_fk
                    WHEN tp.tipo_partecipante_pilota = true THEN mcv.cliente_id_fk
                    ELSE NULL
                END
            )::INT
            FROM mov_clienti_viaggi mcv
            JOIN ana_tipo_partecipante tp ON mcv.tipo_partecipante_id_fk = tp.tipo_partecipante_id
            WHERE mcv.data_viaggio_id_fk = dv.data_viaggio_id
        ), 0) as data_viaggio_numero_mezzi,

        t.transazione_id,
        COALESCE(t.transazione_data_documento, t.transazione_data) as data_documento,
        t.transazione_data as data_registrazione,
        COALESCE(t.transazione_numero_documento, '-')::VARCHAR as numero_documento,
        COALESCE(t.transazione_note, tc.causale_descrizione)::TEXT as transazione_descrizione,
        c.ragione_sociale as controparte_ragione_sociale,

        CASE
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'VENDITE'::VARCHAR
            ELSE COALESCE(UPPER(tf.descrizione), 'ALTRO/VARIE')::VARCHAR
        END as categoria_nome,

        CASE
            WHEN tc.causale_ciclo = 'ATTIVO' THEN 'RICAVO'::VARCHAR
            ELSE 'COSTO'::VARCHAR
        END as categoria_tipo,

        (ABS(COALESCE(t.transazione_imponibile_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_netto_eur,
        (ABS(COALESCE(t.transazione_iva_eur, 0)) * tc.causale_segno)::NUMERIC as importo_iva_eur,
        (ABS(COALESCE(t.transazione_lordo_eur, t.transazione_importo)) * tc.causale_segno)::NUMERIC as importo_lordo_eur,

        (ABS(
            CASE
                WHEN tc.causale_ciclo = 'PASSIVO' AND NOT v_iva_detraibile
                    THEN COALESCE(t.transazione_lordo_eur, t.transazione_importo)
                ELSE COALESCE(t.transazione_imponibile_eur, t.transazione_importo)
            END
        ) * tc.causale_segno)::NUMERIC as importo_effettivo_eur,

        (COALESCE((
            SELECT SUM(pg.transazione_importo)
            FROM mov_transazioni pg
            WHERE pg.transazione_fattura_fk = t.transazione_id
              AND pg.transazione_stato != 'ANNULLATO'
        ), 0))::NUMERIC as importo_pagato_eur,

        t.transazione_stato::VARCHAR as stato_pagamento

    FROM mov_transazioni t
    JOIN ana_date_viaggi dv ON t.transazione_data_viaggio_id = dv.data_viaggio_id
    JOIN ana_viaggi v ON dv.viaggio_id_fk = v.viaggio_id
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id

    WHERE t.transazione_azienda_id = p_azienda_id
      AND t.transazione_stato != 'ANNULLATO'
      AND tc.causale_is_documento = TRUE
      AND EXTRACT(YEAR FROM dv.data_viaggio_data_inizio) = p_anno
      AND EXISTS (
          SELECT 1
          FROM mov_transazioni tx
          JOIN ana_tipi_causali tcx ON tx.transazione_causale_tipo_id = tcx.causale_id
          WHERE tx.transazione_data_viaggio_id = dv.data_viaggio_id
            AND tx.transazione_stato != 'ANNULLATO'
            AND tcx.causale_is_documento = TRUE
      )

    ORDER BY
        dv.data_viaggio_data_inizio ASC,
        v.viaggio_id,
        dv.data_viaggio_id,
        tc.causale_ciclo DESC,
        categoria_nome ASC,
        t.transazione_data ASC;
END;
$function$;

COMMENT ON FUNCTION fn_get_bilancio_annuale_viaggi(integer, integer) IS
    'Righe del bilancio annuale dei viaggi. Stessa regola di fn_get_bilancio_viaggio su importo_effettivo_eur.';

COMMIT;

-- ============================================================================
-- Verifica: su un''azienda che NON detrae, i costi devono avere
-- importo_effettivo_eur = importo_lordo_eur; i ricavi restano al netto.
--
--   SELECT categoria_tipo, importo_netto_eur, importo_lordo_eur, importo_effettivo_eur
--     FROM fn_get_bilancio_viaggio(<azienda>, <viaggio>);
--
-- ============================================================================
