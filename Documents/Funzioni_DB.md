# Funzioni Database (PostgreSQL)

Questo documento elenca le funzioni e stored procedure del database, raggruppate per area funzionale.

---

## 1. Sicurezza e Utenti
Funzioni relative all'autenticazione, gestione utenti, ruoli e permessi.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_app_login` | Login con auto-detect tenant. Restituisce dati utente completi inclusi `valuta_default_id` e `valuta_codice_iso` tramite JOIN con `ana_valute`. | `p_email citext, p_password text` | `jsonb` (include: user_id, email, nome, cognome, role_code, role_name, azienda_id, valuta_default_id, **valuta_codice_iso**, last_login_at) | `Services/Authentication/AuthenticationService.cs`, `Models/UserInfo.cs` |
| `fn_app_login_text` | Versione text-based di fn_app_login. Restituisce dati utente completi inclusi `valuta_default_id` e `valuta_codice_iso` tramite JOIN con `ana_valute`. | `p_email text, p_password text` | `jsonb` (include: user_id, email, nome, cognome, role_code, role_name, azienda_id, valuta_default_id, **valuta_codice_iso**, last_login_at) | `Services/Authentication/AuthenticationService.cs`, `Models/UserInfo.cs` |
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

## 4. Gestione IVA (Contabilità)
Funzioni per la gestione delle aliquote IVA e calcolo automatico su transazioni contabili.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_ana_aliquote_iva_get_all` | Recupera tutte le aliquote IVA per azienda ordinate per ordinamento e descrizione | `p_azienda_id INTEGER` | `TABLE(iva_id INT, azienda_fk INT, iva_codice VARCHAR, iva_descrizione VARCHAR, iva_percentuale NUMERIC, iva_natura VARCHAR, is_default BOOL, is_active BOOL, ordinamento SMALLINT, created_at TIMESTAMPTZ, created_by VARCHAR, updated_at TIMESTAMPTZ, updated_by VARCHAR)` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `fn_ana_aliquote_iva_get_active` | Recupera solo le aliquote IVA attive (is_active = TRUE) per azienda - usato per dropdown UI | `p_azienda_id INTEGER` | `TABLE(iva_id INT, azienda_fk INT, iva_codice VARCHAR, iva_descrizione VARCHAR, iva_percentuale NUMERIC, iva_natura VARCHAR, is_default BOOL, is_active BOOL, ordinamento SMALLINT)` | `Components/Shared/AliquotaIvaSelect.razor` |
| `fn_ana_aliquote_iva_get_default` | Recupera l'aliquota IVA default (is_default = TRUE) per azienda - max 1 per azienda garantita da trigger | `p_azienda_id INTEGER` | `TABLE(iva_id INT, azienda_fk INT, iva_codice VARCHAR, iva_descrizione VARCHAR, iva_percentuale NUMERIC, iva_natura VARCHAR, is_default BOOL, is_active BOOL, ordinamento SMALLINT)` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `sp_ana_aliquote_iva_create` | Crea nuova aliquota IVA con normalizzazione UPPER CASE su iva_codice. Gestisce auto-setting di default se prima aliquota azienda | `p_azienda_id INTEGER, p_iva_codice VARCHAR, p_iva_descrizione VARCHAR, p_iva_percentuale NUMERIC, p_iva_natura VARCHAR (nullable), p_is_default BOOLEAN, p_is_active BOOLEAN, p_ordinamento SMALLINT, p_created_by VARCHAR (nullable)` | `RETURNS INTEGER (iva_id)` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `sp_ana_aliquote_iva_update` | Aggiorna aliquota IVA esistente con normalizzazione UPPER CASE. Trigger auto-rimuove default da altre se impostato | `p_iva_id INTEGER, p_iva_codice VARCHAR, p_iva_descrizione VARCHAR, p_iva_percentuale NUMERIC, p_iva_natura VARCHAR (nullable), p_is_default BOOLEAN, p_is_active BOOLEAN, p_ordinamento SMALLINT, p_updated_by VARCHAR (nullable)` | `RETURNS VOID` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `sp_ana_aliquote_iva_delete` | Soft delete aliquota IVA (imposta is_active = FALSE). Impedisce eliminazione fisica se FK da mov_transazioni | `p_iva_id INTEGER` | `RETURNS VOID` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `sp_ana_aliquote_iva_set_default` | Imposta aliquota come default (rimuove flag da altre). Transazione atomica per garantire single default | `p_iva_id INTEGER, p_azienda_id INTEGER` | `RETURNS VOID` | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `fn_calcola_iva_transazione` | **TRIGGER FUNCTION** - Calcola automaticamente IVA su INSERT/UPDATE mov_transazioni. **Aggiornata 2026-02-15**: Migliorata logica di **scorporo inverso**: se viene fornito solo il LORDO, calcola automaticamente Imponibile e IVA basandosi sull'aliquota. Mantiene priorità ai valori manuali se completi. Garantisce integrità dati per constraint `chk_iva_completeness`. | Trigger BEFORE INSERT OR UPDATE su `mov_transazioni` | Ricalcola: `transazione_imponibile_eur, transazione_iva_eur, transazione_lordo_eur` | `SqlScripts/Fix_Trigger_IVACalc.sql` |

**Note Implementative IVA:**

1. **Metadata-Driven**: Tutta la logica IVA è configurata nei metadati di `ana_tipi_causali` (causale_genera_iva, causale_richiede_iva, causale_aliquota_iva_default_fk)
2. **Auto-Determinazione Modalità**: Trigger determina automaticamente se scorporare (LORDO - PASSIVO) o calcolare (NETTO - ATTIVO) basandosi su causale_ciclo
3. **Regola d'Oro - Correzioni Manuali**: Se utente compila TUTTI e TRE i campi IVA manualmente, trigger NON ricalcola ma valida solo coerenza matematica (tolleranza ±0.01€)
4. **IVA Solo EUR**: Automaticamente azzerata per valute estere (Fuori Campo IVA art. 7-ter)
5. **Validazione Obbligatoria**: Causali che marcano `causale_richiede_iva = TRUE` bloccano INSERT se aliquota mancante

---

## 5. Gestione Viaggi
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
| `fn_validate_data_documento` | **Trigger Function** (2026-02-08): Valida che le transazioni in valuta estera (non EUR) abbiano obbligatoriamente la `transazione_data_documento` popolata. Blocca INSERT/UPDATE con messaggio esplicito se la validazione fallisce. Questo garantisce che il tasso di cambio possa essere recuperato correttamente dalla Frankfurter API usando la data del documento. | TRIGGER (NEW record) | TRIGGER `trg_validate_data_documento` (BEFORE INSERT OR UPDATE) | `SqlScripts/Migration_AddDataDocumentoConstraint.sql` |
| `fn_calcola_importo_eur` | **TRIGGER FUNCTION** (Aggiornata 2026-02-15): Calcola automaticamente il controvalore in EUR. **New Feature**: Rileva automaticamente se la transazione è già in Valuta Base (EUR) e copia direttamente gli importi senza lookup su tassi cambio, prevenendo errori su date future/mancanti. Per valute estere, usa `transazione_data_documento` per recuperare il tasso e popola metadata storico. | TRIGGER (NEW/OLD record) | TRIGGER `trg_calcola_importo_eur` (BEFORE INSERT OR UPDATE) | `SqlScripts/Fix_Trigger_Importo_EUR.sql` |
| `fn_get_fatturato_annuale` | Calcola il fatturato annuale (entrate) per un'azienda convertito nella valuta target. Filtra per tipo movimento 'ENTRATA' e stato != 'ANNULLATO'. Usa l'anno di `transazione_data_documento` (con fallback a `transazione_data`). **Conversione valuta**: applica il tasso di cambio alla data del documento usando `fn_get_tasso_cambio`. | `p_azienda_id INTEGER, p_anno INTEGER, p_valuta_target_id INTEGER` | `NUMERIC(15,2)` | `Statistics/StatisticRevenue.cs` |
| `fn_get_fatturato_periodo` | Calcola il fatturato per un periodo specifico (date esatte) convertito nella valuta target. Utilizzato per confronti Period-over-Period. Filtra per tipo movimento 'ENTRATA' e stato != 'ANNULLATO'. **Conversione valuta**: applica il tasso di cambio alla data del documento. | `p_azienda_id INTEGER, p_data_inizio DATE, p_data_fine DATE, p_valuta_target_id INTEGER` | `NUMERIC(15,2)` | `Statistics/StatisticRevenue.cs` |
| `fn_get_fatturato_mensile_trend` | Restituisce il trend mensile del fatturato per un anno specifico. Restituisce sempre 12 righe (gennaio-dicembre) con valore 0 per mesi senza entrate. **Conversione valuta**: applica il tasso di cambio alla data del documento per ogni transazione. | `p_azienda_id INTEGER, p_anno INTEGER, p_valuta_target_id INTEGER` | `TABLE(mese INTEGER, fatturato NUMERIC(15,2))` | `Statistics/StatisticRevenue.cs` |

### 📝 Note Implementative - Gestione Tassi di Cambio (2026-02-08)

**Nuovi Campi Tabella `mov_transazioni`**:
- `transazione_tasso_cambio_applicato` (NUMERIC(15,6)): Tasso effettivamente utilizzato per la conversione
- `transazione_tasso_fonte` (VARCHAR(50)): Fonte del tasso (FRANKFURTER_API, FALLBACK_DB, FALLBACK_DB_INVERSO, EUR_BASE)
- `transazione_tasso_data_validita` (DATE): Data di validità del tasso applicato

**Flusso Automatico Recupero Tassi**:
1. L'utente inserisce una transazione in valuta estera (es. USD) tramite UI
2. `MovTransazioniService.CreateAsync()` chiama `ExchangeRateService.UpdateRateForDateAsync()` PRIMA del salvataggio
3. Frankfurter API viene interrogata: `https://api.frankfurter.app/YYYY-MM-DD?from=EUR&to=USD` (timeout 5 secondi)
4. Se API OK → tasso salvato in `ana_tassi_cambio` con fonte FRANKFURTER_API
5. Se API timeout/errore → warning message generato per l'utente
6. INSERT/UPDATE in `mov_transazioni` → trigger `trg_validate_data_documento` verifica data_documento presente
7. Trigger `trg_calcola_importo_eur` calcola importo EUR e memorizza metadata tasso
8. UI mostra toast SUCCESS + eventuale toast WARNING (5 sec) se usato fallback

