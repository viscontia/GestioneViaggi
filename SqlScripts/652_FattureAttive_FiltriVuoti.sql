-- ============================================================================
-- L'elenco delle fatture attive: un filtro lasciato in bianco non e' un filtro
--
-- SINTOMO. «Ancora nessuna fattura visibile da stampare», con una fattura in
-- archivio e i filtri all'apparenza puliti.
--
-- CAUSA. `p_stato IS NULL OR transazione_stato = p_stato`. Se la tendina Stato
-- manda una **stringa vuota** invece di NULL — ed e' cio' che fa una tendina
-- MudBlazor svuotata dopo essere stata usata — la condizione diventa
-- `transazione_stato = ''`, che nessuna transazione soddisfa: l'elenco esce
-- vuoto e sembra che non ci sia niente da stampare.
--
-- ⚠️ Vuoto e assente sono la stessa cosa, ed e' una regola che il progetto ha
-- gia' scritto altrove: `fn_ana_clienti_campi_mancanti` la enuncia nel suo primo
-- commento, e `_payload` del sito la applica scartando i campi vuoti. Qui
-- mancava, e il chiamante non puo' essere l'unico presidio: basta una tendina
-- che si comporta diversamente e il filtro torna a mordere.
--
-- ℹ️ Stessa cura per il numero documento: `ILIKE '%%'` non escluderebbe nulla,
-- quindi li' il danno non c'era — ma la regola si applica in un posto solo per
-- tutti e due, invece di ricordarsi quale dei due era innocuo.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_get_fatture_attive_elenco(
    p_azienda_id integer,
    p_controparte_id integer DEFAULT NULL::integer,
    p_data_doc_da date DEFAULT NULL::date,
    p_data_doc_a date DEFAULT NULL::date,
    p_importo_da numeric DEFAULT NULL::numeric,
    p_importo_a numeric DEFAULT NULL::numeric,
    p_stato character varying DEFAULT NULL::character varying,
    p_numero_documento character varying DEFAULT NULL::character varying
)
RETURNS TABLE(transazione_id integer, transazione_data date, data_documento date,
              numero_documento character varying, numero_protocollo_iva integer,
              controparte_ragione_sociale character varying, imponibile_eur numeric,
              iva_eur numeric, lordo_eur numeric, stato character varying,
              data_scadenza date, causale_descrizione character varying)
LANGUAGE plpgsql
AS $function$
DECLARE
    -- Si normalizza UNA VOLTA, all'ingresso: cosi' la condizione sotto resta
    -- leggibile e non c'e' modo di applicare la regola a un filtro e non all'altro.
    v_stato   VARCHAR := NULLIF(btrim(COALESCE(p_stato, '')), '');
    v_num_doc VARCHAR := NULLIF(btrim(COALESCE(p_numero_documento, '')), '');
BEGIN
    RETURN QUERY
    SELECT
        t.transazione_id,
        t.transazione_data,
        t.transazione_data_documento AS data_documento,
        t.transazione_numero_documento AS numero_documento,
        t.transazione_numero_protocollo_iva AS numero_protocollo_iva,
        c.ragione_sociale AS controparte_ragione_sociale,
        t.transazione_imponibile_eur AS imponibile_eur,
        t.transazione_iva_eur AS iva_eur,
        t.transazione_lordo_eur AS lordo_eur,
        t.transazione_stato AS stato,
        t.transazione_data_scadenza AS data_scadenza,
        tc.causale_descrizione
    FROM mov_transazioni t
    JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
    JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
    WHERE t.transazione_azienda_id = p_azienda_id
      AND tc.causale_ciclo = 'ATTIVO'
      -- Anche lo zero vale «nessun filtro»: una tendina svuotata torna a 0, non a NULL.
      AND (COALESCE(p_controparte_id, 0) = 0 OR t.transazione_controparte_id = p_controparte_id)
      AND (p_data_doc_da IS NULL OR COALESCE(t.transazione_data_documento, t.transazione_data) >= p_data_doc_da)
      AND (p_data_doc_a IS NULL OR COALESCE(t.transazione_data_documento, t.transazione_data) <= p_data_doc_a)
      AND (p_importo_da IS NULL OR COALESCE(t.transazione_lordo_eur, t.transazione_importo) >= p_importo_da)
      AND (p_importo_a IS NULL OR COALESCE(t.transazione_lordo_eur, t.transazione_importo) <= p_importo_a)
      AND (v_stato IS NULL OR t.transazione_stato = v_stato)
      AND (v_num_doc IS NULL OR t.transazione_numero_documento ILIKE '%' || v_num_doc || '%')
    ORDER BY COALESCE(t.transazione_data_documento, t.transazione_data) DESC, t.created_at DESC;
END;
$function$;

COMMENT ON FUNCTION fn_get_fatture_attive_elenco(integer, integer, date, date, numeric, numeric, character varying, character varying) IS
    'Elenco delle fatture attive per la stampa. Un filtro vuoto (stringa vuota o zero) vale come filtro assente: prima una tendina svuotata cercava lo stato '''' e l''elenco usciva vuoto (script 652).';

COMMIT;

-- ============================================================================
-- Verifica: le tre chiamate devono dare lo STESSO numero di righe.
--
--   SELECT count(*) FROM fn_get_fatture_attive_elenco(2);
--   SELECT count(*) FROM fn_get_fatture_attive_elenco(2, 0, NULL, NULL, NULL, NULL, '', '');
--   SELECT count(*) FROM fn_get_fatture_attive_elenco(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
-- ============================================================================
