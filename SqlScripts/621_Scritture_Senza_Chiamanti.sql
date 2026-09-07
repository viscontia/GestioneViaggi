-- =============================================================================
-- 621 — Blocco A: le scritture che non chiama più nessuno
-- =============================================================================
--
-- Adriano, 2026-09-07: «non voglio più avere due prodotti software che scrivono
-- sullo stesso database in modalità diverse e che hanno controlli diversi».
--
-- ⚠️ Misurato prima di toccare: su **172 funzioni che scrivono**, **50 non le chiama
-- nessuno** — né il gestionale, né il sito, né altre funzioni, né un trigger.
-- Non sono innocue: sono la prossima strada che qualcuno prenderà, e nessuna di
-- loro conosce i controlli aggiunti dopo (capienza, genere, silos, consensi).
--
-- ⛔️ **Non si eliminano tutte in blocco**, e la ricognizione ha mostrato perché:
--
--   • `fn_app_login_text`, `fn_app_request_password_reset`, `fn_app_health_check`,
--     `fn_app_list_users`, `fn_app_list_roles` sono VIVE — le usa il gestionale per
--     far entrare la gente. La famiglia `fn_app_*` non era «roba morta»: conteneva
--     funzioni vive e i loro doppioni vecchi;
--   • `fn_silos_rimappa_movimenti` sembra orfana ma è la bonifica dei silos, che va
--     eseguita AL GO-LIVE (script 587-589);
--   • `ana_aziende_esp` è «predisposta ma inutilizzata, pronta per un eventuale uso
--     futuro» — decisione del 2026-07-12: cancellarne le funzioni la disferebbe.
--
-- Restano fuori da questo script anche accesso, password e token: sbagliare lì
-- significa non entrare più nel gestionale, e si fa in un momento dedicato.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Sostituite dal lavoro di questi giorni
-- ---------------------------------------------------------------------------
-- ⚠️ `ana_clienti` aveva TREDICI funzioni di scrittura e `mov_clienti_viaggi` OTTO.
-- Queste sono le versioni vecchie, rimpiazzate da `fn_ana_clienti_insert/update/
-- delete` e `fn_mov_clienti_viaggi_insert/update/delete`, che i due software già
-- chiamano. Le `fn_wizard_*` erano la copia che il sito si era fatto per conto suo.
DROP FUNCTION IF EXISTS fn_wizard_insert_cliente(integer,character varying,character varying,character varying,character varying,integer,character varying,integer,date,character varying,character varying,character varying,character varying,text,character varying,character varying,character varying,date,date,character varying);
DROP FUNCTION IF EXISTS fn_wizard_insert_prenotazione(integer,integer,integer,integer,integer,integer,integer,character varying,character varying,text);
DROP FUNCTION IF EXISTS fn_wizard_update_cliente(integer,character varying,character varying,character varying,character varying,integer,character varying,integer,date,character varying,character varying,character varying,character varying,text,character varying,character varying,character varying,date,date);
DROP FUNCTION IF EXISTS sp_ana_clienti_create(character varying,character varying,character varying,character varying,integer,character varying,integer,date,character varying,character varying,character varying,character varying,character varying,bytea,bytea,character varying,character varying,character varying,date,date,text,character varying,character varying,character varying,timestamp without time zone,character varying,character varying,character varying,timestamp without time zone,character varying,integer);
DROP FUNCTION IF EXISTS sp_ana_clienti_delete(integer,integer);
DROP FUNCTION IF EXISTS sp_ana_clienti_update(integer,character varying,character varying,character varying,character varying,integer,character varying,integer,date,character varying,character varying,character varying,character varying,character varying,bytea,bytea,character varying,character varying,character varying,date,date,text,character varying,character varying,character varying,timestamp without time zone,character varying,character varying,character varying,timestamp without time zone,character varying,integer);
DROP FUNCTION IF EXISTS sp_mov_clienti_viaggi_delete(integer,integer,integer);
DROP FUNCTION IF EXISTS sp_mov_clienti_viaggi_update(integer,integer,integer,integer,integer,integer,numeric,character varying,character varying,text,integer);

