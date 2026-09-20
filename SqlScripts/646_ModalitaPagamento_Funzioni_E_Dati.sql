-- ============================================================================
-- Modalità di pagamento: le funzioni e la tabella precompilata
--
-- Segue il 645. Tre cose:
--   1. le funzioni di lettura e scrittura, con lo stesso stile delle altre
--      tabelle contabili (fn_..._get_all / sp_..._create / _update / _delete);
--   2. un rifiuto della cancellazione che DICE CHI LA STA USANDO, invece del
--      solito «impossibile eliminare»;
--   3. quindici modalità già pronte per ogni azienda, così la tabella non nasce
--      vuota e nessuno deve inventarsi le convenzioni da zero.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Lettura
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_ana_modalita_pagamento_get_all(p_azienda_id INTEGER)
RETURNS SETOF ana_modalita_pagamento
LANGUAGE sql STABLE
AS $$
    SELECT * FROM ana_modalita_pagamento
    WHERE azienda_fk = p_azienda_id
    ORDER BY modpag_ordinamento, modpag_codice;
$$;

CREATE OR REPLACE FUNCTION fn_ana_modalita_pagamento_get_active(p_azienda_id INTEGER)
RETURNS SETOF ana_modalita_pagamento
LANGUAGE sql STABLE
AS $$
    SELECT * FROM ana_modalita_pagamento
    WHERE azienda_fk = p_azienda_id AND is_active = TRUE
    ORDER BY modpag_ordinamento, modpag_codice;
$$;

