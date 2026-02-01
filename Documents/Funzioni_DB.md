# Funzioni Database (PostgreSQL)

Questo documento elenca le funzioni e stored procedure del database, raggruppate per area funzionale.

---

## 1. Sicurezza e Utenti
Funzioni relative all'autenticazione, gestione utenti, ruoli e permessi.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_app_login` | Login con auto-detect tenant | `p_email citext, p_password text` | `jsonb` | - |
| `fn_app_login_text` | - | `p_email text, p_password text` | `jsonb` | `Services/Authentication/AuthenticationService.cs` |
| `fn_app_login_text_debug` | - | `p_email text, p_password text` | `jsonb` | - |
| `fn_app_profile` | - | `p_user_id uuid` | `jsonb` | - |
| `fn_app_list_users` | Restituisce lista utenti paginata con filtri | `p_tenant_id text, ...` | `jsonb` | `Services/Security/UserService.cs` |
| `sp_app_create_user` | Crea nuovo utente | `p_email text, ...` | - | `Services/Security/UserService.cs` |
| `sp_app_update_user` | Aggiorna dati utente | `p_user_id uuid, ...` | - | `Services/Security/UserService.cs` |
| `sp_app_delete_user` | Elimina utente | `p_user_id uuid` | - | `Services/Security/UserService.cs` |
| `fn_app_list_roles` | Restituisce lista ruoli paginata per tenant | `p_tenant_id text, ...` | `jsonb` | `Services/Security/RoleService.cs` |
| `sp_app_create_role` | Crea nuovo ruolo applicativo | `p_role_code text, ...` | - | `Services/Security/RoleService.cs` |
| `sp_app_update_role` | Aggiorna ruolo esistente | `p_role_code text, ...` | - | `Services/Security/RoleService.cs` |
| `sp_app_delete_role` | Elimina ruolo esistente | `p_role_code text` | - | `Services/Security/RoleService.cs` |
| `can_access_azienda` | Determina se utente corrente può accedere a specifica azienda basato sul ruolo | `target_azienda_id integer` | `boolean` | - |
| `current_role` | Restituisce ruolo attivo della sessione | - | `text` | - |
| `current_user_id` | - | - | `uuid` | - |
| `set_user_context` | Imposta contesto completo utente: tenant, azienda e ruolo | `p_user_id uuid` | `TABLE(tenant_id text, azienda_id integer, ...)` | - |
| `fn_check_email_unique_across_companies` | Verifica unicità email attraverso tutti i tenant | `p_email text` | `boolean` | `Services/Security/UserService.cs` |
| `framework_hash_password` | *Alias: hash_password* | `p_password text` | `character varying` | - |
| `generate_reset_token` | Genera token sicuro univoco per reset password | - | `character varying` | - |
| `validate_reset_token` | Valida token di reset verificando validità, scadenza e stato attivo | `p_token character varying` | `character varying` | - |
| `reset_password_with_token` | Esegue reset password con token e invalida tutti i token utente | `p_token character varying, ...` | `character varying` | - |
| `request_password_reset_retool` | Procedura principale per Retool con messaggi italiani | `p_email character varying, ...` | `void` | - |
| `check_reset_rate_limit` | Verifica numero tentativi reset negli ultimi 15 minuti per email | `p_email character varying` | `integer` | - |
| `get_reset_stats` | Genera statistiche sistema reset password per periodo specificato | `p_days integer` | `character varying` | - |

---