-- ---------------------------------------------------------------------------
-- 2. L'interfaccia esterna che non usa più nessuno
-- ---------------------------------------------------------------------------
-- CRUD su aziende, paesi e geografia, scritti per un consumatore esterno (app o
-- Retool) che non esiste più. ⚠️ Il gestionale la geografia la legge con altre
-- funzioni: queste erano solo scrittura, e nessuno scriveva.
-- ⛔️ `fn_superadmin_update_table` faceva un UPDATE su QUALSIASI tabella passata come
-- stringa: nessun controllo poteva valere, perché non sapeva nemmeno su cosa stava
-- scrivendo.
DROP FUNCTION IF EXISTS fn_app_create_azienda(jsonb);
DROP FUNCTION IF EXISTS fn_app_create_azienda(character varying,character varying,character varying,character varying,character varying,numeric,boolean,boolean,character varying,character varying,character varying,boolean);
DROP FUNCTION IF EXISTS fn_app_create_country(character varying,character varying,character varying,character varying,character varying,bigint,numeric,integer,integer,integer,integer);
DROP FUNCTION IF EXISTS fn_app_create_country_organization(character varying,character varying);
DROP FUNCTION IF EXISTS fn_app_create_geo_capoluogo(jsonb);
DROP FUNCTION IF EXISTS fn_app_create_geo_comuni(jsonb);
DROP FUNCTION IF EXISTS fn_app_create_geo_ita_ripgeo(jsonb);
DROP FUNCTION IF EXISTS fn_app_create_geo_province(jsonb);
DROP FUNCTION IF EXISTS fn_app_create_geo_regioni_ita(jsonb);
DROP FUNCTION IF EXISTS fn_app_delete_country(integer);
DROP FUNCTION IF EXISTS fn_app_delete_country_organization(integer);
DROP FUNCTION IF EXISTS fn_app_delete_geo_capoluogo(text);
DROP FUNCTION IF EXISTS fn_app_delete_geo_comuni(text);
DROP FUNCTION IF EXISTS fn_app_delete_geo_ita_ripgeo(text);
DROP FUNCTION IF EXISTS fn_app_delete_geo_province(text);
DROP FUNCTION IF EXISTS fn_app_delete_geo_regioni_ita(text);
DROP FUNCTION IF EXISTS fn_app_toggle_azienda_status(integer,uuid,boolean);
DROP FUNCTION IF EXISTS fn_app_update_azienda(integer,character varying,character varying,character varying,character varying,numeric,boolean,boolean,character varying,character varying,character varying,boolean);
DROP FUNCTION IF EXISTS fn_app_update_country(integer,character varying,character varying,character varying,character varying,character varying,bigint,numeric,integer,integer,integer,integer);
DROP FUNCTION IF EXISTS fn_app_update_country_organization(integer,character varying,character varying);
DROP FUNCTION IF EXISTS fn_app_update_geo_capoluogo(jsonb);
DROP FUNCTION IF EXISTS fn_app_update_geo_comuni(jsonb);
DROP FUNCTION IF EXISTS fn_app_update_geo_ita_ripgeo(jsonb);
DROP FUNCTION IF EXISTS fn_app_update_geo_province(jsonb);
DROP FUNCTION IF EXISTS fn_app_update_geo_regioni_ita(jsonb);
DROP FUNCTION IF EXISTS fn_superadmin_update_table(uuid,character varying,character varying,character varying);


-- ---------------------------------------------------------------------------
-- 3. Retool
-- ---------------------------------------------------------------------------
-- ⚠️ Adriano, 2026-09-07: «tutto quello che riguarda Retool è roba non usata. Retool
-- l'ho abbandonato almeno un anno fa, forse più».
--
-- Cercato: a database ne resta UNA sola, e la documentazione la dava già per
-- «deprecata, ha bug (tipo INTEGER invece di UUID per user_id)». Nel codice del
-- gestionale e del sito: nessuna traccia. Nessuna tabella, nessuna colonna.
--
-- ⛔️ È una funzione di reimpostazione password: quella VIVA è
-- `fn_app_request_password_reset`, che il gestionale chiama da
-- `PasswordResetService.cs`. Due strade per reimpostare una password, una delle
-- quali con un difetto noto, sono esattamente il genere di duplicazione che si paga
-- il giorno in cui qualcuno prende quella sbagliata.
DROP FUNCTION IF EXISTS request_password_reset_retool(character varying, inet, character varying);
