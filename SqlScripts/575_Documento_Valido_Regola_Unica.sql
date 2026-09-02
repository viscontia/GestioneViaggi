-- =============================================================================
-- 575 — Il giudizio sul documento in un posto solo, e chiamato da tre parti
-- =============================================================================
--
-- Lo script 574 aveva messo la regola dentro fn_partecipanti_documento_non_valido,
-- che interroga una PARTENZA. Ma all'iscrizione il cliente non e' ancora iscritto:
-- quella funzione non lo vedrebbe, e riscrivere il confronto dentro
-- fn_mov_clienti_viaggi_valida vorrebbe dire due copie della stessa regola —
-- destinate a divergere, come e' successo per tutto il resto.
--
-- Il giudizio scende quindi in fn_documento_stato_per_viaggio, che non sa niente
-- di clienti e di iscrizioni: prende tre date e dice come sta il documento.
-- Sopra ci stanno i due chiamanti, e domani un terzo.
--
--   fn_documento_stato_per_viaggio   ← la regola
--        ├── fn_partecipanti_documento_non_valido   (lista partecipanti, stampe)
--        └── fn_mov_clienti_viaggi_valida           (iscrizione)
--
-- All'iscrizione la gravita' dipende dalla destinazione, come deciso il
-- 2026-09-02: all'ESTERO e' un ERRORE — senza documento valido non si parte, e
-- iscrivere qualcuno a un viaggio che non potra' fare non e' un servizio. In
-- ITALIA e' un AVVISO: si parte lo stesso, ma l'albergo puo' rifiutare la
-- registrazione, dove i documenti di tutti gli occupanti si presentano per legge.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- La regola, e nient'altro.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_documento_stato_per_viaggio(
    p_scadenza      DATE,
    p_viaggio_inizio DATE,
    p_viaggio_fine   DATE
)
RETURNS TABLE(stato VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_scadenza IS NULL THEN
        RETURN QUERY SELECT 'MANCANTE'::VARCHAR,
               'Nessuna data di scadenza del documento in anagrafica.'::TEXT;
    ELSIF p_scadenza < p_viaggio_inizio THEN
        RETURN QUERY SELECT 'SCADUTO'::VARCHAR,
               format('Documento scaduto il %s, prima della partenza del %s.',
                      to_char(p_scadenza, 'DD/MM/YYYY'),
                      to_char(p_viaggio_inizio, 'DD/MM/YYYY'))::TEXT;
    ELSIF p_scadenza <= p_viaggio_fine THEN
        -- Scade DURANTE il viaggio: si parte con un documento che al rientro non
        -- vale piu'. E' il caso che nessuno guarda, perche' oggi il documento e'
        -- valido e sembra tutto a posto.
        RETURN QUERY SELECT 'SCADE_DURANTE'::VARCHAR,
               format('Documento in scadenza il %s, durante il viaggio (rientro il %s).',
                      to_char(p_scadenza, 'DD/MM/YYYY'),
                      to_char(p_viaggio_fine, 'DD/MM/YYYY'))::TEXT;
    ELSE
        RETURN QUERY SELECT 'VALIDO'::VARCHAR, NULL::TEXT;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_documento_stato_per_viaggio(DATE, DATE, DATE) IS
'Come sta un documento rispetto a un viaggio: MANCANTE, SCADUTO, SCADE_DURANTE, VALIDO.
Non conta se e'' scaduto oggi: conta se arriva valido alla FINE del viaggio. Regola unica,
usata dalla lista partecipanti, dalle stampe e dalla validazione dell''iscrizione.';


-- ---------------------------------------------------------------------------
-- I partecipanti di una partenza cui il documento non basta.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_partecipanti_documento_non_valido(INTEGER);

CREATE OR REPLACE FUNCTION fn_partecipanti_documento_non_valido(
    p_data_viaggio_id INTEGER
)
RETURNS TABLE(
    cliente_id INTEGER,
    cognome VARCHAR,
    nome VARCHAR,
    email VARCHAR,
    prefisso VARCHAR,
    telefono VARCHAR,
    documento_scadenza DATE,
    stato VARCHAR,
    viaggio_estero BOOLEAN,
    messaggio TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_inizio DATE;
    v_fine   DATE;
    v_estero BOOLEAN;
BEGIN
    SELECT d.data_viaggio_data_inizio, d.data_viaggio_data_fine,
           -- Nazione non indicata = si assume estero: e' il caso piu' severo, e
           -- sui documenti di chi parte non si tira a indovinare.
           COALESCE(c.iso_alpha2, 'XX') <> 'IT'
      INTO v_inizio, v_fine, v_estero
    FROM ana_date_viaggi d
    JOIN ana_viaggi v         ON v.viaggio_id = d.viaggio_id_fk
    LEFT JOIN eba_countries c ON c.country_id = v.viaggio_nazione_fk
    WHERE d.data_viaggio_id = p_data_viaggio_id;

    IF v_inizio IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT cl.cliente_id, cl.cliente_cognome, cl.cliente_nome,
           cl.cliente_email, cl.cliente_preftelint, cl.cliente_telefono,
           cl.cliente_documento_rilasciato_scadenza,
           s.stato, v_estero, s.messaggio
    FROM mov_clienti_viaggi mcv
    JOIN ana_clienti cl ON cl.cliente_id = mcv.cliente_id_fk
    CROSS JOIN LATERAL fn_documento_stato_per_viaggio(
        cl.cliente_documento_rilasciato_scadenza, v_inizio, v_fine) s
    WHERE mcv.data_viaggio_id_fk = p_data_viaggio_id
      AND s.stato <> 'VALIDO'
    ORDER BY cl.cliente_cognome, cl.cliente_nome;
END;
$$;

COMMENT ON FUNCTION fn_partecipanti_documento_non_valido(INTEGER) IS
'Partecipanti a una partenza il cui documento non arriva valido alla fine del viaggio, con
email e telefono per avvisarli. Interroga la PARTENZA e non l''iscrizione: un documento
valido quando ci si e'' iscritti puo'' non esserlo piu'' al momento di partire.';
