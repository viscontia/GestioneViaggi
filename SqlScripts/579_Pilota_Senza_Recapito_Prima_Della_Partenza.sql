-- =============================================================================
-- 579 — Chi guida e non si riesce a raggiungere
-- =============================================================================
--
-- Trovato il 2026-09-03 provando il controllo pre-stampa: PUGLIESE ALBERTO parte
-- come pilota su ICHNUSA TOUR senza email e senza telefono in anagrafica, e
-- nessuno se ne accorge — perche' il suo documento e' valido fino al 2027, e il
-- controllo guardava soltanto i documenti.
--
-- E' lo stesso problema dei documenti visto da un'altra parte: la regola c'e'
-- gia' (SqlScripts/563: per un pilota prefisso e telefono sono obbligatori), ma
-- vale al salvataggio dell'anagrafica — quindi non tocca i clienti storici, che
-- nessuno ha piu' riaperto da allora. Prima della partenza vanno visti lo stesso:
-- a chi guida si mandano convocazione, variazioni di programma e istruzioni.
--
-- Non entra come nuovo controllo separato ma nella lista che gia' si guarda prima
-- di partire: un secondo elenco da aprire a parte e' un elenco che non si apre.
-- Lo stato SENZA_RECAPITO non impedisce di partire, quindi resta in giallo.
-- =============================================================================

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
    WITH partecipanti AS (
        SELECT cl.cliente_id, cl.cliente_cognome, cl.cliente_nome,
               cl.cliente_email, cl.cliente_preftelint, cl.cliente_telefono,
               cl.cliente_documento_rilasciato_scadenza AS scadenza,
               -- Guida chi e' iscritto come pilota: si legge dal dato del ruolo,
               -- non dalla descrizione.
               COALESCE(tp.tipo_partecipante_pilota, FALSE) AS guida
        FROM mov_clienti_viaggi mcv
        JOIN ana_clienti cl            ON cl.cliente_id = mcv.cliente_id_fk
        LEFT JOIN ana_tipo_partecipante tp
               ON tp.tipo_partecipante_id = mcv.tipo_partecipante_id_fk
        WHERE mcv.data_viaggio_id_fk = p_data_viaggio_id
    ),
    documenti AS (
        SELECT p.cliente_id, p.cliente_cognome, p.cliente_nome, p.cliente_email,
               p.cliente_preftelint, p.cliente_telefono, p.scadenza,
               s.stato, s.messaggio
        FROM partecipanti p
        CROSS JOIN LATERAL fn_documento_stato_per_viaggio(p.scadenza, v_inizio, v_fine) s
        WHERE s.stato <> 'VALIDO'
    ),
    recapiti AS (
        -- Solo chi guida: per un passeggero il recapito puo' mancare di proposito
        -- (spesso e' la moglie o la compagna del pilota, e il contatto e' il suo).
        -- Non si ripete chi e' gia' segnalato per il documento: sarebbe due righe
        -- per la stessa persona, e la telefonata resta una sola.
        SELECT p.cliente_id, p.cliente_cognome, p.cliente_nome, p.cliente_email,
               p.cliente_preftelint, p.cliente_telefono, p.scadenza,
               'SENZA_RECAPITO'::VARCHAR AS stato,
               'Guida senza email né telefono in anagrafica: non c''è modo di avvisarlo.'::TEXT AS messaggio
        FROM partecipanti p
        WHERE p.guida
          AND btrim(COALESCE(p.cliente_email, '')) = ''
          AND btrim(COALESCE(p.cliente_telefono, '')) = ''
          AND p.cliente_id NOT IN (SELECT d.cliente_id FROM documenti d)
    )
    SELECT r.cliente_id, r.cliente_cognome, r.cliente_nome, r.cliente_email,
           r.cliente_preftelint, r.cliente_telefono, r.scadenza,
           r.stato, v_estero, r.messaggio
    FROM (SELECT * FROM documenti UNION ALL SELECT * FROM recapiti) r
    ORDER BY r.cliente_cognome, r.cliente_nome;
END;
$$;

COMMENT ON FUNCTION fn_partecipanti_documento_non_valido(INTEGER) IS
'Partecipanti a una partenza da sistemare prima di partire, con email e telefono per
avvisarli: documento che non arriva valido alla fine del viaggio (MANCANTE, SCADUTO,
SCADE_DURANTE) oppure pilota senza alcun recapito (SENZA_RECAPITO). Interroga la PARTENZA
e non l''iscrizione: un documento valido quando ci si e'' iscritti puo'' non esserlo piu''
al momento di partire.';
