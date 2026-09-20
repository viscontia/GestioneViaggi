-- ============================================================================
-- Firme duplicate: tredici mine disinnescate, e una guardia per il futuro
--
-- IL PROBLEMA, già visto. Lo script 638 ha dovuto eliminare tre firme morte
-- delle funzioni del bilancio perché le stampe rispondevano
-- «function ... is not unique» e NON PARTIVANO PIÙ. Quel difetto non era un
-- caso isolato: era un sintomo. Ogni volta che una funzione viene ricreata con
-- un parametro in più, Postgres **non sostituisce** la vecchia — ne tiene due.
-- Finché la chiamata usa tutti i parametri va bene; il giorno in cui qualcuno
-- ne omette uno che ha un valore predefinito, entrambe diventano candidate e il
-- database si rifiuta di scegliere.
--
-- IL CENSIMENTO. Cercate tutte le funzioni nostre con più di una firma: sono
-- quindici. Di queste, tredici sono versioni successive della stessa cosa, dove
-- la vecchia è semplicemente rimasta indietro.
--
-- ⛔️ DUE MERITANO UNA RIGA A PARTE.
--
--   1. `reset_password_with_token` esisteva in due versioni con lo STESSO numero
--      di parametri: `(varchar, text)` che fa `crypt()` sulla password, e
--      `(varchar, varchar)` che scrive nel campo `password_hash` **quello che
--      riceve**. Se una chiamata fosse finita sulla seconda, la password
--      sarebbe stata salvata IN CHIARO e l'accesso non avrebbe più funzionato.
--      Oggi non succede solo perché il C# scrive `@NewPassword::text`.
--   2. `sp_app_delete_role` aveva due firme da un parametro, `text` e
--      `varchar`: ambiguità pura, risolta oggi solo perché Npgsql manda `text`.
--
-- COME SI È SCELTO COSA TENERE. Non a occhio: per ognuna si è cercata la
-- chiamata vera — nel gestionale, nel sito Flask, o dentro un'altra funzione —
-- e si è tenuta la firma che quella chiamata usa. Le vecchie sono coperte dalle
-- nuove, che hanno un valore predefinito per i parametri aggiunti.
--
-- ℹ️ DUE CASI LASCIATI APPOSTA, e non è una dimenticanza:
--   * `fn_get_tasso_cambio` ha `(varchar, varchar, date)` e `(int, int, date)`:
--     tipi diversi e incompatibili fra loro, quindi Postgres sa sempre quale
--     scegliere. Non è una mina, è un vero overload.
--   * `fn_superadmin_get_all_companies` ha una versione senza parametri e una
--     con `(uuid, varchar)`: nessuna chiamata a nessuna delle due, nemmeno nel
--     sito. Non è ambigua (la seconda ha un parametro obbligatorio) e non si sa
--     quale sia quella buona: sceglierne una al buio sarebbe peggio.
--
-- ⚠️ Non cambia il comportamento di nulla: ogni chiamata in essere continua a
-- risolversi sulla stessa funzione di prima. Si toglie solo ciò che poteva farla
-- risolvere altrove.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Le due bombe: password in chiaro e ruolo ambiguo
-- ============================================================================
DROP FUNCTION IF EXISTS reset_password_with_token(p_token character varying, p_new_password_hash character varying);
DROP PROCEDURE IF EXISTS sp_app_delete_role(IN p_role_code character varying);

-- ============================================================================
-- 2) Causali contabili — la famiglia che ha gia' rotto le stampe (638)
--    Si tiene la firma a 17 e 16 parametri, quella con p_tipo_documento_sdi.
-- ============================================================================
DROP FUNCTION IF EXISTS sp_ana_tipi_causali_create(p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_created_by character varying, p_updated_by character varying);
DROP FUNCTION IF EXISTS sp_ana_tipi_causali_create(p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_created_by character varying, p_updated_by character varying, p_causale_concorre_fatturato boolean);

DROP FUNCTION IF EXISTS sp_ana_tipi_causali_update(p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_updated_by character varying);
DROP FUNCTION IF EXISTS sp_ana_tipi_causali_update(p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_updated_by character varying, p_causale_concorre_fatturato boolean);

