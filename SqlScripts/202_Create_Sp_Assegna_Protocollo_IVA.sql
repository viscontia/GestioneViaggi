-- ============================================================================
-- sp_assegna_protocollo_iva
-- Assegna atomicamente un numero di protocollo IVA a una transazione.
-- Idempotente: se la transazione ha gia' un protocollo, lo ritorna senza modifiche.
-- Ritorna NULL se la transazione non qualifica per il protocollo IVA.
--
-- Atomicita': l'UPSERT con ON CONFLICT DO UPDATE acquisisce un lock esclusivo
-- sulla riga del contatore, garantendo serializzazione anche con inserimenti
-- simultanei da piu' utenti della stessa azienda.
-- ============================================================================

CREATE OR REPLACE FUNCTION sp_assegna_protocollo_iva(
    p_transazione_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_azienda_id       INTEGER;
    v_causale_id       INTEGER;
    v_valuta_id        INTEGER;
    v_stato            VARCHAR;
    v_data_documento   DATE;
    v_data_transazione DATE;
    v_protocollo_attuale INTEGER;
    v_genera_iva       BOOLEAN;
    v_ciclo            VARCHAR(10);
    v_codice_iso       VARCHAR(10);
    v_anno             INTEGER;
    v_nuovo_numero     INTEGER;
BEGIN
    -- 1. Recupera i dati della transazione con lock
    SELECT
        t.transazione_azienda_id,
        t.transazione_causale_tipo_id,
        t.transazione_valuta_id,
        t.transazione_stato,
        t.transazione_data_documento,
        t.transazione_data::date,
        t.transazione_numero_protocollo_iva
    INTO
        v_azienda_id, v_causale_id, v_valuta_id, v_stato,
        v_data_documento, v_data_transazione, v_protocollo_attuale
    FROM mov_transazioni t
    WHERE t.transazione_id = p_transazione_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transazione % non trovata', p_transazione_id;
    END IF;

    -- 2. Se ha gia' un protocollo, ritornalo (idempotente)
    IF v_protocollo_attuale IS NOT NULL THEN
        RETURN v_protocollo_attuale;
    END IF;

    -- 3. Verifica qualificazione: causale con genera_iva = TRUE
    SELECT ca.causale_genera_iva, ca.causale_ciclo
    INTO v_genera_iva, v_ciclo
    FROM ana_tipi_causali ca
    WHERE ca.causale_id = v_causale_id;

    IF NOT v_genera_iva THEN
        RETURN NULL;
    END IF;

    -- 4. Verifica qualificazione: valuta EUR
    SELECT v.valuta_codice_iso INTO v_codice_iso
    FROM ana_valute v
    WHERE v.valuta_id = v_valuta_id;

    IF v_codice_iso != 'EUR' THEN
        RETURN NULL;
    END IF;

    -- 5. Verifica qualificazione: stato != ANNULLATO
    IF v_stato = 'ANNULLATO' THEN
        RETURN NULL;
    END IF;

    -- 6. Determina anno dalla data documento (fallback: data transazione)
    v_anno := EXTRACT(YEAR FROM COALESCE(v_data_documento, v_data_transazione));

    -- 7. Incremento atomico del contatore con UPSERT
    --    L'UPDATE implicito nel ON CONFLICT acquisisce un ROW EXCLUSIVE lock
    INSERT INTO mov_contatori_protocollo_iva
        (contatore_azienda_id, contatore_anno, contatore_ciclo, contatore_ultimo_numero, updated_at)
    VALUES
        (v_azienda_id, v_anno, v_ciclo, 1, NOW())
    ON CONFLICT (contatore_azienda_id, contatore_anno, contatore_ciclo)
    DO UPDATE SET
        contatore_ultimo_numero = mov_contatori_protocollo_iva.contatore_ultimo_numero + 1,
        updated_at = NOW()
    RETURNING contatore_ultimo_numero INTO v_nuovo_numero;

    -- 8. Assegna il protocollo alla transazione
    UPDATE mov_transazioni
    SET transazione_numero_protocollo_iva = v_nuovo_numero
    WHERE transazione_id = p_transazione_id;

    RETURN v_nuovo_numero;
END;
$function$;

COMMENT ON FUNCTION sp_assegna_protocollo_iva(INTEGER) IS
    'Assegna atomicamente un numero di protocollo IVA progressivo a una transazione qualificante (genera_iva=TRUE, EUR, non annullata). Idempotente.';
