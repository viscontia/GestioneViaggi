-- ============================================================================
-- Le letture del wizard restano dentro la propria azienda
--
-- ⛔️ TROVATO DALLA REVISIONE DEL SITO FLASK (2026-09-26). Tre funzioni del
-- wizard leggevano i clienti per id SENZA filtro per azienda:
--   * fn_wizard_get_client_data(p_cliente_id)
--   * fn_wizard_get_partecipanti_details(p_ids)
--   * fn_wizard_get_partecipanti(p_ids)
-- Il sito dell'azienda 2 ha restituito nome, email, data di nascita e
-- intolleranze del cliente 1163, che e' dell'azienda 6. Il sito sta chiudendo
-- il suo lato (accetta solo id riconosciuti in sessione), ma il confine fra
-- aziende e' una decisione del database, e deve reggere anche se il sito sbaglia.
--
-- STORIA. Le tre funzioni NON nascono in SqlScripts: le ha create il sito Flask
-- (Iscrizione-Viaggi-Offroad PostgreSQL/Documenti PostgreSQL/Migration_Scripts/
-- Add_Cliente_Read_Functions.sql, 2026-03-21; fn_wizard_get_partecipanti con la
-- migrazione dell'endpoint /api/partecipanti). Nel gestionale le citano solo il
-- 583, il 584 e il 626, nei commenti. Da qui in avanti vivono qui.
--
-- LA SCELTA SULLA FIRMA: un parametro p_azienda_id in piu', in seconda
-- posizione come in fn_wizard_leggi_dati_cliente(p_email, p_azienda_id). Il
-- sito passera' azienda_corrente(). Non si legge l'azienda da una variabile di
-- sessione: il sito imposta solo my.app_user, e «il database decide» non puo'
-- dipendere da un'impostazione che chi chiama puo' dimenticare.
-- ⚠️ LA VECCHIA FIRMA SI CANCELLA, non si affianca: lasciarla vorrebbe dire
-- lasciare aperta la stessa porta. Si puo' perche' i chiamanti sono tutti nel
-- sito Flask (verificato il 2026-09-26): il gestionale C# non le usa, e nessuna
-- funzione SQL le chiama.
-- ⛔️ ORDINE DI RILASCIO: questo script e il sito aggiornato vanno insieme. Il
-- sito di oggi chiama le firme vecchie e, dopo il 663, riceve «function does not
-- exist» su riepilogo, email di conferma e /api/partecipanti.
--
-- Il corpo e' quello di prima, copiato dal database, con il solo filtro
-- `AND c.azienda_fk = p_azienda_id` in piu'.
--
-- Permessi: nessun GRANT. Le funzioni nuove nascono chiuse ad anon (script
-- 659); le chiama solo Flask, che si connette come postgres, proprietario.
-- search_path fissato, come da script 655.
--
-- Test: Test_663_Wizard_Partecipanti_Filtro_Azienda.sql (transazione annullata).
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS fn_wizard_get_client_data(integer);
DROP FUNCTION IF EXISTS fn_wizard_get_partecipanti_details(integer[]);
DROP FUNCTION IF EXISTS fn_wizard_get_partecipanti(integer[]);

CREATE OR REPLACE FUNCTION fn_wizard_get_client_data(p_cliente_id integer, p_azienda_id integer)
 RETURNS TABLE(cliente_cognome character varying, cliente_nome character varying, cliente_data_nascita date, cliente_sesso character, comune_codfisc character varying, cliente_intolleranza text)
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cliente_cognome,
        c.cliente_nome,
        c.cliente_data_nascita,
        c.cliente_sesso,
        g.comune_codfisc,
        c.cliente_intolleranza
    FROM ana_clienti c
    LEFT JOIN ana_geo_comuni g ON c.cliente_comune_nascita_fk = g.comune_id
    WHERE c.cliente_id = p_cliente_id
      AND c.azienda_fk = p_azienda_id;
END;
$$;

COMMENT ON FUNCTION fn_wizard_get_client_data(integer, integer) IS
'Restituisce i dati anagrafici di un cliente dato il suo ID, incluso il codice catastale del comune di nascita. Usato per la validazione del codice fiscale. Solo clienti dell''azienda indicata (script 663).';

CREATE OR REPLACE FUNCTION fn_wizard_get_partecipanti_details(p_ids integer[], p_azienda_id integer)
 RETURNS TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying, cliente_email character varying, cliente_data_nascita date, cliente_intolleranza text)
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cliente_id,
        c.cliente_cognome,
        c.cliente_nome,
        c.cliente_email,
        c.cliente_data_nascita,
        c.cliente_intolleranza
    FROM ana_clienti c
    WHERE c.cliente_id = ANY(p_ids)
      AND c.azienda_fk = p_azienda_id;
END;
$$;

COMMENT ON FUNCTION fn_wizard_get_partecipanti_details(integer[], integer) IS
'Restituisce i dettagli (ID, cognome, nome, email, data nascita, intolleranze) per una lista di ID partecipanti. Usato per comporre il riepilogo iscrizione e l''email di conferma. Gli ID di un''altra azienda si ignorano (script 663).';

CREATE OR REPLACE FUNCTION fn_wizard_get_partecipanti(p_ids integer[], p_azienda_id integer)
 RETURNS TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying)
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cliente_id,
        c.cliente_cognome,
        c.cliente_nome
    FROM ana_clienti c
    WHERE c.cliente_id = ANY(p_ids)
      AND c.azienda_fk = p_azienda_id
    ORDER BY c.cliente_cognome, c.cliente_nome;
END;
$$;

COMMENT ON FUNCTION fn_wizard_get_partecipanti(integer[], integer) IS
'Cognome e nome, in ordine alfabetico, per una lista di ID partecipanti (/api/partecipanti del sito). Gli ID di un''altra azienda si ignorano (script 663).';

COMMIT;