**File Documentazione Completa**: `Documents/Changelog_ExchangeRateIntegration.md`

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

## 8. Contabilità - Aliquote IVA

Funzioni CRUD per la gestione delle aliquote IVA multi-tenant con supporto fatturazione elettronica.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_ana_aliquote_iva_get_all` | Recupera tutte le aliquote IVA per azienda, ordinate per ordinamento e descrizione. Usato dalla griglia principale. | `p_azienda_id INTEGER` | `SETOF ana_aliquote_iva` (tutte le colonne) | `Services/CRUD/AnaAliquoteIvaService.cs`, `Components/Pages/Tabelle/AnaAliquoteIvaPage.razor` |
| `fn_ana_aliquote_iva_get_active` | Recupera solo le aliquote IVA attive per azienda. Usato nei dropdown/combobox per selezione aliquota nelle transazioni. | `p_azienda_id INTEGER` | `SETOF ana_aliquote_iva` (solo record con `is_active = TRUE`) | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `fn_ana_aliquote_iva_get_default` | Recupera l'aliquota IVA default per azienda (preselezionata in UI). | `p_azienda_id INTEGER` | `ana_aliquote_iva` (singolo record o NULL) | `Services/CRUD/AnaAliquoteIvaService.cs` |
| `sp_ana_aliquote_iva_create` | Crea nuova aliquota IVA con validazione completa. **Normalizzazione automatica**: forza UPPER CASE su codice, descrizione e natura FE. **Validazioni**: azienda obbligatoria, codice/descrizione non vuoti, percentuale 0-100. **Gestione errori**: DUPLICATE_CODICE (unique violation), INVALID_AZIENDA (FK violation), INVALID_DATA (check constraint). | `p_azienda_fk INTEGER, p_iva_codice VARCHAR(10), p_iva_descrizione VARCHAR(100), p_iva_percentuale NUMERIC(5,2), p_iva_natura VARCHAR(10), p_is_default BOOLEAN, p_is_active BOOLEAN, p_ordinamento SMALLINT, p_created_by VARCHAR(50), p_updated_by VARCHAR(50)` | `INTEGER` (iva_id del record creato) | `Services/CRUD/AnaAliquoteIvaService.cs`, `Components/Pages/Tabelle/AnaAliquoteIvaEditDialog.razor` |
| `sp_ana_aliquote_iva_update` | Aggiorna aliquota IVA esistente con validazione. **Normalizzazione automatica**: forza UPPER CASE. **Validazioni**: verifica esistenza record, campi obbligatori non vuoti. **Gestione errori**: RECORD_NOT_FOUND, DUPLICATE_CODICE, INVALID_DATA. | `p_iva_id INTEGER, p_iva_codice VARCHAR(10), p_iva_descrizione VARCHAR(100), p_iva_percentuale NUMERIC(5,2), p_iva_natura VARCHAR(10), p_is_default BOOLEAN, p_is_active BOOLEAN, p_ordinamento SMALLINT, p_updated_by VARCHAR(50)` | `VOID` | `Services/CRUD/AnaAliquoteIvaService.cs`, `Components/Pages/Tabelle/AnaAliquoteIvaEditDialog.razor` |
| `sp_ana_aliquote_iva_delete` | Elimina aliquota IVA. Blocca eliminazione se in uso da altre tabelle (es. transazioni). **Gestione errori**: RECORD_NOT_FOUND, RECORD_IN_USE (FK violation). | `p_iva_id INTEGER` | `VOID` | `Services/CRUD/AnaAliquoteIvaService.cs`, `Components/Pages/Tabelle/AnaAliquoteIvaPage.razor` |
| `sp_ana_aliquote_iva_set_default` | Imposta un'aliquota come default per azienda. **Automazione**: il trigger `fn_check_single_default_iva` rimuove automaticamente il flag `is_default` dalle altre aliquote della stessa azienda, garantendo che solo 1 aliquota per azienda sia default. | `p_iva_id INTEGER, p_azienda_id INTEGER` | `VOID` | `Services/CRUD/AnaAliquoteIvaService.cs` |

### 📝 Note Implementative - Aliquote IVA (2026-02-14)

**Architettura DB-First Completa**:
- ✅ **Zero SQL diretto** in `AnaAliquoteIvaService.cs` - tutte le operazioni delegate al database
- ✅ Normalizzazione UPPER CASE gestita lato database (stored procedures)
- ✅ Validazioni business rules nel database (constraint + procedure logic)
- ✅ Trigger `fn_check_single_default_iva` garantisce constraint "single default per azienda"
- ✅ Trigger `fn_touch_updated_at_iva` aggiorna automaticamente `updated_at` su ogni modifica

**Constraint e Validazioni DB**:
- `uk_iva_azienda_codice`: UNIQUE su (azienda_fk, iva_codice) - previene duplicati
- `chk_iva_percentuale`: CHECK percentuale tra 0 e 100
- `chk_iva_codice_upper`: CHECK codice sempre UPPER CASE
- Trigger automatic single default enforcement

**Codici Natura FE Supportati** (Fatturazione Elettronica):
- `N1`: Escluso art. 15 (es. Fuori Campo IVA)
- `N2.x`: Non soggetto (es. N2.1 Regime forfettario)
- `N3.x`: Non imponibile (es. N3.1 Esportazioni)
- `N4`: Esente IVA
- `N5`: Regime margine
- `N6.x`: Reverse charge
- `N7`: Altro

**File SQL**: `SqlScripts/Create_AnaAliquoteIva.sql` (tabella + trigger), `SqlScripts/Create_AnaAliquoteIva_CRUD.sql` (stored functions)

---

## 8.1. Contabilità - Tipi Causali

Funzioni CRUD per la gestione dei tipi di causale contabile con metadati IVA e scadenze.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_ana_tipi_causali_get_all` | Recupera tutte le causali per azienda, ordinate per ciclo e descrizione. Usato dalla griglia principale. | `p_azienda_id INTEGER` | `SETOF ana_tipi_causali` (tutte le colonne) | `Services/CRUD/AnaTipiCausaliService.cs` |
| `fn_ana_tipi_causali_get_active` | Recupera solo le causali attive per azienda. Usato nei dropdown/combobox per selezione causale nelle transazioni. | `p_azienda_id INTEGER` | `SETOF ana_tipi_causali` (solo record con `is_active = TRUE`) | `Services/CRUD/AnaTipiCausaliService.cs` |
| `fn_ana_tipi_causali_get_active_by_ciclo` | Recupera causali attive filtrate per ciclo contabile (ATTIVO/PASSIVO). Usato nei filtri transazioni per mostrare solo causali del ciclo selezionato. | `p_azienda_id INTEGER, p_ciclo VARCHAR(10)` | `SETOF ana_tipi_causali` (record attivi del ciclo specificato) | `Services/CRUD/AnaTipiCausaliService.cs` |
| `sp_ana_tipi_causali_create` | Crea nuova causale con validazione completa. **Normalizzazione automatica**: forza UPPER CASE su codice, descrizione e ciclo. **Validazioni**: azienda obbligatoria, codice/descrizione non vuoti, ciclo ATTIVO/PASSIVO, segno ±1. **Gestione errori**: DUPLICATE_CODICE (unique violation), INVALID_AZIENDA (FK violation), INVALID_DATA (check constraint). | `p_azienda_fk INTEGER, p_causale_codice VARCHAR(10), p_causale_descrizione VARCHAR(100), p_causale_segno INTEGER, p_causale_is_documento BOOLEAN, p_causale_ciclo VARCHAR(10), p_causale_richiede_scadenza BOOLEAN, p_causale_giorni_scadenza_default INTEGER, p_causale_genera_scadenza_auto BOOLEAN, p_causale_genera_iva BOOLEAN, p_causale_richiede_iva BOOLEAN, p_causale_aliquota_iva_default_fk INTEGER, p_is_active BOOLEAN, p_created_by VARCHAR(50), p_updated_by VARCHAR(50)` | `INTEGER` (causale_id del record creato) | `Services/CRUD/AnaTipiCausaliService.cs` |
| `sp_ana_tipi_causali_update` | Aggiorna causale esistente con validazione. **Normalizzazione automatica**: forza UPPER CASE. **Validazioni**: verifica esistenza record, campi obbligatori non vuoti, ciclo ATTIVO/PASSIVO, segno ±1. **Gestione errori**: RECORD_NOT_FOUND, DUPLICATE_CODICE, INVALID_DATA, INVALID_REFERENCE. | `p_causale_id INTEGER, p_causale_codice VARCHAR(10), p_causale_descrizione VARCHAR(100), p_causale_segno INTEGER, p_causale_is_documento BOOLEAN, p_causale_ciclo VARCHAR(10), p_causale_richiede_scadenza BOOLEAN, p_causale_giorni_scadenza_default INTEGER, p_causale_genera_scadenza_auto BOOLEAN, p_causale_genera_iva BOOLEAN, p_causale_richiede_iva BOOLEAN, p_causale_aliquota_iva_default_fk INTEGER, p_is_active BOOLEAN, p_updated_by VARCHAR(50)` | `VOID` | `Services/CRUD/AnaTipiCausaliService.cs` |
| `sp_ana_tipi_causali_delete` | Elimina causale. Blocca eliminazione se in uso da transazioni. **Gestione errori**: RECORD_NOT_FOUND, RECORD_IN_USE (FK violation). | `p_causale_id INTEGER` | `VOID` | `Services/CRUD/AnaTipiCausaliService.cs` |

