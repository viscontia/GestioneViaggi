-- =============================================================================
-- 538 — Tabella ana_titolo_persone + FK da ana_clienti + sesso derivato
-- =============================================================================
-- Il titolo del cliente era testo libero in ana_clienti.cliente_titolo, scelto da
-- una tendina cablata nel dialog. Non funzionava: il normalizzatore forzava il
-- maiuscolo al salvataggio ("Sig." -> "SIG.") e alla riapertura il valore non
-- corrispondeva piu' a nessuna voce, quindi il campo appariva vuoto. I 728 clienti
-- importati da Oracle avevano poi codici ("SIG", "SRA") mai presenti in tendina.
--
-- Qui il titolo diventa una lookup con FK numerica: il maiuscolo non puo' piu'
-- rompere il collegamento. E il sesso del cliente smette di essere un dato a se',
-- inseribile in contraddizione col titolo: lo deriva un trigger.
-- =============================================================================

BEGIN;

-- 1. La tabella ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ana_titolo_persone (
    titolo_persone_cod         INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titolo_persone_descrizione VARCHAR(30)  NOT NULL,
    titolo_persone_sesso       CHAR(1)      NOT NULL
);

ALTER TABLE ana_titolo_persone DROP CONSTRAINT IF EXISTS ana_titolo_persone_sesso_check;
ALTER TABLE ana_titolo_persone
    ADD CONSTRAINT ana_titolo_persone_sesso_check CHECK (titolo_persone_sesso IN ('M','F'));

-- Univocita' sulla descrizione: due "SIG." renderebbero la tendina ambigua.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ana_titolo_persone_descrizione
    ON ana_titolo_persone (UPPER(titolo_persone_descrizione));

COMMENT ON TABLE  ana_titolo_persone IS 'Titoli di cortesia delle persone fisiche. Tabella GLOBALE (nessun azienda_id), come le altre lookup del progetto. Ogni titolo porta il sesso: e'' la sorgente di ana_clienti.cliente_sesso.';
COMMENT ON COLUMN ana_titolo_persone.titolo_persone_sesso IS 'M o F. Solo forme di genere esistenti: niente righe ambigue, altrimenti il sesso derivato sarebbe casuale.';

-- 2. I titoli ------------------------------------------------------------------
INSERT INTO ana_titolo_persone (titolo_persone_descrizione, titolo_persone_sesso)
SELECT d, s FROM (VALUES
    ('SIG.',     'M'),
    ('SIG.RA',   'F'),
    ('DOTT.',    'M'),
    ('DOTT.SSA', 'F'),
    ('PROF.',    'M'),
    ('PROF.SSA', 'F'),
    ('AVV.',     'M'),
    ('AVV.SSA',  'F'),
    ('ING.',     'M'),
    ('ING.RA',   'F')
) AS v(d, s)
WHERE NOT EXISTS (
    SELECT 1 FROM ana_titolo_persone t WHERE UPPER(t.titolo_persone_descrizione) = v.d
);

-- 3. La FK su ana_clienti -------------------------------------------------------
ALTER TABLE ana_clienti ADD COLUMN IF NOT EXISTS cliente_titolo_fk INTEGER;

ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_titolo_fk_fkey;
ALTER TABLE ana_clienti
    ADD CONSTRAINT ana_clienti_titolo_fk_fkey
    FOREIGN KEY (cliente_titolo_fk) REFERENCES ana_titolo_persone(titolo_persone_cod);

CREATE INDEX IF NOT EXISTS idx_ana_clienti_titolo_fk ON ana_clienti (cliente_titolo_fk);

-- 4. Travaso dei dati esistenti -------------------------------------------------
-- Regola decisa il 2026-08-19: dove titolo e sesso si contraddicono (11 clienti con
-- "SIG" ma sesso F) vince il SESSO. "SIG" e' il default dell'import Oracle; il sesso
-- e' stato messo a mano ed e' il dato piu' affidabile.
UPDATE ana_clienti c
SET cliente_titolo_fk = t.titolo_persone_cod
FROM ana_titolo_persone t
WHERE c.cliente_titolo_fk IS NULL
  AND t.titolo_persone_descrizione = CASE
        WHEN UPPER(COALESCE(c.cliente_titolo,'')) LIKE 'DOTT%'
             THEN CASE WHEN c.cliente_sesso = 'F' THEN 'DOTT.SSA' ELSE 'DOTT.' END
        WHEN UPPER(COALESCE(c.cliente_titolo,'')) LIKE 'PROF%'
             THEN CASE WHEN c.cliente_sesso = 'F' THEN 'PROF.SSA' ELSE 'PROF.' END
        WHEN UPPER(COALESCE(c.cliente_titolo,'')) LIKE 'AVV%'
             THEN CASE WHEN c.cliente_sesso = 'F' THEN 'AVV.SSA' ELSE 'AVV.' END
        WHEN UPPER(COALESCE(c.cliente_titolo,'')) LIKE 'ING%'
             THEN CASE WHEN c.cliente_sesso = 'F' THEN 'ING.RA' ELSE 'ING.' END
        -- Tutto il resto (SIG, SRA, SIG., SIG.RA, vuoto) ricade sul titolo generico,
        -- scelto dal sesso: e' la riga che sistema gli 11 incoerenti.
        ELSE CASE WHEN c.cliente_sesso = 'F' THEN 'SIG.RA' ELSE 'SIG.' END
    END;

