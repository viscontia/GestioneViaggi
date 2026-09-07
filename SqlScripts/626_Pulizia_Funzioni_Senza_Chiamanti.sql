-- ============================================================================
-- 626 — Le 84 funzioni che non chiama piu' nessuno
--
-- Adriano, 2026-09-07: «Non ho capito le 83 letture morte. Se sono morte perche'
-- le teniamo? Lo stesso per le orfane.» Aveva ragione: erano rimaste per
-- prudenza, e la prudenza giusta non e' tenerle, e' verificarle una per una.
--
-- COME SONO STATE TROVATE (il metodo, perche' il conteggio da solo sbaglia)
-- Per ognuna delle 660 funzioni dello schema public si e' contato chi la usa in:
--   1. C# e Razor del gestionale, e Python/JS del sito — con i commenti TOLTI
--      prima di cercare. ⚠️ E' il passo che era mancato: contare un nome dentro
--      un commento aveva gia' fatto sembrare viva una funzione morta, e viceversa.
--   2. il corpo di tutte le altre funzioni;
--   3. gli script di SqlScripts/, escludendo la CREATE/DROP di se stessa;
--   4. ⚠️ i trigger, i CHECK, le viste, i default, gli indici e le policy RLS —
--      un trigger non nomina la sua funzione in nessun file, e cercandola a
--      grep sembra morta. E' cosi' che `fn_partenza_conclusa` si era salvata.
-- Escluse le 110 funzioni che appartengono alle estensioni (pg_trgm, citext,
-- uuid-ossp): non sono nostre.
-- Le firme sono LETTE da pg_proc, non indovinate: un DROP con firma sbagliata
-- non da' errore, lascia la funzione al suo posto e fa credere di aver pulito.
-- Verificato anche su PROD (sola lettura) che nessuna sia agganciata la' a un
-- trigger o a una policy.
--
-- QUATTRO NON SONO QUI, e non per dimenticanza (dettagli nella relazione §2.19):
--   check_reset_rate_limit, get_reset_stats, cleanup_expired_tokens,
--   trg_user_roles_delete_protection
-- Non sono avanzi: sono controlli veri che nessuno ha mai collegato. Toglierle
-- farebbe sparire la traccia di una lacuna, invece di colmarla.
--
-- LE DEFINIZIONI NON SI PERDONO: molte di queste non comparivano in nessuno
-- script, esistevano solo dentro il database. Sono state salvate per intero in
--   Documents/2026-09-07-Funzioni_rimosse_definizioni.sql
-- che sta fuori da SqlScripts/ apposta, per non essere riapplicato dal ciclo di
-- go-live.
--
-- Rigiocabile: ogni DROP e' IF EXISTS.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Geografia e paesi — 33 funzioni
-- Il gestionale legge comuni, province, regioni e paesi con SQL scritto dentro il C#
-- (`FROM ana_geo_comuni`, `FROM ana_geo_province`...). Queste sono la versione DB-first
-- dello stesso lavoro, e non le ha mai chiamate nessuno: due strade per lo stesso dato,
-- di cui una non e' mai stata percorsa.
-- ⚠️ Non e' che la geografia smetta di funzionare: continua a funzionare come oggi. Quando
-- si sistemera' l'SQL inline (§2.18) le funzioni andranno riscritte sullo schema di allora —
-- queste sono anteriori a tre re-model (titolo/sesso, silos, cliente_lingua) e nessuno le ha
-- mai eseguite, quindi non c'e' motivo di crederle giuste.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_app_get_all_countries(p_tenant_id character varying, p_page integer, p_page_size integer, p_search text, p_sort_by character varying, p_sort_order character varying);
DROP FUNCTION IF EXISTS public.fn_app_get_all_country_organizations(p_tenant_id character varying, p_page integer, p_page_size integer, p_search text, p_sort_by character varying, p_sort_order character varying);
DROP FUNCTION IF EXISTS public.fn_app_get_all_geo_capoluogos(p_tenant_id text, p_page integer, p_page_size integer, p_search text, p_sort_by text, p_sort_order text);
DROP FUNCTION IF EXISTS public.fn_app_get_all_geo_comunis(p_tenant_id text, p_page integer, p_page_size integer, p_search text, p_sort_by text, p_sort_order text);
DROP FUNCTION IF EXISTS public.fn_app_get_all_geo_ita_ripgeos(p_tenant_id text, p_page integer, p_page_size integer, p_search text, p_sort_by text, p_sort_order text);
DROP FUNCTION IF EXISTS public.fn_app_get_all_geo_provinces(p_tenant_id text, p_page integer, p_page_size integer, p_search text, p_sort_by text, p_sort_order text);
DROP FUNCTION IF EXISTS public.fn_app_get_all_geo_regioni_itas(p_tenant_id text, p_page integer, p_page_size integer, p_search text, p_sort_by text, p_sort_order text);
DROP FUNCTION IF EXISTS public.fn_app_get_comune_by_id(p_comune_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_comune_formatted(p_comune_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_comuni_lookup(p_search_term text, p_limit integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_by_id(p_country_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_intermediate_by_id(p_intermediate_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_intermediates_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_country_organization_by_id(p_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_organizations_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_country_region_by_id(p_region_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_regions_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_country_sub_region_by_id(p_sub_region_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_country_sub_regions_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_geo_capoluogo(p_id text);
DROP FUNCTION IF EXISTS public.fn_app_get_geo_capoluogos_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_geo_comuni(p_id text);
DROP FUNCTION IF EXISTS public.fn_app_get_geo_comunis_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_geo_ita_ripgeo(p_id text);
DROP FUNCTION IF EXISTS public.fn_app_get_geo_ita_ripgeos_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_geo_province(p_id text);
DROP FUNCTION IF EXISTS public.fn_app_get_geo_provinces_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_geo_regioni_ita(p_id text);
DROP FUNCTION IF EXISTS public.fn_app_get_geo_regioni_itas_lookup();
DROP FUNCTION IF EXISTS public.fn_app_get_tipo_sede_by_id(p_tipo_sede_id integer);

-- ---------------------------------------------------------------------------
-- Anagrafica azienda e profilo utente — 4 funzioni
-- Stessa situazione della geografia: `ana_aziende` e il profilo si leggono inline nel C#.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_app_get_all_aziende();
DROP FUNCTION IF EXISTS public.fn_app_get_all_aziende(p_user_id uuid, p_page_number integer, p_page_size integer, p_search_term text, p_sort_column text, p_sort_direction text, p_filters jsonb);
DROP FUNCTION IF EXISTS public.fn_app_get_azienda_by_id(p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_app_get_azienda_by_id(p_azienda_id integer, p_tenant_id character varying);
DROP FUNCTION IF EXISTS public.fn_app_get_aziende_distinct_values(p_column_name text);
DROP FUNCTION IF EXISTS public.fn_app_profile(p_user_id uuid);

-- ---------------------------------------------------------------------------
-- Aliquote IVA — 7 funzioni
-- L'IVA si modifica davvero dalla UI (AnaAliquoteIvaPage + EditDialog), ma quelle pagine
-- scrivono e leggono con SQL inline. Le sette funzioni qui sotto — tre letture e quattro
-- scritture — non le chiama nessuno.
-- ⚠️ Erano l'unico posto dove la regola dell'aliquota predefinita stava scritta a database:
-- oggi quella regola vive solo nel C#, e questo script non la sposta, la constata.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_ana_aliquote_iva_get_active(p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_ana_aliquote_iva_get_all(p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_ana_aliquote_iva_get_default(p_azienda_id integer);
DROP FUNCTION IF EXISTS public.sp_ana_aliquote_iva_create(p_azienda_fk integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_created_by character varying, p_updated_by character varying);
DROP FUNCTION IF EXISTS public.sp_ana_aliquote_iva_delete(p_iva_id integer);
DROP FUNCTION IF EXISTS public.sp_ana_aliquote_iva_set_default(p_iva_id integer, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.sp_ana_aliquote_iva_update(p_iva_id integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_updated_by character varying);

-- ---------------------------------------------------------------------------
-- Vecchio sito pubblico — 5 funzioni
-- `fn_trip_*`, `fn_trips_available` e `get_count_travel_*` servivano il sito precedente.
-- Il sito nuovo passa dalle `fn_web_*`.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_trip_dates(p_azienda_id integer, p_viaggio_id integer);
DROP FUNCTION IF EXISTS public.fn_trip_details(p_azienda_id integer, p_viaggio_id integer);
DROP FUNCTION IF EXISTS public.fn_trips_available(p_azienda_id integer);
DROP FUNCTION IF EXISTS public.get_count_travel_future(p_cliente_id integer, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.get_count_travel_made(p_cliente_id integer, p_azienda_id integer);

-- ---------------------------------------------------------------------------
-- Vecchio wizard di iscrizione — 4 funzioni
-- Avanzi della prima versione del wizard. `fn_wizard_get_smtp_config` e' sostituita da
-- `fn_get_smtp_config_for_email`, che e' viva e la usano entrambe le applicazioni.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_wizard_check_cf_esistenza(p_cf character varying, p_azienda_id integer, p_cliente_id integer);
DROP FUNCTION IF EXISTS public.fn_wizard_find_email_by_anagrafica(p_cognome character varying, p_nome character varying, p_cf character varying, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_wizard_find_email_by_cf(p_cf character varying, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_wizard_get_smtp_config(p_azienda_id integer);

-- ---------------------------------------------------------------------------
-- Controlli di esistenza cliente — 3 funzioni
-- Sostituite da `fn_ana_clienti_valida`, l'unica regola condivisa fra gestionale e sito.
-- Erano il caso peggiore: tre porte che dicevano se un cliente esiste gia', ognuna con la
-- sua idea di uguaglianza.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_exists_cliente_anagrafica(p_cognome character varying, p_nome character varying, p_data_nascita date, p_codice_fiscale character varying, p_exclude_cliente_id integer, p_azienda_fk integer);
DROP FUNCTION IF EXISTS public.fn_exists_cliente_codice_fiscale(p_codice_fiscale character varying, p_exclude_cliente_id integer, p_azienda_fk integer);
DROP FUNCTION IF EXISTS public.fn_exists_cliente_email(p_email character varying, p_exclude_cliente_id integer, p_azienda_fk integer);

-- ---------------------------------------------------------------------------
-- Gestione loghi — 5 funzioni
-- Aiutanti mai collegati: calcolo hash, controllo MIME, testo d'aiuto, statistiche d'accesso.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_app_logo_create_backup_20250909(p_tenant_id character varying, p_azienda_fk integer, p_logo_data jsonb);
DROP FUNCTION IF EXISTS public.fn_get_logo_field_help(field_name text);
DROP FUNCTION IF EXISTS public.fn_logo_calculate_hash(p_binary_data bytea);
DROP FUNCTION IF EXISTS public.fn_logo_setup_master_detail_relation();
DROP FUNCTION IF EXISTS public.fn_logo_update_access_stats(p_logo_id uuid);
DROP FUNCTION IF EXISTS public.fn_logo_validate_mime_type(p_file_format character varying, p_mime_type character varying);

-- ---------------------------------------------------------------------------
-- Configurazione SMTP: prove e controlli mai chiamati — 5 funzioni
-- ⚠️ Tre di queste sono validazioni (`fn_validate_config_type_requirements`,
-- `fn_validate_protocol_requirements`, `fn_validate_security_port_consistency`): una
-- validazione che non viene mai chiamata e' peggio del niente, perche' fa credere che il
-- controllo ci sia. La prova SMTP vera oggi la fa il gestionale in C#.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_test_smtp_config(p_smtp_id uuid);
DROP FUNCTION IF EXISTS public.fn_validate_config_type_requirements(p_config_type character varying, p_from_email text, p_host character varying, p_port integer, p_username character varying);
DROP FUNCTION IF EXISTS public.fn_validate_protocol_requirements(p_direction character varying, p_protocol character varying, p_host character varying, p_port integer, p_inbound_host character varying, p_inbound_port integer, p_inbound_protocol character varying);
DROP FUNCTION IF EXISTS public.fn_validate_security_port_consistency(p_security_method character varying, p_port integer, p_inbound_security_method character varying, p_inbound_port integer, p_inbound_protocol character varying);
DROP FUNCTION IF EXISTS public.sp_ana_aziende_smtp_test_connection(p_smtp_id uuid);

-- ---------------------------------------------------------------------------
-- Doppioni delle CRUD web — 5 funzioni
-- Ognuna ha accanto il proprio sostituto vivo: `fn_web_indirizzi_get` accanto a
-- `fn_web_indirizzi_list`, `fn_web_aziende_funzioni_get` accanto a `_list` e
-- `_get_by_funzione`. E' il difetto gia' visto piu' volte: la funzione vecchia resta
-- accanto alla nuova, distinta solo dal suffisso, e prima o poi qualcuno prende quella.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_web_aziende_funzioni_delete(p_id bigint, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_web_aziende_funzioni_get(p_id bigint, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_web_indirizzi_get(p_id bigint, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_web_newsletter_blocchi_get(p_id bigint, p_azienda_id integer);
DROP FUNCTION IF EXISTS public.fn_web_tour_contenuti_get_by_viaggio(p_viaggio_id integer, p_azienda_id integer);

-- ---------------------------------------------------------------------------
-- Diagnostica e backup — 3 funzioni
-- ⚠️ `fn_app_login_text_debug` va via per una ragione in piu' della pulizia: dato un
-- indirizzo email qualsiasi restituisce l'**hash della password** di quell'utente, insieme
-- alla password ricevuta in chiaro. Non e' raggiungibile dal sito (il ruolo `anon` non legge
-- `app_users`, verificato su PROD il 2026-09-07), quindi non e' una falla aperta: e' una
-- mina, che esplode il giorno in cui qualcuno concede una lettura in piu' o la rende
-- SECURITY DEFINER. Il login vero e' `fn_app_login_text`, che resta.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_app_login_text_debug(p_email text, p_password text);
DROP FUNCTION IF EXISTS public.fn_get_debug_v2(p_azienda_id integer);

-- ---------------------------------------------------------------------------
-- Impianto RLS mai realizzato — 5 funzioni
-- `can_access_azienda`, `current_azienda`, `current_role`, `current_user_id` e
-- `set_user_context` appartengono a un disegno di sicurezza per righe che il progetto non ha
-- adottato: la separazione fra aziende la fa l'applicazione con `ITenantContext`. Verificato
-- che nessuna delle 47 policy attive (ne' in locale ne' su PROD) le usi.
-- ⚠️ `current_role` copriva per giunta un nome riservato di PostgreSQL.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.can_access_azienda(target_azienda_id integer);
DROP FUNCTION IF EXISTS public.current_azienda();
DROP FUNCTION IF EXISTS public.current_role();
DROP FUNCTION IF EXISTS public.current_user_id();
DROP FUNCTION IF EXISTS public.set_user_context(p_user_id uuid);
DROP FUNCTION IF EXISTS public.set_user_context(p_user_id uuid, p_azienda_id integer);

-- ---------------------------------------------------------------------------
-- Funzioni di trigger senza trigger — 3 funzioni
-- Scritte per essere agganciate a una tabella, e mai agganciate: verificato che non
-- esista alcun trigger che le usi, ne' in locale ne' su PROD.
-- ⚠️ `update_updated_at_column` si toglie qualificata `public.`: Supabase ne ha una sua,
-- omonima, sullo schema `storage`, e quella non si tocca.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.trg_app_users_login_count();
DROP FUNCTION IF EXISTS public.trg_app_users_updated_at();
DROP FUNCTION IF EXISTS public.trg_user_roles_updated_at();
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Resto — funzioni singole
-- `hash_password` (le password le fabbricano `sp_app_create_user`, `sp_app_update_user` e
-- `reset_password_with_token`, tutte vive), `fn_get_menu_breadcrumbs` (i menu non passano di
-- li'), `sp_resolve_room_violation_park` (avanzo del lavoro sugli alloggi),
-- `fn_get_transazioni_per_stampa` (sostituita da `fn_get_mov_transazioni_print_data`, quella
-- che il 2026-09-07 e' stata rimessa in funzione).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_get_menu_breadcrumbs(p_menu_id uuid);
DROP FUNCTION IF EXISTS public.fn_get_transazioni_per_stampa(p_azienda_id integer, p_controparte_id integer, p_tipo_movimento character varying, p_stati character varying[], p_viaggio_id integer, p_data_viaggio_id integer, p_valuta_id integer, p_data_transazione_da date, p_data_transazione_a date, p_data_documento_da date, p_data_documento_a date, p_importo_da numeric, p_importo_a numeric, p_numero_documento character varying, p_solo_con_documento boolean, p_solo_scadute boolean, p_solo_con_viaggio boolean, p_solo_senza_viaggio boolean, p_solo_con_fattura boolean, p_ordinamento character varying);
DROP FUNCTION IF EXISTS public.hash_password(p_password text);
DROP FUNCTION IF EXISTS public.sp_resolve_room_violation_park(p_room_id integer, p_survivor_ids integer[]);

-- funzioni coperte: 84 nomi, 87 firme

-- ---------------------------------------------------------------------------
-- Verifica: dopo questo script nessuna delle 84 deve piu' esistere.
-- ---------------------------------------------------------------------------
DO $verifica$
DECLARE v_rimaste text;
BEGIN
    SELECT string_agg(p.proname, ', ') INTO v_rimaste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(string_to_array('can_access_azienda,current_azienda,current_role,current_user_id,fn_ana_aliquote_iva_get_active,fn_ana_aliquote_iva_get_all,fn_ana_aliquote_iva_get_default,fn_app_get_all_aziende,fn_app_get_all_countries,fn_app_get_all_country_organizations,fn_app_get_all_geo_capoluogos,fn_app_get_all_geo_comunis,fn_app_get_all_geo_ita_ripgeos,fn_app_get_all_geo_provinces,fn_app_get_all_geo_regioni_itas,fn_app_get_azienda_by_id,fn_app_get_aziende_distinct_values,fn_app_get_comune_by_id,fn_app_get_comune_formatted,fn_app_get_comuni_lookup,fn_app_get_country_by_id,fn_app_get_country_intermediate_by_id,fn_app_get_country_intermediates_lookup,fn_app_get_country_organization_by_id,fn_app_get_country_organizations_lookup,fn_app_get_country_region_by_id,fn_app_get_country_regions_lookup,fn_app_get_country_sub_region_by_id,fn_app_get_country_sub_regions_lookup,fn_app_get_geo_capoluogo,fn_app_get_geo_capoluogos_lookup,fn_app_get_geo_comuni,fn_app_get_geo_comunis_lookup,fn_app_get_geo_ita_ripgeo,fn_app_get_geo_ita_ripgeos_lookup,fn_app_get_geo_province,fn_app_get_geo_provinces_lookup,fn_app_get_geo_regioni_ita,fn_app_get_geo_regioni_itas_lookup,fn_app_get_tipo_sede_by_id,fn_app_login_text_debug,fn_app_logo_create_backup_20250909,fn_app_profile,fn_exists_cliente_anagrafica,fn_exists_cliente_codice_fiscale,fn_exists_cliente_email,fn_get_debug_v2,fn_get_logo_field_help,fn_get_menu_breadcrumbs,fn_get_transazioni_per_stampa,fn_logo_calculate_hash,fn_logo_setup_master_detail_relation,fn_logo_update_access_stats,fn_logo_validate_mime_type,fn_test_smtp_config,fn_trip_dates,fn_trip_details,fn_trips_available,fn_validate_config_type_requirements,fn_validate_protocol_requirements,fn_validate_security_port_consistency,fn_web_aziende_funzioni_delete,fn_web_aziende_funzioni_get,fn_web_indirizzi_get,fn_web_newsletter_blocchi_get,fn_web_tour_contenuti_get_by_viaggio,fn_wizard_check_cf_esistenza,fn_wizard_find_email_by_anagrafica,fn_wizard_find_email_by_cf,fn_wizard_get_smtp_config,get_count_travel_future,get_count_travel_made,hash_password,set_user_context,sp_ana_aliquote_iva_create,sp_ana_aliquote_iva_delete,sp_ana_aliquote_iva_set_default,sp_ana_aliquote_iva_update,sp_ana_aziende_smtp_test_connection,sp_resolve_room_violation_park,trg_app_users_login_count,trg_app_users_updated_at,trg_user_roles_updated_at,update_updated_at_column', ','));

    IF v_rimaste IS NOT NULL THEN
        RAISE EXCEPTION 'Queste dovevano sparire e sono ancora qui: %', v_rimaste;
    END IF;
    RAISE NOTICE '626: le 84 funzioni senza chiamanti non ci sono piu.';
END
$verifica$;

COMMIT;
