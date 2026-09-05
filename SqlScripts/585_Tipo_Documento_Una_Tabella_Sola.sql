-- =============================================================================
-- 585 — Il tipo di documento diventa una tabella, e i codici tornano tre
-- =============================================================================
--
-- Trovato il 2026-09-05 provando l'iscrizione di ARRIGONI FLAVIO: il sito
-- avvisava che «manca il TIPO DOCUMENTO» su un cliente che ce l'ha (`CID`, con
-- numero ed ente). Il database infatti non segnalava nulla: l'avviso era del
-- sito, che quel codice non lo conosce.
--
-- Guardando meglio, gli elenchi erano TRE, tutti scritti a mano e tutti diversi:
--
--   gestionale (nel markup)  CI · Passaporto · Patente     ← parole intere!
--   sito (in Python)         CI · PAS · PAT
--   dati reali su PROD       CID (144) · CI (38) · PAT (17) · PAS (7) · PASSAPORTO (1)
--
-- Nessuno dei due software conosce `CID`, che e' il codice piu' diffuso: 144
-- clienti su 207 con documento. E il gestionale, salvando «Passaporto» per
-- esteso, non si limita a non leggere i dati storici — ne CREA di nuovi in una
-- forma che nessun altro riconosce. Il valore `PASSAPORTO` su PROD viene da li'.
--
-- Cinque codici per tre documenti: `CID` e `CI` sono la stessa carta d'identita',
-- `PAS` e `PASSAPORTO` lo stesso passaporto. Si normalizzano.
-- =============================================================================

CREATE TABLE IF NOT EXISTS ana_tipo_documento (
    tipo_doc_codice      VARCHAR(10)  PRIMARY KEY,
    tipo_doc_descrizione VARCHAR(60)  NOT NULL,
    tipo_doc_ordine      SMALLINT     NOT NULL DEFAULT 99,
    tipo_doc_attivo      BOOLEAN      NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE ana_tipo_documento IS
'I documenti di identita'' ammessi. Unica fonte per il gestionale e per il sito di
iscrizione: prima erano tre elenchi scritti a mano, che non coincidevano.';

INSERT INTO ana_tipo_documento (tipo_doc_codice, tipo_doc_descrizione, tipo_doc_ordine) VALUES
    -- L'ordine e' quello in cui si incontrano nella realta': la carta d'identita'
    -- e' il documento della grande maggioranza.
    ('CI',  'Carta d''identità', 1),
    ('PAS', 'Passaporto',        2),
    ('PAT', 'Patente',           3)
ON CONFLICT (tipo_doc_codice) DO UPDATE
    SET tipo_doc_descrizione = EXCLUDED.tipo_doc_descrizione,
        tipo_doc_ordine      = EXCLUDED.tipo_doc_ordine;


-- ---------------------------------------------------------------------------
-- I dati esistenti: cinque codici tornano tre
-- ---------------------------------------------------------------------------
-- `CID` e `CI` sono la stessa cosa, e cosi' `PASSAPORTO` e `PAS`. Si tiene la
-- sigla breve, che e' quella gia' prevalente fra i codici "puliti" e quella che
-- entrambi i software useranno d'ora in poi.
--
-- ⚠️ Su PROD questo UPDATE tocca circa 145 righe (144 CID + 1 PASSAPORTO).
-- Non si perde nessuna informazione: cambia la scrittura, non il documento.
UPDATE ana_clienti SET cliente_tipodoc_identita = 'CI'
 WHERE upper(btrim(cliente_tipodoc_identita)) IN ('CID', 'C.I.', 'CARTA IDENTITA', 'CARTA D''IDENTITA');

UPDATE ana_clienti SET cliente_tipodoc_identita = 'PAS'
 WHERE upper(btrim(cliente_tipodoc_identita)) IN ('PASSAPORTO', 'PASSPORT');

UPDATE ana_clienti SET cliente_tipodoc_identita = 'PAT'
 WHERE upper(btrim(cliente_tipodoc_identita)) IN ('PATENTE', 'PATENTE DI GUIDA');

-- Gli spazi non contano come contenuto.
UPDATE ana_clienti SET cliente_tipodoc_identita = btrim(cliente_tipodoc_identita)
 WHERE cliente_tipodoc_identita <> btrim(cliente_tipodoc_identita);


-- ---------------------------------------------------------------------------
-- La lettura, per tutti e due i software
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_tipo_documento_get_all()
RETURNS TABLE(codice VARCHAR, descrizione VARCHAR)
LANGUAGE sql
STABLE
AS $$
    SELECT t.tipo_doc_codice, t.tipo_doc_descrizione
    FROM ana_tipo_documento t
    WHERE t.tipo_doc_attivo
    ORDER BY t.tipo_doc_ordine, t.tipo_doc_descrizione;
$$;

COMMENT ON FUNCTION fn_ana_tipo_documento_get_all() IS
'I tipi di documento selezionabili. Unica fonte: il gestionale e il sito leggono questa,
e non possono piu'' proporre elenchi diversi.';
