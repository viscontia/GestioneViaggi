-- ============================================================================
-- 669 — Le correzioni proposte dal cliente sul sito (L12-bis)
--
-- Chi e' in archivio senza un'email verificata non riceve il codice usa e getta
-- (script 662): puo' completare i campi vuoti, non cambiare quelli pieni. Con un
-- documento scaduto l'iscrizione si fermava su «scrivi all'organizzazione» (prova
-- M8, 2026-09-26). Da qui il cliente puo' PROPORRE i dati nuovi: si conservano a
-- parte, non toccano la scheda, e li approva o scarta Antonio dal gestionale (670).
--
-- Decisioni di Adriano (2026-09-26): si propongono documento e recapiti; Antonio
-- le vede in mail, nella scheda cliente e nel promemoria all'apertura (L2);
-- approvate, al cliente arriva «puoi completare l'iscrizione».
--
-- ⛔️ Una proposta non mostra mai i dati in archivio a chi la fa: chi conosce
-- cognome, nome e nascita di qualcuno puo' al massimo MANDARE una proposta, che un
-- umano legge prima che cambi qualcosa.
--
-- Regole, tutte qui:
--   * solo i campi di fn_web_proposta_campi_ammessi(): documento e recapiti. Nome,
--     cognome, nascita e codice fiscale sono l'identita', e l'email ha L12;
--   * una sola proposta IN_ATTESA per cliente: una nuova sostituisce la vecchia;
--   * al massimo 3 proposte al giorno per cliente;
--   * date e comune si controllano nel formato; la validazione vera (coerenza delle
--     date, documento) la fa fn_ana_clienti_update all'approvazione.
--
-- Solo per il sito Flask e il gestionale (postgres, proprietario): nessun GRANT.
-- Test: Test_669_Web_Proposte_Modifica.sql.
--
-- ✅ Applicato in locale e a PROD il 2026-09-26 (test OK), insieme al sito Flask che manda le proposte.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS web_proposte_modifica (
    proposta_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id       INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    cliente_id       INTEGER      NOT NULL REFERENCES ana_clienti(cliente_id) ON DELETE CASCADE,
    email_proponente VARCHAR(254) NOT NULL,
    dati             JSONB        NOT NULL,
    stato            VARCHAR(12)  NOT NULL DEFAULT 'IN_ATTESA'
                     CHECK (stato IN ('IN_ATTESA', 'APPROVATA', 'SCARTATA', 'SOSTITUITA')),
    creata_il        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    decisa_il        TIMESTAMPTZ,
    decisa_da        VARCHAR(100)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_web_proposte_una_in_attesa
    ON web_proposte_modifica (cliente_id) WHERE stato = 'IN_ATTESA';
CREATE INDEX IF NOT EXISTS ix_web_proposte_azienda_stato
    ON web_proposte_modifica (azienda_id, stato);

ALTER TABLE web_proposte_modifica ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS superadmin_bypass_all ON web_proposte_modifica;
CREATE POLICY superadmin_bypass_all ON web_proposte_modifica TO app_superadmin USING (true) WITH CHECK (true);

-- ⚠️ `authenticated` esiste su Supabase ma non in locale (come nel 662).
DO $$
DECLARE v_ruolo TEXT;
BEGIN
    FOR v_ruolo IN
        SELECT r FROM unnest(ARRAY['anon','authenticated']) r
         WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r)
    LOOP
        EXECUTE format('REVOKE ALL ON web_proposte_modifica FROM %I', v_ruolo);
    END LOOP;
END $$;

COMMENT ON TABLE web_proposte_modifica IS
    'Correzioni di documento e recapiti proposte dal cliente sul sito quando il codice non puo'' arrivargli: non toccano la scheda finche'' il gestionale non le approva (script 669, L12-bis).';

CREATE OR REPLACE FUNCTION fn_web_proposta_campi_ammessi()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path = public, pg_temp
AS $$
    SELECT ARRAY['cliente_tipodoc_identita', 'cliente_documento_numero',
                 'cliente_documento_rilasciato_da', 'cliente_documento_rilasciato_data',
                 'cliente_documento_rilasciato_scadenza',
                 'cliente_preftelint', 'cliente_telefono',
                 'cliente_indirizzo_residenza', 'cliente_comune_residenza_fk'];
$$;

CREATE OR REPLACE FUNCTION fn_web_proposta_crea(
    p_azienda_id integer, p_cliente_id integer, p_email varchar, p_dati jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
DECLARE
    v_dati jsonb;
    v_id   bigint;
    v_oggi integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ana_clienti
                    WHERE cliente_id = p_cliente_id AND azienda_fk = p_azienda_id) THEN
        RAISE EXCEPTION 'Scheda non trovata.' USING ERRCODE = 'check_violation';
    END IF;

    -- Solo i campi ammessi, e solo quelli con un valore.
    SELECT coalesce(jsonb_object_agg(e.k, e.v), '{}'::jsonb) INTO v_dati
      FROM jsonb_each(coalesce(p_dati, '{}'::jsonb)) AS e(k, v)
     WHERE e.k = ANY (fn_web_proposta_campi_ammessi())
       AND nullif(btrim(e.v #>> '{}'), '') IS NOT NULL;
    IF v_dati = '{}'::jsonb THEN
        RAISE EXCEPTION 'La proposta non contiene nessun dato da aggiornare.' USING ERRCODE = 'check_violation';
    END IF;

    -- Il formato di date e comune, con un messaggio leggibile: la validazione vera
    -- la fa fn_ana_clienti_update quando Antonio approva.
    BEGIN
        PERFORM (v_dati ->> 'cliente_documento_rilasciato_data')::date,
                (v_dati ->> 'cliente_documento_rilasciato_scadenza')::date,
                (v_dati ->> 'cliente_comune_residenza_fk')::integer;
    EXCEPTION WHEN others THEN
        RAISE EXCEPTION 'Una data o il comune non sono scritti in modo valido.' USING ERRCODE = 'check_violation';
    END;

    SELECT count(*) INTO v_oggi FROM web_proposte_modifica
     WHERE cliente_id = p_cliente_id AND creata_il > now() - interval '1 day';
    IF v_oggi >= 3 THEN
        RAISE EXCEPTION 'Ci sono già troppe proposte per questa scheda oggi: riprova domani.'
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE web_proposte_modifica
       SET stato = 'SOSTITUITA', decisa_il = now(), decisa_da = 'sito:nuova-proposta'
     WHERE cliente_id = p_cliente_id AND stato = 'IN_ATTESA';

    INSERT INTO web_proposte_modifica (azienda_id, cliente_id, email_proponente, dati)
    VALUES (p_azienda_id, p_cliente_id, btrim(p_email), v_dati)
    RETURNING proposta_id INTO v_id;
    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_web_proposta_crea(integer, integer, varchar, jsonb) IS
    'L12-bis (669): conserva una proposta di correzione dal sito senza toccare la scheda; solo campi ammessi, una in attesa per cliente, 3 al giorno.';

COMMIT;
