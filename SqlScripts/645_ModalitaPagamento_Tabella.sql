-- ============================================================================
-- Modalità di pagamento: la tabella che mancava alla contabilità
--
-- PERCHE'. Oggi la scadenza di un movimento la decide la CAUSALE, con un numero
-- di giorni uguale per tutti («fattura fornitore = 30 giorni»). Ma i giorni non
-- sono una proprietà del tipo di documento: sono un **accordo con quella
-- controparte**. Un fornitore paga a 30 giorni data fattura, un altro a 60 fine
-- mese, l'agenzia vuole la rimessa diretta. Finora andava riscritto a mano ogni
-- volta, e a mano si sbaglia.
--
-- COSA INTRODUCE.
--   1. `ana_modalita_pagamento` — la tabella, per azienda (silos rigidi).
--   2. Una modalità **predefinita su ogni controparte**: si sceglie una volta.
--   3. Una modalità **sul singolo movimento**: la proposta arriva dalla
--      controparte e resta modificabile, perché l'eccezione esiste sempre.
--
-- IL CODICE MNEMONICO. Non esiste uno standard di legge per i TERMINI, ma una
-- convenzione commerciale italiana consolidata: `30DF` = 30 giorni data
-- fattura, `60FM` = 60 giorni fine mese, `RD` = rimessa diretta. È quella che
-- si legge sulle fatture e che si usa a voce, quindi è quella che usiamo.
--
-- ⚠️ Per la FATTURA ELETTRONICA invece lo standard c'è ed è obbligatorio, e la
-- tabella lo porta con sé:
--   * `modpag_sdi_modalita`   — ModalitaPagamento, da MP01 a MP23
--                               (MP01 contanti, MP05 bonifico, MP12 RIBA,
--                                MP08 carta, MP19 SEPA Direct Debit, ...)
--   * `modpag_sdi_condizioni` — CondizioniPagamento: TP01 a rate,
--                               TP02 pagamento completo, TP03 anticipo.
-- Sono i codici che il Sistema di Interscambio pretende nel blocco
-- DatiPagamento. Metterli qui significa che il giorno in cui si genera l'XML
-- non si dovrà indovinarli: sono già accanto al termine che li riguarda.
--
-- COSA NON FA (per scelta, non per dimenticanza). Niente **rate multiple**: il
-- classico «30/60/90» genererebbe tre scadenze, e un movimento ne ha una sola.
-- Mettere il campo senza saperlo calcolare vorrebbe dire scrivere un numero che
-- il programma poi ignora. Se servirà, si affronta quando si affrontano le
-- scadenze multiple.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) La tabella
-- ============================================================================
CREATE TABLE IF NOT EXISTS ana_modalita_pagamento (
    modpag_id             SERIAL PRIMARY KEY,
    azienda_fk            INTEGER NOT NULL REFERENCES ana_aziende(azienda_id),

    -- Il codice che si legge in fattura: 30DF, 60FM, RD, RIBA30...
    modpag_codice         VARCHAR(10)  NOT NULL,
    modpag_descrizione    VARCHAR(100) NOT NULL,

    -- Come si calcola la scadenza a partire dalla data del documento.
    -- giorni = 0 e fine_mese = false significa «subito», cioè rimessa diretta.
    modpag_giorni         INTEGER NOT NULL DEFAULT 0,
    -- ⚠️ Quando è vero i giorni NON si contano dalla data fattura ma dalla
    -- fine del mese in cui cade: «60 FM» su una fattura del 3 marzo scade il
    -- 30 maggio, non il 2 maggio. È la differenza che fa litigare i fornitori.
    modpag_fine_mese      BOOLEAN NOT NULL DEFAULT FALSE,

    -- Fattura elettronica: i codici del Sistema di Interscambio
    modpag_sdi_modalita   VARCHAR(4),
    modpag_sdi_condizioni VARCHAR(4) NOT NULL DEFAULT 'TP02',

    modpag_ordinamento    INTEGER NOT NULL DEFAULT 100,
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,

    created_at            TIMESTAMPTZ DEFAULT now(),
    created_by            VARCHAR(50),
    updated_at            TIMESTAMPTZ,
    updated_by            VARCHAR(50),

    CONSTRAINT uq_modpag_azienda_codice UNIQUE (azienda_fk, modpag_codice),
    CONSTRAINT ck_modpag_codice_maiuscolo CHECK (modpag_codice = UPPER(modpag_codice)),
    CONSTRAINT ck_modpag_giorni CHECK (modpag_giorni BETWEEN 0 AND 365),
    CONSTRAINT ck_modpag_sdi_modalita CHECK (
        modpag_sdi_modalita IS NULL
        OR modpag_sdi_modalita ~ '^MP(0[1-9]|1[0-9]|2[0-3])$'),
    CONSTRAINT ck_modpag_sdi_condizioni CHECK (
        modpag_sdi_condizioni IN ('TP01', 'TP02', 'TP03'))
);

CREATE INDEX IF NOT EXISTS idx_modpag_azienda ON ana_modalita_pagamento(azienda_fk);
CREATE INDEX IF NOT EXISTS idx_modpag_attive  ON ana_modalita_pagamento(azienda_fk, is_active)
    WHERE is_active = TRUE;

COMMENT ON TABLE ana_modalita_pagamento IS
    'Termini e modalità di pagamento per azienda. Il codice è la convenzione commerciale italiana (30DF, 60FM, RD); i due campi sdi portano i codici obbligatori della fattura elettronica (MP01-MP23, TP01-TP03).';
COMMENT ON COLUMN ana_modalita_pagamento.modpag_fine_mese IS
    'Se vero i giorni si contano dalla FINE DEL MESE della data documento, non dalla data stessa.';

-- ============================================================================
-- 2) Il collegamento dalle controparti e dai movimenti
-- ============================================================================
ALTER TABLE ana_controparti
    ADD COLUMN IF NOT EXISTS modalita_pagamento_fk INTEGER
    REFERENCES ana_modalita_pagamento(modpag_id);

COMMENT ON COLUMN ana_controparti.modalita_pagamento_fk IS
    'Modalità di pagamento abituale di questa controparte: è la proposta che compare aprendo un movimento, non un obbligo.';

ALTER TABLE mov_transazioni
    ADD COLUMN IF NOT EXISTS transazione_modalita_pagamento_fk INTEGER
    REFERENCES ana_modalita_pagamento(modpag_id);

COMMENT ON COLUMN mov_transazioni.transazione_modalita_pagamento_fk IS
    'Modalità di pagamento di QUESTO movimento. Parte da quella della controparte e resta modificabile: serve a sapere cosa è stato pattuito davvero, anche quando in seguito l''accordo con la controparte cambia.';

CREATE INDEX IF NOT EXISTS idx_transazioni_modpag
    ON mov_transazioni(transazione_modalita_pagamento_fk)
    WHERE transazione_modalita_pagamento_fk IS NOT NULL;

COMMIT;
