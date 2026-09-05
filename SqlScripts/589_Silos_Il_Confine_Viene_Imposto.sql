-- =============================================================================
-- 589 — Il confine fra aziende smette di essere solo un'intenzione
-- =============================================================================
--
-- Gli script 587 e 588 hanno rimesso a posto i movimenti ereditati da Oracle. Ma
-- ripulire non basta: finche' nessuno impedisce di rifarlo, si rifara'. Le colonne
-- puntano ad `ana_clienti` e basta, e nessun vincolo ha mai guardato a quale azienda
-- appartenessero il cliente e il viaggio — per questo il disallineamento e' rimasto
-- invisibile per anni.
--
-- Da qui in avanti: chi partecipa a un viaggio, chi ne e' indicato come pilota e chi
-- occupa una camera dev'essere un cliente DELL'AZIENDA di quel viaggio.
--
-- ⚠️ Si esegue DOPO 587 e 588. Prima, i dati esistenti lo violerebbero (70 righe in
-- locale, 55 su PROD) e ogni successiva modifica di quelle righe fallirebbe.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_guardia_silo_azienda()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_azienda_viaggio INTEGER;
    v_clienti         INTEGER[];
    r                 RECORD;
BEGIN
    SELECT v.azienda_id INTO v_azienda_viaggio
    FROM ana_viaggi v WHERE v.viaggio_id = NEW.viaggio_id_fk;

    -- I riferimenti al cliente si leggono dalla riga come JSON invece che per nome:
    -- le due tabelle hanno colonne diverse (una coppia contro sei posti letto) e
    -- nominarle direttamente qui costringerebbe a due guardie separate — cioe' due
    -- copie della stessa regola. In PL/pgSQL, poi, `NEW.colonna` viene risolto anche
    -- nel ramo non eseguito: un CASE su TG_TABLE_NAME non basterebbe comunque.
    SELECT array_agg((e.value #>> '{}')::INTEGER)
      INTO v_clienti
    FROM jsonb_each(to_jsonb(NEW)) e
    WHERE e.key IN ('cliente_id_fk', 'cliente_pilota_id_fk',
                    'cliente_id1_fk', 'cliente_id2_fk', 'cliente_id3_fk',
                    'cliente_id4_fk', 'cliente_id5_fk', 'cliente_id6_fk')
      AND e.value <> 'null'::jsonb;

    FOR r IN
        SELECT c.azienda_fk, c.cliente_cognome || ' ' || c.cliente_nome AS nominativo
        FROM ana_clienti c
        WHERE c.cliente_id = ANY (v_clienti)
          AND c.azienda_fk <> v_azienda_viaggio
    LOOP
        RAISE EXCEPTION
            '% è un cliente dell''azienda %, mentre questo viaggio è dell''azienda %. Va prima creata la sua scheda nell''azienda %.',
            r.nominativo, r.azienda_fk, v_azienda_viaggio, v_azienda_viaggio
            USING ERRCODE = 'check_violation';
    END LOOP;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_guardia_silo_azienda() IS
'Rifiuta i movimenti in cui il cliente appartiene a un''azienda diversa da quella del
viaggio. Le aziende sono silos: fino al 2026-09-05 era un''intenzione scritta nei
documenti e in nessun vincolo, e i dati importati da Oracle l''avevano attraversata.';

DROP TRIGGER IF EXISTS trg_silo_azienda ON mov_clienti_viaggi;
CREATE TRIGGER trg_silo_azienda
    BEFORE INSERT OR UPDATE OF viaggio_id_fk, cliente_id_fk, cliente_pilota_id_fk
    ON mov_clienti_viaggi
    FOR EACH ROW EXECUTE FUNCTION fn_guardia_silo_azienda();

DROP TRIGGER IF EXISTS trg_silo_azienda ON mov_clienti_alloggi;
CREATE TRIGGER trg_silo_azienda
    BEFORE INSERT OR UPDATE OF viaggio_id_fk, cliente_id1_fk, cliente_id2_fk,
                               cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk
    ON mov_clienti_alloggi
    FOR EACH ROW EXECUTE FUNCTION fn_guardia_silo_azienda();