### 📝 Note Implementative - Tipi Causali (2026-02-14)

**Architettura DB-First Completa**:
- ✅ **Zero SQL diretto** in `AnaTipiCausaliService.cs` - tutte le operazioni delegate al database
- ✅ Normalizzazione UPPER CASE gestita lato database (stored procedures)
- ✅ Validazioni business rules nel database (constraint + procedure logic)
- ✅ Gestione metadati IVA per trigger automatico calcolo IVA (STEP 3 - Implementazione_IVA.md)

**Metadati IVA (Nuovi dal 2026-02-14)**:
- `causale_genera_iva`: TRUE se la causale può avere IVA (FT, FV, ND, NDA)
- `causale_richiede_iva`: TRUE se IVA è obbligatoria (trigger validerà presenza aliquota)
- `causale_aliquota_iva_default_fk`: FK a aliquota IVA preselezionata in UI

**Constraint e Validazioni DB**:
- `chk_iva_richiede_implica_genera`: Se richiede IVA obbligatoria, deve anche generare IVA
- Unique constraint su (azienda_fk, causale_codice) - previene duplicati
- Check segno ±1 e ciclo ATTIVO/PASSIVO

**File SQL**: `SqlScripts/Create_AnaTipiCausali_CRUD.sql`, `SqlScripts/Migration_Add_Causale_IVA_Metadata.sql` (metadati IVA)

