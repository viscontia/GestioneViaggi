-- =============================================================================
-- 574 — Chi parte con un documento che non arriva alla fine del viaggio
-- =============================================================================
--
-- Trovato il 2026-09-02 ragionando su un difetto del sito: nessuno, da nessuna
-- parte, controlla che il documento di un partecipante sia valido **alla data del
-- viaggio**. Le conseguenze non sono informatiche: all'estero non si parte
-- affatto, e in Italia l'albergo puo' rifiutare la registrazione — dove i
-- documenti di tutti gli occupanti si presentano per legge (vedi script 563).
--
-- Due precisazioni che cambiano il controllo:
--
--   1. Non conta «scaduto oggi», conta «scaduto alla FINE del viaggio». Un
--      documento che scade il 20 ottobre e' perfettamente valido adesso, e non
--      serve a niente per una partenza che rientra il 24.
--
--   2. Non basta controllare all'iscrizione. Ci si iscrive mesi prima: un
--      documento valido a giugno puo' essere scaduto a ottobre. Per questo la
--      funzione interroga una PARTENZA, non un'iscrizione: cosi' la stessa
--      risposta serve al momento dell'iscrizione, alla lista dei partecipanti e
--      alle stampe, e dice sempre la verita' del giorno in cui la si chiede.
--
-- Restituisce anche email e telefono perche' chi la usa deve poter avvisare la
-- persona, non solo sapere che c'e' un problema.
-- =============================================================================

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
    stato VARCHAR,        -- MANCANTE | SCADUTO | SCADE_DURANTE
    viaggio_estero BOOLEAN,
    messaggio TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_inizio  DATE;
    v_fine    DATE;
    v_estero  BOOLEAN;
BEGIN
    SELECT d.data_viaggio_data_inizio,
           d.data_viaggio_data_fine,
           -- Estero: qualunque nazione diversa dall'Italia. Con nazione non
           -- indicata si assume estero, perche' e' il caso piu' severo e non si
           -- tira a indovinare sui documenti di chi parte.
           COALESCE(c.iso_alpha2, 'XX') <> 'IT'
      INTO v_inizio, v_fine, v_estero
    FROM ana_date_viaggi d
    JOIN ana_viaggi v      ON v.viaggio_id = d.viaggio_id_fk
    LEFT JOIN eba_countries c ON c.country_id = v.viaggio_nazione_fk
    WHERE d.data_viaggio_id = p_data_viaggio_id;

    IF v_inizio IS NULL THEN
        RETURN;   -- partenza inesistente: niente da dire
    END IF;

    RETURN QUERY
    SELECT cl.cliente_id,
           cl.cliente_cognome,
           cl.cliente_nome,
           cl.cliente_email,
           cl.cliente_preftelint,
           cl.cliente_telefono,
           cl.cliente_documento_rilasciato_scadenza,
           CASE
               WHEN cl.cliente_documento_rilasciato_scadenza IS NULL THEN 'MANCANTE'
               WHEN cl.cliente_documento_rilasciato_scadenza < v_inizio THEN 'SCADUTO'
               ELSE 'SCADE_DURANTE'
           END::VARCHAR,
           v_estero,
           CASE
               WHEN cl.cliente_documento_rilasciato_scadenza IS NULL THEN
                    'Nessuna data di scadenza del documento in anagrafica.'
               WHEN cl.cliente_documento_rilasciato_scadenza < v_inizio THEN
                    format('Documento scaduto il %s, prima della partenza del %s.',
                           to_char(cl.cliente_documento_rilasciato_scadenza, 'DD/MM/YYYY'),
                           to_char(v_inizio, 'DD/MM/YYYY'))
               ELSE
                    format('Documento in scadenza il %s, durante il viaggio (rientro il %s).',
                           to_char(cl.cliente_documento_rilasciato_scadenza, 'DD/MM/YYYY'),
                           to_char(v_fine, 'DD/MM/YYYY'))
           END::TEXT
    FROM mov_clienti_viaggi mcv
    JOIN ana_clienti cl ON cl.cliente_id = mcv.cliente_id_fk
    WHERE mcv.data_viaggio_id_fk = p_data_viaggio_id
      -- Non valido se manca la data, o se non arriva alla fine del viaggio.
      AND (cl.cliente_documento_rilasciato_scadenza IS NULL
           OR cl.cliente_documento_rilasciato_scadenza <= v_fine)
    ORDER BY cl.cliente_cognome, cl.cliente_nome;
END;
$$;

COMMENT ON FUNCTION fn_partecipanti_documento_non_valido(INTEGER) IS
'Partecipanti a una partenza il cui documento non arriva valido alla fine del viaggio:
mancante, gia'' scaduto, o in scadenza durante il viaggio. Con email e telefono per poterli
avvisare, e il flag viaggio_estero perche'' all''estero non si parte affatto. Interroga la
PARTENZA e non l''iscrizione: un documento valido quando ci si e'' iscritti puo'' non esserlo
piu'' al momento di partire.';