-- ============================================================================
-- 3) Stampe dei movimenti — si tiene la firma con p_causale_ciclo (22 parametri),
--    quella che fn_get_mov_transazioni_print_data chiama davvero.
-- ============================================================================
DROP FUNCTION IF EXISTS fn_get_transazioni_stampa_dettaglio(p_azienda_id integer, p_controparte_id integer, p_causale_tipo_id integer, p_stati character varying[], p_viaggio_id integer, p_data_viaggio_id integer, p_valuta_id integer, p_data_transazione_da date, p_data_transazione_a date, p_data_documento_da date, p_data_documento_a date, p_importo_da numeric, p_importo_a numeric, p_numero_documento character varying, p_solo_con_documento boolean, p_solo_scadute boolean, p_solo_con_viaggio boolean, p_solo_senza_viaggio boolean, p_solo_con_fattura boolean, p_ordinamento character varying, p_valuta_target_id integer);
DROP FUNCTION IF EXISTS fn_get_transazioni_stampa_subtotali(p_azienda_id integer, p_controparte_id integer, p_causale_tipo_id integer, p_stati character varying[], p_viaggio_id integer, p_data_viaggio_id integer, p_valuta_id integer, p_data_transazione_da date, p_data_transazione_a date, p_data_documento_da date, p_data_documento_a date, p_importo_da numeric, p_importo_a numeric, p_numero_documento character varying, p_solo_con_documento boolean, p_solo_scadute boolean, p_solo_con_viaggio boolean, p_solo_senza_viaggio boolean, p_solo_con_fattura boolean, p_ordinamento character varying, p_valuta_target_id integer);

-- ============================================================================
-- 4) Utenti e ruoli — sono PROCEDURE, si eliminano con DROP PROCEDURE.
--    Si tengono: create_user a 8 parametri, update_user a 10, i ruoli a 3.
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_app_create_user(IN p_email text, IN p_password text, IN p_nome text, IN p_cognome text, IN p_role_code text, IN p_azienda_id integer);
DROP PROCEDURE IF EXISTS sp_app_create_user(IN p_email text, IN p_password text, IN p_nome text, IN p_cognome text, IN p_role_code text, IN p_azienda_id integer, IN p_data_nascita date);
DROP PROCEDURE IF EXISTS sp_app_update_user(IN p_user_id uuid, IN p_email text, IN p_password text, IN p_nome text, IN p_cognome text, IN p_role_code text, IN p_azienda_id integer, IN p_is_active boolean);
DROP PROCEDURE IF EXISTS sp_app_update_user(IN p_user_id uuid, IN p_email text, IN p_password text, IN p_nome text, IN p_cognome text, IN p_role_code text, IN p_azienda_id integer, IN p_is_active boolean, IN p_data_nascita date);
DROP PROCEDURE IF EXISTS sp_app_create_role(IN p_role_code character varying, IN p_role_name character varying);
DROP PROCEDURE IF EXISTS sp_app_update_role(IN p_role_code character varying, IN p_role_name character varying);

-- ============================================================================
-- 5) Le rimanenti
--    * verifica_duplicato: si tiene quella con p_email, l'unica che il
--      gestionale E il sito Flask chiamano (otto parametri da entrambe le parti);
--    * monthly_trend: si tiene quella con p_date_column;
--    * fn_app_login: nessuno la chiama piu' (il gestionale usa
--      fn_app_login_text), ma le due firme restavano ambigue con due argomenti.
--      Si tiene la piu' completa, che ha i valori predefiniti per ip e browser.
-- ============================================================================
DROP FUNCTION IF EXISTS fn_ana_clienti_verifica_duplicato(p_azienda_id integer, p_cognome character varying, p_nome character varying, p_data_nascita date, p_comune_nascita_id integer, p_cf character varying, p_escludi_cliente_id integer);
DROP FUNCTION IF EXISTS fn_get_monthly_trend(p_table_name text, p_year integer, p_azienda_id integer);
DROP FUNCTION IF EXISTS fn_app_login(p_email citext, p_password text);

COMMIT;

-- ============================================================================
-- 6) La guardia: perche' non serva rifare l'indagine da capo
--
-- Elenca le funzioni NOSTRE che hanno piu' di una firma. Le funzioni delle
-- estensioni (pgcrypto, citext) sono escluse: ne hanno per mestiere.
-- Da lanciare dopo ogni giro di script, e prima di un rilascio.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_check_firme_duplicate()
RETURNS TABLE(funzione TEXT, firme BIGINT, dettaglio TEXT)
LANGUAGE sql STABLE
AS $$
    SELECT p.proname::TEXT,
           count(*),
           string_agg(pg_get_function_identity_arguments(p.oid), E'\n  | ' ORDER BY p.pronargs)
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      -- Fuori tutto cio' che appartiene a un'estensione installata
      AND NOT EXISTS (
          SELECT 1 FROM pg_depend d
          WHERE d.objid = p.oid AND d.deptype = 'e'
      )
      -- I due overload legittimi, per tipi incompatibili fra loro
      AND p.proname NOT IN ('fn_get_tasso_cambio', 'fn_superadmin_get_all_companies')
    GROUP BY p.proname
    HAVING count(*) > 1
    ORDER BY 2 DESC, 1;
$$;

COMMENT ON FUNCTION fn_check_firme_duplicate() IS
    'Funzioni con piu'' di una firma: quasi sempre una versione vecchia rimasta indietro, che prima o poi fa fallire una chiamata con «function ... is not unique». Lanciarla dopo ogni giro di script e prima di un rilascio (script 649).';

-- ============================================================================
-- Verifica: dopo questo script deve restituire ZERO righe.
--
--   SELECT * FROM fn_check_firme_duplicate();
-- ============================================================================