## 2. Gestione Multi-Tenant e Aziende
Funzioni per la gestione della struttura SaaS (Tenant, Aziende, Organizzazioni) e funzionalità SuperAdmin.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_app_create_azienda` | Crea nuova azienda/tenant (solo SuperAdmin) | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_update_azienda` | Aggiorna dati azienda esistente (solo SuperAdmin) | `p_azienda_id integer, ...` | `jsonb` | - |
| `fn_app_toggle_azienda_status` | Attiva/disattiva stato azienda (solo SuperAdmin) | `p_azienda_id integer, ...` | `jsonb` | - |
| `fn_app_get_all_aziende` | Recupera lista paginata di tutte le aziende con filtri e ricerca per SuperAdmin | `p_user_id uuid, ...` | `jsonb` | - |
| `fn_app_get_azienda_by_id` | Recupera dettaglio singola azienda per ID o tenant_id | `p_azienda_id integer` | `jsonb` | - |
| `current_azienda` | Restituisce ID azienda corrente per ruoli azienda-specifici | - | `integer` | - |
| `fn_superadmin_get_all_companies` | Recupera tutte le aziende cross-tenant per SuperAdmin | `p_user_id uuid, ...` | `jsonb` | - |
| `fn_superadmin_query_table` | SELECT generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_update_table` | UPDATE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_delete_from_table` | DELETE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_describe_table` | DESCRIBE schema tabella per SuperAdmin | `p_user_id uuid, p_table_name character varying` | `jsonb` | - |
| `get_company_print_info` | Recupera dati intestazione azienda (Ragione Sociale, Tel, PEC, Sito) per stampe | `p_azienda_id integer` | `TABLE(ragione_sociale text, telefono text, email text, sito_web text, piva text, logo_data bytea)` | `Services/Printing/TravelPrintService.cs` |
| `fn_logo_setup_master_detail_relation` | - | - | `jsonb` | - |

---

## 3. Geografia
Funzioni CRUD e di lookup per nazioni, regioni, province e comuni.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_app_get_all_countries` | Recupera tutte le nazioni con paginazione, ricerca e ordinamento | `p_tenant_id character varying, ...` | `jsonb` | - |
| `fn_app_get_country_by_id` | Recupera una nazione specifica per ID | `p_country_id integer` | `jsonb` | - |
| `fn_app_create_country` | Crea una nuova nazione | `p_name character varying, ...` | `jsonb` | - |
| `fn_app_update_country` | Aggiorna una nazione esistente | `p_country_id integer, ...` | `jsonb` | - |
| `fn_app_delete_country` | Elimina una nazione | `p_country_id integer` | `jsonb` | - |
| `fn_app_get_country_regions_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_country_sub_regions_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_country_intermediates_lookup` | - | - | `TABLE(value integer, label character varying)` | - |
| `fn_app_get_all_geo_regioni_itas` | Lista paginata regioni con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_geo_regioni_itas_lookup` | Lookup regioni per combobox | - | `jsonb` | - |
| `fn_app_get_all_geo_provinces` | Lista paginata province con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_geo_provinces_lookup` | Lookup province per combobox | - | `jsonb` | - |
| `fn_app_get_all_geo_comunis` | Lista paginata comuni con ricerca e ordinamento | `p_tenant_id text, ...` | `jsonb` | - |
| `fn_app_get_geo_comunis_lookup` | Lookup comuni per combobox | - | `jsonb` | - |
| `fn_app_get_comune_by_id` | Recupera un singolo comune formattato per ID con formato 'CAP - COMUNE (PROVINCIA)' | `p_comune_id integer` | `TABLE(comune_id integer, comune_formatted text, ...)` | - |
| `fn_app_get_comuni_lookup` | - | `p_search_term text, ...` | `TABLE(comune_id integer, comune_formatted text, ...)` | - |

---