-- Il titolo e' obbligatorio: e' l'unica sorgente del sesso (decisione del 2026-08-19).
ALTER TABLE ana_clienti ALTER COLUMN cliente_titolo_fk SET NOT NULL;

COMMENT ON COLUMN ana_clienti.cliente_titolo  IS 'DEPRECATO dal 2026-08-19: sostituito da cliente_titolo_fk. Conservato come rete di sicurezza fino alla verifica in produzione, poi si elimina.';
COMMENT ON COLUMN ana_clienti.cliente_titolo_fk IS 'FK a ana_titolo_persone. Determina cliente_sesso via trigger trg_ana_clienti_sesso_dal_titolo.';

-- 5. Il sesso lo decide il titolo ----------------------------------------------
-- Non e' una comodita' dell'interfaccia: e' l'invariante. Messo nel DB perche'
-- ana_clienti si scrive anche dall'import Oracle e da quello Excel, che non
-- passano dalla form.
CREATE OR REPLACE FUNCTION trg_ana_clienti_sesso_dal_titolo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT t.titolo_persone_sesso INTO NEW.cliente_sesso
    FROM ana_titolo_persone t
    WHERE t.titolo_persone_cod = NEW.cliente_titolo_fk;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ana_clienti_sesso_dal_titolo ON ana_clienti;
CREATE TRIGGER trg_ana_clienti_sesso_dal_titolo
    BEFORE INSERT OR UPDATE OF cliente_titolo_fk ON ana_clienti
    FOR EACH ROW EXECUTE FUNCTION trg_ana_clienti_sesso_dal_titolo();

-- 6. CRUD della lookup (DB-First) ----------------------------------------------
CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_list()
RETURNS SETOF ana_titolo_persone
LANGUAGE sql STABLE
AS $$
    SELECT * FROM ana_titolo_persone ORDER BY titolo_persone_descrizione;
$$;

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_get(p_cod INTEGER)
RETURNS SETOF ana_titolo_persone
LANGUAGE sql STABLE
AS $$
    SELECT * FROM ana_titolo_persone WHERE titolo_persone_cod = p_cod;
$$;

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_insert(
    p_descrizione VARCHAR,
    p_sesso       CHAR
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_cod INTEGER;
BEGIN
    INSERT INTO ana_titolo_persone (titolo_persone_descrizione, titolo_persone_sesso)
    VALUES (p_descrizione, p_sesso)
    RETURNING titolo_persone_cod INTO v_cod;
    RETURN v_cod;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_update(
    p_cod         INTEGER,
    p_descrizione VARCHAR,
    p_sesso       CHAR
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_righe INTEGER;
BEGIN
    UPDATE ana_titolo_persone
    SET titolo_persone_descrizione = p_descrizione,
        titolo_persone_sesso       = p_sesso
    WHERE titolo_persone_cod = p_cod;
    GET DIAGNOSTICS v_righe = ROW_COUNT;

    -- Cambiare il sesso di un titolo cambia il sesso di chi lo porta: il trigger su
    -- ana_clienti scatta solo sulle sue UPDATE, quindi qui si riallinea a mano.
    UPDATE ana_clienti
    SET cliente_sesso = p_sesso
    WHERE cliente_titolo_fk = p_cod AND cliente_sesso IS DISTINCT FROM p_sesso;

    RETURN v_righe;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_delete(p_cod INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_righe INTEGER; v_clienti INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_clienti FROM ana_clienti WHERE cliente_titolo_fk = p_cod;
    IF v_clienti > 0 THEN
        RAISE EXCEPTION 'Titolo usato da % client%: non si puo'' eliminare.',
            v_clienti, CASE WHEN v_clienti = 1 THEN 'e' ELSE 'i' END;
    END IF;

    DELETE FROM ana_titolo_persone WHERE titolo_persone_cod = p_cod;
    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe;
END;
$$;

COMMIT;