---

## 9. Contabilità - Stampe e Report

Funzioni per l'estrazione dati e report PDF dei movimenti contabili.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_transazioni_stampa_dettaglio` | Estrae dettagli transazioni con chiave raggruppamento dinamica (CONTROPARTE/DATA_DOCUMENTO/TIPO_MOVIMENTO) e conversione valuta target. Supporta nuovi campi IVA (imponibile, iva, lordo), aliquote e filtro per Ciclo Contabile. Utilizza `fn_get_tasso_cambio` con tasso storicizzato basato su `transazione_data_documento`. | `p_azienda_id INT, p_controparte_id INT, p_causale_tipo_id INT, p_stati VARCHAR[], p_viaggio_id INT, p_data_viaggio_id INT, p_valuta_id INT, p_data_transazione_da DATE, p_data_transazione_a DATE, p_data_documento_da DATE, p_data_documento_a DATE, p_importo_da NUMERIC, p_importo_a NUMERIC, p_numero_documento VARCHAR, p_solo_con_documento BOOL, p_solo_scadute BOOL, p_solo_con_viaggio BOOL, p_solo_senza_viaggio BOOL, p_solo_con_fattura BOOL, p_ordinamento VARCHAR DEFAULT 'CONTROPARTE', p_valuta_target_id INT, p_causale_ciclo VARCHAR` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INT, transazione_id INT, transazione_data DATE, transazione_data_documento DATE, transazione_data_scadenza DATE, transazione_data_pagamento DATE, controparte_ragione_sociale VARCHAR, transazione_tipo_movimento VARCHAR, transazione_causale VARCHAR, causale_ciclo VARCHAR, transazione_stato VARCHAR, transazione_numero_documento VARCHAR, valuta_codice_iso VARCHAR, imponibile_eur NUMERIC, iva_eur NUMERIC, lordo_eur NUMERIC, aliquota_iva_codice VARCHAR, aliquota_iva_percentuale NUMERIC, importo_valuta_target NUMERIC, valuta_target_iso VARCHAR, viaggio_descrizione VARCHAR, data_viaggio_data_inizio DATE)` | `Services/Printing/MovTransazioniPrintService.cs`, `SqlScripts/fn_get_transazioni_stampa_dettaglio.sql` |
| `fn_get_transazioni_stampa_subtotali` | Calcola sub-totali aggregati per gruppo/valuta e totali generali usando GROUPING SETS. Fornisce totali per Imponibile, IVA e Lordo convertiti in valuta target. Il flag `is_totale_generale` distingue sub-totali di gruppo da totali complessivi. **Updated 2026-02-15**: Utilizza `ABS()` sugli importi prima di applicare il segno della causale per evitare "doppie negazioni" e garantire saldi corretti anche per pagamenti/note credito. | `p_azienda_id INT, p_controparte_id INT, p_causale_tipo_id INT, p_stati VARCHAR[], p_viaggio_id INT, p_data_viaggio_id INT, p_valuta_id INT, p_data_transazione_da DATE, p_data_transazione_a DATE, p_data_documento_da DATE, p_data_documento_a DATE, p_importo_da NUMERIC, p_importo_a NUMERIC, p_numero_documento VARCHAR, p_solo_con_documento BOOL, p_solo_scadute BOOL, p_solo_con_viaggio BOOL, p_solo_senza_viaggio BOOL, p_solo_con_fattura BOOL, p_ordinamento VARCHAR DEFAULT 'CONTROPARTE', p_valuta_target_id INT, p_causale_ciclo VARCHAR` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INT, valuta_codice_iso VARCHAR, totale_valuta_originale NUMERIC, totale_valuta_target NUMERIC, totale_imponibile_target NUMERIC, totale_iva_target NUMERIC, totale_fatturato_target NUMERIC, totale_pagato_target NUMERIC, valuta_target_iso VARCHAR, conteggio_transazioni INT, is_totale_generale BOOL)` | `Services/Printing/MovTransazioniPrintService.cs`, `SqlScripts/fn_get_transazioni_stampa_subtotali.sql` |
| `fn_get_transazioni_per_stampa` | Function base per estrazione transazioni con filtri. Restituisce dettagli transazioni con JOIN su fornitori, valute, viaggi. **Nota**: sostituita da `fn_get_transazioni_stampa_dettaglio` per report con raggruppamenti. | `p_azienda_id INT, p_fornitore_id INT, p_tipo_movimento VARCHAR, p_stati VARCHAR[], ...` | `TABLE(transazione_id INT, ...)` | `Services/CRUD/MovTransazioniService.cs` |
| `fn_get_scadenzario_stampa` | Estrae dati scadenzario per stampa PDF con raggruppamento dinamico. Utilizza la vista `vw_scadenzario` come base e supporta 3 tipi di raggruppamento: **URGENZA** (SCADUTO/URGENTE/IN_SCADENZA/NORMALE), **MESE** (per mese di scadenza), **CONTROPARTE** (per fornitore/cliente). Applica filtri multipli su azienda, controparte, ciclo contabile (ATTIVO/PASSIVO), urgenza, intervallo date scadenza e viaggio. Focus su pianificazione finanziaria cash flow. | `p_azienda_id INTEGER, p_controparte_id INTEGER, p_causale_ciclo VARCHAR(10), p_urgenza VARCHAR(20), p_data_scadenza_da DATE, p_data_scadenza_a DATE, p_viaggio_id INTEGER, p_solo_con_viaggio BOOLEAN, p_solo_senza_viaggio BOOLEAN, p_raggruppamento VARCHAR(20) DEFAULT 'URGENZA'` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INTEGER, transazione_id INTEGER, data_scadenza DATE, data_documento DATE, numero_documento VARCHAR, controparte_ragione_sociale VARCHAR, causale_ciclo VARCHAR, causale_descrizione VARCHAR, importo_originale NUMERIC, residuo NUMERIC, valuta_codice_iso VARCHAR, giorni_a_scadenza INTEGER, urgenza VARCHAR, stato VARCHAR, viaggio_descrizione TEXT, note TEXT)` | `Services/Printing/ScadenzarioPrintService.cs`, `Scripts/Migrazione_Contabile/08_crea_function_scadenzario_stampa.sql` |

