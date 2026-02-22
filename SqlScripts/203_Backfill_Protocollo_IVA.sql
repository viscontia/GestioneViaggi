-- ============================================================================
-- Backfill: Assegna protocollo IVA a tutte le transazioni esistenti qualificanti
-- che non hanno ancora un protocollo assegnato.
-- Ordinate per data_documento + transazione_id per ricostruire l'ordine
-- cronologico piu' fedele possibile.
--
-- NOTA: Eseguire DOPO aver creato la tabella contatori (200),
--       la colonna protocollo (201) e la stored procedure (202).
-- ============================================================================

DO $$
DECLARE
    r RECORD;
    v_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Inizio backfill protocollo IVA...';

    FOR r IN
        SELECT t.transazione_id
        FROM mov_transazioni t
        INNER JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
        INNER JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
        WHERE ca.causale_genera_iva = TRUE
          AND v.valuta_codice_iso = 'EUR'
          AND t.transazione_stato != 'ANNULLATO'
          AND t.transazione_numero_protocollo_iva IS NULL
        ORDER BY
            t.transazione_azienda_id ASC,
            ca.causale_ciclo ASC,
            COALESCE(t.transazione_data_documento, t.transazione_data::date) ASC,
            t.transazione_id ASC
    LOOP
        PERFORM sp_assegna_protocollo_iva(r.transazione_id);
        v_count := v_count + 1;
    END LOOP;

    RAISE NOTICE 'Backfill completato: % transazioni protocollate.', v_count;
END $$;
