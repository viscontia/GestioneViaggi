# Funzioni Database (PostgreSQL)

## Elenco Funzioni
| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `can_access_azienda` | Determina se utente corrente può accedere a specifica azienda basato sul ruolo | `target_azienda_id integer` | `boolean` | - |
| `check_possible_duplicate_travels` | Identifica potenziali duplicati dei viaggi basandosi su parole chiave nella descrizione | `p_description text, p_azienda_id integer` | `TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, matching_words text)` | `Services/CRUD/AnaViaggiService.cs` |
| `check_reset_rate_limit` | Verifica numero tentativi reset negli ultimi 15 minuti per email | `p_email character varying` | `integer` | - |
| `chk_room_consistency_on_delete` | Verifica violazioni capacità camera prima di cancellazione partecipante | `p_data_viaggio_id integer, p_cliente_id_to_remove integer` | `TABLE(violation_detected boolean, ...)` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `cleanup_expired_tokens` | Pulizia automatica token scaduti e dati obsoleti per ottimizzazione | - | `integer` | - |
| `cleanup_business_events` | Elimina vecchi log degli eventi di business mantenendo solo gli ultimi N giorni | `p_days_to_keep integer` | `void` | `Services/Shared/RecentActivityService.cs` |
| `current_azienda` | Restituisce ID azienda corrente per ruoli azienda-specifici | - | `integer` | - |
| `current_role` | Restituisce ruolo attivo della sessione | - | `text` | - |
| `current_user_id` | - | - | `uuid` | - |
| `fn_app_create_azienda` | Crea nuova azienda/tenant (solo SuperAdmin) | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_create_country` | Crea una nuova nazione | `p_name character varying, ...` | `jsonb` | - |
| `fn_app_create_country_organization` | Crea una nuova organizzazione | `p_code character varying, p_name character varying` | `jsonb` | - |
| `fn_app_create_geo_capoluogo` | Crea nuovo capoluogo | `p_data jsonb` | `jsonb` | - |
| `fn_app_create_geo_comuni` | Crea nuovo comune | `p_data jsonb` | `jsonb` | - |
| `fn_app_create_geo_ita_ripgeo` | Crea nuovo ripartizione geografica | `p_data jsonb` | `jsonb` | - |
| `fn_app_create_geo_province` | Crea nuovo provincia | `p_data jsonb` | `jsonb` | - |
| `fn_app_create_geo_regioni_ita` | Crea nuovo regione | `p_data jsonb` | `jsonb` | - |
| `fn_app_delete_country` | Elimina una nazione | `p_country_id integer` | `jsonb` | - |
| `fn_app_delete_country_organization` | Elimina un'organizzazione | `p_id integer` | `jsonb` | - |
| `fn_app_delete_geo_capoluogo` | Elimina capoluogo | `p_id text` | `jsonb` | - |
| `fn_app_delete_geo_comuni` | Elimina comune | `p_id text` | `jsonb` | - |
| `fn_app_delete_geo_ita_ripgeo` | Elimina ripartizione geografica | `p_id text` | `jsonb` | - |
| `fn_app_delete_geo_province` | Elimina provincia | `p_id text` | `jsonb` | - |
| `fn_app_delete_geo_regioni_ita` | Elimina regione | `p_id text` | `jsonb` | - |
| `fn_app_get_all_aziende` | Recupera lista paginata di tutte le aziende con filtri e ricerca per SuperAdmin | `p_user_id uuid, ...` | `jsonb` | - |
| `fn_app_get_all_countries` | Recupera tutte le nazioni con paginazione, ricerca e ordinamento | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_get_all_country_organizations` | Recupera tutte le organizzazioni con paginazione, ricerca e ordinamento | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_get_all_geo_capoluogos` | Lista paginata capoluoghi con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_all_geo_comunis` | Lista paginata comuni con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_all_geo_ita_ripgeos` | Lista paginata ripartizioni geografiche con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_all_geo_provinces` | Lista paginata province con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_all_geo_regioni_itas` | Lista paginata regioni con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_azienda_by_id` | Recupera dettaglio singola azienda per ID o tenant_id | `p_azienda_id integer` | `jsonb` | - |
| `fn_app_get_aziende_distinct_values` | Recupera valori distinti per filtri dropdown nelle colonne | `p_column_name text` | `jsonb` | - |
| `fn_app_get_comune_by_id` | Recupera un singolo comune formattato per ID con formato 'CAP - COMUNE (PROVINCIA)' | `p_comune_id integer` | `TABLE(comune_id integer, comune_formatted text, ...)` | - |
| `fn_app_get_comune_formatted` | - | `p_comune_id integer` | `text` | - |
| `fn_app_get_comuni_lookup` | - | `p_search_term text, ...` | `TABLE(comune_id integer, comune_formatted text, ...)` | - |
| `fn_app_get_country_by_id` | Recupera una nazione specifica per ID | `p_country_id integer` | `jsonb` | - |
| `fn_app_get_country_intermediate_by_id` | Returns a single intermediate region by ID with full details | `p_intermediate_id integer` | `TABLE(id integer, name text)` | - |
| `fn_app_get_country_intermediates_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_country_organization_by_id` | Recupera un'organizzazione specifica per ID | `p_id integer` | `jsonb` | - |
| `fn_app_get_country_organizations_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_country_region_by_id` | Returns a single country region by ID with full details | `p_region_id integer` | `TABLE(id integer, name text)` | - |
| `fn_app_get_country_regions_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_country_sub_region_by_id` | Returns a single country sub-region by ID with full details | `p_sub_region_id integer` | `TABLE(id integer, name text)` | - |
| `fn_app_get_country_sub_regions_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_geo_capoluogo` | Recupera singolo capoluogo per ID | `p_id text` | `jsonb` | - |
| `fn_app_get_geo_capoluogos_lookup` | - | - | `jsonb` | - |
| `fn_app_get_geo_comuni` | Recupera singolo comune per ID | `p_id text` | `jsonb` | - |
| `fn_app_get_geo_comunis_lookup` | Lookup comuni per combobox | - | `jsonb` | - |
| `fn_app_get_geo_ita_ripgeo` | Recupera singolo ripartizione geografica per ID | `p_id text` | `jsonb` | - |
| `fn_app_get_geo_ita_ripgeos_lookup` | - | - | `jsonb` | - |
| `fn_app_get_geo_province` | Recupera singolo provincia per ID | `p_id text` | `jsonb` | - |
| `fn_app_get_geo_provinces_lookup` | Lookup province per combobox | - | `jsonb` | - |
| `fn_app_get_geo_regioni_ita` | Recupera singolo regione per ID | `p_id text` | `jsonb` | - |
| `fn_app_get_geo_regioni_itas_lookup` | Lookup regioni per combobox | - | `jsonb` | - |
| `fn_app_get_tipo_sede_by_id` | Recupera un singolo tipo sede per ID con tutti i dettagli | `p_tipo_sede_id integer` | `TABLE(tipo_sede_id integer, ...)` | - |
| `fn_app_health_check` | - | - | `json` | `Services/Authentication/AuthenticationService.cs` |
| `fn_app_list_roles` | Restituisce lista ruoli paginata per tenant | `p_tenant_id text, ...` | `jsonb` | `Services/Security/RoleService.cs` |
| `fn_app_list_users` | Restituisce lista utenti paginata con filtri | `p_tenant_id text, ...` | `jsonb` | `Services/Security/UserService.cs` |
| `fn_app_login` | Login con auto-detect tenant | `p_email citext, p_password text` | `jsonb` | - |
| `fn_app_login_text` | - | `p_email text, p_password text` | `jsonb` | `Services/Authentication/AuthenticationService.cs` |
| `fn_app_login_text_debug` | - | `p_email text, p_password text` | `jsonb` | - |
| `fn_app_logo_create_backup_20250909` | - | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_profile` | - | `p_user_id uuid` | `jsonb` | - |
| `fn_app_toggle_azienda_status` | Attiva/disattiva stato azienda (solo SuperAdmin) | `p_azienda_id integer, ...` | `jsonb` | - |
| `fn_app_update_azienda` | Aggiorna dati azienda esistente (solo SuperAdmin) | `p_azienda_id integer, ...` | `jsonb` | - |
| `fn_app_update_country` | Aggiorna una nazione esistente | `p_country_id integer, ...` | `jsonb` | - |
| `fn_app_update_country_organization` | Aggiorna un'organizzazione esistente | `p_id integer, ...` | `jsonb` | - |
| `fn_app_update_geo_capoluogo` | Aggiorna capoluogo esistente | `p_data jsonb` | `jsonb` | - |
| `fn_app_update_geo_comuni` | Aggiorna comune esistente | `p_data jsonb` | `jsonb` | - |
| `fn_app_update_geo_ita_ripgeo` | Aggiorna ripartizione geografica esistente | `p_data jsonb` | `jsonb` | - |
| `fn_app_update_geo_province` | Aggiorna provincia esistente | `p_data jsonb` | `jsonb` | - |
| `fn_app_update_geo_regioni_ita` | Aggiorna regione esistente | `p_data jsonb` | `jsonb` | - |
| `fn_check_email_unique_across_companies` | Verifica unicità email attraverso tutti i tenant | `p_email text` | `boolean` | `Services/Security/UserService.cs` |
| `fn_get_logo_field_help` | - | `field_name text` | `text` | - |
| `fn_get_menu_breadcrumbs` | Recupera breadcrumbs path per menu specifico | `p_menu_id uuid` | `jsonb` | - |
| `fn_is_pec_domain` | - | `p_email text` | `boolean` | - |
| `fn_log_business_event` | Registra un evento nella tabella ana_business_events (chiamata dai trigger) | `p_event_type varchar, p_description text, ...` | `void` | - |
| `fn_logo_calculate_hash` | - | `p_binary_data bytea` | `character varying` | - |
| `fn_logo_setup_master_detail_relation` | - | - | `jsonb` | - |
| `fn_logo_update_access_stats` | - | `p_logo_id uuid` | `void` | - |
| `fn_logo_validate_mime_type` | - | `p_file_format character varying, ...` | `boolean` | - |
| `fn_superadmin_delete_from_table` | DELETE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_describe_table` | DESCRIBE schema tabella per SuperAdmin | `p_user_id uuid, p_table_name character varying` | `jsonb` | - |
| `fn_superadmin_get_all_companies` | Recupera tutte le aziende cross-tenant per SuperAdmin | `p_user_id uuid, ...` | `jsonb` | - |
| `fn_superadmin_query_table` | SELECT generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_update_table` | UPDATE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_test_smtp_config` | - | `p_smtp_id uuid` | `TABLE(success boolean, message text, ...)` | - |
| `fn_validate_config_type_requirements` | - | `p_config_type character varying, ...` | `text` | - |
| `fn_validate_email_format` | - | `p_email text` | `boolean` | - |
| `fn_validate_protocol_requirements` | - | `p_direction character varying, ...` | `text` | - |
| `fn_validate_security_port_consistency` | - | `p_security_method character varying, ...` | `text` | - |
| `generate_reset_token` | Genera token sicuro univoco per reset password | - | `character varying` | - |
| `get_all_participants_travel` | - | `p_data_viaggio_id integer` | `TABLE(nominativo text)` | - |
| `get_all_travel_detail` | Restituisce tutti i dettagli di un singolo viaggio (Data Viaggio) incrociando ana_date_viaggi, ana_viaggi e vari lookup (tipo viaggio, nazione, trattamento, pernottamento, avvicinamento) | `p_data_viaggio_id integer` | `TABLE(data_viaggio_id integer, viaggio_id integer, azienda_id integer, titolo text, descrizione_estesa text, tipo text, nazione text, data_inizio date, data_fine date, effettuato_sino char, km integer, giorni integer, notti integer, trattamento text, pernottamento text, costi vari integer, pasti_al_sacco char, tipo_avvicinamento text, note_viaggio text, note_data_viaggio text, link text)` | `Services/Printing/TravelPrintService.cs` |
| `get_client_travel_history` | - | `p_cliente_id integer, p_azienda_id integer` | `TABLE(data_viaggio_id integer, titolo text, ...)` | - |
| `get_cliente_detail` | - | `p_cliente_id integer` | `TABLE(cliente_id integer, ...)` | - |
| `get_company_print_info` | Recupera dati intestazione azienda (Ragione Sociale, Tel, PEC, Sito) per stampe | `p_azienda_id integer` | `TABLE(ragione_sociale text, telefono text, email text, sito_web text, piva text, logo_data bytea)` | `Services/Printing/TravelPrintService.cs` |
| `get_count_travel_future` | - | `p_cliente_id integer, p_azienda_id integer` | `integer` | - |
| `get_count_travel_made` | - | `p_cliente_id integer, p_azienda_id integer` | `integer` | - |
| `get_customer_nationality` | - | `p_cliente_id integer` | `text` | - |
| `get_datetrips_fromtrip` | - | `p_viaggio_id integer` | `TABLE(data_viaggio_id integer, viaggio_id_fk integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_exist_travel_customer_by_year` | - | `p_cliente_id integer` | `TABLE(anno integer)` | - |
| `get_mezzo_by_pilot` | Recupera dettagli mezzo associato a un pilota per un viaggio | `p_viaggio_id integer, ...` | `text` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_count` | Conteggio totale partecipanti per data viaggio. Più efficiente di Count() in memoria su collection caricata. | `p_data_viaggio_id integer` | `integer` | `Services/CRUD/MovClientiViaggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `get_participants_sorted` | Restituisce partecipanti ordinati per: cognome pilota → pilota prima dei passeggeri → cognome passeggeri. Elimina necessità di ordinamento LINQ in memoria. | `p_data_viaggio_id integer` | `TABLE(..., is_pilot boolean, telefono text, email text, residenza text, codice_fiscale text, data_nascita date, luogo_nascita text)` | `Services/CRUD/MovClientiViaggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `get_participants_without_accommodation` | Restituisce solo partecipanti senza camera assegnata tramite LEFT JOIN atomico con mov_clienti_alloggi. Elimina necessità di join in memoria tra partecipanti e camere. | `p_data_viaggio_id integer` | `TABLE(viaggio_id integer, data_id integer, cliente_id integer, nominativo text, tipo_partecipante_id integer, ruolo text, note text, cane_sino varchar(1), intolleranze text, mezzo_dettagli text, cliente_pilota_id integer, grouping_key integer)` | `Services/CRUD/MovClientiViaggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `get_reset_stats` | Genera statistiche sistema reset password per periodo specificato | `p_days integer` | `character varying` | - |
| `get_rooms_count` | Conteggio totale camere per data viaggio. Più efficiente di Count() in memoria su collection caricata. | `p_data_viaggio_id integer` | `integer` | `Services/CRUD/MovClientiAlloggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `get_rooms_with_occupants` | Restituisce camere con occupanti aggregati tramite ARRAY_AGG (nomi e IDs). Elimina necessità di loop su 6 slot ClienteIdXFk + lookup partecipanti in memoria. Gestisce duplicati con DISTINCT. | `p_data_viaggio_id integer` | `TABLE(alloggio_pk integer, tipo_alloggio text, max_occupants integer, current_occupants integer, occupant_names text[], occupant_ids integer[], has_supplement boolean)` | `Services/CRUD/MovClientiAlloggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `get_totmezzi_dataviaggio` | - | `p_viaggio_id integer, p_data_viaggio_id integer` | `integer` | - |
| `get_travel_passengers` | - | `p_data_viaggio_id integer, p_exclude_client_id integer` | `TABLE(nominativo text, ruolo text)` | - |
| `get_travel_stats` | Calcola totali partecipanti, equipaggi e veicoli per una data viaggio | `p_data_viaggio_id integer` | `TABLE(total_participants integer, total_crews integer, total_vehicles integer)` | `Services/Printing/TravelPrintService.cs`, `SqlScripts/get_travel_stats.sql` |
| `get_viaggio_partecipanti` | - | `p_data_viaggio_id integer` | `TABLE(gruppo_id integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_viaggio_partecipanti_summary` | Restituisce riepilogo testuale partecipanti per tooltip/export | `p_data_viaggio_id integer` | `text` | - |
| `hash_password` | - | `p_password text` | `character varying` | - |
| `request_password_reset_retool` | Procedura principale per Retool con messaggi italiani | `p_email character varying, ...` | `void` | - |
| `reset_password_with_token` | Esegue reset password con token e invalida tutti i token utente | `p_token character varying, ...` | `character varying` | - |
| `set_user_context` | Imposta contesto completo utente: tenant, azienda e ruolo | `p_user_id uuid` | `TABLE(tenant_id text, azienda_id integer, ...)` | - |
| `sp_ana_aziende_smtp_test_connection` | - | `p_smtp_id uuid` | `TABLE(success boolean, message text, ...)` | - |
| `sp_app_create_role` | Crea nuovo ruolo applicativo | `p_role_code text, ...` | - | `Services/Security/RoleService.cs` |
| `sp_app_create_user` | Crea nuovo utente | `p_email text, ...` | - | `Services/Security/UserService.cs` |
| `sp_app_delete_role` | Elimina ruolo esistente | `p_role_code text` | - | `Services/Security/RoleService.cs` |
| `sp_app_delete_user` | Elimina utente | `p_user_id uuid` | - | `Services/Security/UserService.cs` |
| `sp_app_update_role` | Aggiorna ruolo esistente | `p_role_code text, ...` | - | `Services/Security/RoleService.cs` |
| `sp_app_update_user` | Aggiorna dati utente | `p_user_id uuid, ...` | - | `Services/Security/UserService.cs` |
| `sp_mov_clienti_alloggi_create` | Crea associazione cliente-alloggio | `p_viaggio_id integer, ...` | `integer` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_mov_clienti_alloggi_delete` | Elimina associazione cliente-alloggio | `p_pk integer` | `void` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_mov_clienti_alloggi_update` | Aggiorna associazione cliente-alloggio | `p_pk integer, ...` | `void` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_mov_clienti_viaggi_create` | Iscrive partecipante al viaggio | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_delete` | Rimuove partecipante dal viaggio (con cleanup alloggi) | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_update` | Aggiorna dati iscrizione partecipante | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_remove_client_from_room` | Rimuove cliente da camera, compattando slot e eliminando camera se vuota | `p_room_id integer, p_cliente_id integer` | `void` | `SqlScripts/92_Create_Room_Consistency_Functions.sql` |
| `sp_resolve_room_violation_move` | Sposta superstiti in nuova camera e pulisce vecchia | `p_old_room_id integer, p_new_tipo integer, p_survivors integer[]` | `void` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_resolve_room_violation_park` | Rimuove superstiti da camera lasciandoli senza alloggio | `p_room_id integer, p_survivors integer[]` | `void` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_assign_to_first_free_slot` | Assegna cliente al primo slot libero di una camera in modo atomico. Trova automaticamente ClienteIdXFk libero (1-6), valida capacità massima, esegue UPDATE. Elimina necessità di logica if-else a cascata in C#. | `p_alloggio_pk integer, p_cliente_id integer` | `boolean` (TRUE se assegnato, FALSE se camera piena) | `Services/CRUD/MovClientiAlloggiService.cs`, `Components/Shared/ViaggioPartecipantiManagerDialog.razor` |
| `validate_codice_fiscale` | - | `cf text` | `boolean` | - |
| `validate_partita_iva` | - | `piva text` | `boolean` | - |
| `validate_reset_token` | Valida token di reset verificando validità, scadenza e stato attivo | `p_token character varying` | `character varying` | - |

## Implementazioni Service-Side (Logica Applicativa)
| Componente | Funzionalità | Descrizione | Files Coinvolti |
| :--- | :--- | :--- | :--- |
| `ComuneService` | Decodifica Geografica | Esegue JOIN su `ana_geo_province`, `ana_geo_regioni_ita` per recuperare Sigla Provincia e Nome Regione direttamente in fase di SELECT. | `Services/CRUD/ComuneService.cs`, `Components/Shared/ClienteDialog.razor` |