### 📝 Note Implementative - Report PDF Transazioni (2026-02-09)

**Architettura DB-Centric**:
- Tutta la logica di raggruppamento, ordinamento e calcolo sub-totali è gestita nel DB
- Il client C# si limita a chiamare le function e renderizzare il PDF
- Conversione valuta utilizza tassi storici basati sulla data documento

**Flusso Generazione Report**:
1. Utente apre `StampaMovimentiDialog.razor` e seleziona filtri
2. `MovTransazioniPrintService.GetDataPerStampaAsync()` chiama entrambe le function DB
3. `MovTransazioniPrinter.GeneratePdfAsync()` genera PDF A4 landscape con QuestPDF
4. PDF aperto automaticamente tramite `Launcher.OpenAsync()`

**Ordinamenti Supportati**:
- `FORNITORE`: Raggruppa per ragione sociale fornitore
- `DATA_DOCUMENTO`: Raggruppa per mese/anno (es. "Febbraio 2026")
- `TIPO_MOVIMENTO`: Raggruppa per Entrate/Uscite
- `IMPORTO_ASC` / `IMPORTO_DESC`: Nessun raggruppamento, solo ordinamento

### 📝 Note Implementative - Report PDF Scadenzario (2026-02-16)

**Architettura DB-First**:
- Query scadenzario delegata completamente alla function DB `fn_get_scadenzario_stampa`
- Zero SQL diretto in `ScadenzarioPrintService.cs`
- Utilizza vista `vw_scadenzario` come base dati (già definita in `07_crea_view_reportistica.sql`)
- Calcolo subtotali e aggregazioni in memoria lato C# su dati già estratti