## 4. Gestione Viaggi
Funzioni core per la gestione dei viaggi (`ana_viaggi` e `ana_date_viaggi`).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `get_all_travel_detail` | Restituisce tutti i dettagli di un singolo viaggio (Data Viaggio) incrociando ana_date_viaggi, ana_viaggi e vari lookup | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/Printing/TravelPrintService.cs` |
| `check_possible_duplicate_travels` | Identifica potenziali duplicati dei viaggi basandosi su parole chiave nella descrizione | `p_description text, p_azienda_id integer` | `TABLE(...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_viaggi_grouped_by_year` | Restituisce viaggi e date viaggi raggruppati per anno con stato. Usato per TreeView. | `p_azienda_id integer` | `TABLE(...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_datetrips_fromtrip` | - | `p_viaggio_id integer` | `TABLE(data_viaggio_id integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_viaggio_partecipanti` | - | `p_data_viaggio_id integer` | `TABLE(gruppo_id integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_travel_stats` | Calcola totali partecipanti, equipaggi e veicoli per una data viaggio | `p_data_viaggio_id integer` | `TABLE(total_participants, ...)` | `Services/Printing/TravelPrintService.cs` |

---

## 5. Partecipanti e Alloggi
Funzioni per la gestione dei partecipanti (`mov_clienti_viaggi`) e delle rooming list (`mov_clienti_alloggi`).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `sp_mov_clienti_viaggi_create` | Iscrive partecipante al viaggio | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_update` | Aggiorna dati iscrizione partecipante | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_delete` | Rimuove partecipante dal viaggio (con cleanup alloggi) | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_sorted` | Restituisce partecipanti ordinati per equipaggio, inclusi dati anagrafici e documenti completi. | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_count` | Conteggio totale partecipanti efficiente | `p_data_viaggio_id integer` | `integer` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_without_accommodation` | Restituisce solo partecipanti senza camera assegnata | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_alloggi_create` | Crea associazione cliente-alloggio | `p_viaggio_id integer, ...` | `integer` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_assign_to_first_free_slot` | Assegna cliente al primo slot libero in modo atomico | `p_alloggio_pk integer, p_cliente_id integer` | `boolean` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `get_rooms_with_occupants` | Restituisce camere con occupanti aggregati (ARRAY) | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `get_rooming_list_data` | Dati completi per stampa Rooming List | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/Printing/RoomingListPrintService.cs` |
| `get_client_travel_history` | - | `p_cliente_id integer, p_azienda_id integer` | `TABLE(data_viaggio_id integer, ...)` | - |
| `get_pilots_grouped_by_vehicle` | Restituisce SOLO i piloti ordinati per mezzo | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/Printing/TravelPrintService.cs` |
| `chk_room_consistency_on_delete` | Verifica violazioni capacità camera prima di cancellazione | `p_data_viaggio_id integer, ...` | `TABLE(...)` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_resolve_room_violation_move` | Sposta superstiti in nuova camera e pulisce vecchia | `p_old_room_id integer, ...` | `void` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `sp_remove_client_from_room` | Rimuove cliente da camera compattando slot | `p_room_id integer, p_cliente_id integer` | `void` | - |

---

## 6. Finanza e Valute
Funzioni per la gestione di valute e tassi di cambio.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_tasso_cambio` | Restituisce il tasso di cambio per una coppia di valute (ISO o ID) e una data specifica. **Logica avanzata**: se il tasso non esiste per la data richiesta, cerca il più recente disponibile. Se la coppia diretta non esiste, tenta il calcolo inverso (1/tasso). | `p_iso_da VARCHAR, p_iso_a VARCHAR, p_data DATE` (Overload: `p_valuta_da INT, ...`) | `NUMERIC(15,6)` | - |
| `fn_calcola_importo_eur` | **Trigger Function**: Calcola automaticamente il controvalore in EUR per ogni transazione inserita o modificata in `mov_transazioni`, utilizzando il tasso di cambio della data transazione. | TRIGGER (NEW/OLD record) | TRIGGER `trg_calcola_importo_eur` | - |

---

## 7. Statistiche e Utility di Sistema
Funzioni di manutenzione, log, validazione e calcolo statistiche.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_log_business_event` | Registra un evento nella tabella ana_business_events | `p_event_type varchar, ...` | `void` | - |
| `cleanup_business_events` | Elimina vecchi log degli eventi di business | `p_days_to_keep integer` | `void` | `Services/Shared/RecentActivityService.cs` |
| `fn_get_monthly_trend` | Calcola trend mensile (conteggio records) per una tabella | `p_table_name text, ...` | `TABLE(month_num, count_val)` | `Services/CRUD/StatisticBase.cs` |
| `fn_app_health_check` | - | - | `json` | `Services/Authentication/AuthenticationService.cs` |
| `validate_email_format` | - | `p_email text` | `boolean` | - |
| `validate_partita_iva` | - | `piva text` | `boolean` | - |
| `validate_codice_fiscale` | - | `cf text` | `boolean` | - |
| `fn_test_smtp_config` | - | `p_smtp_id uuid` | `TABLE(success boolean, ...)` | - |
| `sp_ana_aziende_smtp_test_connection` | - | `p_smtp_id uuid` | `TABLE(success boolean, ...)` | - |
| `cleanup_expired_tokens` | Pulizia automatica token scaduti e dati obsoleti | - | `integer` | - |

---

## 8. Implementazioni Service-Side (Logica Applicativa)
Nota: Queste non sono funzioni DB, ma descrizioni di logica C# rilevante.

| Componente | Funzionalità | Descrizione | Files Coinvolti |
| :--- | :--- | :--- | :--- |
| `ComuneService` | Decodifica Geografica | Esegue JOIN su `ana_geo_province`, `ana_geo_regioni_ita` per recuperare Sigla Provincia e Nome Regione. | `Services/CRUD/ComuneService.cs` |
