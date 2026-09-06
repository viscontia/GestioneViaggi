-- =============================================================================
-- 602 — Una sistemazione dev'essere di un genere che il viaggio prevede
-- =============================================================================
--
-- Chiude il caso aperto il 2026-09-06: `fn_alloggi_assegnazione_valida` segnala
-- l'incoerenza, ma nessun vincolo la impedisce. Scrivendo direttamente nel database
-- — un'importazione, una correzione a mano, il prossimo software che si collega —
-- si puo' ancora assegnare una camera d'albergo a un viaggio in tenda.
--
-- ⚠️ E' successo davvero: su PROD ci sono **17 assegnazioni incoerenti**, camere
-- d'albergo su viaggi con pernottamento `NESSUNO`. Sono **tutte nell'azienda 6**;
-- SFT (azienda 2) ne ha zero.
--
-- -----------------------------------------------------------------------------
-- COSA SI CONTROLLA, E COSA NO
-- -----------------------------------------------------------------------------
-- ✅ **Il genere**: che il tipo assegnato sia fra quelli che il viaggio prevede.
--    E' un fatto sul viaggio — o ha alberghi o non li ha — e non ha eccezioni.
--
-- ⛔️ **La capienza NO.** Sarebbe stato naturale aggiungerla, ed e' sbagliato:
--    Antonio ha spiegato il 2026-09-06 che quelle sei doppie con un occupante solo
--    sono reali — «quell'albergo non offriva camere singole, e succede spesso».
--    Una regola rigida sulla capienza rifiuterebbe una situazione vera, costringendo
--    chi lavora ad annotarla altrove: e' il modo in cui i dati escono dal sistema.
--    La capienza resta un rilievo di `fn_alloggi_assegnazione_valida`, che blocca
--    l'interfaccia ma non la mano di chi sa cosa sta facendo.
--
-- ⚠️ Il trigger vale su INSERT e UPDATE: le righe storiche restano come sono, ma
-- toccarne una incoerente la fara' rifiutare. E' voluto — chi la modifica e' anche
-- chi puo' correggerla — ma va saputo prima, non scoperto.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_guardia_alloggio_coerente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_genere      INTEGER;
    v_codice      VARCHAR;
    v_tipo_desc   VARCHAR;
    v_pern_fk     INTEGER;
    v_pern_desc   VARCHAR;
    v_ammessi     TEXT;
BEGIN
    SELECT t.genere_fk, g.genere_codice, t.tipo_alloggio_descrizione
      INTO v_genere, v_codice, v_tipo_desc
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE t.tipo_alloggio_id = NEW.tipo_alloggio_id_fk;

    -- Tipo sconosciuto: non e' questa guardia a doverlo dire, ci pensa la chiave esterna.
    IF v_genere IS NULL THEN
        RETURN NEW;
    END IF;

    -- «Nessuna sistemazione» vale sempre, su qualunque viaggio: chi dorme nel proprio
    -- mezzo o si ferma da parenti esiste ovunque, e non si configura.
    IF v_codice = 'NESSUNA' THEN
        RETURN NEW;
    END IF;

    SELECT v.viaggio_tipo_pernottamento_fk, p.ana_tipo_pernottamento_descrizione
      INTO v_pern_fk, v_pern_desc
    FROM ana_viaggi v
    LEFT JOIN ana_tipo_pernottamento p ON p.ana_tipo_pernottamento_id = v.viaggio_tipo_pernottamento_fk
    WHERE v.viaggio_id = NEW.viaggio_id_fk;

    IF EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
               WHERE pg.pernottamento_fk = v_pern_fk AND pg.genere_fk = v_genere) THEN
        RETURN NEW;
    END IF;

    SELECT string_agg(g.genere_descrizione, ', ' ORDER BY g.genere_ordine)
      INTO v_ammessi
    FROM ana_tipo_pernottamento_generi pg
    JOIN ana_alloggio_generi g ON g.genere_id = pg.genere_fk
    WHERE pg.pernottamento_fk = v_pern_fk;

    RAISE EXCEPTION
        '«%» non e'' una sistemazione prevista da questo viaggio (pernottamento: %). Ammesse: %.',
        v_tipo_desc,
        COALESCE(v_pern_desc, 'non indicato'),
        COALESCE(v_ammessi, 'nessuna, oltre a «nessuna sistemazione»')
        USING ERRCODE = 'check_violation';
END;
$$;

COMMENT ON FUNCTION fn_guardia_alloggio_coerente() IS
'Rifiuta le sistemazioni di un genere che il viaggio non prevede: una tenda su un viaggio in
albergo, una camera su uno in campo tendato. ⚠️ NON controlla la capienza — una doppia con
un occupante solo e'' una situazione reale quando l''albergo non ha singole.';

DROP TRIGGER IF EXISTS trg_alloggio_coerente ON mov_clienti_alloggi;
CREATE TRIGGER trg_alloggio_coerente
    BEFORE INSERT OR UPDATE OF viaggio_id_fk, tipo_alloggio_id_fk
    ON mov_clienti_alloggi
    FOR EACH ROW EXECUTE FUNCTION fn_guardia_alloggio_coerente();