**Flusso Generazione Scadenzario**:
1. Utente apre `StampaScadenzarioDialog.razor` e seleziona filtri (ciclo, urgenza, date, controparte)
2. `ScadenzarioPrintService.GetDataPerStampaAsync()` chiama `fn_get_scadenzario_stampa`
3. Aggregazioni subtotali calcolate in memoria (logica applicativa)
4. `ScadenzarioPrinter.GeneratePdfAsync()` genera PDF A4 landscape con QuestPDF
5. PDF con sezione Cash Flow: Entrate previste vs Uscite previste con saldo netto

**Raggruppamenti Supportati**:
- `URGENZA` (default): Priorità pagamenti - SCADUTO (rosso) → URGENTE (arancione) → IN_SCADENZA → NORMALE (verde)
- `MESE`: Analisi cash flow mensile - raggruppa per mese di scadenza
- `CONTROPARTE`: Vista per fornitore/cliente - tutti i debiti/crediti verso una controparte

**Classificazione Automatica Urgenza** (da `vw_scadenzario`):
- **SCADUTO**: transazione_data_scadenza < CURRENT_DATE (in ritardo)
- **URGENTE**: scadenza entro 7 giorni
- **IN_SCADENZA**: scadenza entro 30 giorni
- **NORMALE**: oltre 30 giorni

**Differenze vs Stampa Movimenti**:
- **Pivot diverso**: Scadenzario ordinato per data scadenza (futuro), Movimenti per controparte (passato)
- **Focus**: Scadenzario = Pianificazione finanziaria (cosa succederà), Movimenti = Riconciliazione (cosa è successo)
- **Campi chiave**: Residuo da pagare, giorni a scadenza, urgenza colorata

---

## 10. Implementazioni Service-Side (Logica Applicativa)
Nota: Queste non sono funzioni DB, ma descrizioni di logica C# rilevante.

| Componente | Funzionalità | Descrizione | Files Coinvolti |
| :--- | :--- | :--- | :--- |
| `ComuneService` | Decodifica Geografica | Esegue JOIN su `ana_geo_province`, `ana_geo_regioni_ita` per recuperare Sigla Provincia e Nome Regione. | `Services/CRUD/ComuneService.cs` |

