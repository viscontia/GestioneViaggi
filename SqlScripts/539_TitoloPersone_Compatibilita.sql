-- =============================================================================
-- 539 — Titolo persone: compatibilita' con chi scrive ancora il testo
-- =============================================================================
-- Lo script 538 ha reso cliente_titolo_fk obbligatoria. Ma ana_clienti non si
-- scrive solo dalla form: ci sono nove function (wizard partecipanti, sp_ana_clienti_*,
-- export, dettaglio) che leggono e scrivono la vecchia cliente_titolo testuale.
-- Riscriverle tutte sarebbe un intervento largo e rischioso su un gestionale in
-- esercizio; peggio, andrebbe fatto in un colpo solo perche' un INSERT senza FK
-- fallirebbe all'istante.
--
-- Qui il DB si fa carico della coerenza: chi scrive il testo ottiene la FK giusta,
-- chi legge il testo lo trova aggiornato, e il sesso lo decide sempre il titolo.
-- La colonna testuale resta uno specchio, non una seconda verita': si elimina dopo
-- la verifica in produzione, insieme a questo pezzo di trigger.
-- =============================================================================

BEGIN;

-- Testo libero -> codice del titolo. Stessa regola della migrazione 538: dove testo e
-- sesso si contraddicono vince il SESSO.
CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_da_testo(
    p_testo VARCHAR,
    p_sesso CHAR
) RETURNS INTEGER
LANGUAGE sql STABLE
AS $$
    SELECT t.titolo_persone_cod
    FROM ana_titolo_persone t
    WHERE t.titolo_persone_descrizione = CASE
        WHEN UPPER(COALESCE(p_testo,'')) LIKE 'DOTT%' THEN CASE WHEN p_sesso = 'F' THEN 'DOTT.SSA' ELSE 'DOTT.' END
        WHEN UPPER(COALESCE(p_testo,'')) LIKE 'PROF%' THEN CASE WHEN p_sesso = 'F' THEN 'PROF.SSA' ELSE 'PROF.' END
        WHEN UPPER(COALESCE(p_testo,'')) LIKE 'AVV%'  THEN CASE WHEN p_sesso = 'F' THEN 'AVV.SSA'  ELSE 'AVV.'  END
        WHEN UPPER(COALESCE(p_testo,'')) LIKE 'ING%'  THEN CASE WHEN p_sesso = 'F' THEN 'ING.RA'   ELSE 'ING.'  END
        ELSE CASE WHEN p_sesso = 'F' THEN 'SIG.RA' ELSE 'SIG.' END
    END;
$$;

COMMENT ON FUNCTION fn_ana_titolo_persone_da_testo(VARCHAR, CHAR) IS
'Ponte di compatibilita'': risolve il codice del titolo dal vecchio testo libero. Da eliminare con la colonna ana_clienti.cliente_titolo.';

CREATE OR REPLACE FUNCTION trg_ana_clienti_sesso_dal_titolo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE v_descrizione VARCHAR;
BEGIN
    -- 1. Chi ha scritto solo il testo (wizard, sp_ana_clienti_*) ottiene comunque la FK.
    IF NEW.cliente_titolo_fk IS NULL THEN
        NEW.cliente_titolo_fk := fn_ana_titolo_persone_da_testo(NEW.cliente_titolo, NEW.cliente_sesso);
    END IF;

    -- 2. Il sesso lo decide il titolo. Sempre, da qualunque strada si arrivi.
    SELECT t.titolo_persone_sesso, t.titolo_persone_descrizione
      INTO NEW.cliente_sesso, v_descrizione
    FROM ana_titolo_persone t
    WHERE t.titolo_persone_cod = NEW.cliente_titolo_fk;

    -- 3. La colonna deprecata resta uno specchio, per chi la legge ancora.
    NEW.cliente_titolo := v_descrizione;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ana_clienti_sesso_dal_titolo ON ana_clienti;
CREATE TRIGGER trg_ana_clienti_sesso_dal_titolo
    BEFORE INSERT OR UPDATE ON ana_clienti
    FOR EACH ROW EXECUTE FUNCTION trg_ana_clienti_sesso_dal_titolo();

-- Riallineo lo specchio sui dati gia' presenti: fino a ieri contenevano SIG/SRA.
UPDATE ana_clienti c
SET cliente_titolo = t.titolo_persone_descrizione
FROM ana_titolo_persone t
WHERE t.titolo_persone_cod = c.cliente_titolo_fk
  AND c.cliente_titolo IS DISTINCT FROM t.titolo_persone_descrizione;

COMMIT;
