-- ============================================================================
-- 670 — Leggere, approvare e scartare le proposte del sito (L12-bis)
--
-- Seconda meta' del 669: il gestionale mostra ad Antonio la proposta accanto ai
-- valori in archivio, e la approva o la scarta. Solo l'approvazione cambia la
-- scheda, e passa dalla stessa strada del gestionale (fn_ana_clienti_update): se i
-- dati non tornano (una scadenza prima del rilascio, per dire) l'approvazione si
-- ferma con il messaggio della validazione, e niente cambia.
--
--   fn_web_proposta_del_cliente(cliente, azienda)  → una riga per campo proposto
--   fn_web_proposte_in_attesa(azienda)             → per il promemoria (L2)
--   fn_web_proposta_approva(id, azienda, utente)   → email e nome per la mail
--   fn_web_proposta_scarta(id, azienda, utente)    → true se c'era da scartare
--
-- Solo per il gestionale (postgres, proprietario): nessun GRANT.
-- Test: Test_670_Web_Proposte_Decisione.sql.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_proposta_del_cliente(p_cliente_id integer, p_azienda_id integer)
 RETURNS TABLE(proposta_id bigint, creata_il timestamptz, email_proponente varchar,
               campo text, etichetta text, in_archivio text, proposto text)
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    WITH p AS (
        SELECT w.* FROM web_proposte_modifica w
          JOIN ana_clienti c ON c.cliente_id = w.cliente_id AND c.azienda_fk = p_azienda_id
         WHERE w.cliente_id = p_cliente_id AND w.azienda_id = p_azienda_id AND w.stato = 'IN_ATTESA'
    ),
    etichette(ordine, campo, etichetta) AS (VALUES
        (1, 'cliente_tipodoc_identita',              'Tipo di documento'),
        (2, 'cliente_documento_numero',              'Numero del documento'),
        (3, 'cliente_documento_rilasciato_da',       'Rilasciato da'),
        (4, 'cliente_documento_rilasciato_data',     'Data di rilascio'),
        (5, 'cliente_documento_rilasciato_scadenza', 'Scadenza del documento'),
        (6, 'cliente_preftelint',                    'Prefisso internazionale'),
        (7, 'cliente_telefono',                      'Telefono'),
        (8, 'cliente_indirizzo_residenza',           'Indirizzo di residenza'),
        (9, 'cliente_comune_residenza_fk',           'Comune di residenza')
    ),
    -- Per chi legge: descrizioni al posto dei codici, date all'italiana.
    leggibile AS (
        SELECT p.proposta_id, p.creata_il, p.email_proponente, e.ordine, e.campo, e.etichetta,
               CASE e.campo
                   WHEN 'cliente_tipodoc_identita' THEN
                       coalesce((SELECT t.tipo_doc_descrizione FROM ana_tipo_documento t WHERE t.tipo_doc_codice = c.cliente_tipodoc_identita), c.cliente_tipodoc_identita)
                   WHEN 'cliente_comune_residenza_fk' THEN
                       (SELECT g.comune_descrizione FROM ana_geo_comuni g WHERE g.comune_id = c.cliente_comune_residenza_fk)
                   WHEN 'cliente_documento_rilasciato_data' THEN to_char(c.cliente_documento_rilasciato_data, 'DD/MM/YYYY')
                   WHEN 'cliente_documento_rilasciato_scadenza' THEN to_char(c.cliente_documento_rilasciato_scadenza, 'DD/MM/YYYY')
                   ELSE to_jsonb(c) ->> e.campo
               END AS in_archivio,
               CASE e.campo
                   WHEN 'cliente_tipodoc_identita' THEN
                       coalesce((SELECT t.tipo_doc_descrizione FROM ana_tipo_documento t WHERE t.tipo_doc_codice = p.dati ->> e.campo), p.dati ->> e.campo)
                   WHEN 'cliente_comune_residenza_fk' THEN
                       (SELECT g.comune_descrizione FROM ana_geo_comuni g WHERE g.comune_id = (p.dati ->> e.campo)::integer)
                   WHEN 'cliente_documento_rilasciato_data' THEN to_char((p.dati ->> e.campo)::date, 'DD/MM/YYYY')
                   WHEN 'cliente_documento_rilasciato_scadenza' THEN to_char((p.dati ->> e.campo)::date, 'DD/MM/YYYY')
                   ELSE p.dati ->> e.campo
               END AS proposto
          FROM p
          JOIN ana_clienti c ON c.cliente_id = p.cliente_id
          JOIN etichette e ON p.dati ? e.campo
    )
    SELECT proposta_id, creata_il, email_proponente, campo, etichetta, in_archivio, proposto
      FROM leggibile ORDER BY ordine;
$$;

CREATE OR REPLACE FUNCTION fn_web_proposte_in_attesa(p_azienda_id integer)
 RETURNS TABLE(proposta_id bigint, cliente_id integer, cognome varchar, nome varchar, creata_il timestamptz)
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    SELECT w.proposta_id, c.cliente_id, c.cliente_cognome, c.cliente_nome, w.creata_il
      FROM web_proposte_modifica w
      JOIN ana_clienti c ON c.cliente_id = w.cliente_id AND c.azienda_fk = p_azienda_id
     WHERE w.azienda_id = p_azienda_id AND w.stato = 'IN_ATTESA'
     ORDER BY w.creata_il;
$$;

CREATE OR REPLACE FUNCTION fn_web_proposta_approva(p_proposta_id bigint, p_azienda_id integer, p_utente varchar)
 RETURNS TABLE(email varchar, cognome varchar, nome varchar)
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
DECLARE r RECORD;
BEGIN
    SELECT w.* INTO r FROM web_proposte_modifica w
     WHERE w.proposta_id = p_proposta_id AND w.azienda_id = p_azienda_id AND w.stato = 'IN_ATTESA'
     FOR UPDATE;
    IF r.proposta_id IS NULL THEN
        RAISE EXCEPTION 'La proposta non c''è più o è già stata decisa.' USING ERRCODE = 'check_violation';
    END IF;

    -- Chi approva firma la modifica (trigger di audit su ana_clienti).
    PERFORM set_config('my.app_user', coalesce(nullif(btrim(p_utente), ''), 'gestionale'), true);
    -- La stessa scrittura del gestionale, con la sua validazione: se solleva,
    -- l'errore risale e la transazione non cambia niente.
    PERFORM fn_ana_clienti_update(r.cliente_id, r.dati, false);

    UPDATE web_proposte_modifica
       SET stato = 'APPROVATA', decisa_il = now(), decisa_da = p_utente
     WHERE proposta_id = r.proposta_id;

    RETURN QUERY
    SELECT r.email_proponente, c.cliente_cognome, c.cliente_nome
      FROM ana_clienti c WHERE c.cliente_id = r.cliente_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_web_proposta_scarta(p_proposta_id bigint, p_azienda_id integer, p_utente varchar)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
DECLARE v_righe integer;
BEGIN
    UPDATE web_proposte_modifica
       SET stato = 'SCARTATA', decisa_il = now(), decisa_da = p_utente
     WHERE proposta_id = p_proposta_id AND azienda_id = p_azienda_id AND stato = 'IN_ATTESA';
    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe > 0;
END;
$$;

COMMIT;