-- ============================================================================
-- 2) Scrittura
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ana_modalita_pagamento_create(
    p_azienda_fk            INTEGER,
    p_modpag_codice         VARCHAR,
    p_modpag_descrizione    VARCHAR,
    p_modpag_giorni         INTEGER DEFAULT 0,
    p_modpag_fine_mese      BOOLEAN DEFAULT FALSE,
    p_modpag_sdi_modalita   VARCHAR DEFAULT NULL,
    p_modpag_sdi_condizioni VARCHAR DEFAULT 'TP02',
    p_modpag_ordinamento    INTEGER DEFAULT 100,
    p_is_active             BOOLEAN DEFAULT TRUE,
    p_created_by            VARCHAR DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO ana_modalita_pagamento (
        azienda_fk, modpag_codice, modpag_descrizione, modpag_giorni,
        modpag_fine_mese, modpag_sdi_modalita, modpag_sdi_condizioni,
        modpag_ordinamento, is_active, created_by
    ) VALUES (
        p_azienda_fk, UPPER(TRIM(p_modpag_codice)), TRIM(p_modpag_descrizione),
        p_modpag_giorni, p_modpag_fine_mese, p_modpag_sdi_modalita,
        COALESCE(p_modpag_sdi_condizioni, 'TP02'), p_modpag_ordinamento,
        p_is_active, p_created_by
    )
    RETURNING modpag_id INTO v_id;

    RETURN v_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_KEY: Esiste già una modalità con il codice %', UPPER(TRIM(p_modpag_codice));
END;
$$;

CREATE OR REPLACE FUNCTION sp_ana_modalita_pagamento_update(
    p_modpag_id             INTEGER,
    p_modpag_codice         VARCHAR,
    p_modpag_descrizione    VARCHAR,
    p_modpag_giorni         INTEGER DEFAULT 0,
    p_modpag_fine_mese      BOOLEAN DEFAULT FALSE,
    p_modpag_sdi_modalita   VARCHAR DEFAULT NULL,
    p_modpag_sdi_condizioni VARCHAR DEFAULT 'TP02',
    p_modpag_ordinamento    INTEGER DEFAULT 100,
    p_is_active             BOOLEAN DEFAULT TRUE,
    p_updated_by            VARCHAR DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE ana_modalita_pagamento SET
        modpag_codice         = UPPER(TRIM(p_modpag_codice)),
        modpag_descrizione    = TRIM(p_modpag_descrizione),
        modpag_giorni         = p_modpag_giorni,
        modpag_fine_mese      = p_modpag_fine_mese,
        modpag_sdi_modalita   = p_modpag_sdi_modalita,
        modpag_sdi_condizioni = COALESCE(p_modpag_sdi_condizioni, 'TP02'),
        modpag_ordinamento    = p_modpag_ordinamento,
        is_active             = p_is_active,
        updated_at            = now(),
        updated_by            = p_updated_by
    WHERE modpag_id = p_modpag_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Modalità di pagamento % non trovata', p_modpag_id;
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_KEY: Esiste già una modalità con il codice %', UPPER(TRIM(p_modpag_codice));
END;
$$;

-- ⚠️ Il rifiuto spiega. Dire «impossibile eliminare» costringe a cercare a mano
-- chi la sta usando: qui il messaggio porta già i numeri e il primo nome.
CREATE OR REPLACE FUNCTION sp_ana_modalita_pagamento_delete(p_modpag_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_codice       VARCHAR(10);
    v_controparti  INTEGER;
    v_movimenti    INTEGER;
    v_prima        VARCHAR(100);
BEGIN
    SELECT modpag_codice INTO v_codice
    FROM ana_modalita_pagamento WHERE modpag_id = p_modpag_id;

    IF v_codice IS NULL THEN
        RAISE EXCEPTION 'RECORD_NOT_FOUND: Modalità di pagamento % non trovata', p_modpag_id;
    END IF;

    SELECT COUNT(*) INTO v_controparti
    FROM ana_controparti WHERE modalita_pagamento_fk = p_modpag_id;

    SELECT COUNT(*) INTO v_movimenti
    FROM mov_transazioni WHERE transazione_modalita_pagamento_fk = p_modpag_id;

    IF v_movimenti > 0 THEN
        RAISE EXCEPTION 'RECORD_IN_USE: La modalità % è usata da % movimenti contabili e non si può eliminare. Si può disattivarla: resta sui movimenti già registrati e non compare più fra le scelte.',
            v_codice, v_movimenti;
    END IF;

    IF v_controparti > 0 THEN
        SELECT ragione_sociale INTO v_prima
        FROM ana_controparti WHERE modalita_pagamento_fk = p_modpag_id
        ORDER BY ragione_sociale LIMIT 1;

        RAISE EXCEPTION 'RECORD_IN_USE: La modalità % è la predefinita di % controparti (fra cui %). Toglierla da quelle schede, oppure disattivarla.',
            v_codice, v_controparti, v_prima;
    END IF;

    DELETE FROM ana_modalita_pagamento WHERE modpag_id = p_modpag_id;
END;
$$;

COMMIT;

-- ============================================================================
-- 3) Le quindici modalità di partenza, per ogni azienda
--
-- Scelte guardando come si paga davvero in Italia:
--   * RD / CONT / CARTA / ASS coprono l'incasso immediato;
--   * ANTIC e' la caparra alla prenotazione, che per un tour operator e' la
--     regola e non l'eccezione — ed e' l'unica che porta TP03 (anticipo);
--   * i DF contano dalla data fattura, i FM dalla fine del mese: sono le due
--     convenzioni che si leggono su ogni fattura italiana;
--   * RIBA e MAV servono con i fornitori strutturati, SDD per le utenze.
--
-- ⚠️ Idempotente: ON CONFLICT DO NOTHING sul vincolo (azienda, codice), cosi'
-- riapplicarlo non duplica nulla e non tocca le modifiche gia' fatte a mano.
-- ============================================================================
INSERT INTO ana_modalita_pagamento
    (azienda_fk, modpag_codice, modpag_descrizione, modpag_giorni,
     modpag_fine_mese, modpag_sdi_modalita, modpag_sdi_condizioni,
     modpag_ordinamento, created_by)
SELECT a.azienda_id, d.codice, d.descrizione, d.giorni, d.fine_mese,
       d.mp, d.tp, d.ord, 'script 646'
FROM ana_aziende a
CROSS JOIN (VALUES
    ('RD',       'Rimessa diretta (bonifico a vista)',        0, FALSE, 'MP05', 'TP02',  10),
    ('CONT',     'Contanti alla consegna',                    0, FALSE, 'MP01', 'TP02',  20),
    ('CARTA',    'Carta di credito o bancomat',               0, FALSE, 'MP08', 'TP02',  30),
    ('ASS',      'Assegno bancario',                          0, FALSE, 'MP02', 'TP02',  40),
    ('ANTIC',    'Anticipo / caparra alla prenotazione',      0, FALSE, 'MP05', 'TP03',  50),
    ('30DF',     'Bonifico 30 giorni data fattura',          30, FALSE, 'MP05', 'TP02',  60),
    ('60DF',     'Bonifico 60 giorni data fattura',          60, FALSE, 'MP05', 'TP02',  70),
    ('90DF',     'Bonifico 90 giorni data fattura',          90, FALSE, 'MP05', 'TP02',  80),
    ('30FM',     'Bonifico 30 giorni fine mese',             30, TRUE,  'MP05', 'TP02',  90),
    ('60FM',     'Bonifico 60 giorni fine mese',             60, TRUE,  'MP05', 'TP02', 100),
    ('90FM',     'Bonifico 90 giorni fine mese',             90, TRUE,  'MP05', 'TP02', 110),
    ('RIBA30',   'Ricevuta bancaria 30 giorni data fattura', 30, FALSE, 'MP12', 'TP02', 120),
    ('RIBA60FM', 'Ricevuta bancaria 60 giorni fine mese',    60, TRUE,  'MP12', 'TP02', 130),
    ('MAV',      'Pagamento con MAV 30 giorni',              30, FALSE, 'MP13', 'TP02', 140),
    ('SDD',      'Addebito diretto SEPA (SDD)',               0, FALSE, 'MP19', 'TP02', 150)
) AS d(codice, descrizione, giorni, fine_mese, mp, tp, ord)
ON CONFLICT (azienda_fk, modpag_codice) DO NOTHING;

-- ============================================================================
-- Verifica:
--   SELECT azienda_fk, count(*) FROM ana_modalita_pagamento GROUP BY 1;
--   SELECT modpag_codice, modpag_descrizione, modpag_giorni, modpag_fine_mese,
--          modpag_sdi_modalita
--     FROM fn_ana_modalita_pagamento_get_active(2);
-- ============================================================================
