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
| `validate_reset_token` | Valida token di reset verificando validità, scadenza e stato attivo. Restituisce `VALID|user_id|email` se valido, `INVALID_OR_EXPIRED` altrimenti. | `p_token character varying` | `character varying` | `Services/Authentication/PasswordResetService.cs` |
| `reset_password_with_token` | Esegue reset password con token e invalida tutti i token utente. Accetta password in chiaro (hashing bcrypt nel DB). Restituisce `SUCCESS` o `INVALID_OR_EXPIRED_TOKEN`. | `p_token character varying, p_new_password_plain text` | `character varying` | `Services/Authentication/PasswordResetService.cs` |
| `fn_app_request_password_reset` | **Funzione principale per reset password dall'app MAUI.** Genera un codice a 6 cifre, controlla rate limit (3 tentativi/15 min), verifica utente attivo, disattiva token precedenti. Anti-enumeration: se email non trovata, risponde con successo senza codice. Restituisce JSONB con: success, user_found, reset_code, user_id, email, nome, azienda_id, role_code, expires_at. | `p_email citext` | `jsonb` | `Services/Authentication/PasswordResetService.cs`, `SqlScripts/80_Create_FnAppRequestPasswordReset.sql` |
| `fn_get_smtp_config_for_email` | Recupera la prima configurazione SMTP outbound attiva per un'azienda. Restituisce JSONB con host, port, username, password (decriptata da password_enc), security_method, from_name, from_email. Ritorna NULL se nessuna config trovata. | `p_azienda_id integer` | `jsonb` | `Services/Email/SmtpEmailSender.cs`, `Services/Email/EmailSenderFactory.cs`, `SqlScripts/82_Create_FnGetSmtpConfigForEmail.sql` |
| `request_password_reset_retool` | Procedura legacy per Retool con messaggi italiani. **Deprecata**: ha bug (tipo INTEGER invece di UUID per user_id, colonna is_suspended inesistente). Usare `fn_app_request_password_reset` per l'app MAUI. | `p_email character varying, ...` | `void` | - |
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
| `fn_get_azienda_badge_counts` | **Ottimizzazione Connection Leak**: Recupera in un'unica chiamata tutti i conteggi per i tab del dialog Azienda (Sedi, Contatti, Banche, Email, Reparti, SMTP, Logo). Riduce il numero di sessioni da 7 a 1. | `p_azienda_id integer` | `TABLE(sedi INT, contatti INT, banche INT, email INT, reparti INT, smtp INT, logo INT)` | `Components/Shared/AziendaDialog.razor`, `SqlScripts/250_Create_FnGetAziendaBadgeCounts.sql` |
| `current_azienda` | Restituisce ID azienda corrente per ruoli azienda-specifici | - | `integer` | - |
| `fn_superadmin_get_all_companies` | Recupera tutte le aziende cross-tenant per SuperAdmin | `p_user_id uuid, ...` | `jsonb` | - |
| `fn_superadmin_query_table` | SELECT generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_update_table` | UPDATE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_delete_from_table` | DELETE generico per SuperAdmin su qualsiasi tabella | `p_user_id uuid, p_table_name character varying, ...` | `jsonb` | - |
| `fn_superadmin_describe_table` | DESCRIBE schema tabella per SuperAdmin | `p_user_id uuid, p_table_name character varying` | `jsonb` | - |
| `get_company_print_info` | Recupera dati intestazione azienda (Ragione Sociale, Tel, PEC, Sito) per stampe. **Logo convertito in base64** per compatibilità JSON. | `p_azienda_id integer` | `TABLE(ragione_sociale text, telefono text, email text, sito_web text, piva text, logo_data text)` | `Services/Printing/TravelPrintService.cs` |
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
| `sp_assegna_protocollo_iva` | **STORED FUNCTION** - Assegna atomicamente un numero di protocollo IVA sequenziale progressivo a una transazione qualificante. **Idempotente**: se la transazione ha già un protocollo assegnato, restituisce quello esistente senza generarne uno nuovo. **Criteri Qualificazione**: la transazione deve avere `causale_genera_iva = TRUE`, valuta EUR, stato != ANNULLATO. **Numerazione**: separata per azienda, anno solare (da `transazione_data_documento` o fallback `transazione_data`), e ciclo contabile (ATTIVO/PASSIVO). Utilizza **UPSERT** con `ON CONFLICT DO UPDATE` per incremento atomico del contatore con row-level locking, garantendo sicurezza in caso di accesso concorrente. Restituisce NULL se la transazione non qualifica per un protocollo IVA. | `p_transazione_id INTEGER` | `INTEGER` (numero protocollo o NULL) | `SqlScripts/202_Create_Sp_Assegna_Protocollo_IVA.sql`, `Services/CRUD/MovTransazioniService.cs` (CreateAsync STEP 8, UpdateAsync STEP 9) |

**Note Implementative IVA:**

1. **Metadata-Driven**: Tutta la logica IVA è configurata nei metadati di `ana_tipi_causali` (causale_genera_iva, causale_richiede_iva, causale_aliquota_iva_default_fk)
2. **Auto-Determinazione Modalità**: Trigger determina automaticamente se scorporare (LORDO - PASSIVO) o calcolare (NETTO - ATTIVO) basandosi su causale_ciclo
3. **Regola d'Oro - Correzioni Manuali**: Se utente compila TUTTI e TRE i campi IVA manualmente, trigger NON ricalcola ma valida solo coerenza matematica (tolleranza ±0.01€)
4. **IVA Solo EUR**: Automaticamente azzerata per valute estere (Fuori Campo IVA art. 7-ter)
5. **Validazione Obbligatoria**: Causali che marcano `causale_richiede_iva = TRUE` bloccano INSERT se aliquota mancante

### 📝 Note Implementative - Protocollo IVA (2026-02-22)

**Nuova Tabella `mov_contatori_protocollo_iva`**:
- Tabella contatori per numerazione protocollo IVA
- Separata per: `contatore_azienda_id`, `contatore_anno` (solare), `contatore_ciclo` (ATTIVO/PASSIVO)
- Numerazione **ricomincia da 1** ogni anno per ogni combinazione azienda+ciclo
- Colonne: `contatore_id` (PK SERIAL), `contatore_azienda_id` (FK ana_aziende), `contatore_anno` (INT), `contatore_ciclo` (VARCHAR CHECK PASSIVO/ATTIVO), `contatore_ultimo_numero` (INT DEFAULT 0), `updated_at` (TIMESTAMPTZ)
- **UNIQUE constraint** su `(contatore_azienda_id, contatore_anno, contatore_ciclo)` - garantisce un solo contatore per combinazione
- **File SQL**: `SqlScripts/200_Create_MovContatoriProtocolloIva.sql`

**Nuova Colonna `mov_transazioni.transazione_numero_protocollo_iva`**:
- Tipo: `INTEGER`, nullable (NULL = transazione non-IVA o non ancora protocollata)
- **Partial index**: `idx_transazioni_protocollo_iva` su `(transazione_azienda_id, transazione_numero_protocollo_iva) WHERE transazione_numero_protocollo_iva IS NOT NULL`
- Ottimizza le query di ricerca per numero protocollo ignorando le transazioni senza protocollo
- **File SQL**: `SqlScripts/201_Migration_Add_Protocollo_IVA.sql`

**Formato Display C#** (UI e stampe):
- **Acquisti (PASSIVO)**: `ANNO/A/N` (es. 2026/A/123 = 123° acquisto IVA del 2026)
- **Vendite (ATTIVO)**: `ANNO/V/N` (es. 2026/V/45 = 45° vendita IVA del 2026)
- Implementato in: `Services/Printing/RegistroIvaPrintDTO.cs` (property `NumeroProtocolloFormatted`)

**Meccanismo UPSERT per Sicurezza Concorrente**:
- `sp_assegna_protocollo_iva` utilizza `INSERT ... ON CONFLICT (azienda, anno, ciclo) DO UPDATE SET contatore_ultimo_numero = contatore_ultimo_numero + 1 RETURNING contatore_ultimo_numero`
- Il row-level locking PostgreSQL garantisce che non vengano mai assegnati numeri duplicati anche con inserimenti concorrenti
- **Atomicità completa**: lettura + incremento + assign in un'unica transazione database

**Protezione Hard Delete**:
- `MovTransazioniService.DeleteAsync()` **blocca l'eliminazione** se `transazione_numero_protocollo_iva IS NOT NULL`
- Messaggio errore: "Impossibile eliminare la transazione perché ha un numero di protocollo IVA assegnato (ANNO/X/N). La cancellazione fisica non è consentita per garantire la continuità del registro IVA."
- Soluzione alternativa: soft delete (cambiare stato in ANNULLATO)

**Gestione Cambio Anno**:
- Se in `MovTransazioniService.UpdateAsync()` l'anno della transazione cambia (modifica `transazione_data_documento`):
  1. Il protocollo esistente viene **revocato** (impostato a NULL)
  2. Viene **riassegnato** un nuovo protocollo nell'anno corretto
- Questo garantisce che il protocollo rifletta sempre l'anno fiscale reale della transazione

**Backfill Script**:
- Script one-time per assegnare protocolli alle transazioni esistenti qualificanti
- Ordinamento: per azienda, ciclo, COALESCE(data_documento, data_transazione), transazione_id
- Garantisce che le transazioni storiche ricevano protocolli nell'ordine cronologico originale
- **File SQL**: `SqlScripts/203_Backfill_Protocollo_IVA.sql`
- **Esecuzione**: manuale, solo una volta dopo deployment della feature

**Files Coinvolti**:
- `Services/CRUD/MovTransazioniService.cs` (STEP 8 CreateAsync, STEP 9 UpdateAsync, DeleteAsync validation)
- `Services/Printing/RegistroIvaPrintDTO.cs` (NumeroProtocolloFormatted property)
- `Services/Printing/RegistroIvaPrintService.cs` (mapping nuovo campo)
- `Services/Printing/RegistroIvaPrinter.cs` (rendering colonna protocollo in PDF)
- `Models/MovTransazioni.cs` (property TransazioneNumeroProtocolloIva)
- `SqlScripts/fn_get_registro_iva.sql` (aggiornata con nuove colonne output)

---

## 5. Gestione Viaggi
Funzioni core per la gestione dei viaggi (`ana_viaggi` e `ana_date_viaggi`).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `get_all_travel_detail` | Restituisce tutti i dettagli di un singolo viaggio (Data Viaggio) incrociando ana_date_viaggi, ana_viaggi e vari lookup | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/Printing/TravelPrintService.cs` |
| `check_possible_duplicate_travels` | Identifica potenziali duplicati dei viaggi basandosi su parole chiave nella descrizione | `p_description text, p_azienda_id integer` | `TABLE(...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_viaggi_grouped_by_year` | Restituisce viaggi e date viaggi raggruppati per anno con stato. Usato per TreeView. | `p_azienda_id integer` | `TABLE(...)` | `Services/CRUD/AnaViaggiService.cs` |
| `fn_get_viaggi_with_transactions` | Restituisce solo i viaggi che hanno almeno un movimento contabile (transazione non ANNULLATA con causale documento). Include JOIN su nazioni, tipi viaggio, trattamento, pernottamento, avvicinamento e azienda. Filtra tramite EXISTS su `mov_transazioni` + `ana_tipi_causali` (causale_is_documento = TRUE). | `p_azienda_id INTEGER` (nullable: NULL o 0 = tutte le aziende) | `TABLE(viaggio_id INT, viaggio_descrizione_breve VARCHAR(255), viaggio_descrizione_estesa TEXT, viaggio_numero_giorni INT, viaggio_numero_notti INT, viaggio_pasti_al_sacco CHAR(1), viaggio_num_km INT, viaggio_note TEXT, viaggio_link VARCHAR(500), viaggio_nazione_fk INT, viaggio_tipo_viaggio_fk INT, viaggio_tipo_trattamento_fk INT, viaggio_tipo_pernottamento_fk INT, viaggio_tipo_avvicinamento_fk INT, azienda_id INT, created_by VARCHAR(50), created TIMESTAMPTZ, updated_by VARCHAR(50), updated TIMESTAMPTZ, nazione_nome VARCHAR(100), tipo_viaggi_descrizione VARCHAR(100), tipo_trattamento_descrizione VARCHAR(100), ana_tipo_pernottamento_descrizione VARCHAR(100), tipo_avvicinamento_descrizione VARCHAR(100), azienda_nome VARCHAR(255), matching_dates_count INT)` | `Services/CRUD/AnaViaggiService.cs`, `Components/Shared/StampaBilancioViaggioDialog.razor` |
| `get_datetrips_fromtrip` | - | `p_viaggio_id integer` | `TABLE(data_viaggio_id integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_viaggio_partecipanti` | - | `p_data_viaggio_id integer` | `TABLE(gruppo_id integer, ...)` | `Services/CRUD/AnaViaggiService.cs` |
| `get_mezzi_count` | Conteggio efficiente dei mezzi (veicoli) partecipanti per una data viaggio. Conta solo i partecipanti con mezzo assegnato (ana_mezzi_id_fk IS NOT NULL). Utilizzata da `fn_get_viaggi_init_data` per popolare il campo `totMezzi` delle date. | `p_data_viaggio_id integer` | `integer` | `Components/Shared/AnaViaggiDialog.razor`, `SqlScripts/351_Create_GetMezziCount.sql` |
| `fn_get_viaggi_init_data` | **FAT INIT FUNCTION**: Recupera in un'unica chiamata tutti i lookups necessari per il dialog viaggi (Nazioni, TipiViaggio, TipiTrattamento, TipiPernottamento, TipiAvvicinamento, Aziende) + le date del viaggio (se `p_viaggio_id` fornito) con contatori `totMezzi` e `totClienti`. Restituisce JSON con chiavi in camelCase. **Fixed 2026-03-16**: Corretti campi date per includere tutti i costi bambini, note e campi audit. **Fixed 2026-04-08**: Corretti nomi colonne (`tipo_viaggi_id`, `tipo_viaggi_descrizione`, `ana_tipo_pernottamento_id`, `ana_tipo_pernottamento_descrizione`, `ragione_sociale`); `ORDER BY` spostato dentro `json_agg()` per compatibilità PostgreSQL. | `p_viaggio_id integer DEFAULT NULL` | `json` (include dates con tutti i campi: id, viaggioIdFk, dataInizio, dataFine, effettuatoSino, costoPilota, costoPasseggero, costoPasseggeroAutoGuida, costoBambino02/26/612, note, totMezzi, totClienti, aziendaId, createdBy, created, updatedBy, updated) | `Services/CRUD/AnaViaggiService.cs`, `Components/Shared/AnaViaggiDialog.razor`, `SqlScripts/260_Create_FnGetViaggiInitData.sql` |
| `fn_get_date_viaggi_with_transactions` | Restituisce tutti i campi di `ana_date_viaggi` per un dato `viaggio_id`, aggiungendo il flag booleano `has_transactions`. Il flag è `TRUE` solo se esistono transazioni non ANNULLATE con causale documento (`causale_is_documento = TRUE`). **Updated 2026-04-08**: Aggiunto JOIN su `ana_tipi_causali` e filtro `transazione_stato != 'ANNULLATO'` + `causale_is_documento = TRUE` per escludere transazioni annullate e movimenti non-documento. | `p_viaggio_id integer` | `TABLE(data_viaggio_id, viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine, data_viaggio_effettuato_sino, has_transactions boolean)` | `Components/Shared/ViaggioDatesManager.razor`, `SqlScripts/fn_get_date_viaggi_with_transactions.sql` |
| `get_travel_stats` | Calcola totali partecipanti, equipaggi e veicoli per una data viaggio | `p_data_viaggio_id integer` | `TABLE(total_participants, ...)` | `Services/Printing/TravelPrintService.cs` |

---

### 5.1. CRUD Viaggi (ana_viaggi)
Stored procedures e funzioni per le operazioni CRUD su `ana_viaggi`.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `sp_ana_viaggi_create` | Crea un nuovo viaggio con tutti i campi obbligatori e opzionali | 18 parametri: `p_viaggio_descrizione_breve VARCHAR(255), p_viaggio_descrizione_estesa TEXT, p_viaggio_numero_giorni INTEGER, p_viaggio_numero_notti INTEGER, p_viaggio_pasti_al_sacco CHAR(1), p_viaggio_num_km INTEGER, p_viaggio_tipo_avvicinamento_fk INTEGER, p_viaggio_note TEXT, p_viaggio_link VARCHAR(500), p_viaggio_nazione_fk INTEGER, p_viaggio_tipo_viaggio_fk INTEGER, p_viaggio_tipo_trattamento_fk INTEGER, p_viaggio_tipo_pernottamento_fk INTEGER, p_azienda_id INTEGER, p_created_by VARCHAR(50), p_created TIMESTAMPTZ, p_updated_by VARCHAR(50), p_updated TIMESTAMPTZ` | `INTEGER` (viaggio_id del record creato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql` |
| `sp_ana_viaggi_update` | Aggiorna un viaggio esistente | 17 parametri (include `p_viaggio_id` nel WHERE) | `VOID` (solleva EXCEPTION se record non trovato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql` |
| `sp_ana_viaggi_delete` | Elimina un viaggio e le sue date associate (cascade manuale) dopo validazione dipendenze. Verifica assenza di `mov_clienti_viaggi` e `mov_clienti_alloggi` collegati. Elimina prima `ana_date_viaggi` (cascade manuale). | `p_viaggio_id INTEGER` | `TABLE(deleted BOOLEAN, error_message TEXT)` | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql` |
| `fn_ana_viaggi_get_all` | Recupera tutti i viaggi con LEFT JOIN su lookup tables (nazioni, tipi viaggio, trattamento, pernottamento, avvicinamento, azienda) e filtri opzionali (anno, completato, futuro). Include conteggio date corrispondenti. | `p_azienda_id INTEGER DEFAULT NULL, p_filter_year INTEGER DEFAULT NULL, p_only_completed BOOLEAN DEFAULT NULL, p_future_only BOOLEAN DEFAULT NULL` | `TABLE` con tutti i campi di `ana_viaggi` + descrizioni lookup + `matching_dates_count BIGINT` | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql` |
| `fn_ana_viaggi_get_by_id` | Recupera un singolo viaggio per ID con tutti i LEFT JOIN su lookup tables | `p_viaggio_id INTEGER` | `TABLE` con tutti i campi di `ana_viaggi` + descrizioni lookup | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql` |

**Note:**
- I trigger `trg_ana_viaggi_audit` gestiscono automaticamente i campi audit se non forniti
- Tutti i costi sono di tipo `INTEGER` (non DECIMAL)
- Uppercase enforcement per descrizioni e note avviene lato C#
- Multi-tenancy tramite filtro `azienda_id`
- **⚠️ IMPORTANTE (Mapping)**: `fn_ana_viaggi_get_all` e `fn_ana_viaggi_get_by_id` restituiscono i nomi delle colonne con il prefisso completo della tabella (es: `viaggio_descrizione_breve`, `viaggio_numero_giorni`). In C# **NON usare Dapper diretto** per il mapping, ma utilizzare `NpgsqlDataReader` + `MapFromReader()` per gestire correttamente i nomi con prefisso. Stesso pattern usato in `GetViaggiWithTransactionsAsync()`.

---

### 5.2. CRUD Date Viaggi (ana_date_viaggi)
Stored procedures per le operazioni CRUD su `ana_date_viaggi`.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `sp_ana_date_viaggi_create` | Crea una nuova data viaggio | 13 parametri: `p_viaggio_id_fk INTEGER, p_data_viaggio_data_inizio DATE, p_data_viaggio_data_fine DATE, p_data_viaggio_effettuato_sino CHAR(1), p_data_viaggio_costo_pilota INTEGER, p_data_viaggio_costo_passeggero INTEGER, p_data_viaggio_costo_passeggero_auto_guida INTEGER, p_data_viaggio_costo_bambino_0_2 INTEGER, p_data_viaggio_costo_bambino_2_6 INTEGER, p_data_viaggio_costo_bambino_6_12 INTEGER, p_data_viaggio_note VARCHAR(250), p_azienda_id INTEGER, p_created_by VARCHAR(255)` | `INTEGER` (data_viaggio_id del record creato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/401_Create_SpAnaDateViaggiCrud.sql` |
| `sp_ana_date_viaggi_update` | Aggiorna una data viaggio esistente | 14 parametri (include `p_data_viaggio_id`, `p_updated_by`, `p_updated`) | `VOID` (solleva EXCEPTION se record non trovato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/401_Create_SpAnaDateViaggiCrud.sql` |
| `sp_ana_date_viaggi_delete` | Elimina una data viaggio dopo validazione dipendenze. Verifica assenza di `mov_clienti_viaggi` e `mov_clienti_alloggi` collegati. | `p_data_viaggio_id INTEGER` | `TABLE(deleted BOOLEAN, error_message TEXT)` | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/401_Create_SpAnaDateViaggiCrud.sql` |

**Note:**
- I trigger `trg_ana_date_viaggi_audit` gestiscono automaticamente i timestamp
- Check constraints: `chk_data_viaggio_date_order` (fine >= inizio), `chk_data_viaggio_costi_positive` (tutti i costi >= 0)
- `data_viaggio_effettuato_sino` può essere 'Y', 'N', 'P' o NULL

---

## 5.3. Partecipanti e Alloggi
Funzioni per la gestione dei partecipanti (`mov_clienti_viaggi`) e delle rooming list (`mov_clienti_alloggi`).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_viaggio_partecipanti_init_data` | **FAT INIT FUNCTION**: Recupera in un'unica chiamata tutti i dati per il dialog partecipanti (partecipanti ordinati, partecipanti senza camera, camere con occupanti, tipi partecipante, tipi alloggio, contatori, titolo). Restituisce JSON con chiavi in camelCase. **Fixed 2026-03-16**: Corretta sintassi ORDER BY (spostata dentro json_agg) per tipoPartecipanti e tipoAlloggi. | `p_viaggio_id integer, p_data_viaggio_id integer` | `json` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/353_Fix_FnGetViaggioPartecipantiInitData_OrderBy.sql` |
| `sp_mov_clienti_viaggi_create` | Iscrive partecipante al viaggio | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/91_Create_SpMovClientiViaggi_CRUD.sql` |
| `sp_mov_clienti_viaggi_update` | Aggiorna dati iscrizione partecipante | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/91_Create_SpMovClientiViaggi_CRUD.sql` |
| `sp_mov_clienti_viaggi_delete` | Rimuove partecipante dal viaggio (con cleanup alloggi) | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/91_Create_SpMovClientiViaggi_CRUD.sql` |
| `fn_get_mov_clienti_viaggi_by_date` | Recupera tutti i partecipanti iscritti a una specifica data viaggio (dati raw senza arricchimenti). **DB-First conversion 2026-03-16**: sostituisce SQL inline in GetByDateIdAsync. | `p_data_viaggio_id integer` | `TABLE(viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk, tipo_partecipante_id_fk, ana_mezzi_id_fk, mezzo_modello_id_fk, cliente_pilota_id_fk, mov_cliente_viaggio_scontoval_totale, mov_cliente_viaggio_targa_mezzo, mov_cliente_viaggio_cane_sino, mov_cliente_viaggio_note)` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/402_Create_MovClientiViaggi_ReadFunctions.sql` |
| `fn_get_participants_view` | Vista arricchita partecipanti con dati anagrafici, ruolo, intolleranze e dettagli mezzo. Ordinata per equipaggio (pilota → passeggeri). **DB-First conversion 2026-03-16**: sostituisce SQL inline in GetParticipantsViewAsync. | `p_data_viaggio_id integer` | `TABLE(viaggio_id, data_id, cliente_id, nominativo, tipo_partecipante_id, ruolo, note, cane_sino, intolleranze, mezzo_dettagli, cliente_pilota_id, grouping_key)` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/402_Create_MovClientiViaggi_ReadFunctions.sql` |
| `fn_get_trip_header_string` | Genera intestazione viaggio formattata per UI: "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)". **DB-First conversion 2026-03-16**: sostituisce SQL inline in GetTripHeaderStringAsync. | `p_viaggio_id integer, p_data_viaggio_id integer` | `text` | `Services/CRUD/MovClientiViaggiService.cs`, `SqlScripts/402_Create_MovClientiViaggi_ReadFunctions.sql` |
| `get_participants_sorted` | Restituisce partecipanti ordinati per equipaggio, inclusi dati anagrafici e documenti completi. | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_count` | Conteggio totale partecipanti efficiente | `p_data_viaggio_id integer` | `integer` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_without_accommodation` | Restituisce solo partecipanti senza camera assegnata | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_alloggi_create` | Crea associazione cliente-alloggio (camera) con validazione capacità | `p_viaggio_id integer, ...` | `integer` | `Services/CRUD/MovClientiAlloggiService.cs`, `SqlScripts/93_Create_SpMovClientiAlloggi_CRUD.sql` |
| `sp_mov_clienti_alloggi_update` | Aggiorna assegnazione camera esistente | `p_pk integer, ...` | `void` | `Services/CRUD/MovClientiAlloggiService.cs`, `SqlScripts/93_Create_SpMovClientiAlloggi_CRUD.sql` |
| `sp_mov_clienti_alloggi_delete` | Elimina camera assegnata | `p_pk integer` | `void` | `Services/CRUD/MovClientiAlloggiService.cs`, `SqlScripts/93_Create_SpMovClientiAlloggi_CRUD.sql` |
| `fn_get_mov_clienti_alloggi_by_date` | Recupera tutti gli alloggi (camere) assegnati per una specifica data viaggio. Restituisce dati raw con i 6 slot clienti (ClienteId1Fk...ClienteId6Fk). **DB-First conversion 2026-03-16**: sostituisce SQL inline in GetByDateIdAsync. | `p_data_viaggio_id integer` | `TABLE(mov_clienti_alloggio_pk, viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk, cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)` | `Services/CRUD/MovClientiAlloggiService.cs`, `SqlScripts/403_Create_MovClientiAlloggi_ReadFunction.sql` |
| `sp_assign_to_first_free_slot` | Assegna cliente al primo slot libero in modo atomico | `p_alloggio_pk integer, p_cliente_id integer` | `boolean` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `get_rooms_with_occupants` | Restituisce camere con occupanti aggregati (ARRAY) | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiAlloggiService.cs` |
| `get_rooming_list_data` | Dati completi per stampa Rooming List con ordinamento pilota/passeggeri. **Nuovi campi**: `position_number` (slot 1-6), `is_pilot` (TRUE per slot 1). **Ordinamento**: camere per cognome pilota all'interno tipo alloggio, all'interno camera pilota prima poi passeggeri alfabetici. | `p_data_viaggio_id integer` | `TABLE(cliente_id, room_id, nominativo, eta, data_nascita, luogo_nascita, indirizzo_residenza, citta_residenza, residenza_completa, country_code, country_name, nationality, tipo_documento, numero_documento, ente_rilascio, data_rilascio, data_scadenza, intolleranze, tipo_alloggio_id, tipo_alloggio_descrizione, max_occupanti, sort_order, position_number, is_pilot)` | `Services/Printing/RoomingListPrintService.cs` |
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
| `fn_get_fatturato_annuale` | **V2 (2026-02-22)** - Calcola il fatturato annuale netto basato sugli imponibili con segno causale. JOIN con `ana_tipi_causali` filtrando `causale_concorre_fatturato = TRUE`. Usa `COALESCE(transazione_imponibile_eur, transazione_importo_eur_old, 0) * c.causale_segno` per compatibilita' retroattiva dati storici. Filtra stato != 'ANNULLATO'. Usa anno di `transazione_data_documento` (fallback `transazione_data`). **SuperAdmin**: se `p_azienda_id IS NULL`, somma tutte le aziende. Il parametro `p_valuta_target_id` e' mantenuto per retrocompatibilita' signature ma non usato nel calcolo (importi gia' in EUR). | `p_azienda_id INTEGER (nullable), p_anno INTEGER, p_valuta_target_id INTEGER DEFAULT NULL` | `NUMERIC(15,2)` | `Statistics/StatisticRevenue.cs` |
| `fn_get_fatturato_periodo` | **V2 (2026-02-22)** - Calcola il fatturato netto per un periodo specifico (date esatte). Stessa logica V2 di `fn_get_fatturato_annuale`: JOIN `ana_tipi_causali` con `causale_concorre_fatturato = TRUE`, importi netti con segno causale, supporto SuperAdmin (`p_azienda_id IS NULL`). Utilizzato per confronti Period-over-Period. | `p_azienda_id INTEGER (nullable), p_data_inizio DATE, p_data_fine DATE, p_valuta_target_id INTEGER DEFAULT NULL` | `NUMERIC(15,2)` | `Statistics/StatisticRevenue.cs` |
| `fn_get_fatturato_mensile_trend` | **V2 (2026-02-22)** - Restituisce il trend mensile del fatturato netto per un anno. Stessa logica V2: JOIN `ana_tipi_causali`, imponibili con segno, supporto SuperAdmin. Restituisce sempre 12 righe (gen-dic) con LEFT JOIN su `generate_series(1,12)`, valore 0 per mesi senza movimenti qualificanti. | `p_azienda_id INTEGER (nullable), p_anno INTEGER, p_valuta_target_id INTEGER DEFAULT NULL` | `TABLE(mese INTEGER, fatturato NUMERIC(15,2))` | `Statistics/StatisticRevenue.cs` |

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
| `sp_ana_tipi_causali_create` | Crea nuova causale con validazione completa. **Normalizzazione automatica**: forza UPPER CASE su codice, descrizione, ciclo e tipo_documento_sdi. **Validazioni**: azienda obbligatoria, codice/descrizione non vuoti, ciclo ATTIVO/PASSIVO, segno ±1. **Gestione errori**: DUPLICATE_CODICE (unique violation), INVALID_AZIENDA (FK violation), INVALID_DATA (check constraint). **Aggiornata 2026-02-22**: aggiunto `p_causale_concorre_fatturato`. **Aggiornata 2026-03-07**: aggiunto `p_tipo_documento_sdi` per FatturaPA SDI. | `p_azienda_fk INTEGER, p_causale_codice VARCHAR(10), p_causale_descrizione VARCHAR(100), p_causale_segno INTEGER, p_causale_is_documento BOOLEAN, p_causale_ciclo VARCHAR(10), p_causale_richiede_scadenza BOOLEAN, p_causale_giorni_scadenza_default INTEGER, p_causale_genera_scadenza_auto BOOLEAN, p_causale_genera_iva BOOLEAN, p_causale_richiede_iva BOOLEAN, p_causale_aliquota_iva_default_fk INTEGER, p_is_active BOOLEAN, p_created_by VARCHAR, p_updated_by VARCHAR, p_causale_concorre_fatturato BOOLEAN DEFAULT FALSE, p_tipo_documento_sdi VARCHAR(4) DEFAULT NULL` | `INTEGER` (causale_id del record creato) | `Services/CRUD/AnaTipiCausaliService.cs` |
| `sp_ana_tipi_causali_update` | Aggiorna causale esistente con validazione. **Normalizzazione automatica**: forza UPPER CASE incl. tipo_documento_sdi. **Validazioni**: verifica esistenza record, campi obbligatori non vuoti, ciclo ATTIVO/PASSIVO, segno ±1. **Gestione errori**: NOT_FOUND, DUPLICATE_CODICE, INVALID_DATA. **Aggiornata 2026-02-22**: aggiunto `p_causale_concorre_fatturato`. **Aggiornata 2026-03-07**: aggiunto `p_tipo_documento_sdi` per FatturaPA SDI. | `p_causale_id INTEGER, p_causale_codice VARCHAR(10), p_causale_descrizione VARCHAR(100), p_causale_segno INTEGER, p_causale_is_documento BOOLEAN, p_causale_ciclo VARCHAR(10), p_causale_richiede_scadenza BOOLEAN, p_causale_giorni_scadenza_default INTEGER, p_causale_genera_scadenza_auto BOOLEAN, p_causale_genera_iva BOOLEAN, p_causale_richiede_iva BOOLEAN, p_causale_aliquota_iva_default_fk INTEGER, p_is_active BOOLEAN, p_updated_by VARCHAR, p_causale_concorre_fatturato BOOLEAN DEFAULT FALSE, p_tipo_documento_sdi VARCHAR(4) DEFAULT NULL` | `VOID` | `Services/CRUD/AnaTipiCausaliService.cs` |
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

**Metadato Fatturato (Nuovo dal 2026-02-22)**:
- `causale_concorre_fatturato` (BOOLEAN DEFAULT FALSE): Se TRUE, le transazioni con questa causale concorrono al calcolo del fatturato aziendale
- Popolato a TRUE per le causali ciclo ATTIVO che generano fatturato: FV (Fattura Vendita), NCA (Nota Credito Emessa → riduce fatturato via segno -1), NDA (Nota Debito Emessa → aumenta via segno +1)
- Usato dalle 3 funzioni fatturato V2 (`fn_get_fatturato_annuale`, `fn_get_fatturato_periodo`, `fn_get_fatturato_mensile_trend`) come filtro JOIN
- Configurabile da UI: `AnaTipiCausaliEditDialog.razor` (MudSwitch "Concorre al Fatturato")
- **File SQL migrazione**: `SqlScripts/Migration_Add_ConcorreFatturato.sql` (ALTER TABLE + dati iniziali), `SqlScripts/Migration_Update_Causali_SP_ConcorreFatturato.sql` (SP create/update)

**Logica Fatturato V2 (2026-02-22)**:
- Formula: `SUM(COALESCE(transazione_imponibile_eur, transazione_importo_eur_old, 0) * c.causale_segno)`
- COALESCE garantisce retrocompatibilita': usa imponibile netto se disponibile, altrimenti importo EUR storico
- Il segno causale (+1/-1) gestisce automaticamente note credito/debito
- `StatisticRevenue.cs`: supporta `aziendaId = null` per SuperAdmin (somma tutte le aziende)
- **File SQL**: `SqlScripts/Migration_Update_Fn_Fatturato_V2.sql` (riscrittura 3 funzioni)

**File SQL**: `SqlScripts/Create_AnaTipiCausali_CRUD.sql`, `SqlScripts/Migration_Add_Causale_IVA_Metadata.sql` (metadati IVA)

---

## 8.2. Contabilità - Tipi Fornitore/Controparte

Funzioni CRUD per la gestione dei tipi fornitore (classificazione controparti).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_ana_tipo_fornitore` | Recupera i tipi fornitore filtrati per azienda. Se `p_azienda_id` è NULL (SuperAdmin senza selezione), restituisce tutti i record. Ordinamento alfabetico per descrizione. **Architettura DB-First**: sostituisce SQL inline nel service, garantisce gestione ottimale connessioni e cache query PostgreSQL. | `p_azienda_id INTEGER` (nullable) | `TABLE(tipo_fornitore_id INTEGER, azienda_fk INTEGER, descrizione VARCHAR(50), categoria VARCHAR(20), conto_contabile_default VARCHAR(20), created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ)` | `Services/CRUD/TipoFornitoreService.cs`, `SqlScripts/354_Create_FnGetAnaTipoFornitore.sql` |
| `sp_ana_tipo_fornitore_create` | Crea nuovo tipo fornitore con validazione completa. **Normalizzazione automatica**: forza UPPER CASE su descrizione e categoria. **Validazioni**: azienda obbligatoria, descrizione non vuota, categoria COSTO/RICAVO/MISTO. **Gestione errori**: DUPLICATE_DESCRIZIONE (unique violation), INVALID_AZIENDA (FK violation), INVALID_DATA (check constraint). | `p_azienda_fk INTEGER, p_descrizione VARCHAR(50), p_categoria VARCHAR(20) DEFAULT NULL, p_conto_contabile_default VARCHAR(20) DEFAULT NULL` | `INTEGER` (tipo_fornitore_id del record creato) | `Services/CRUD/TipoFornitoreService.cs`, `SqlScripts/355_Create_AnaTipoFornitore_CRUD.sql` |
| `sp_ana_tipo_fornitore_update` | Aggiorna tipo fornitore esistente con validazione. **Normalizzazione automatica**: forza UPPER CASE su descrizione e categoria. **Validazioni**: descrizione non vuota, categoria COSTO/RICAVO/MISTO. **Gestione errori**: NOT_FOUND, DUPLICATE_DESCRIZIONE, INVALID_DATA. Aggiorna automaticamente `updated_at` timestamp. | `p_tipo_fornitore_id INTEGER, p_descrizione VARCHAR(50), p_categoria VARCHAR(20) DEFAULT NULL, p_conto_contabile_default VARCHAR(20) DEFAULT NULL` | `VOID` | `Services/CRUD/TipoFornitoreService.cs`, `SqlScripts/355_Create_AnaTipoFornitore_CRUD.sql` |
| `sp_ana_tipo_fornitore_delete` | Elimina tipo fornitore. Blocca eliminazione se in uso da controparti (FK constraint). **Gestione errori**: RECORD_NOT_FOUND, RECORD_IN_USE (FK violation da ana_controparti). | `p_tipo_fornitore_id INTEGER` | `VOID` | `Services/CRUD/TipoFornitoreService.cs`, `SqlScripts/355_Create_AnaTipoFornitore_CRUD.sql` |

### 📝 Note Implementative - Tipi Fornitore (2026-03-16)

**Architettura DB-First Completa**:
- ✅ **Zero SQL diretto** in `TipoFornitoreService` - tutte le operazioni CRUD delegate al database
- ✅ Normalizzazione UPPER CASE gestita lato database (stored procedures)
- ✅ Validazioni business rules nel database (constraint + procedure logic)
- ✅ Gestione connessioni ottimizzata - critico per Supabase connection pooling limits
- ✅ Filtro multi-tenant: ogni tipo fornitore appartiene a un'azienda specifica

**Gestione Connessioni Supabase**:
- Funzione `STABLE` per permettere caching PostgreSQL
- Stored procedures riducono round-trips al database
- Riduce numero di sessioni attive rispetto a query dinamiche inline
- Compatibile con connection pooling Supabase (limiti di sessioni concorrenti)

**Validazioni e Constraint DB**:
- Unique constraint su (azienda_fk, descrizione) - previene duplicati per azienda
- Check constraint su categoria: solo COSTO, RICAVO, MISTO
- Foreign key su azienda_fk → blocca creazione con azienda inesistente
- Foreign key da ana_controparti → blocca eliminazione se tipo in uso

**UI Multi-Tenant**:
- `AziendaSelect` senza `ShowAllOption` per forzare selezione
- SuperAdmin: caricamento dati bloccato fino a selezione azienda specifica
- Utenti normali: filtro automatico per azienda corrente dal `TenantContext`

**File SQL**: `SqlScripts/354_Create_FnGetAnaTipoFornitore.sql`, `SqlScripts/355_Create_AnaTipoFornitore_CRUD.sql`

---

## 9. Contabilità - Stampe e Report

Funzioni per l'estrazione dati e report PDF dei movimenti contabili.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_transazioni_stampa_dettaglio` | Estrae dettagli transazioni con chiave raggruppamento dinamica (CONTROPARTE/DATA_DOCUMENTO/TIPO_MOVIMENTO) e conversione valuta target. Supporta nuovi campi IVA (imponibile, iva, lordo), aliquote e filtro per Ciclo Contabile. Utilizza `fn_get_tasso_cambio` con tasso storicizzato basato su `transazione_data_documento`. | `p_azienda_id INT, p_controparte_id INT, p_causale_tipo_id INT, p_stati VARCHAR[], p_viaggio_id INT, p_data_viaggio_id INT, p_valuta_id INT, p_data_transazione_da DATE, p_data_transazione_a DATE, p_data_documento_da DATE, p_data_documento_a DATE, p_importo_da NUMERIC, p_importo_a NUMERIC, p_numero_documento VARCHAR, p_solo_con_documento BOOL, p_solo_scadute BOOL, p_solo_con_viaggio BOOL, p_solo_senza_viaggio BOOL, p_solo_con_fattura BOOL, p_ordinamento VARCHAR DEFAULT 'CONTROPARTE', p_valuta_target_id INT, p_causale_ciclo VARCHAR` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INT, transazione_id INT, transazione_data DATE, transazione_data_documento DATE, transazione_data_scadenza DATE, transazione_data_pagamento DATE, controparte_ragione_sociale VARCHAR, transazione_tipo_movimento VARCHAR, transazione_causale VARCHAR, causale_ciclo VARCHAR, transazione_stato VARCHAR, transazione_numero_documento VARCHAR, valuta_codice_iso VARCHAR, imponibile_eur NUMERIC, iva_eur NUMERIC, lordo_eur NUMERIC, aliquota_iva_codice VARCHAR, aliquota_iva_percentuale NUMERIC, importo_valuta_target NUMERIC, valuta_target_iso VARCHAR, viaggio_descrizione VARCHAR, data_viaggio_data_inizio DATE)` | `Services/Printing/MovTransazioniPrintService.cs`, `SqlScripts/fn_get_transazioni_stampa_dettaglio.sql` |
| `fn_get_transazioni_stampa_subtotali` | Calcola sub-totali aggregati per gruppo/valuta e totali generali usando GROUPING SETS. Fornisce totali per Imponibile, IVA e Lordo convertiti in valuta target. Il flag `is_totale_generale` distingue sub-totali di gruppo da totali complessivi. **Updated 2026-02-15**: Utilizza `ABS()` sugli importi prima di applicare il segno della causale per evitare "doppie negazioni" e garantire saldi corretti anche per pagamenti/note credito. | `p_azienda_id INT, p_controparte_id INT, p_causale_tipo_id INT, p_stati VARCHAR[], p_viaggio_id INT, p_data_viaggio_id INT, p_valuta_id INT, p_data_transazione_da DATE, p_data_transazione_a DATE, p_data_documento_da DATE, p_data_documento_a DATE, p_importo_da NUMERIC, p_importo_a NUMERIC, p_numero_documento VARCHAR, p_solo_con_documento BOOL, p_solo_scadute BOOL, p_solo_con_viaggio BOOL, p_solo_senza_viaggio BOOL, p_solo_con_fattura BOOL, p_ordinamento VARCHAR DEFAULT 'CONTROPARTE', p_valuta_target_id INT, p_causale_ciclo VARCHAR` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INT, valuta_codice_iso VARCHAR, totale_valuta_originale NUMERIC, totale_valuta_target NUMERIC, totale_imponibile_target NUMERIC, totale_iva_target NUMERIC, totale_fatturato_target NUMERIC, totale_pagato_target NUMERIC, valuta_target_iso VARCHAR, conteggio_transazioni INT, is_totale_generale BOOL)` | `Services/Printing/MovTransazioniPrintService.cs`, `SqlScripts/fn_get_transazioni_stampa_subtotali.sql` |
| `fn_get_transazioni_per_stampa` | Function base per estrazione transazioni con filtri. Restituisce dettagli transazioni con JOIN su fornitori, valute, viaggi. **Nota**: sostituita da `fn_get_transazioni_stampa_dettaglio` per report con raggruppamenti. | `p_azienda_id INT, p_fornitore_id INT, p_tipo_movimento VARCHAR, p_stati VARCHAR[], ...` | `TABLE(transazione_id INT, ...)` | `Services/CRUD/MovTransazioniService.cs` |
| `fn_get_scadenzario_stampa` | Estrae dati scadenzario per stampa PDF con raggruppamento dinamico. Utilizza la vista `vw_scadenzario` come base e supporta 3 tipi di raggruppamento: **URGENZA** (SCADUTO/URGENTE/IN_SCADENZA/NORMALE), **MESE** (per mese di scadenza), **CONTROPARTE** (per fornitore/cliente). Applica filtri multipli su azienda, controparte, ciclo contabile (ATTIVO/PASSIVO), urgenza, intervallo date scadenza e viaggio. Focus su pianificazione finanziaria cash flow. | `p_azienda_id INTEGER, p_controparte_id INTEGER, p_causale_ciclo VARCHAR(10), p_urgenza VARCHAR(20), p_data_scadenza_da DATE, p_data_scadenza_a DATE, p_viaggio_id INTEGER, p_solo_con_viaggio BOOLEAN, p_solo_senza_viaggio BOOLEAN, p_raggruppamento VARCHAR(20) DEFAULT 'URGENZA'` | `TABLE(gruppo_chiave TEXT, gruppo_display TEXT, gruppo_ordine INTEGER, transazione_id INTEGER, data_scadenza DATE, data_documento DATE, numero_documento VARCHAR, controparte_ragione_sociale VARCHAR, causale_ciclo VARCHAR, causale_descrizione VARCHAR, importo_originale NUMERIC, residuo NUMERIC, valuta_codice_iso VARCHAR, giorni_a_scadenza INTEGER, urgenza VARCHAR, stato VARCHAR, viaggio_descrizione TEXT, note TEXT)` | `Services/Printing/ScadenzarioPrintService.cs`, `Scripts/Migrazione_Contabile/08_crea_function_scadenzario_stampa.sql` |
| `fn_get_bilancio_viaggio` | Recupera dati economici per report **Bilancio di Viaggio** (Analisi Margini). Aggrega le transazioni filtrate per viaggio classificandole in **RICAVI** (Ciclo Attivo) e **COSTI** (Ciclo Passivo). Calcola importi normalizzati (Imponibile, IVA, Lordo) gestendo i segni delle causali e determina l'importo effettivamente pagato/incassato. Supporta selezione multipla viaggi. | `p_azienda_id INT, p_viaggio_ids INT[], p_data_da DATE, p_data_a DATE` | `TABLE(viaggio_descrizione, transazione_descrizione, categoria_nome, categoria_tipo, importo_netto_eur, importo_pagato_eur, ...)` | `Services/Printing/BilancioViaggioPrintService.cs`, `SqlScripts/fn_get_bilancio_viaggio.sql` |
| `fn_get_bilancio_annuale_viaggi` | Estrae l'intero pool di movimenti contabili (Attivi e Passivi) per l'anno di competenza, raggruppandoli per Data Viaggio, garantendo il corretto ordinamento cronologico. Permette la creazione del report a 3 Livelli (Totale Data, Totale Viaggio, Riepilogo Generale). | `p_azienda_id INT, p_anno INT` | `TABLE(viaggio_id, viaggio_descrizione, data_viaggio_id, data_viaggio_data_inizio, importo_netto_eur, importo_lordo_eur, categoria_tipo, ...)` | `Services/Printing/BilancioViaggioPrintService.cs`, `SqlScripts/fn_get_bilancio_annuale_viaggi.sql` |
| `fn_get_anni_bilancio_viaggi` | Recupera dinamicamente solo gli anni in cui vi sono partenze collegate a transazioni contabili reali (ignorando i viaggi non movimentati). Utile per popolare i filtri UI pre-selezionati. Restituisce anche il conteggio dei viaggi unici contabilizzati per anno. | `p_azienda_id INT` | `TABLE(anno INT, numero_viaggi INT)` | `Services/Printing/BilancioViaggioPrintService.cs`, `SqlScripts/fn_get_anni_bilancio_viaggi.sql` |
| `fn_get_registro_iva` | Estrae dati per stampa **Registro IVA** (Libro Acquisti e Vendite) con filtri per azienda, anno e ciclo contabile (ATTIVO/PASSIVO). Restituisce transazioni ordinate per **numero protocollo IVA** (con NULLS LAST, poi per data documento). **Aggiornata 2026-02-22**: Aggiunti campi output `aliquota_iva_natura VARCHAR` (codice natura FE es. N1, N3.1) e `numero_protocollo_iva INTEGER` per conformità normativa registri IVA. Filtra solo transazioni qualificanti IVA (causale_genera_iva = TRUE, valuta EUR, stato != ANNULLATO). | `p_azienda_id INTEGER, p_anno INTEGER, p_causale_ciclo VARCHAR(10)` | `TABLE(transazione_id INTEGER, data_documento DATE, numero_documento VARCHAR, controparte_ragione_sociale VARCHAR, causale_descrizione VARCHAR, causale_ciclo VARCHAR, imponibile_eur NUMERIC, iva_eur NUMERIC, lordo_eur NUMERIC, aliquota_iva_codice VARCHAR, aliquota_iva_percentuale NUMERIC, aliquota_iva_natura VARCHAR, numero_protocollo_iva INTEGER)` | `Services/Printing/RegistroIvaPrintService.cs`, `Services/Printing/RegistroIvaPrintDTO.cs`, `SqlScripts/fn_get_registro_iva.sql` |
| `fn_get_fattura_attiva_stampa` | Recupera **tutti i dati** necessari per la stampa PDF e l'export XML FatturaPA di una singola fattura attiva. Singola query con JOIN estesi su: azienda, regime fiscale, sede principale, logo, controparte/cliente, comuni/province, causale contabile. **Aggiornata 2026-03-07**: Aggiunti campi SDI: `regime_codice_sdi` (RF01/RF19/RF02), `tipo_cassa_sdi` (TC22), `cassa_prev_percentuale`, `tipo_documento_sdi` (TD01/TD04/TD05). **Filtro**: `causale_ciclo = 'ATTIVO'`. | `p_transazione_id INTEGER` | `TABLE(...regime_codice_sdi VARCHAR, tipo_cassa_sdi VARCHAR, cassa_prev_percentuale NUMERIC, ...tipo_documento_sdi VARCHAR, + tutti i campi precedenti)` | `Services/Printing/FatturaAttivaPrintService.cs`, `Services/Export/FatturaElettronicaXmlService.cs`, `SqlScripts/241_Update_FnGetFatturaAttivaStampa_SDI.sql` |
| `fn_fatturapa_get_next_progressivo` | Restituisce il prossimo **progressivo invio FatturaPA** per l'azienda, formattato a 5 cifre (es. "00001"). Usa UPSERT atomico su tabella `ana_fatturapa_progressivi` (stesso pattern di `sp_assegna_protocollo_iva`). Usato per la nomenclatura file XML: `IT{P.IVA}_{progressivo}.xml`. | `p_azienda_id INTEGER` | `VARCHAR(5)` | `Services/Export/FatturaElettronicaXmlService.cs`, `SqlScripts/240_SDI_Schema_Additions.sql` |
| `fn_get_fatture_attive_elenco` | Elenco fatture attive filtrato per la **pagina di ricerca** `/stampe/fatture-attive`. Supporta 7 filtri opzionali: controparte, range date documento, range importo lordo, stato, numero documento (ILIKE parziale). Filtra automaticamente solo causale ciclo ATTIVO. Ordinamento per data documento DESC, created_at DESC. | `p_azienda_id INTEGER, p_controparte_id INTEGER DEFAULT NULL, p_data_doc_da DATE DEFAULT NULL, p_data_doc_a DATE DEFAULT NULL, p_importo_da NUMERIC DEFAULT NULL, p_importo_a NUMERIC DEFAULT NULL, p_stato VARCHAR DEFAULT NULL, p_numero_documento VARCHAR DEFAULT NULL` | `TABLE(transazione_id INT, transazione_data DATE, data_documento DATE, numero_documento VARCHAR, numero_protocollo_iva INT, controparte_ragione_sociale VARCHAR, imponibile_eur NUMERIC, iva_eur NUMERIC, lordo_eur NUMERIC, stato VARCHAR, data_scadenza DATE, causale_descrizione VARCHAR)` | `Services/Printing/FatturaAttivaPrintService.cs`, `SqlScripts/221_Create_FnGetFattureAttiveElenco.sql` |
| `fn_get_anni_fatture_attive` | Recupera gli **anni distinti** in cui esistono fatture attive (causale ciclo ATTIVO) per un'azienda. Usato per popolare il combobox Anno nella pagina `/stampe/fatture-attive`. Utilizza `COALESCE(transazione_data_documento, transazione_data)` per determinare l'anno. Ordinamento DESC (anno più recente per primo). | `p_azienda_id INTEGER` | `TABLE(anno INTEGER)` | `Services/Printing/FatturaAttivaPrintService.cs`, `SqlScripts/223_Create_FnGetAnniFattureAttive.sql` |

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

### 📝 Note Implementative - Stampa Fatture Attive (2026-03-02)

**Architettura a 3 Livelli**:
1. **DB Functions** (`fn_get_fattura_attiva_stampa`, `fn_get_fatture_attive_elenco`, `fn_get_anni_fatture_attive`): Estrazione dati con JOIN estesi
2. **Service Layer** (`FatturaAttivaPrintService.cs`): Orchestrazione caricamento dati, righe fattura, riepilogo IVA
3. **PDF Generator** (`FatturaAttivaPrinter.cs`): Rendering QuestPDF A4 Portrait con layout fattura professionale

**Flusso Stampa Singola Fattura**:
1. Utente clicca icona stampa (da `MovTransazioniPage` o `StampaFattureAttivePage`)
2. `FatturaAttivaPrintService.GetFatturaAttivaDataAsync()` chiama `fn_get_fattura_attiva_stampa` via Dapper (mapping dinamico manuale per struttura nested)
3. Righe fattura caricate separatamente da `mov_transazioni_righe` JOIN `ana_aliquote_iva`
4. Riepilogo IVA calcolato raggruppando righe per `AliquotaIvaCodice` (escluso tipo BOLLO)
5. **Selezione banca**: 0 banche → senza dati bancari; 1 banca → automatica; >1 banche → `SelezioneBancaDialog` con evidenza banca predefinita
6. `FatturaAttivaPrinter.GeneratePdfAsync()` genera PDF con sezioni: Header (logo + azienda), Identificativo fattura, Destinatario, Dettaglio righe, Riepilogo IVA, Totali, Dati bancari, Scadenza, Note regime fiscale/bollo
7. PDF aperto tramite `IPdfOpenerService`

**Supporto Regimi Fiscali**:
- **Forfettario**: Nota legale "Operazione effettuata ai sensi dell'art.1 commi da 54 a 89 L.190/2014" + nessun riepilogo IVA dettagliato
- **Ordinario/Semplificato**: Riepilogo IVA per aliquota con totali imponibile/IVA/lordo
- **Bollo**: Se presente riga BOLLO, nota "Imposta di bollo assolta sull'originale"

**Aggiornamento Function Esistenti** (Script 222):
- `fn_get_all_transazioni` e `fn_get_transazioni_by_azienda` aggiornate con campo output `causale_ciclo CHARACTER VARYING` (da JOIN `ana_tipi_causali`)
- Necessario per popolare `MovTransazioni.CausaleCiclo` (NotMapped) e abilitare `IsFatturaAttiva` nella DataGrid `MovTransazioniPage`

**Files Coinvolti**:
- `SqlScripts/220_Create_FnGetFatturaAttivaStampa.sql` (function dati singola fattura)
- `SqlScripts/221_Create_FnGetFattureAttiveElenco.sql` (function elenco filtrato)
- `SqlScripts/222_Update_TransazioniFunctions_AddCausaleCiclo.sql` (aggiornamento function esistenti)
- `Services/Printing/FatturaAttivaPrintDTO.cs` (DTOs: InvoiceCompanyInfo, InvoiceClientInfo, InvoiceLineItem, InvoiceVatSummaryRow, InvoiceBankInfo, FatturaAttivaPrintData, FatturaAttivaListItem)
- `Services/Printing/FatturaAttivaPrintService.cs` (service layer Dapper)
- `Services/Printing/FatturaAttivaPrinter.cs` (generatore PDF QuestPDF)
- `Services/Printing/PdfFileNameHelper.cs` (metodo `GetFatturaAttivaFileName`)
- `Models/MovTransazioni.cs` (properties NotMapped: CausaleCiclo, IsFatturaAttiva)
- `Components/Pages/StampaFattureAttivePage.razor` (pagina ricerca `/stampe/fatture-attive`)
- `Components/Pages/MovTransazioniPage.razor` (icona stampa per fatture attive)
- `Components/Shared/SelezioneBancaDialog.razor` (dialog selezione banca)
- `Components/Shared/NavMenu.razor` (voce menu "Stampa Fatture Attive")

### 📝 Note Implementative - Export XML FatturaPA SDI (2026-03-07)

**Architettura Export XML FatturaPA 1.2.2**:
1. **DB Schema**: `ana_regimi_fiscali` estesa con `regime_codice_sdi` (RF01/RF19/RF02) e `tipo_cassa_sdi` (TC22). `ana_tipi_causali` estesa con `tipo_documento_sdi` (TD01/TD04/TD05). Nuova tabella `ana_fatturapa_progressivi` per contatore progressivo invio per azienda.
2. **Riuso dati**: L'export XML riusa `FatturaAttivaPrintService.GetFatturaAttivaDataAsync()` (stessa pipeline della stampa PDF). DTOs estesi con `RegimeCodiceSdi`, `TipoCassaSdi`, `AliquotaIvaNatura`, `TipoDocumentoSdi`.
3. **Generazione XML**: `FatturaElettronicaXmlService` genera XML con `System.Xml.Linq` (zero dipendenze esterne). Namespace FatturaPA: `http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2`.
4. **Validazione pre-export**: Messaggi in italiano comprensibili dall'utente. Abortisce se mancano: P.IVA, Regime SDI, Sede legale, SDI/PEC cliente, Natura IVA per aliquote a 0%.

**Mapping RigaTipo → Blocco XML FatturaPA**:
- `PRESTAZIONE` → `<DettaglioLinee>` nel blocco `<DatiBeniServizi>`
- `CASSA_PREV` → `<DatiCassaPrevidenziale>` nel blocco `<DatiGeneraliDocumento>`
- `BOLLO` → `<DatiBollo>` nel blocco `<DatiGeneraliDocumento>`

**Multi-Regime**:
- **Forfettario** (RF19): Natura N2.2, DatiBollo se > 77.47€, DatiCassaPrevidenziale TC22 (INPS 4%)
- **Ordinario** (RF01): IVA esposta (es. 22%), riepilogo per aliquota con EsigibilitaIVA=I

**Nomenclatura file**: `IT{PartitaIva}_{Progressivo5cifre}.xml` (es. `IT01234567890_00001.xml`)

**Files Coinvolti**:
- `SqlScripts/240_SDI_Schema_Additions.sql` (ALTER + CREATE TABLE + FUNCTION)
- `SqlScripts/241_Update_FnGetFatturaAttivaStampa_SDI.sql` (function aggiornata con campi SDI)
- `Services/Export/FatturaElettronicaXmlService.cs` (validazione + generazione XML)
- `Services/Printing/FatturaAttivaPrintDTO.cs` (DTOs estesi con proprietà SDI)
- `Services/Printing/FatturaAttivaPrintService.cs` (mapping nuovi campi + iva_natura in query righe)
- `Components/Pages/StampaFattureAttivePage.razor` (pulsante "Esporta XML FatturaPA")

---

## 10. Configurazione API (SuperAdmin)

Funzioni CRUD per la gestione delle configurazioni API esterne. Tabella globale (non multi-tenant), accessibile solo al SuperAdmin.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_ana_api_config_get_all` | Recupera tutte le configurazioni API ordinate per service_code e display_order. Usato dalla griglia principale. | (nessuno) | `SETOF ana_api_config` (tutte le colonne) | `Services/CRUD/ApiConfigService.cs`, `Components/Pages/Configurazione/ApiConfigPage.razor` |
| `fn_ana_api_config_get_by_service` | Recupera le configurazioni per un servizio specifico. Usato per lettura API key da codice applicativo. | `p_service_code VARCHAR(50)` | `SETOF ana_api_config` (record del servizio specificato) | `Services/CRUD/ApiConfigService.cs` |
| `sp_ana_api_config_create` | Crea nuova configurazione API con validazione completa. **Normalizzazione automatica**: forza UPPER CASE su service_code, service_name, config_key, config_type, config_description. **Validazioni**: campi obbligatori non vuoti, config_type in (TEXT, API_KEY, URL, SECRET, BOOLEAN). **Gestione errori**: DUPLICATE_KEY (unique violation), INVALID_DATA (check constraint). | `p_service_code VARCHAR(50), p_service_name VARCHAR(100), p_config_key VARCHAR(100), p_config_value TEXT, p_config_type VARCHAR(20), p_config_description VARCHAR(255), p_is_secret BOOLEAN, p_is_active BOOLEAN, p_display_order SMALLINT, p_created_by VARCHAR(50)` | `INTEGER` (config_id del record creato) | `Services/CRUD/ApiConfigService.cs`, `Components/Pages/Configurazione/ApiConfigEditDialog.razor` |
| `sp_ana_api_config_update` | Aggiorna configurazione API esistente con validazione. **Normalizzazione automatica**: forza UPPER CASE. **Validazioni**: verifica esistenza record, campi obbligatori non vuoti, config_type valido. **Gestione errori**: RECORD_NOT_FOUND, DUPLICATE_KEY, INVALID_DATA. | `p_config_id INTEGER, p_service_code VARCHAR(50), p_service_name VARCHAR(100), p_config_key VARCHAR(100), p_config_value TEXT, p_config_type VARCHAR(20), p_config_description VARCHAR(255), p_is_secret BOOLEAN, p_is_active BOOLEAN, p_display_order SMALLINT, p_updated_by VARCHAR(50)` | `VOID` | `Services/CRUD/ApiConfigService.cs`, `Components/Pages/Configurazione/ApiConfigEditDialog.razor` |
| `sp_ana_api_config_delete` | Elimina una singola configurazione API per ID. **Gestione errori**: RECORD_NOT_FOUND. | `p_config_id INTEGER` | `VOID` | `Services/CRUD/ApiConfigService.cs`, `Components/Pages/Configurazione/ApiConfigPage.razor` |
| `sp_ana_api_config_delete_service` | Elimina tutte le configurazioni di un servizio specifico. **Gestione errori**: RECORD_NOT_FOUND (nessuna config trovata). | `p_service_code VARCHAR(50)` | `VOID` | `Services/CRUD/ApiConfigService.cs` |
| `fn_get_api_config_value` | Recupera il valore di una singola configurazione API attiva dato service_code e config_key. **Normalizzazione automatica**: UPPER CASE + TRIM su entrambi i parametri. **Validazioni**: parametri obbligatori, esistenza record, stato attivo (`is_active = TRUE`), valore non vuoto. **Gestione errori**: CONFIG_NOT_FOUND (record inesistente), CONFIG_DISABLED (configurazione disattivata), CONFIG_EMPTY (valore non impostato), INVALID_DATA (parametri vuoti). Usato da `CurrencyApiService` per recuperare API key (ALPHA_VANTAGE, UNIRATE) dal DB con service_code `API_VALUTE` invece che da costanti cablate nel codice. | `p_service_code VARCHAR(50), p_config_key VARCHAR(100)` | `TEXT` (config_value del record trovato) | `Services/CRUD/ApiConfigService.cs`, `Services/ExternalApis/CurrencyApiService.cs` |

### 📝 Note Implementative - Configurazione API (2026-02-20)

**Architettura DB-First Completa**:
- ✅ **Zero SQL diretto** in `ApiConfigService.cs` - tutte le operazioni delegate al database
- ✅ Normalizzazione UPPER CASE gestita lato database (stored procedures)
- ✅ Validazioni business rules nel database (constraint + procedure logic)
- ✅ Trigger `trg_touch_updated_at_api_config` aggiorna automaticamente `updated_at` su ogni modifica

**Differenze vs altre tabelle anagrafiche**:
- **Tabella globale**: Nessun `azienda_fk` - non è multi-tenant
- **Solo SuperAdmin**: Pagina protetta con `@attribute [Authorize(Roles = "superadmin")]`
- **Servizio standalone**: `ApiConfigService` NON eredita da `BaseCrudService<T>`
- **Unique constraint**: `(service_code, config_key)` - una sola chiave per servizio

**Constraint e Validazioni DB**:
- `uk_api_config_service_key`: UNIQUE su (service_code, config_key) - previene duplicati
- Validazione config_type: TEXT, API_KEY, URL, SECRET, BOOLEAN
- Trigger automatic updated_at enforcement

**Recupero API Key dal DB (2026-02-20)**:
- `fn_get_api_config_value('API_VALUTE', 'ALPHA_VANTAGE_API_KEY')` → restituisce la chiave Alpha Vantage
- `fn_get_api_config_value('API_VALUTE', 'UNIRATE_API_KEY')` → restituisce la chiave UniRate
- `CurrencyApiService` carica le chiavi dal DB al primo utilizzo e le mantiene in cache per la durata dello scope
- Le API key non sono più cablate nel codice sorgente

**File SQL**: `SqlScripts/Create_AnaApiConfig.sql` (tabella + trigger), `SqlScripts/Create_AnaApiConfig_CRUD.sql` (stored functions), `SqlScripts/122_Create_fn_get_api_config_value.sql` (funzione lookup singola chiave)

---

## 10.1 Export Dati

Funzioni dedicate all'estrazione dati per export in formati esterni (Excel, CSV).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_clienti_export` | Restituisce i dati clienti in formato flat per export Excel. Solo campi business (no FK tecnici, no blob binari). Comuni e province decodificati con JOIN su `ana_geo_comuni` e `ana_geo_province`. Ordinamento per azienda, cognome, nome. Se `p_azienda_id IS NULL`, restituisce clienti di tutte le aziende (SuperAdmin). | `p_azienda_id INTEGER DEFAULT NULL` | `TABLE(cognome VARCHAR, nome VARCHAR, titolo VARCHAR, sesso CHAR(1), data_nascita DATE, comune_nascita TEXT, provincia_nascita VARCHAR, indirizzo_residenza VARCHAR, comune_residenza TEXT, provincia_residenza VARCHAR, prefisso_telefono VARCHAR, telefono VARCHAR, email VARCHAR, codice_fiscale VARCHAR, iban VARCHAR, tipo_documento VARCHAR, numero_documento VARCHAR, documento_rilasciato_da VARCHAR, documento_data_rilascio DATE, documento_data_scadenza DATE, intolleranza TEXT, note TEXT, azienda VARCHAR)` | `Services/Export/ClienteExportService.cs`, `SqlScripts/230_Create_FnGetClientiExport.sql` |

### Note Implementative - Export Dati (2026-03-03)

**Architettura Export**:
- **DB Function** per estrazione dati flat (decodifica FK lato DB)
- **ExcelExportService** generico con `ExcelColumnDefinition<T>` per generazione .xlsx (ClosedXML)
- **FileOpenerService** generico per apertura file post-generazione (Mac + Windows)
- **ExcelExportButton** componente Blazor riutilizzabile nella toolbar delle DataGrid

**Pattern Riutilizzabilità**:
- Per aggiungere un nuovo export Excel: creare function DB dedicata, DTO, service con `GetColumnDefinitions()`, e usare `ExcelExportButton` nella pagina
- `ExcelExportService.ExportToExcelAsync<T>()` accetta qualsiasi tipo T con lista colonne configurabile

**File SQL**: `SqlScripts/230_Create_FnGetClientiExport.sql`

---

## 11. Implementazioni Service-Side (Logica Applicativa)
Nota: Queste non sono funzioni DB, ma descrizioni di logica C# rilevante.

| Componente | Funzionalità | Descrizione | Files Coinvolti |
| :--- | :--- | :--- | :--- |
| `ComuneService` | Decodifica Geografica | Esegue JOIN su `ana_geo_province`, `ana_geo_regioni_ita` per recuperare Sigla Provincia e Nome Regione. | `Services/CRUD/ComuneService.cs` |

---

## 12. Wizard Iscrizione Viaggi (Flask)

Funzioni PostgreSQL dedicate al wizard di iscrizione viaggi online (applicazione Flask + React, separata dall'app MAUI). Tutte le funzioni usano il prefisso `fn_wizard_*` per distinguerle dalle funzioni dell'app MAUI. Create durante la migrazione Oracle → PostgreSQL (Marzo 2026).

**Progetto**: `Iscrizione-Viaggi-Offroad PostgreSQL` (Flask 3.1 + React 18 + psycopg v3)
**Azienda**: Sardegna Fuori Traccia (AZIENDA_ID = 2)
**Repository**: separato dal repository MAUI

### 12.1 Step 1 - Selezione Viaggio, Data, Email

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_viaggi_disponibili` | Restituisce i viaggi attivi che hanno almeno una data futura. JOIN con `ana_date_viaggi` per filtrare solo viaggi con partenze future. Ordinamento per descrizione. | `p_azienda_id INT` | `TABLE(viaggio_id, viaggio_descrizione_breve, viaggio_descrizione_estesa, ...)` | `Classi_Tabelle_DB/lista_viaggi.py` |
| `fn_wizard_get_viaggio_by_id` | Restituisce il dettaglio di un singolo viaggio con JOIN su nazione (`ana_geo_nazioni`) e tipo pernottamento (`ana_tipo_pernottamento`). Include flag `albergo_sino` per determinare se il viaggio prevede alloggio. | `p_viaggio_id INT` | `TABLE(viaggio_id, viaggio_descrizione_breve, nazione_nome, pernottamento_descrizione, albergo_sino, ...)` | `Classi_Tabelle_DB/lista_viaggi.py` |
| `fn_wizard_get_date_viaggio` | Restituisce le date future disponibili per un viaggio. Filtra `data_inizio >= CURRENT_DATE`. Ordinamento cronologico. | `p_viaggio_id INT` | `TABLE(data_viaggio_id, data_inizio, data_fine, ...)` | `Classi_Tabelle_DB/lista_date_viaggi.py` |
| `fn_wizard_get_date_by_id` | Restituisce il dettaglio di una singola data viaggio con formattazione date in italiano (`TO_CHAR` con locale `it_IT`). Usato per visualizzare le date nel riepilogo. | `p_data_viaggio_id INT` | `TABLE(data_viaggio_id, data_inizio, data_fine, data_inizio_label, data_fine_label, ...)` | `Classi_Tabelle_DB/lista_date_viaggi.py` |
| `fn_wizard_verifica_cliente` | Verifica se un cliente esiste nel database per email e azienda. Usato nello Step 1 per determinare se precompilare il form (cliente esistente) o mostrare form vuoto (nuovo cliente). | `p_email VARCHAR, p_azienda_id INT` | `TABLE(cliente_exists BOOLEAN, cliente_id INT)` | `Classi_Tabelle_DB/cliente.py` |
| `fn_wizard_leggi_dati_cliente` | Recupera tutti i dati anagrafici di un cliente per email, incluse descrizioni comuni (residenza e nascita) tramite JOIN su `ana_geo_comuni`. Usato per precompilare il form dello Step 2. | `p_email VARCHAR` | `TABLE(cliente_id, cliente_titolo, cliente_cognome, cliente_nome, cliente_sesso, cliente_email, cliente_codicefiscale, descrizione_comune_residenza, descrizione_comune_nascita, ...)` | `Classi_Tabelle_DB/cliente.py` |
| `fn_wizard_is_cliente_registrato` | Verifica se un cliente e gia iscritto a uno specifico viaggio/data. Previene prenotazioni duplicate. Restituisce TRUE se esiste gia un record in `mov_clienti_viaggi`. | `p_cliente_id INT, p_viaggio_id INT, p_data_viaggio_id INT` | `BOOLEAN` | `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` |

### 12.2 Step 2 - Dati Pilota/Cliente

#### 12.2.1 Funzioni geografiche (Comuni, Province, Regioni, Nazioni)

Aggiunte il 2026-03-21. Script di migrazione: `Documenti PostgreSQL/Migration_Scripts/Add_Geo_Functions.sql`.

##### Comuni (5 funzioni)

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_comuni` | Tutti i comuni ordinati per descrizione. | — | `TABLE(comune_id INT, comune_descrizione VARCHAR, comune_istat VARCHAR, comune_provincia_fk INT, comune_preftel VARCHAR, comune_cap VARCHAR, comune_codfisc VARCHAR, comune_num_abitanti INT, comune_link VARCHAR, comune_ripgeo_fk INT, comune_capoluogo_fk INT, comune_estero BOOLEAN)` | `Classi_Tabelle_DB/comuni.py` |
| `fn_wizard_get_comune_by_id` | Singolo comune per ID. | `p_comune_id INTEGER` | Same 12 columns as `fn_wizard_get_all_comuni` | `Classi_Tabelle_DB/comuni.py` |
| `fn_wizard_get_comune_by_istat` | Codice catastale dato codice ISTAT. | `p_istat VARCHAR` | `TABLE(comune_codfisc VARCHAR)` | `Classi_Tabelle_DB/comuni.py` |
| `fn_wizard_get_comuni_by_cliente` | FK comuni di nascita e residenza da `ana_clienti`. | `p_cliente_id INTEGER` | `TABLE(cliente_comune_nascita_fk INT, cliente_comune_residenza_fk INT)` | `Classi_Tabelle_DB/comuni.py` |
| `fn_wizard_search_comuni` | Ricerca con ILIKE (case-insensitive, accent-safe). `p_term` passato as-is. La più critica: chiamata da `/api/geo/comuni/search` ad ogni digitazione. | `p_term TEXT, p_limit INTEGER` | `TABLE(comune_id INT, comune_descrizione VARCHAR)` | `Classi_Tabelle_DB/comuni.py`, `app.py` |

##### Province (2 funzioni)

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_province` | Tutte le province ordinate per descrizione. | — | `TABLE(provincia_id INT, provincia_descrizione VARCHAR, provincia_sigla VARCHAR, provincia_superficie NUMERIC, provincia_residenti INT, provincia_num_comuni INT, regione_id_fk INT)` | `Classi_Tabelle_DB/province.py` |
| `fn_wizard_get_provincia_by_comune` | Provincia via JOIN con `ana_geo_comuni`. | `p_comune_id INTEGER` | Same 7 columns as `fn_wizard_get_all_province` | `Classi_Tabelle_DB/province.py` |

##### Regioni (2 funzioni)

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_regioni` | Tutte le regioni ordinate per descrizione. | — | `TABLE(regione_id INT, regione_descrizione VARCHAR, regione_nr_residenti INT, regione_perc_residenti NUMERIC, regione_densita_kmq NUMERIC, regione_nr_province INT, regione_nr_comuni INT, country_id_fk INT)` | `Classi_Tabelle_DB/regioni.py` |
| `fn_wizard_get_regione_by_provincia` | Regione via JOIN con `ana_geo_province`. | `p_provincia_id INTEGER` | Same 8 columns as `fn_wizard_get_all_regioni` | `Classi_Tabelle_DB/regioni.py` |

##### Nazioni (2 funzioni)

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_nazioni` | Tutte le nazioni ordinate per descrizione. | — | `TABLE(country_id INT, name VARCHAR, nationality VARCHAR, country_code VARCHAR, iso_alpha2 VARCHAR, capital VARCHAR, population INT, area_km2 NUMERIC, region_id INT, sub_region_id INT, intermediate_region_id INT, organization_region_id INT)` | `Classi_Tabelle_DB/nazioni.py` |
| `fn_wizard_get_nazione_by_regione` | Nazione via JOIN con `ana_geo_regioni_ita`. | `p_regione_id INTEGER` | Same 12 columns as `fn_wizard_get_all_nazioni` | `Classi_Tabelle_DB/nazioni.py` |

#### 12.2.2 Funzioni lettura cliente (5 funzioni) ✅ Creato (2026-03-21)

Aggiunte il 2026-03-21. Script di migrazione: `Documenti PostgreSQL/Migration_Scripts/Add_Cliente_Read_Functions.sql`.
Usate da: Step 2, Step 3, Step 5 del wizard.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_client_data` | Recupera i dati anagrafici di un cliente per la validazione del codice fiscale. LEFT JOIN tra `ana_clienti` e `ana_geo_comuni` per ottenere il codice catastale del comune di nascita. | `p_cliente_id INTEGER` | `TABLE(cliente_cognome, cliente_nome, cliente_data_nascita, cliente_sesso, comune_codfisc, cliente_intolleranza)` | `Classi_Tabelle_DB/cliente.py` (`get_client_data()`) |
| `fn_wizard_find_email_by_anagrafica` | Cerca l'email di un cliente tramite cognome, nome e codice fiscale (confronto UPPER() case-insensitive). Usato per rilevare clienti duplicati prima dell'inserimento. | `p_cognome VARCHAR, p_nome VARCHAR, p_cf VARCHAR, p_azienda_id INTEGER` | `TABLE(cliente_email VARCHAR)` | `Classi_Tabelle_DB/cliente.py` (`find_existing_email_by_anagrafica()`) |
| `fn_wizard_check_cf_esistenza` | Verifica con EXISTS se un codice fiscale e gia presente per l'azienda. `p_cliente_id NULL` = scenario INSERT (controlla tutti i record); `p_cliente_id non-NULL` = scenario UPDATE (esclude il cliente corrente). | `p_cf VARCHAR, p_azienda_id INTEGER, p_cliente_id INTEGER DEFAULT NULL` | `TABLE(cf_exists BOOLEAN)` | `Classi_Tabelle_DB/cliente.py` (`check_codice_fiscale_esistenza()`) |
| `fn_wizard_find_email_by_cf` | Cerca l'email di un cliente tramite codice fiscale (confronto UPPER() case-insensitive). LIMIT 1. Usato per recuperare l'email del titolare del CF in caso di conflitto. | `p_cf VARCHAR, p_azienda_id INTEGER` | `TABLE(cliente_email VARCHAR)` | `Classi_Tabelle_DB/cliente.py` (`find_existing_email_by_cf()`) |
| `fn_wizard_get_partecipanti_details` | Recupera dati anagrafici completi per un array di ID cliente. Usa `WHERE cliente_id = ANY(p_ids)`. Chiamato con cast esplicito `::integer[]`. Usato nel riepilogo Step 5 e nell'email di conferma. | `p_ids INTEGER[]` | `TABLE(cliente_id, cliente_cognome, cliente_nome, cliente_email, cliente_data_nascita, cliente_intolleranza)` | `Classi_Tabelle_DB/cliente.py` (`get_partecipanti_details()`) |

#### 12.2.3 Operazioni cliente scrittura (2 funzioni) ✅ Creato (2026-03-21)

Aggiunte il 2026-03-21. Script di migrazione: `Documenti PostgreSQL/Migration_Scripts/Add_Cliente_Write_Functions.sql`.
Usate da: `insert_cliente()` e `update_cliente()` in `Classi_Tabelle_DB/cliente.py`.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_insert_cliente` | Inserisce un nuovo cliente in `ana_clienti` e restituisce il `cliente_id` generato. Imposta i campi audit `created_by` e `created`. | `p_azienda_id INTEGER, p_titolo VARCHAR, p_cognome VARCHAR, p_nome VARCHAR, p_sesso VARCHAR, p_comune_residenza_fk INTEGER, p_indirizzo_residenza VARCHAR, p_comune_nascita_fk INTEGER, p_data_nascita DATE, p_preftelint VARCHAR, p_telefono VARCHAR, p_email VARCHAR, p_codicefiscale VARCHAR, p_intolleranza TEXT, p_tipodoc_identita VARCHAR, p_documento_numero VARCHAR, p_documento_rilasciato_da VARCHAR, p_documento_rilasciato_data DATE, p_documento_rilasciato_scadenza DATE, p_created_by VARCHAR DEFAULT 'WIZARD'` | `INTEGER` (nuovo cliente_id) | `Classi_Tabelle_DB/cliente.py` (`insert_cliente()`) |
| `fn_wizard_update_cliente` | Aggiorna i dati anagrafici di un cliente esistente in `ana_clienti`. Restituisce TRUE se almeno una riga è stata aggiornata (FOUND). | `p_cliente_id INTEGER, p_titolo VARCHAR, p_cognome VARCHAR, p_nome VARCHAR, p_sesso VARCHAR, p_comune_residenza_fk INTEGER, p_indirizzo_residenza VARCHAR, p_comune_nascita_fk INTEGER, p_data_nascita DATE, p_preftelint VARCHAR, p_telefono VARCHAR, p_email VARCHAR, p_codicefiscale VARCHAR, p_intolleranza TEXT, p_tipodoc_identita VARCHAR, p_documento_numero VARCHAR, p_documento_rilasciato_da VARCHAR, p_documento_rilasciato_data DATE, p_documento_rilasciato_scadenza DATE` | `BOOLEAN` (FOUND) | `Classi_Tabelle_DB/cliente.py` (`update_cliente()`) |

### 12.3 Step 3 - Passeggeri

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_partecipanti` | Recupera dati anagrafici per un array di ID cliente. Usa `WHERE cliente_id = ANY(p_ids)`. Usato per visualizzare la lista passeggeri selezionati. | `p_ids INT[]` | `TABLE(cliente_id, cliente_cognome, cliente_nome, cliente_email, cliente_data_nascita)` | `app.py` (endpoint `/api/partecipanti`) |

### 12.4 Step 4 - Veicolo

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_tipi_mezzi` | Restituisce tutti i tipi di mezzi ordinati per descrizione. Usato per popolare il combobox tipo mezzo. | - | `TABLE(ana_tipo_mezzo_id, ana_tipo_mezzo_descrizione)` | `tipo_mezzo.py`, `app.py` |
| `fn_wizard_get_all_mezzi` | Restituisce tutte le marche di veicoli ordinate per descrizione. Usato per popolare il combobox marca. | - | `TABLE(ana_mezzi_id, ana_mezzi_descrizione)` | `mezzi.py`, `Classi_Tabelle_Statiche/ana_mezzi_dao.py` |
| `fn_wizard_get_mezzo_by_id` | Restituisce il dettaglio di una singola marca per ID. | `p_mezzo_id INT` | `TABLE(ana_mezzi_id, ana_mezzi_descrizione)` | `mezzi.py` |
| `fn_wizard_get_mezzi_by_tipo` | Restituisce tutte le marche che hanno almeno un modello del tipo specificato, ordinate per descrizione. Usato per filtrare il combobox marca in base al tipo selezionato. | `p_tipo_id INT` | `TABLE(ana_mezzi_id, ana_mezzi_descrizione)` | `mezzi.py`, `app.py` |
| `fn_wizard_get_modelli_by_mezzo` | Restituisce tutti i modelli per una marca specifica, ordinati per descrizione. Usato per popolare il combobox modello. | `p_mezzo_id INT` | `TABLE(mezzo_modello_id, mezzo_modello_descrizione, ana_mezzi_id_fk)` | `modelli_mezzi.py`, `Classi_Tabelle_Statiche/ana_mezzi_modelli_dao.py` |
| `fn_wizard_get_modelli_by_mezzo_and_tipo` | Restituisce tutti i modelli per una marca specifica filtrati per tipo, ordinati per descrizione. Usato per popolare il combobox modello con solo i modelli pertinenti al tipo selezionato. | `p_mezzo_id INT, p_tipo_id INT` | `TABLE(mezzo_modello_id, mezzo_modello_descrizione, mezzo_modello_mezzo_fk, mezzo_modello_tipo_fk)` | `modelli_mezzi.py`, `app.py` |
| `fn_wizard_get_modello_by_id` | Restituisce il dettaglio di un singolo modello per ID. | `p_modello_id INT` | `TABLE(mezzo_modello_id, mezzo_modello_descrizione, ana_mezzi_id_fk)` | `modelli_mezzi.py` |
| `fn_wizard_get_mezzi_by_ids` | Lookup marche per array di ID. Usato nel riepilogo finale per risolvere gli ID in descrizioni leggibili. | `p_ids INT[]` | `TABLE(ana_mezzi_id, ana_mezzi_descrizione)` | `mezzi.py`, `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` |
| `fn_wizard_get_modelli_by_ids` | Lookup modelli per array di ID. Usato nel riepilogo finale per risolvere gli ID in descrizioni leggibili. | `p_ids INT[]` | `TABLE(mezzo_modello_id, mezzo_modello_descrizione)` | `modelli_mezzi.py`, `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` |

### 12.5 Step 5 - Alloggi e Riepilogo

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_all_tipi_alloggio` | Restituisce tutti i tipi di alloggio ordinati per descrizione. Usato per popolare il combobox alloggio. | - | `TABLE(tipo_alloggio_id, tipo_alloggio_descrizione)` | `tipo_alloggio.py` |
| `fn_wizard_get_tipi_alloggio_by_ids` | Lookup tipi alloggio per array di ID. Usato nel riepilogo finale. | `p_ids INT[]` | `TABLE(tipo_alloggio_id, tipo_alloggio_descrizione)` | `tipo_alloggio.py`, `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` |
| `fn_wizard_get_albergo_sino` | Restituisce il flag albergo (Y/N) per un tipo di pernottamento. Determina se mostrare la sezione alloggi nel wizard. | `p_pernottamento_id INT` | `CHAR(1)` ('Y' o 'N') | `Classi_Tabelle_DB/tipo_pernottamento.py` |

### 12.6 Prenotazione Scrittura (Task 4) ✅ Creato (2026-03-21)

Aggiunte il 2026-03-21. Script di migrazione: `Documenti PostgreSQL/Migration_Scripts/Add_Prenotazione_Write_Functions.sql`.
Usate da: `insert_prenotazione()` in `mov_clienti_viaggi_dao.py` e `insert_alloggi_assegnati()` in `mov_clienti_alloggi_dao.py`.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_insert_prenotazione` | Inserisce una singola riga di partecipazione al viaggio in `mov_clienti_viaggi`. I campi audit (`created_by`, `updated_by`, `created`, `updated`) sono gestiti dal trigger di tabella tramite `current_setting('my.app_user', true)`. Chiamata sia per il pilota (tipo_partecipante=4) che per ciascun passeggero (tipo_partecipante=6). | `p_viaggio_id INTEGER, p_data_viaggio_id INTEGER, p_cliente_id INTEGER, p_tipo_partecipante INTEGER, p_pilota_id INTEGER, p_mezzo_id INTEGER, p_modello_id INTEGER, p_targa VARCHAR, p_has_cane VARCHAR, p_notes TEXT` | `VOID` | `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` (`insert_prenotazione()`) |
| `fn_wizard_insert_alloggio_assegnato` | Inserisce una riga di assegnazione camera in `mov_clienti_alloggi`. La PK viene generata tramite `nextval('mov_clienti_alloggi_seq')`. Supporta fino a 6 occupanti per camera (slot `p_cli1`..`p_cli6`; NULL per slot vuoti). | `p_viaggio_id INTEGER, p_data_viaggio_id INTEGER, p_tipo_alloggio_id INTEGER, p_cli1 INTEGER, p_cli2 INTEGER, p_cli3 INTEGER, p_cli4 INTEGER, p_cli5 INTEGER, p_cli6 INTEGER, p_created_by VARCHAR` | `VOID` | `Classi_Tabelle_DB/mov_clienti_alloggi_dao.py` (`insert_alloggi_assegnati()`) |

### 12.7 Prenotazione Lettura (Task 5) ✅ Creato (2026-03-21)

Aggiunte il 2026-03-21. Script di migrazione: `Documenti PostgreSQL/Migration_Scripts/Add_Summary_Read_Functions.sql`.
Usate da: `get_summary_data_for_trip_date()` in `mov_clienti_viaggi_dao.py`.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_registrazioni_viaggio` | Restituisce tutte le righe di `mov_clienti_viaggi` per un viaggio e una data specifici. Sostituisce le due query inline separate per piloti (tipo_partecipante=4) e passeggeri (tipo_partecipante=6); il filtraggio avviene in Python dopo il fetch. | `p_viaggio_id INTEGER, p_data_viaggio_id INTEGER` | `TABLE(viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk, tipo_partecipante_id_fk, cliente_pilota_id_fk, ana_mezzi_id_fk, mezzo_modello_id_fk, mov_cliente_viaggio_targa_mezzo, mov_cliente_viaggio_cane_sino, mov_cliente_viaggio_note)` | `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` (`get_summary_data_for_trip_date()`) |
| `fn_wizard_get_alloggi_viaggio` | Restituisce tutte le righe di `mov_clienti_alloggi` per un viaggio e una data specifici, con i 6 slot occupanti. Sostituisce la query inline su `mov_clienti_alloggi`. | `p_viaggio_id INTEGER, p_data_viaggio_id INTEGER` | `TABLE(mov_clienti_alloggio_pk, viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk, cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)` | `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` (`get_summary_data_for_trip_date()`) |

`fn_wizard_get_partecipanti_details` (sezione 12.2.2) è **riutilizzata** anche qui per recuperare i dettagli anagrafici di tutti i partecipanti: sostituisce la query inline su `ana_clienti`.

### 12.8 Finalizzazione e Email

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_smtp_config` | Recupera la configurazione SMTP per un'azienda dalla tabella `ana_aziende_smtp`. Restituisce host, porta, username, password (da `password_enc->>'value'`), metodo sicurezza, email e nome mittente. Usato da `create_app()` per configurare Flask-Mail. | `p_azienda_id INT` | `TABLE(host, port, username, password, security_method, from_email, from_name)` | `app.py` (funzione `create_app()`) |
| `fn_wizard_get_azienda_email_principale` | Restituisce l'indirizzo email principale (`is_principale=true`) dell'azienda specificata dalla tabella `ana_aziende_email`. Usato in `/api/prenotazione/finalizza` per inviare la mail di riepilogo progressivo alla segreteria. | `p_azienda_id INTEGER` | `CHARACTER VARYING` (email principale) | `app.py` (route `/api/prenotazione/finalizza`), `Classi_Tabelle_DB/azienda_dao.py` (`AziendaDAO.get_email_principale`) |

La finalizzazione della prenotazione è ora completamente DB-First: Task 4 e Task 5 completati il 2026-03-21. I campi audit (`created_by`, `updated_by`) sono gestiti tramite trigger di tabella che leggono `current_setting('my.app_user', true)`.

Le stored procedure MAUI `sp_mov_clienti_viaggi_create` e `sp_mov_clienti_alloggi_create` (sezione 5) **non sono usate** dal wizard perche hanno una signature diversa e logica aggiuntiva specifica per l'app MAUI.

### Note Implementative - Wizard Iscrizione Viaggi (2026-03-10)

**Architettura**:
- **Driver**: psycopg v3 con `psycopg_pool.ConnectionPool(min_size=1, max_size=5)`
- **Pattern DAO**: `conn = db_manager.get_connection()` → `cursor.execute()` → `db_manager.release_connection(conn)`
- **Bind params**: `%(nome_parametro)s` (named params psycopg)
- **Approccio misto**: Funzioni `fn_wizard_*` per query di lettura complesse (JOIN, filtri, formattazione); SQL diretto per operazioni CRUD semplici (INSERT/UPDATE con RETURNING)

**Tabelle coinvolte**:
- `ana_viaggi`, `ana_date_viaggi` → Selezione viaggio e data
- `ana_clienti` → Anagrafica pilota e passeggeri
- `ana_geo_comuni`, `ana_geo_province`, `ana_geo_regioni_ita`, `ana_geo_nazioni` → Dati geografici
- `ana_mezzi`, `ana_mezzi_modelli` → Veicoli
- `ana_tipo_alloggio`, `ana_tipo_pernottamento` → Alloggi
- `mov_clienti_viaggi` → Iscrizioni al viaggio
- `mov_clienti_alloggi` → Assegnazione camere
- `ana_aziende_smtp` → Configurazione email
- `ana_aziende_email` → Email principale azienda (destinatario mail segreteria)

**Totale funzioni fn_wizard_***: 41 (7 Step 1 + 11 Step 2 Geo + 5 Step 2 Cliente lettura + 2 Step 2 Cliente scrittura + 1 Step 3 + 6 Step 4 + 3 Step 5 + 2 Prenotazione scrittura + 2 Prenotazione lettura + 2 Email)

### `fn_get_viaggi_init_data`
Recupera in un'unica chiamata JSON tutti i lookups (Nazioni, Tipi Viaggio, Trattamenti, Pernottamenti, Avvicinamenti, Aziende) e le date di un viaggio. Utilizzata per l'inizializzazione di `AnaViaggiDialog.razor`.

- **Parametri**:
  - `p_viaggio_id` (INT, default NULL): ID del viaggio per recuperare le date (modalità edit).
- **Ritorna**: `JSON` contenente gli array di lookup e le date.
- **Utilizzo**: `AnaViaggiService.GetViaggiInitDataAsync(int? viaggioId)`
- **Fix 2026-04-08**: Corretti nomi colonne (`tipo_viaggi_id`, `ana_tipo_pernottamento_id`, `ragione_sociale`); `ORDER BY` spostato dentro `json_agg()`.

### `fn_get_viaggio_partecipanti_init_data`
Recupera l'intero stato iniziale del dialog gestione partecipanti, inclusi partecipanti (ordinati e senza camera), contatori, riepiloghi, liste camere con occupanti, intestazione viaggio e lookups necessari. Consolidamento di circa 9 chiamate separate.

- **Parametri**:
  - `p_viaggio_id` (INT): ID del viaggio.
  - `p_data_viaggio_id` (INT): ID della data viaggio specifica.
- **Ritorna**: `JSON` con lo stato completo del dialog.
- **Utilizzo**: `MovClientiViaggiService.GetPartecipantiInitDataAsync(int viaggioId, int dataViaggioId)`

### `fn_get_cliente_init_data`
Recupera in un'unica chiamata JSON tutti i dati necessari per l'inizializzazione del dialog Cliente: lista completa dei comuni (per ricerca), lista aziende (per SuperAdmin) e dettagli geografici del cliente (nascita e residenza). Ottimizzazione che riduce le connessioni parallele e il carico di memoria.

- **Parametri**:
  - `p_cliente_id` (INT, default NULL): ID del cliente per recuperare i dettagli comuni esistenti.
- **Ritorna**: `JSON` contenente `Comuni`, `Aziende`, `ComuneNascita` e `ComuneResidenza`.
- **Utilizzo**: `ClienteService.GetClienteInitDataAsync(int? clienteId)`

### `fn_get_controparte_init_data`
Recupera in un'unica chiamata JSON tutti i dati necessari per l'inizializzazione del dialog Controparte: comuni, aziende (per SuperAdmin), tipi fornitore e dettaglio comune della controparte.

- **Parametri**:
  - `p_controparte_id` (INT, default NULL): ID della controparte per recuperare i dettagli comuni esistenti.
- **Ritorna**: `JSON` contenente `Comuni`, `Aziende`, `TipiFornitore` e `Comune`.
- **Utilizzo**: `ContropartiService.GetControparteInitDataAsync(int? controparteId)`

## Area: Movimenti Contabili

### `fn_get_transazione_init_data`
Funzione per il pattern **Fat Init** dell'area contabile. Recupera in un'unica chiamata JSON tutti i lookups (Causali, IVA, Valute), le liste di azienda (Controparti, Viaggi) e opzionalmente i dati di una transazione esistente con le sue righe.

- **Parametri**:
  - `p_azienda_id` (INT): ID dell'azienda per filtrare lookups e liste.
  - `p_transazione_id` (INT, default NULL): ID della transazione per recuperare i dettagli (modalità edit).
- **Ritorna**: `JSON` contenente `Causali`, `AliquoteIva`, `Valute`, `Controparti`, `Viaggi`, `ShowHelperCalcolo` e `TransazioneJson`.
- **Utilizzo**: `MovTransazioniService.GetTransazioneInitDataAsync(int aziendaId, int? transazioneId)`

### `fn_get_travel_print_data`
- **Descrizione**: Funzione **Fat Init** per ottimizzare la stampa della scheda viaggio. Aggrega i dati di testata, azienda, partecipanti, statistiche e mezzi in un'unica chiamata JSON. Consolidamento di 5 chiamate separate. **Logo convertito in base64 per compatibilità JSON**.
- **Parametri**:
  - `p_data_viaggio_id` (INT): ID della data viaggio specifica.
- **Ritorna**: `JSON` con chiavi `Header`, `Company`, `Participants`, `Stats`, `PilotsByVehicle`.
- **Utilizzo**: `TravelPrintService.GetPrintDataAsync(int dataViaggioId)`

### `fn_get_rooming_list_print_data`
- **Descrizione**: Funzione **Fat Init** per ottimizzare la stampa della Rooming List. Aggrega i dati di testata, azienda e partecipanti (camere) in un'unica chiamata JSON. Consolidamento di 3 chiamate separate. **Logo convertito in base64 per compatibilità JSON**.
- **Parametri**:
  - `p_data_viaggio_id` (INT): ID della data viaggio specifica.
- **Ritorna**: `JSON` con chiavi `Header`, `Company`, `Participants`.
- **Utilizzo**: `RoomingListPrintService.GetRoomingListDataAsync(int dataViaggioId)`
| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_mov_transazioni_print_data` | **Fat Init**: Ottimizzazione per la stampa dei movimenti contabili. Aggrega Info Azienda (Ragione Sociale, P.IVA, etc.), Dettagli transazioni (via `fn_get_transazioni_stampa_dettaglio`) e Subtotali (via `fn_get_transazioni_stampa_subtotali`) in un unico JSONB. Riduce le connessioni parallele da 3 a 1. **Logo convertito in base64 per compatibilità JSON**. | `p_azienda_id INT, p_controparte_id INT, p_causale_tipo_id INT, p_stati VARCHAR[], p_viaggio_id INT, p_data_viaggio_id INT, p_valuta_id INT, p_data_transazione_da DATE, p_data_transazione_a DATE, p_data_documento_da DATE, p_data_documento_a DATE, p_importo_da NUMERIC, p_importo_a NUMERIC, p_numero_documento VARCHAR, p_solo_con_documento BOOL, p_solo_scadute BOOL, p_solo_con_viaggio BOOL, p_solo_senza_viaggio BOOL, p_solo_con_fattura BOOL, p_ordinamento VARCHAR, p_valuta_target_id INT, p_causale_ciclo VARCHAR` | `JSONB` (chiavi: azienda, dettagli, subtotali) | `Services/Printing/MovTransazioniPrintService.cs`, `SqlScripts/310_Create_FnGetMovTransazioniPrintData.sql` |
| `fn_get_registro_iva_print_data` | **Fat Init**: Ottimizzazione per la stampa del Registro IVA. Aggrega i dati dell'azienda emittente (inclusi logo e sede) e l'elenco delle transazioni (via `fn_get_registro_iva`) filtrate per anno e ciclo contabile (ATTIVO/PASSIVO). **Logo convertito in base64 per compatibilità JSON**. | `p_azienda_id INTEGER, p_anno INTEGER, p_causale_ciclo VARCHAR(10)` | `JSONB` (chiavi: azienda, items) | `Services/Printing/RegistroIvaPrintService.cs`, `SqlScripts/320_Create_FnGetRegistroIvaPrintData.sql` |
| `fn_get_scadenzario_print_data` | **Fat Init**: Ottimizzazione per la stampa dello Scadenzario. Consolida i dati dell'azienda e l'estrazione dettagliata dello scadenzario finanziario (via `fn_get_scadenzario_stampa`). Supporta tutti i filtri di ricerca e raggruppamento dinamico (URGENZA/MESE/CONTROPARTE). **Logo convertito in base64 per compatibilità JSON**. | `p_azienda_id INTEGER, p_controparte_id INTEGER, p_causale_ciclo VARCHAR(10), p_urgenza VARCHAR(20), p_data_scadenza_da DATE, p_data_scadenza_a DATE, p_viaggio_id INTEGER, p_solo_con_viaggio BOOLEAN, p_solo_senza_viaggio BOOLEAN, p_raggruppamento VARCHAR(20)` | `JSONB` (chiavi: azienda, dettagli) | `Services/Printing/ScadenzarioPrintService.cs`, `SqlScripts/330_Create_FnGetScadenzarioPrintData.sql` |
| `fn_get_bilancio_viaggio_print_data` | **Fat Init**: Ottimizzazione per il report Bilancio Viaggio (Singolo o Annuale). Consolida 3-4 query: Info Azienda, Logo binario e dati economici (via `fn_get_bilancio_viaggio` o `fn_get_bilancio_annuale_viaggi`). Permette di generare il bilancio economico completo in un unico passaggio. **Logo convertito in base64 per compatibilità JSON**. | `p_azienda_id INT, p_viaggio_ids INT[], p_data_da DATE, p_data_a DATE, p_anno INT, p_valuta_target_id INT, p_data_viaggio_id INT` | `JSONB` (chiavi: azienda, dettagli) | `Services/Printing/BilancioViaggioPrintService.cs`, `SqlScripts/340_Create_FnGetBilancioViaggioPrintData.sql` |
| `fn_get_fattura_attiva_print_data` | **Fat Init**: Ottimizzazione per la stampa della Fattura Attiva. Risolve il problema delle query multiple per testata (Azienda+Cliente) e righe di dettaglio. Restituisce un oggetto JSONB completo pronto per il mapping nel DTO `FatturaAttivaPrintData`. Include campi SDI per fatturazione elettronica. **Logo convertito in base64 per compatibilità JSON**. | `p_transazione_id INTEGER` | `JSONB` (chiavi: testata, righe) | `Services/Printing/FatturaAttivaPrintService.cs`, `SqlScripts/350_Create_FnGetFatturaAttivaPrintData.sql` |

---

## Fix Logo Stampe (2026-03-15)

**Problema**: PostgreSQL serializzava i campi BYTEA in formato esadecimale (`\x...`) quando convertiti in JSONB, mentre il codice C# si aspettava stringhe base64.

**Soluzione**: Modificate tutte le funzioni di stampa per convertire i logo in base64 direttamente in PostgreSQL usando `encode(binary_data, 'base64')`.

### Funzioni Modificate

| Funzione | Tipo Modifica | File Script |
|----------|---------------|-------------|
| `get_company_print_info` | Cambiato tipo ritorno `logo_data` da `BYTEA` a `TEXT`, aggiunto `encode()` | `SqlScripts/get_company_print_info.sql` |
| `fn_get_rooming_list_print_data` | Rimosso `encode()` duplicato (già fatto da `get_company_print_info`) | `SqlScripts/300_Create_FnGetRoomingListPrintData.sql` |
| `fn_get_fattura_attiva_stampa` | Cambiato tipo `logo_data` da `BYTEA` a `TEXT`, aggiunto `encode()` | `SqlScripts/220_Create_FnGetFatturaAttivaStampa.sql`, `SqlScripts/241_Update_FnGetFatturaAttivaStampa_SDI.sql` |

### Funzioni Non Modificate (Già Corrette)

Le seguenti funzioni usavano `get_company_print_info` e passavano direttamente `logo_data`, quindi funzionano correttamente senza modifiche:
- `fn_get_mov_transazioni_print_data`
- `fn_get_registro_iva_print_data`
- `fn_get_scadenzario_print_data`
- `fn_get_bilancio_viaggio_print_data`
- `fn_get_travel_print_data`

---

## 10. Anagrafiche Clienti

Funzioni e stored procedures per la gestione completa dell'anagrafica clienti (CRUD, ricerca, validazioni). Implementazione **DB-First** completa: zero SQL inline nel codice C#, tutta la logica SQL risiede nel database.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_cliente_by_id` | Recupera singolo cliente per ID con dati completi inclusi comuni di nascita e residenza (nested JSON con nome, sigla provincia, flag estero) | `p_cliente_id INT, p_azienda_fk INT` | `JSON` (oggetto cliente completo con ComuneNascita e ComuneResidenza nested) | `Repositories/ClienteRepository.cs` (GetByIdAsync) |
| `fn_get_all_clienti` | Recupera tutti i clienti per azienda con conteggi viaggi (fatti/futuri) e dati comuni. Supporta filtro opzionale per anno di creazione. Restituisce array JSON con oggetti cliente inclusi comuni nested | `p_azienda_fk INT (nullable), p_filter_year INT (nullable)` | `JSON` (array di clienti con ViaggiFatti, ViaggiDaFare, ComuneNascita, ComuneResidenza) | `Repositories/ClienteRepository.cs` (GetAllAsync), `Components/Pages/Clienti.razor` |
| `sp_ana_clienti_create` | Crea nuovo cliente con validazione e gestione errori. Gestisce eccezioni unique_violation (email/CF duplicati), foreign_key_violation (comune/azienda inesistente). Restituisce JSON con cliente creato inclusi campi audit (created_by, created) | `31 parametri cliente (p_cliente_titolo, p_cliente_cognome, p_cliente_nome, ..., p_azienda_fk)` | `JSON` (cliente creato con tutti i campi) | `Repositories/ClienteRepository.cs` (InsertAsync) |
| `sp_ana_clienti_update` | Aggiorna cliente esistente con validazione e gestione errori. Controlla esistenza cliente prima di aggiornare. Gestisce eccezioni come create. Restituisce JSON con cliente aggiornato inclusi campi audit (updated_by, updated) | `32 parametri (p_cliente_id, p_cliente_titolo, ..., p_azienda_fk)` | `JSON` (cliente aggiornato) | `Repositories/ClienteRepository.cs` (UpdateAsync) |
| `sp_ana_clienti_delete` | Elimina cliente con controlli di integrità referenziale. Impedisce eliminazione se cliente ha prenotazioni viaggi attive (mov_clienti_viaggi) o assegnazioni alloggio (mov_clienti_alloggi). Messaggi di errore in italiano | `p_cliente_id INT, p_azienda_fk INT` | `VOID` (solleva EXCEPTION se vincolato) | `Repositories/ClienteRepository.cs` (DeleteAsync) |
| `fn_exists_cliente_email` | Verifica unicità email per azienda escludendo cliente corrente (utile in UPDATE). Supporta controllo per nuovo cliente (p_cliente_id = 0) o cliente esistente | `p_email VARCHAR(150), p_cliente_id INT, p_azienda_fk INT` | `BOOLEAN` (TRUE se email già in uso da altro cliente) | `Repositories/ClienteRepository.cs` (ExistsByEmailAsync), `Services/CRUD/ClienteService.cs` (validazione) |
| `fn_exists_cliente_codice_fiscale` | Verifica unicità codice fiscale per azienda escludendo cliente corrente. Pattern identico a fn_exists_cliente_email per CF | `p_codice_fiscale VARCHAR(16), p_cliente_id INT, p_azienda_fk INT` | `BOOLEAN` (TRUE se CF già in uso) | `Repositories/ClienteRepository.cs` (ExistsByCodiceFiscaleAsync), `Services/CRUD/ClienteService.cs` |
| `fn_exists_cliente_anagrafica` | Verifica duplicati anagrafica completa: cognome + nome + data nascita + codice fiscale. Impedisce inserimento di clienti con stessa identità. Esclude cliente corrente se in UPDATE | `p_cognome VARCHAR(50), p_nome VARCHAR(50), p_data_nascita DATE, p_codice_fiscale VARCHAR(16), p_cliente_id INT, p_azienda_fk INT` | `BOOLEAN` (TRUE se anagrafica già esistente) | `Repositories/ClienteRepository.cs` (ExistsAnagraficaAsync), `Services/CRUD/ClienteService.cs` |
| `fn_search_clienti` | Ricerca full-text clienti per cognome, nome, email, codice fiscale, telefono. Usa pattern matching LIKE case-insensitive con UPPER. Restituisce JSON con comuni nested come fn_get_all_clienti | `p_azienda_fk INT, p_search_text VARCHAR(100)` | `JSON` (array clienti matching con ComuneNascita/ComuneResidenza nested) | `Repositories/ClienteRepository.cs` (SearchAsync) |
| `fn_count_clienti_by_azienda` | Conta totale clienti per azienda. Usato per statistiche e report | `p_azienda_fk INT` | `INT` (numero totale clienti) | `Repositories/ClienteRepository.cs` (CountByAziendaAsync) |

### 📝 Note Implementative - Anagrafiche Clienti (2026-03-16)

#### 🏗️ Architettura DB-First

**Principio**: ZERO SQL inline nel codice C#. Tutta la logica SQL risiede nelle stored procedures PostgreSQL.

**Prima del refactoring** (inline SQL):
```csharp
var sql = @"SELECT cliente_id, cliente_cognome, ... FROM ana_clienti WHERE ...";
await using var command = new NpgsqlCommand(sql, connection);
var reader = await command.ExecuteReaderAsync();
// mapping manuale da reader a oggetto
```

**Dopo il refactoring** (DB-First):
```csharp
var sql = "SELECT fn_get_all_clienti(@aziendaFk::INT, @filterYear::INT)";
var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);
var clienti = JsonSerializer.Deserialize<List<Cliente>>(jsonResult);
```

**Vantaggi**:
- ✅ Logica SQL centralizzata e testabile nel DB
- ✅ Riduzione drastica della complessità del repository C#
- ✅ Consistenza con altre gestioni (mov_clienti_viaggi, ana_tipo_fornitore)
- ✅ Validazioni e controlli di integrità a livello DB
- ✅ Manutenzione semplificata (modifiche SQL senza rebuild C#)

#### 🗺️ Gestione Comuni (Nested JSON)

Le funzioni `fn_get_all_clienti` e `fn_search_clienti` restituiscono i comuni di nascita e residenza come **oggetti nested JSON**:

```json
{
  "ClienteId": 123,
  "Cognome": "ROSSI",
  "Nome": "MARIO",
  "ComuneNascita": {
    "Nome": "MILANO",
    "ProvinciaSigla": "MI",
    "ProvinciaDescrizione": "MILANO",
    "ComuneEstero": false
  },
  "ComuneResidenza": {
    "Nome": "ROMA",
    "ProvinciaSigla": "RM",
    "ProvinciaDescrizione": "ROMA",
    "ComuneEstero": false
  }
}
```

Per comuni esteri:
```json
{
  "ComuneNascita": {
    "Nome": "CASABLANCA",
    "ProvinciaSigla": "MM",
    "ProvinciaDescrizione": "ESTERO - MAROCCO",
    "ComuneEstero": true
  }
}
```

**JOIN necessari** nelle stored procedures:
```sql
LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
```

#### 🎯 Visualizzazione UI (Datagrid)

La datagrid clienti mostra:
- **NATO A**: `ComuneNascita.Nome (IT)` per italiani, `ComuneNascita.Nome (ProvinciaSigla)` per esteri
- **RESIDENZA**: `ComuneResidenza.Nome (IT)` per italiani, `ComuneResidenza.Nome (ProvinciaSigla)` per esteri
- **PROV.**: `ComuneResidenza.ProvinciaSigla` SOLO per comuni italiani (colonna vuota per esteri)

**Larghezza colonne**: `min-width: 150px` per NATO A e RESIDENZA per evitare troncamento nomi lunghi (es. ALESSANDRIA, MONFERRATO).

#### 🔒 Validazioni e Controlli Integrità

**Validazioni sintattiche** (lato Service C#):
- Lunghezza campi (nome max 50, email max 150, etc.)
- Formato email, telefono, IBAN, codice fiscale
- Date coerenti (nascita < oggi, rilascio doc < scadenza doc)

**Validazioni business** (lato DB + Service):
- Unicità email per azienda (`fn_exists_cliente_email`)
- Unicità codice fiscale per azienda (`fn_exists_cliente_codice_fiscale`)
- Duplicati anagrafica completa (`fn_exists_cliente_anagrafica`)

**Controlli integrità referenziale** (stored procedure delete):
- Impedisce eliminazione cliente con viaggi attivi
- Impedisce eliminazione cliente con alloggi assegnati
- Messaggi di errore italiani: `"Impossibile eliminare il cliente con id % - ha prenotazioni viaggi attive"`

#### 📊 Performance e Ottimizzazioni

**Conteggi viaggi** ottimizzati con `LEFT JOIN LATERAL`:
```sql
LEFT JOIN LATERAL (
    SELECT COUNT(*) as count
    FROM mov_clienti_viaggi mcv
    JOIN ana_date_viaggi adv ON mcv.data_viaggio_id_fk = adv.data_viaggio_id
    WHERE mcv.cliente_id_fk = c.cliente_id
      AND adv.data_viaggio_data_inizio < CURRENT_DATE
) viaggi_fatti ON true
```

**Indici presenti** (da verificare):
- `ana_clienti.cliente_email` (unicità per ricerca email)
- `ana_clienti.cliente_codicefiscale` (unicità per ricerca CF)
- `ana_clienti.azienda_fk` (multi-tenancy)
- `mov_clienti_viaggi.cliente_id_fk` (JOIN viaggi)

#### 🔄 Pattern SuperAdmin

**Comportamento allineato** con altre gestioni (es. AnaTipoFornitore):
- Se SuperAdmin e **nessuna azienda selezionata**: mostra barra loading blu, nessun record
- Se SuperAdmin e **azienda selezionata**: carica clienti solo di quell'azienda
- Se utente normale: carica automaticamente clienti della propria azienda

**Codice**:
```csharp
// SuperAdmin MUST select a company first
if (_isSuperAdmin && !filterId.HasValue)
{
    _items = new List<Cliente>();
    _filteredItems = new List<Cliente>();
    // Keep _loading = true to show loading indicator
    return;
}
```

#### 📝 Script SQL

- **Script principale**: `SqlScripts/356_Create_AnaClienti_CRUD_Procedures.sql`
- **Deployment**: `docker exec -i postgres_db psql -U postgres -d gestione_viaggi < SqlScripts/356_Create_AnaClienti_CRUD_Procedures.sql`
- **Grants**: Tutte le funzioni hanno `GRANT EXECUTE TO PUBLIC`

---

## Allineamento Database (2026-03-15)

### Funzioni Allineate

In data 2026-03-15 è stato effettuato un allineamento completo delle funzioni tra il database locale (Docker) e Supabase (produzione).

| Funzione | Azione | Note |
|----------|--------|------|
| `fn_get_controparte_init_data` | Creata su entrambi | Script `263_Create_FnGetControparteInitData.sql` corretto (nomi colonne tabelle geografiche) |
| `fn_get_cliente_init_data` | Aggiornata su entrambi | Script `262_Create_FnGetClienteInitData.sql` corretto (`ana_geo_regioni` → `ana_geo_regioni_ita`, `provincia_regione_fk` → `regione_id_fk`, `JOIN` → `LEFT JOIN`) |
| `fn_get_azienda_badge_counts` | Creata su Docker | Era presente solo su Supabase |
| `fn_wizard_*` (21 funzioni) | Migrate su Supabase | Funzioni wizard iscrizione online |

### Correzioni Script SQL

Gli script SQL sono stati corretti per allinearsi allo schema effettivo delle tabelle geografiche:

| Errore | Correzione |
|--------|------------|
| `c.comune` | `c.comune_descrizione` |
| `c.cap` | `c.comune_cap` |
| `ana_geo_regioni` | `ana_geo_regioni_ita` |
| `p.provincia_regione_fk` | `p.regione_id_fk` |
| `c.comune_estero` (CHAR) | `(c.comune_estero = 'Y')` (conversione a boolean per JSON) |

### Stato Finale

- **Docker (locale)**: 169 funzioni `fn_*`
- **Supabase (prod)**: 169 funzioni `fn_*`
- **Differenze**: Nessuna

---

## Estensione Web / Utility

Oggetti fondazionali condivisi da tutte le future tabelle `web_*` (nuovo sito pubblico).

### `trg_web_audit()` — trigger di audit condiviso

Funzione trigger unica, riusata da tutte le tabelle `web_*` (DRY, niente copie per-tabella).

- **INSERT**: se `NEW.created_by` è NULL lo valorizza con `COALESCE(current_setting('my.app_user', true), current_user, 'system')`; se `NEW.created` è NULL lo valorizza con `CURRENT_TIMESTAMP`.
- **UPDATE**: valorizza sempre `NEW.updated = CURRENT_TIMESTAMP` e `NEW.updated_by = COALESCE(current_setting('my.app_user', true), current_user, 'system')`.
- Legge il tenant/utente corrente dalla GUC `my.app_user` (impostata dal gestionale via `set_config('my.app_user', <email>, true)`).
- **Script**: `SqlScripts/407_Create_FnTrgWebAudit.sql`. Va agganciato con un trigger `BEFORE INSERT OR UPDATE` su ogni tabella `web_*` che espone le colonne `created`, `created_by`, `updated`, `updated_by`.

### Ruolo `anon`

Ruolo di sola lettura per il traffico pubblico del sito (equivalente locale dell'`anon` di Supabase): `NOLOGIN`, non superuser, **subisce le RLS** (`rolbypassrls=f`). Ha solo `USAGE` su `schema public`; i `GRANT SELECT` specifici vivono negli script delle singole tabelle web. **Script**: `SqlScripts/406_Setup_RoleAnon.sql`.

### Tabella `web_categorie_sport` — categorie "Sport" del sito

Categorie sportive (es. `FUORISTRADA`, `QUAD`, `MOTO_ENDURO`, `MOTO_STRADALE`) mostrate sul sito pubblico, per azienda (multi-tenant).

- **Colonne**: `web_categorie_sport_id` (PK identity), `codice` VARCHAR(20), `etichetta` VARCHAR(50), `slug` VARCHAR(50), `ordine` INTEGER DEFAULT 0, più coda standard `azienda_id` / `created_by` / `created` / `updated_by` / `updated`.
- **Vincoli**: unique `(azienda_id, codice)` e `(azienda_id, slug)`; FK `azienda_id → ana_aziende(azienda_id)` ON DELETE RESTRICT.
- **Audit/RLS**: trigger `trg_web_categorie_sport_audit` (usa `trg_web_audit()`); RLS abilitata con policy `superadmin_bypass_all` per `app_superadmin`.
- **Script**: `SqlScripts/408_Create_WebCategorieSport.sql`.

### Colonna `ana_tipo_viaggi.web_categoria_fk` — mappatura tipo viaggio → categoria sport web

Colonna `BIGINT NULL` aggiunta a `ana_tipo_viaggi` che associa un tipo viaggio a una categoria sport del sito (allineata alla PK `BIGINT` identity di `web_categorie_sport`). FK `web_categoria_fk → web_categorie_sport(web_categorie_sport_id)` ON DELETE SET NULL (se la categoria viene eliminata, il tipo viaggio resta senza mappatura). **Script**: `SqlScripts/409_Alter_AnaTipoViaggi_WebCategoria.sql`.

### Cluster contenuti tour web (1° rilascio)

Tutte con coda standard (`azienda_id` FK `ana_aziende` ON DELETE RESTRICT, audit `created/created_by/updated/updated_by`), trigger `trg_web_audit()`, RLS `superadmin_bypass_all`. Nessun grant ad `anon` (rimandato al Blocco 3).

- **`web_tour_contenuti`** (`SqlScripts/410`) — contenuti editoriali del tour, **1:1** con `ana_viaggi` (`viaggio_id_fk INTEGER UNIQUE`). Campi: sottotitolo, `descrizione_html`, `difficolta` (CHECK `turistica/media/medio_alta/alta`), durata_testo, luoghi_visitati, `info_*_html`, `slug`, meta SEO, `stato_pubblicazione` (CHECK `bozza/pubblicato/archiviato`, default `bozza`), ordine, data_pubblicazione. UNIQUE `(azienda_id, slug)`; indice `(azienda_id, stato_pubblicazione)`.
- **`web_tour_itinerario`** (`SqlScripts/411`) — giornate dell'itinerario (N per tour). `viaggio_id_fk INTEGER`, giorno_numero, titolo_giornata, ordine. UNIQUE `(viaggio_id_fk, giorno_numero)`.
- **`web_tour_itinerario_passaggi`** (`SqlScripts/412`) — passaggi di ogni giornata. `itinerario_id_fk BIGINT` → `web_tour_itinerario` **ON DELETE CASCADE**; testo_html, immagine (url/storage_path/didascalia), ordine.
- **`web_tour_immagini`** (`SqlScripts/413`) — galleria del tour. `viaggio_id_fk INTEGER`, `tipo` (CHECK `principale/galleria`, default `galleria`), url, storage_path, alt/titolo/dimensioni/mime, ordine. Indice `(viaggio_id_fk, tipo, ordine)`; **unique parziale** `uq_web_tour_immagini_principale` (una sola `principale` per tour).
- **`web_tour_mappa`** (`SqlScripts/414`) — mappa percorso, **1:1** (`viaggio_id_fk INTEGER UNIQUE`). `gpx_originale` (solo server), bbox `NUMERIC(9,6)`, provider (`geoapify`), stile (`osm-bright`), `parametri_render JSONB`, immagine (url/storage_path), data_generazione.

### Traduzioni, newsletter e config per-azienda (1° rilascio)

Coda standard + `trg_web_audit()` + RLS `superadmin_bypass_all`; nessun grant ad `anon` (Blocco 3). `email` = `CITEXT` (case-insensitive).

- **`web_traduzioni`** (`SqlScripts/415`) — traduzioni per-campo **polimorfiche** (`entita`, `entita_id BIGINT`, `campo`, `lingua CHAR(2)` CHECK `FR/EN/DE/ES`; IT = sorgente, non qui). Flag `tradotto_auto/revisionato/obsoleto`. UNIQUE `(entita, entita_id, campo, lingua)`.
- **`web_newsletter_iscritti`** (`SqlScripts/416`) — iscritti newsletter. `email CITEXT`, lingua, consenso (+data/fonte), `stato` CHECK `attivo/disiscritto`, `token_disiscrizione`, `cliente_fk → ana_clienti` (solo dedup). UNIQUE `(azienda_id, email)`.
- **`web_newsletter_invii`** (`SqlScripts/417`) — invii (IT; traduzioni in `web_traduzioni`). `stato` CHECK `bozza/in_invio/inviata`, canale, numero_destinatari.
- **`web_newsletter_invii_destinatari`** (`SqlScripts/418`) — log consegna per destinatario. `invio_id_fk BIGINT` → `web_newsletter_invii` **ON DELETE CASCADE**; email, stato_consegna.
- **`web_newsletter_soppressioni`** (`SqlScripts/419`) — lista soppressione (esclusa da ogni invio). `motivo`, UNIQUE `(azienda_id, email)`.
- **`web_aziende_funzioni`** (`SqlScripts/420`) — toggle funzioni per-azienda (recensioni/pagamenti_online/blog/newsletter_esp/…). `attiva`, `parametri JSONB`. UNIQUE `(azienda_id, funzione)`.
- **`ana_aziende_esp`** (`SqlScripts/421`) — credenziali ESP per-azienda (1 per azienda: `azienda_id UNIQUE`). `api_key_enc JSONB` **cifrata** (pattern `password_enc`), sender_email/name/domain, attivo.

### Predisposizione pagamenti + blog (create ma NON cablate nel 1° rilascio)

Coda standard + `trg_web_audit()` + RLS `superadmin_bypass_all`. Chiavi Stripe/segreti in `JSONB` cifrati lato app; importi in **centesimi** (`INTEGER`).

- **`web_pagamenti_config`** (`SqlScripts/422`) — chiavi Stripe per-azienda (`azienda_id UNIQUE`): `stripe_publishable_key`, `stripe_secret_key_enc`/`stripe_webhook_secret_enc` cifrate, `modo` CHECK `test/live`.
- **`web_pagamenti_regole`** (`SqlScripts/423`) — regole pagamento per-azienda (`azienda_id UNIQUE`): `modalita` CHECK `soluzione_unica/acconto_saldo` + scadenze acconto/saldo/unica (CHECK sui tipi), valuta.
- **`web_pagamenti_reminder_regole`** (`SqlScripts/424`) — regole promemoria/solleciti (N per azienda): `tipo` CHECK `promemoria/sollecito`, `offset_giorni`, CCN operatore (`ccn_email_fk → ana_aziende_email`), template IT.
- **`web_pagamenti_transazioni`** (`SqlScripts/425`) — incassi Stripe. `importo_cent INTEGER`, `tipo` CHECK `acconto/saldo/unica`, `stato` CHECK `creato/in_attesa/pagato/fallito/rimborsato`, link Stripe, `data_viaggio_id_fk`/`cliente_fk`. **`mov_transazione_fk INTEGER`** → `mov_transazioni(transazione_id)` (PK legacy INTEGER) **UNIQUE** = idempotenza 1:1 incasso→contabilità. Campi fattura (numero/pdf_storage_path/inviata_data). Indici `(azienda_id, stato)`, `(scadenza)`.
- **`web_pagamenti_reminder_log`** (`SqlScripts/426`) — log promemoria anti-duplicati. `transazione_fk` → `web_pagamenti_transazioni` ON DELETE CASCADE; UNIQUE `(transazione_fk, reminder_regola_fk)`.
- **`web_blog_articoli`** (`SqlScripts/427`) — blog/diario. slug UNIQUE per azienda, `stato_pubblicazione` CHECK, meta SEO.

> **Nota deviazione da Spec §2.17:** `mov_transazione_fk` è `INTEGER` (non `BIGINT`) per allinearsi alla PK legacy `mov_transazioni.transazione_id` (INTEGER) e consentire una FK reale; aggiunto `UNIQUE` per l'idempotenza indicata dalla Spec.

### Modifiche a tabelle esistenti (`ana_*`)

- **`ana_clienti`** (`SqlScripts/428`) — consenso marketing: `consenso_marketing BOOLEAN DEFAULT false`, `consenso_marketing_data`, `consenso_marketing_fonte`. + `controparte_fk INTEGER NULL` (**predisposizione Fase 4**, SENZA FK: `ana_fornitori` citata dalla Spec §1.4 NON esiste; target reale previsto `ana_controparti(controparte_id)`, vincolo differito).
- **`ana_aziende`** (`SqlScripts/429`) — `token_iscrizione VARCHAR(64)`: token per il link "Iscriviti" dell'app iscrizioni Flask (da allineare al `.env` su Hetzner).

> **Rollback:** `SqlScripts/499_Rollback_EstensioneWeb.sql` annulla l'intero schema estensione (alter + 19 tabelle + `trg_web_audit` + ruolo `anon`), idempotente `IF EXISTS`. Solo locale, con backup.




























<!-- AUTO-GENERATED-START (generate_db_functions_doc.sh — NON modificare a mano, rigenerato da deploy_sql.sh) -->

## 📌 Appendice Auto-Generata (pg_catalog)

> Rigenerata automaticamente da `generate_db_functions_doc.sh` (invocato da `deploy_sql.sh`) leggendo lo schema reale su Docker `postgres_db`.
> Non modificare questa sezione a mano: viene sovrascritta ad ogni deploy.

| Function | Argomenti | Output | Commento DB (`COMMENT ON FUNCTION`) |
|---|---|---|---|
| `ana_geo_capoluogo_trg1_func` |  | trigger |  |
| `ana_geo_capoluogo_trg2_func` |  | trigger |  |
| `ana_geo_ita_ripgeo_trg1_func` |  | trigger |  |
| `ana_geo_ita_ripgeo_trg2_func` |  | trigger |  |
| `ana_geo_regioni_ita_trg1_func` |  | trigger |  |
| `ana_geo_regioni_ita_trg2_func` |  | trigger |  |
| `ana_mezzi_modelli_trg1_func` |  | trigger |  |
| `ana_mezzi_modelli_trg2_func` |  | trigger |  |
| `ana_mezzi_tgr1_func` |  | trigger |  |
| `ana_mezzi_tgr2_func` |  | trigger |  |
| `ana_tipo_alloggio_trg1_func` |  | trigger |  |
| `ana_tipo_alloggio_trg2_func` |  | trigger |  |
| `ana_tipo_pernottamento_check_delete` |  | trigger |  |
| `ana_tipo_trattamento_check_delete` |  | trigger |  |
| `ana_tipo_viaggi_check_delete` |  | trigger |  |
| `ana_viaggi_trg1_func` |  | trigger |  |
| `ana_viaggi_trg2_func` |  | trigger |  |
| `can_access_azienda` | target_azienda_id integer | boolean | Determina se utente corrente può accedere a specifica azienda basato sul ruolo |
| `check_delete_ana_tipo_partecipante` |  | trigger | Trigger che verifica l'integrità referenziale prima dell'eliminazione di un tipo partecipante |
| `check_possible_duplicate_travels` | p_description text, p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, matching_words text) |  |
| `check_reset_rate_limit` | p_email character varying | integer | Verifica numero tentativi reset negli ultimi 15 minuti per email |
| `chk_room_consistency_on_delete` | p_data_viaggio_id integer, p_cliente_id_to_remove integer | TABLE(violation_detected boolean, room_id integer, room_type_desc text, required_seats integer, current_occupants_count integer, remaining_occupants_count integer, survivor_ids integer[]) |  |
| `cleanup_audit_login` | p_days integer | integer |  |
| `cleanup_business_events` | p_days_to_keep integer | integer |  |
| `cleanup_expired_tokens` |  | integer | Pulizia automatica token scaduti e dati obsoleti per ottimizzazione |
| `current_azienda` |  | integer | Restituisce ID azienda corrente per ruoli azienda-specifici |
| `current_role` |  | text | Restituisce ruolo attivo della sessione |
| `current_user_id` |  | uuid | Restituisce l'UUID dell'utente corrente dalla sessione o dal contesto |
| `eba_countries_biu_func` |  | trigger |  |
| `eba_countries_trg2_func` |  | trigger |  |
| `eba_country_intermediates_biu_func` |  | trigger |  |
| `eba_country_organizations_biu_func` |  | trigger |  |
| `eba_country_regions_biu_func` |  | trigger |  |
| `eba_country_sub_regions_biu_func` |  | trigger |  |
| `fn_ana_aliquote_iva_get_active` | p_azienda_id integer | SETOF ana_aliquote_iva | Recupera solo le aliquote IVA attive per azienda (per dropdown UI) |
| `fn_ana_aliquote_iva_get_all` | p_azienda_id integer | SETOF ana_aliquote_iva | Recupera tutte le aliquote IVA per azienda, ordinate per ordinamento e descrizione |
| `fn_ana_aliquote_iva_get_default` | p_azienda_id integer | ana_aliquote_iva | Recupera l'aliquota IVA default per azienda (preselezionata in UI) |
| `fn_ana_api_config_get_all` |  | SETOF ana_api_config | Recupera tutte le configurazioni API ordinate per servizio e ordine di visualizzazione. Usato dalla griglia principale. |
| `fn_ana_api_config_get_by_service` | p_service_code character varying | SETOF ana_api_config | Recupera le configurazioni per un servizio specifico. Usato per lettura API key da codice. |
| `fn_ana_tipi_causali_get_active` | p_azienda_id integer | SETOF ana_tipi_causali | Recupera solo le causali attive per azienda. Usato nei dropdown/combobox. |
| `fn_ana_tipi_causali_get_active_by_ciclo` | p_azienda_id integer, p_ciclo character varying | SETOF ana_tipi_causali | Recupera causali attive filtrate per ciclo contabile (ATTIVO/PASSIVO). Usato nei filtri transazioni. |
| `fn_ana_tipi_causali_get_all` | p_azienda_id integer | SETOF ana_tipi_causali | Recupera tutte le causali per azienda, ordinate per ciclo e descrizione. Usato dalla griglia principale. |
| `fn_ana_viaggi_get_all` | p_azienda_id integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer, p_only_completed boolean DEFAULT NULL::boolean, p_future_only boolean DEFAULT NULL::boolean | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_nazione_fk integer, viaggio_tipo_pernottamento_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, viaggio_link character varying, viaggio_mappa bytea, viaggio_mappa_mimetype character varying, viaggio_mappa_filename character varying, viaggio_mappa_charset character varying, viaggio_mappa_upd_date date, azienda_id integer, viaggio_tipo_avvicinamento_fk integer, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying, matching_dates_count bigint) |  |
| `fn_ana_viaggi_get_by_id` | p_viaggio_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_nazione_fk integer, viaggio_tipo_pernottamento_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, viaggio_link character varying, viaggio_mappa bytea, viaggio_mappa_mimetype character varying, viaggio_mappa_filename character varying, viaggio_mappa_charset character varying, viaggio_mappa_upd_date date, azienda_id integer, viaggio_tipo_avvicinamento_fk integer, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying) |  |
| `fn_app_create_azienda` | p_data jsonb | jsonb |  |
| `fn_app_create_azienda` | p_tenant_id character varying, p_ragione_sociale character varying, p_partita_iva character varying, p_forma_giuridica character varying DEFAULT NULL::character varying, p_codice_fiscale character varying DEFAULT NULL::character varying, p_capitale_sociale numeric DEFAULT NULL::numeric, p_socio_unico boolean DEFAULT false, p_in_liquidazione boolean DEFAULT false, p_pec character varying DEFAULT NULL::character varying, p_sito_web character varying DEFAULT NULL::character varying, p_telefono_principale character varying DEFAULT NULL::character varying, p_attivo boolean DEFAULT true | jsonb | Crea nuova azienda/tenant (solo SuperAdmin) |
| `fn_app_create_country` | p_name character varying, p_nationality character varying, p_country_code character varying, p_iso_alpha2 character varying, p_capital character varying DEFAULT NULL::character varying, p_population bigint DEFAULT NULL::bigint, p_area_km2 numeric DEFAULT NULL::numeric, p_region_id integer DEFAULT NULL::integer, p_sub_region_id integer DEFAULT NULL::integer, p_intermediate_region_id integer DEFAULT NULL::integer, p_organization_region_id integer DEFAULT NULL::integer | jsonb | Crea una nuova nazione |
| `fn_app_create_country_organization` | p_code character varying, p_name character varying | jsonb | Crea una nuova organizzazione |
| `fn_app_create_geo_capoluogo` | p_data jsonb | jsonb | Crea nuovo capoluogo |
| `fn_app_create_geo_comuni` | p_data jsonb | jsonb | Crea nuovo comune |
| `fn_app_create_geo_ita_ripgeo` | p_data jsonb | jsonb | Crea nuovo ripartizione geografica |
| `fn_app_create_geo_province` | p_data jsonb | jsonb | Crea nuovo provincia |
| `fn_app_create_geo_regioni_ita` | p_data jsonb | jsonb | Crea nuovo regione |
| `fn_app_delete_country` | p_country_id integer | jsonb | Elimina una nazione |
| `fn_app_delete_country_organization` | p_id integer | jsonb | Elimina un'organizzazione |
| `fn_app_delete_geo_capoluogo` | p_id text | jsonb | Elimina capoluogo |
| `fn_app_delete_geo_comuni` | p_id text | jsonb | Elimina comune |
| `fn_app_delete_geo_ita_ripgeo` | p_id text | jsonb | Elimina ripartizione geografica |
| `fn_app_delete_geo_province` | p_id text | jsonb | Elimina provincia |
| `fn_app_delete_geo_regioni_ita` | p_id text | jsonb | Elimina regione |
| `fn_app_get_all_aziende` | p_user_id uuid DEFAULT NULL::uuid, p_page_number integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search_term text DEFAULT NULL::text, p_sort_column text DEFAULT 'ragione_sociale'::text, p_sort_direction text DEFAULT 'ASC'::text, p_filters jsonb DEFAULT NULL::jsonb | jsonb | Recupera lista paginata di tutte le aziende con filtri e ricerca per SuperAdmin |
| `fn_app_get_all_aziende` |  | jsonb |  |
| `fn_app_get_all_countries` | p_tenant_id character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_search text DEFAULT NULL::text, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying | jsonb | Recupera tutte le nazioni con paginazione, ricerca e ordinamento |
| `fn_app_get_all_country_organizations` | p_tenant_id character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_search text DEFAULT NULL::text, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying | jsonb | Recupera tutte le organizzazioni con paginazione, ricerca e ordinamento |
| `fn_app_get_all_geo_capoluogos` | p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'capoluogo_id'::text, p_sort_order text DEFAULT 'asc'::text | jsonb | Lista paginata capoluoghi con ricerca e ordinamento |
| `fn_app_get_all_geo_comunis` | p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'comune_id'::text, p_sort_order text DEFAULT 'asc'::text | jsonb | Lista paginata comuni con ricerca e ordinamento |
| `fn_app_get_all_geo_ita_ripgeos` | p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'ripgeo_id'::text, p_sort_order text DEFAULT 'asc'::text | jsonb | Lista paginata ripartizioni geografiche con ricerca e ordinamento |
| `fn_app_get_all_geo_provinces` | p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'provincia_id'::text, p_sort_order text DEFAULT 'asc'::text | jsonb | Lista paginata province con ricerca e ordinamento |
| `fn_app_get_all_geo_regioni_itas` | p_tenant_id text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'regione_id'::text, p_sort_order text DEFAULT 'asc'::text | jsonb | Lista paginata regioni con ricerca e ordinamento |
| `fn_app_get_azienda_by_id` | p_azienda_id integer DEFAULT NULL::integer, p_tenant_id character varying DEFAULT NULL::character varying | jsonb | Recupera dettaglio singola azienda per ID o tenant_id |
| `fn_app_get_azienda_by_id` | p_azienda_id integer | jsonb |  |
| `fn_app_get_aziende_distinct_values` | p_column_name text | jsonb | Recupera valori distinti per filtri dropdown nelle colonne |
| `fn_app_get_comune_by_id` | p_comune_id integer | TABLE(comune_id integer, comune_formatted text, comune_cap character varying, comune_descrizione character varying, provincia_sigla character, provincia_descrizione character varying) | Recupera un singolo comune formattato per ID con formato "CAP - COMUNE (PROVINCIA)".  |
| `Utilizzata dai SmartCombobox per mostrare descrizioni invece di codici.` |  |  |  |
| `fn_app_get_comune_formatted` | p_comune_id integer | text | Restituisce una stringa formattata 'CAP - COMUNE (SIGLA)' per un dato ID comune |
| `fn_app_get_comuni_lookup` | p_search_term text DEFAULT NULL::text, p_limit integer DEFAULT 100 | TABLE(comune_id integer, comune_formatted text, comune_descrizione character varying, comune_cap character varying, provincia_sigla character varying) | Ricerca comuni per autocompletamento (nome, cap o provincia) restituendo lista formattata |
| `fn_app_get_country_by_id` | p_country_id integer | jsonb | Recupera una nazione specifica per ID |
| `fn_app_get_country_intermediate_by_id` | p_intermediate_id integer | TABLE(id integer, name text) | Returns a single intermediate region by ID with full details for SmartCombobox display. Used for foreign key resolution. |
| `fn_app_get_country_intermediates_lookup` |  | TABLE(value integer, label character varying) |  |
| `fn_app_get_country_organization_by_id` | p_id integer | jsonb | Recupera un'organizzazione specifica per ID |
| `fn_app_get_country_organizations_lookup` |  | TABLE(value integer, label character varying) |  |
| `fn_app_get_country_region_by_id` | p_region_id integer | TABLE(id integer, name text) | Returns a single country region by ID with full details for SmartCombobox display. Used for foreign key resolution. |
| `fn_app_get_country_regions_lookup` |  | TABLE(value integer, label character varying) |  |
| `fn_app_get_country_sub_region_by_id` | p_sub_region_id integer | TABLE(id integer, name text) | Returns a single country sub-region by ID with full details for SmartCombobox display. Used for foreign key resolution. |
| `fn_app_get_country_sub_regions_lookup` |  | TABLE(value integer, label character varying) |  |
| `fn_app_get_geo_capoluogo` | p_id text | jsonb | Recupera singolo capoluogo per ID |
| `fn_app_get_geo_capoluogos_lookup` |  | jsonb |  |
| `fn_app_get_geo_comuni` | p_id text | jsonb | Recupera singolo comune per ID |
| `fn_app_get_geo_comunis_lookup` |  | jsonb | Lookup comuni per combobox (formato {value, label}) |
| `fn_app_get_geo_ita_ripgeo` | p_id text | jsonb | Recupera singolo ripartizione geografica per ID |
| `fn_app_get_geo_ita_ripgeos_lookup` |  | jsonb |  |
| `fn_app_get_geo_province` | p_id text | jsonb | Recupera singolo provincia per ID |
| `fn_app_get_geo_provinces_lookup` |  | jsonb | Lookup province per combobox (formato {value, label}) |
| `fn_app_get_geo_regioni_ita` | p_id text | jsonb | Recupera singolo regione per ID |
| `fn_app_get_geo_regioni_itas_lookup` |  | jsonb | Lookup regioni per combobox (formato {value, label}) |
| `fn_app_get_tipo_sede_by_id` | p_tipo_sede_id integer | TABLE(tipo_sede_id integer, codice character varying, descrizione character varying, is_active boolean) | Recupera un singolo tipo sede per ID con tutti i dettagli.  |
| `Utilizzata dai SmartCombobox per mostrare descrizioni invece di codici.` |  |  |  |
| `fn_app_health_check` |  | json |  |
| `fn_app_list_roles` |  | TABLE(role_id integer, role_code character varying, role_name character varying, is_system boolean, created_at timestamp with time zone) |  |
| `fn_app_list_users` |  | TABLE(user_id uuid, email text, nome text, cognome text, role_code text, role_name text, azienda_id integer, ragione_sociale text, is_active boolean, last_login_at timestamp with time zone, created_at timestamp with time zone, data_nascita date, valuta_default_id integer) |  |
| `fn_app_login` | p_email citext, p_password text, p_ip inet DEFAULT inet_client_addr(), p_user_agent text DEFAULT 'Unknown'::text | jsonb |  |
| `fn_app_login` | p_email citext, p_password text | jsonb |  |
| `fn_app_login_text` | p_email text, p_password text | jsonb |  |
| `fn_app_login_text_debug` | p_email text, p_password text | jsonb | Versione di debug del login che restituisce hash e dettagli di confronto password |
| `fn_app_logo_create_backup_20250909` | p_tenant_id character varying, p_azienda_fk integer, p_logo_data jsonb | jsonb | Funzione di backup legacy per la tabella loghi (Non utilizzare) |
| `fn_app_profile` | p_user_id uuid | jsonb | Restituisce il profilo completo dell'utente corrente inclusi ruoli e azienda |
| `fn_app_request_password_reset` | p_email citext | jsonb | Genera un codice di reset password a 6 cifre. Rate limit: 3 tentativi/15min. Anti-enumeration: risposta generica se email non trovata. |
| `fn_app_toggle_azienda_status` | p_azienda_id integer, p_user_id uuid, p_new_status boolean | jsonb | Attiva/disattiva stato azienda (solo SuperAdmin) |
| `fn_app_update_azienda` | p_azienda_id integer, p_ragione_sociale character varying DEFAULT NULL::character varying, p_forma_giuridica character varying DEFAULT NULL::character varying, p_partita_iva character varying DEFAULT NULL::character varying, p_codice_fiscale character varying DEFAULT NULL::character varying, p_capitale_sociale numeric DEFAULT NULL::numeric, p_socio_unico boolean DEFAULT NULL::boolean, p_in_liquidazione boolean DEFAULT NULL::boolean, p_pec character varying DEFAULT NULL::character varying, p_sito_web character varying DEFAULT NULL::character varying, p_telefono_principale character varying DEFAULT NULL::character varying, p_attivo boolean DEFAULT NULL::boolean | jsonb | Aggiorna dati azienda esistente (solo SuperAdmin) |
| `fn_app_update_country` | p_country_id integer, p_name character varying DEFAULT NULL::character varying, p_nationality character varying DEFAULT NULL::character varying, p_country_code character varying DEFAULT NULL::character varying, p_iso_alpha2 character varying DEFAULT NULL::character varying, p_capital character varying DEFAULT NULL::character varying, p_population bigint DEFAULT NULL::bigint, p_area_km2 numeric DEFAULT NULL::numeric, p_region_id integer DEFAULT NULL::integer, p_sub_region_id integer DEFAULT NULL::integer, p_intermediate_region_id integer DEFAULT NULL::integer, p_organization_region_id integer DEFAULT NULL::integer | jsonb | Aggiorna una nazione esistente |
| `fn_app_update_country_organization` | p_id integer, p_code character varying DEFAULT NULL::character varying, p_name character varying DEFAULT NULL::character varying | jsonb | Aggiorna un'organizzazione esistente |
| `fn_app_update_geo_capoluogo` | p_data jsonb | jsonb | Aggiorna capoluogo esistente |
| `fn_app_update_geo_comuni` | p_data jsonb | jsonb | Aggiorna comune esistente |
| `fn_app_update_geo_ita_ripgeo` | p_data jsonb | jsonb | Aggiorna ripartizione geografica esistente |
| `fn_app_update_geo_province` | p_data jsonb | jsonb | Aggiorna provincia esistente |
| `fn_app_update_geo_regioni_ita` | p_data jsonb | jsonb | Aggiorna regione esistente |
| `fn_calcola_dati_riga` |  | trigger |  |
| `fn_calcola_importo_eur` |  | trigger | Calcola automaticamente transazione_importo_eur usando il tasso di cambio alla data_documento. Memorizza anche il tasso applicato, la fonte (API/FALLBACK) e la data di validità del tasso. |
| `fn_calcola_iva_transazione` |  | trigger | Calcola automaticamente IVA su transazioni basandosi su: ciclo causale, modalità input (LORDO/NETTO), aliquota selezionata. |
| `PRIORITÀ MASSIMA a correzioni manuali (se tutti e tre i campi IVA sono NOT NULL, non ricalcola).` |  |  |  |
| `Tolleranza arrotondamenti: 0.01 EUR.` |  |  |  |
| `fn_check_email_unique_across_companies` |  | trigger | Garantisce che una email non possa essere usata da aziende diverse. |
| `La stessa azienda può usare la stessa email per reparti diversi.` |  |  |  |
| `fn_check_single_default_iva` |  | trigger | Garantisce che solo 1 aliquota per azienda abbia is_default = TRUE. Eseguito BEFORE INSERT/UPDATE quando is_default = TRUE. |
| `fn_count_clienti_by_azienda` | p_azienda_fk integer | integer | DB-First: Count total clienti for specific azienda |
| `fn_enforce_user_azienda_integrity` |  | trigger |  |
| `fn_exists_cliente_anagrafica` | p_cognome character varying, p_nome character varying, p_data_nascita date, p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if cliente with same anagrafica data already exists |
| `fn_exists_cliente_codice_fiscale` | p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if codice fiscale already exists for another cliente |
| `fn_exists_cliente_email` | p_email character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if email already exists for another cliente |
| `fn_fatturapa_get_next_progressivo` | p_azienda_id integer | character varying | Restituisce il prossimo progressivo invio FatturaPA per l'azienda (formato 5 cifre). UPSERT atomico. |
| `fn_get_all_clienti` | p_azienda_fk integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer | json | DB-First: Get all clienti with travel counts, optional azienda filter |
| `fn_get_all_transazioni` | p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_transazione date DEFAULT NULL::date, p_solo_da_pagare boolean DEFAULT false, p_causale_tipo_id integer DEFAULT NULL::integer | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_causale_tipo_id integer, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_data_documento date, transazione_fattura_fk integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita date, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, causale_descrizione character varying, causale_segno integer, causale_ciclo character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_ana_tipo_fornitore` | p_azienda_id integer DEFAULT NULL::integer | TABLE(tipo_fornitore_id integer, azienda_fk integer, descrizione character varying, categoria character varying, conto_contabile_default character varying, created_at timestamp with time zone, updated_at timestamp with time zone) | Recupera i tipi fornitore filtrati per azienda. Se p_azienda_id è NULL, restituisce tutti i record (SuperAdmin). |
| `fn_get_anni_bilancio_viaggi` | p_azienda_id integer | TABLE(anno integer, numero_viaggi integer) |  |
| `fn_get_anni_fatture_attive` | p_azienda_id integer | TABLE(anno integer) |  |
| `fn_get_api_config_value` | p_service_code character varying, p_config_key character varying | text | Recupera il valore di una singola configurazione API attiva per service_code e config_key. Validazioni: parametri obbligatori, esistenza record, stato attivo, valore non vuoto. Usato da CurrencyApiService per recuperare API key dinamicamente dal DB invece che dal codice. |
| `fn_get_azienda_badge_counts` | p_azienda_id integer | TABLE(sedi integer, contatti integer, banche integer, email integer, reparti integer, smtp integer, logo integer) |  |
| `fn_get_bilancio_annuale_viaggi` | p_azienda_id integer, p_anno integer, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_numero_partecipanti integer, data_viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_annuale_viaggi` | p_azienda_id integer, p_anno integer | TABLE(viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_numero_partecipanti integer, data_viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_id integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_ids integer[], p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_id integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_calendar_data` | p_year integer, p_month integer, p_azienda_id integer DEFAULT NULL::integer | TABLE(data_viaggio_id integer, viaggio_id integer, descrizione_viaggio text, data_inizio date, data_fine date, tot_clienti integer, effettuato_sino character, azienda_id integer, azienda_nome text) | Recupera viaggi che intersecano un mese specifico per il calendario. |
| `Un viaggio viene incluso se: data_inizio <= fine_mese AND data_fine >= inizio_mese.` |  |  |  |
| `Include conteggio partecipanti e nome azienda per tooltip.` |  |  |  |
| `fn_get_cliente_by_id` | p_cliente_id integer, p_azienda_fk integer | json | DB-First: Get cliente by ID with all related data (azienda, comuni) |
| `fn_get_cliente_init_data` | p_cliente_id integer DEFAULT NULL::integer | json |  |
| `fn_get_clienti_export` | p_azienda_id integer DEFAULT NULL::integer | TABLE(cognome character varying, nome character varying, titolo character varying, sesso character, data_nascita date, comune_nascita text, provincia_nascita character varying, indirizzo_residenza character varying, comune_residenza text, provincia_residenza character varying, prefisso_telefono character varying, telefono character varying, email character varying, codice_fiscale character varying, iban character varying, tipo_documento character varying, numero_documento character varying, documento_rilasciato_da character varying, documento_data_rilascio date, documento_data_scadenza date, intolleranza text, note text, azienda character varying) | Restituisce dati clienti flat per export Excel. Campi business only, comuni/province decodificati. |
| `fn_get_controparte_init_data` | p_controparte_id integer DEFAULT NULL::integer | json |  |
| `fn_get_date_viaggi_with_transactions` | p_viaggio_id integer | TABLE(data_viaggio_id integer, viaggio_id_fk integer, data_viaggio_data_inizio timestamp without time zone, data_viaggio_data_fine timestamp without time zone, data_viaggio_effettuato_sino character varying, has_transactions boolean) |  |
| `fn_get_date_viaggi_with_transazioni` | p_viaggio_id integer | TABLE("DataViaggioId" integer, "ViaggioIdFk" integer, "DataInizio" date, "DataFine" date, "Effettuato" character) |  |
| `fn_get_debug_v2` | p_azienda_id integer | TABLE(transazione_id integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita timestamp without time zone) |  |
| `fn_get_fattura_attiva_stampa` | p_transazione_id integer | TABLE(transazione_id integer, transazione_data date, transazione_data_documento date, transazione_data_scadenza date, transazione_numero_documento character varying, transazione_stato character varying, transazione_causale text, transazione_numero_protocollo_iva integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_tipo_movimento character varying, azienda_id integer, azienda_ragione_sociale character varying, azienda_forma_giuridica character varying, azienda_partita_iva character varying, azienda_codice_fiscale character varying, azienda_telefono character varying, azienda_pec character varying, azienda_sito_web character varying, azienda_codice_sdi character varying, azienda_rea_numero character varying, azienda_rea_provincia_sigla character varying, azienda_capitale_sociale numeric, azienda_socio_unico boolean, azienda_in_liquidazione boolean, regime_codice character varying, regime_descrizione character varying, regime_is_iva_detraibile boolean, regime_codice_sdi character varying, tipo_cassa_sdi character varying, cassa_prev_percentuale numeric, sede_indirizzo character varying, sede_numero_civico character varying, sede_cap character varying, sede_comune character varying, sede_provincia_sigla character varying, sede_telefono character varying, sede_email character varying, logo_data text, controparte_id integer, controparte_ragione_sociale character varying, controparte_indirizzo character varying, controparte_cap character varying, controparte_comune character varying, controparte_provincia_sigla character varying, controparte_partita_iva character varying, controparte_codice_fiscale character varying, controparte_codice_sdi character varying, controparte_pec character varying, controparte_fornitore_estero boolean, causale_descrizione character varying, causale_ciclo character varying, causale_codice character varying, tipo_documento_sdi character varying) | Recupera tutti i dati per stampa/export fattura attiva, inclusi campi SDI (regime_codice_sdi, tipo_cassa_sdi, tipo_documento_sdi) |
| `fn_get_fatturato_annuale` | p_azienda_id integer, p_anno integer, p_valuta_target_id integer DEFAULT NULL::integer | numeric | V2 - Calcola il fatturato annuale netto (imponibili con segno causale) per un'azienda. Se p_azienda_id IS NULL, somma tutte le aziende (SuperAdmin). |
| `fn_get_fatturato_mensile_trend` | p_azienda_id integer, p_anno integer, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(mese integer, fatturato numeric) | V2 - Restituisce il fatturato mensile netto (gen-dic). Se p_azienda_id IS NULL, somma tutte le aziende. |
| `fn_get_fatturato_periodo` | p_azienda_id integer, p_data_inizio date, p_data_fine date, p_valuta_target_id integer DEFAULT NULL::integer | numeric | V2 - Calcola il fatturato netto per un periodo specifico. Se p_azienda_id IS NULL, somma tutte le aziende. |
| `fn_get_fatture_attive_elenco` | p_azienda_id integer, p_controparte_id integer DEFAULT NULL::integer, p_data_doc_da date DEFAULT NULL::date, p_data_doc_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_stato character varying DEFAULT NULL::character varying, p_numero_documento character varying DEFAULT NULL::character varying | TABLE(transazione_id integer, transazione_data date, data_documento date, numero_documento character varying, numero_protocollo_iva integer, controparte_ragione_sociale character varying, imponibile_eur numeric, iva_eur numeric, lordo_eur numeric, stato character varying, data_scadenza date, causale_descrizione character varying) |  |
| `fn_get_logo_field_help` | field_name text | text | Restituisce il testo di aiuto per i campi della configurazione logo |
| `fn_get_menu_breadcrumbs` | p_menu_id uuid | jsonb | Recupera breadcrumbs path per menu specifico |
| `fn_get_monthly_trend` | p_table_name text, p_year integer, p_azienda_id integer DEFAULT NULL::integer, p_date_column text DEFAULT 'created'::text | TABLE(month_num integer, count_val bigint) |  |
| `fn_get_monthly_trend` | p_table_name text, p_year integer, p_azienda_id integer DEFAULT NULL::integer | TABLE(month_num integer, count_val bigint) |  |
| `fn_get_mov_clienti_alloggi_by_date` | p_data_viaggio_id integer | TABLE(mov_clienti_alloggio_pk integer, viaggio_id_fk integer, data_viaggio_id_fk integer, tipo_alloggio_id_fk integer, cliente_id1_fk integer, cliente_id2_fk integer, cliente_id3_fk integer, cliente_id4_fk integer, cliente_id5_fk integer, cliente_id6_fk integer) | Recupera tutti gli alloggi (camere) assegnati per una specifica data viaggio. Restituisce dati raw con i 6 slot clienti (ClienteId1Fk...ClienteId6Fk). |
| `fn_get_mov_clienti_viaggi_by_date` | p_data_viaggio_id integer | TABLE(viaggio_id_fk integer, data_viaggio_id_fk integer, cliente_id_fk integer, tipo_partecipante_id_fk integer, ana_mezzi_id_fk integer, mezzo_modello_id_fk integer, cliente_pilota_id_fk integer, mov_cliente_viaggio_scontoval_totale numeric, mov_cliente_viaggio_targa_mezzo character varying, mov_cliente_viaggio_cane_sino character varying, mov_cliente_viaggio_note text) | Recupera tutti i partecipanti iscritti a una specifica data viaggio. Usato per caricamento dati raw senza arricchimenti. |
| `fn_get_participants_view` | p_data_viaggio_id integer | TABLE(viaggio_id integer, data_id integer, cliente_id integer, nominativo character varying, tipo_partecipante_id integer, ruolo character varying, note text, cane_sino character varying, intolleranze text, mezzo_dettagli text, cliente_pilota_id integer, grouping_key integer) | Vista arricchita partecipanti con dati anagrafici, ruolo, intolleranze e dettagli mezzo. Ordinata per equipaggio (pilota → passeggeri). |
| `fn_get_registro_iva` | p_azienda_id integer, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date | TABLE(causale_ciclo character varying, transazione_id integer, transazione_data_documento date, transazione_numero_documento character varying, controparte_ragione_sociale character varying, causale_codice character varying, causale_descrizione character varying, aliquota_iva_codice character varying, aliquota_iva_percentuale numeric, aliquota_iva_descrizione character varying, aliquota_iva_natura character varying, numero_protocollo_iva integer, imponibile_eur numeric, iva_eur numeric, lordo_eur numeric, causale_segno integer) |  |
| `fn_get_rooming_list_print_data` | p_data_viaggio_id integer | jsonb |  |
| `fn_get_scadenzario_stampa` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying, p_urgenza character varying DEFAULT NULL::character varying, p_data_scadenza_da date DEFAULT NULL::date, p_data_scadenza_a date DEFAULT NULL::date, p_viaggio_id integer DEFAULT NULL::integer, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_raggruppamento character varying DEFAULT 'URGENZA'::character varying | TABLE(gruppochiave text, gruppodisplay text, gruppoordine integer, transazioneid integer, datascadenza date, datadocumento date, numerodocumento character varying, controparteragionesociale character varying, causaleciclo character varying, causaledescrizione character varying, importooriginale numeric, residuo numeric, valutacodiceiso character varying, giorniascadenza integer, urgenza character varying, stato character varying, viaggiodescrizione character varying, note text) | Restituisce le scadenze aperte con calcolo del residuo e classificazione urgenza per la stampa. |
| `fn_get_smtp_config_for_email` | p_azienda_id integer | jsonb | Recupera la prima configurazione SMTP outbound attiva per azienda. Ritorna NULL se non configurata. |
| `fn_get_tasso_cambio` | p_valuta_da integer, p_valuta_a integer, p_data date | numeric | Restituisce il tasso di cambio più recente (<= data) calcolando anche l'inverso. Core function. |
| `fn_get_tasso_cambio` | p_iso_da character varying, p_iso_a character varying, p_data date | numeric | Wrapper che accetta codici ISO e invoca la core function. |
| `fn_get_transazioni_by_azienda` | p_azienda_id integer, p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_transazione date DEFAULT NULL::date, p_solo_da_pagare boolean DEFAULT false, p_causale_tipo_id integer DEFAULT NULL::integer | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_causale_tipo_id integer, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_data_documento date, transazione_fattura_fk integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita date, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, causale_descrizione character varying, causale_segno integer, causale_ciclo character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_per_stampa` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_tipo_movimento character varying DEFAULT NULL::character varying, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'DATA_DOCUMENTO'::character varying | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_tipo_movimento character varying, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_data_documento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_fattura_fk integer, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_dettaglio` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, transazione_id integer, transazione_data date, transazione_data_documento date, transazione_data_scadenza date, transazione_data_pagamento date, controparte_ragione_sociale character varying, tipo_movimento_codice character varying, tipo_movimento_descrizione character varying, causale_segno integer, transazione_causale text, transazione_stato character varying, transazione_numero_documento character varying, valuta_codice_iso character varying, transazione_importo numeric, importo_valuta_target numeric, valuta_target_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_dettaglio` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, transazione_id integer, transazione_data date, transazione_data_documento date, transazione_data_scadenza date, transazione_data_pagamento date, controparte_ragione_sociale character varying, tipo_movimento_codice character varying, tipo_movimento_descrizione character varying, causale_segno integer, transazione_causale text, causale_ciclo character varying, transazione_stato character varying, transazione_numero_documento character varying, valuta_codice_iso character varying, imponibile_eur numeric, iva_eur numeric, lordo_eur numeric, aliquota_iva_codice character varying, aliquota_iva_percentuale numeric, importo_valuta_target numeric, valuta_target_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_subtotali` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, valuta_codice_iso character varying, totale_valuta_originale numeric, totale_valuta_target numeric, totale_fatturato_target numeric, totale_pagato_target numeric, totale_imponibile_target numeric, totale_iva_target numeric, valuta_target_iso character varying, conteggio_transazioni integer, is_totale_generale boolean) |  |
| `fn_get_transazioni_stampa_subtotali` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, valuta_codice_iso character varying, totale_valuta_originale numeric, totale_valuta_target numeric, totale_fatturato_target numeric, totale_pagato_target numeric, valuta_target_iso character varying, conteggio_transazioni integer, is_totale_generale boolean) |  |
| `fn_get_travel_print_data` | p_data_viaggio_id integer | jsonb |  |
| `fn_get_trip_header_string` | p_viaggio_id integer, p_data_viaggio_id integer | text | Genera intestazione viaggio formattata: "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)". Usato per header UI. |
| `fn_get_viaggi_init_data` | p_viaggio_id integer DEFAULT NULL::integer | json |  |
| `fn_get_viaggi_with_transactions` | p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_link character varying, viaggio_nazione_fk integer, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_tipo_pernottamento_fk integer, viaggio_tipo_avvicinamento_fk integer, azienda_id integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying, matching_dates_count integer) |  |
| `fn_get_viaggi_with_transazioni` | p_azienda_id integer | TABLE("Id" integer, "DescrizioneBreve" character varying, "DescrizioneEstesa" text, "NazioneNome" character varying, "NumeroGiorni" integer) |  |
| `fn_get_viaggio_partecipanti_init_data` | p_viaggio_id integer, p_data_viaggio_id integer | json |  |
| `fn_is_pec_domain` | p_email text | boolean | Verifica se un indirizzo email appartiene a un dominio PEC noto |
| `fn_log_business_event` | p_event_type character varying, p_description text, p_entity_table character varying, p_entity_id integer, p_azienda_id integer, p_created_by character varying | void |  |
| `fn_logo_calculate_hash` | p_binary_data bytea | character varying | Calcola l'hash SHA256 di un blob binario per verifica integrità |
| `fn_logo_setup_master_detail_relation` |  | jsonb | Configura la relazione master-detail e i metadati per la gestione dei loghi aziendali |
| `fn_logo_update_access_stats` | p_logo_id uuid | void | Aggiorna le statistiche di accesso (timestamp e contatore) per un logo |
| `fn_logo_validate_mime_type` | p_file_format character varying, p_mime_type character varying | boolean | Valida che il formato file corrisponda al MIME type dichiarato |
| `fn_search_clienti` | p_azienda_fk integer, p_search_text character varying | json | DB-First: Full-text search clienti by cognome, nome, email, CF, telefono |
| `fn_set_azienda_id` |  | trigger |  |
| `fn_superadmin_delete_from_table` | p_user_id uuid, p_table_name character varying, p_where_clause character varying | jsonb | DELETE generico per SuperAdmin su qualsiasi tabella |
| `fn_superadmin_describe_table` | p_user_id uuid, p_table_name character varying | jsonb | DESCRIBE schema tabella per SuperAdmin |
| `fn_superadmin_get_all_companies` |  | jsonb |  |
| `fn_superadmin_get_all_companies` | p_user_id uuid, p_tenant_filter character varying DEFAULT NULL::character varying | jsonb | Recupera tutte le aziende cross-tenant per SuperAdmin |
| `fn_superadmin_query_table` | p_user_id uuid, p_table_name character varying, p_where_clause character varying DEFAULT NULL::character varying, p_limit_count integer DEFAULT NULL::integer | jsonb | SELECT generico per SuperAdmin su qualsiasi tabella |
| `fn_superadmin_update_table` | p_user_id uuid, p_table_name character varying, p_set_clause character varying, p_where_clause character varying | jsonb | UPDATE generico per SuperAdmin su qualsiasi tabella |
| `fn_test_smtp_config` | p_smtp_id uuid | TABLE(success boolean, message text, response_time interval) | Esegue un test simulato della configurazione SMTP e aggiorna lo stato |
| `fn_touch_data_ultima_modifica` |  | trigger |  |
| `fn_touch_updated_at` |  | trigger |  |
| `fn_touch_updated_at_iva` |  | trigger |  |
| `fn_touch_updated_at_menu` |  | trigger |  |
| `fn_touch_updated_at_regimi_fiscali` |  | trigger |  |
| `fn_touch_updated_at_simple` |  | trigger |  |
| `fn_touch_updated_at_smtp_enhanced` |  | trigger |  |
| `fn_trg_user_roles_protect_system` |  | trigger |  |
| `fn_trg_user_roles_update_audit` |  | trigger |  |
| `fn_trip_dates` | p_azienda_id integer, p_viaggio_id integer | TABLE(data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date) |  |
| `fn_trip_details` | p_azienda_id integer, p_viaggio_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_numero_giorni integer, nome_nazione character varying, viaggio_tipo_pernottamento_fk integer, ana_tipo_pernottamento_con_albergo character varying) |  |
| `fn_trips_available` | p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_numero_giorni integer, nome_nazione character varying) |  |
| `fn_update_mov_transazioni_totals` |  | trigger |  |
| `fn_validate_config_type_requirements` | p_config_type character varying, p_from_email text, p_host character varying, p_port integer, p_username character varying | text | Verifica i requisiti specifici per tipo di configurazione email (main, pec, support, etc) |
| `fn_validate_data_documento` |  | trigger | Valida che le transazioni in valuta estera abbiano obbligatoriamente la data_documento per recuperare il tasso di cambio corretto |
| `fn_validate_date_viaggio_duration` |  | trigger |  |
| `fn_validate_email_format` | p_email text | boolean | Valida il formato sintattico di un indirizzo email via regex |
| `fn_validate_logo_before_insert` |  | trigger |  |
| `fn_validate_protocol_requirements` | p_direction character varying, p_protocol character varying, p_host character varying, p_port integer, p_inbound_host character varying, p_inbound_port integer, p_inbound_protocol character varying | text | Verifica la coerenza dei parametri di protocollo (porte, host) per inbound/outbound |
| `fn_validate_security_port_consistency` | p_security_method character varying, p_port integer, p_inbound_security_method character varying, p_inbound_port integer, p_inbound_protocol character varying | text | Verifica la coerenza tra metodo di sicurezza (SSL/TLS) e porte standard |
| `fn_validate_transazione_metadata` |  | trigger | Validates transactions based on metadata from ana_tipi_causali. Enforces: scadenza requirements (RULE 1), auto-generation (RULE 2), stato consistency (RULE 3-4). All rules are data-driven, no hardcoding. |
| `fn_wizard_check_cf_esistenza` | p_cf character varying, p_azienda_id integer, p_cliente_id integer DEFAULT NULL::integer | TABLE(cf_exists boolean) | Verifica se un codice fiscale esiste gia per una determinata azienda. Se p_cliente_id e fornito, esclude quel cliente dalla verifica (scenario aggiornamento). Usato per prevenire duplicati. |
| `fn_wizard_find_email_by_anagrafica` | p_cognome character varying, p_nome character varying, p_cf character varying, p_azienda_id integer | TABLE(cliente_email character varying) | Restituisce l'email di un cliente esistente cercando per cognome, nome e codice fiscale. Usato per recuperare l'email in caso di violazione unique constraint durante l'inserimento. |
| `fn_wizard_find_email_by_cf` | p_cf character varying, p_azienda_id integer | TABLE(cliente_email character varying) | Restituisce l'email associata a un codice fiscale per una determinata azienda. Usato per informare l'utente dell'email gia registrata con quel CF. |
| `fn_wizard_get_albergo_sino` | p_pernottamento_id integer | character |  |
| `fn_wizard_get_all_comuni` |  | TABLE(comune_id integer, comune_descrizione character varying, comune_istat character varying, comune_provincia_fk integer, comune_preftel character varying, comune_cap character varying, comune_codfisc character varying, comune_num_abitanti integer, comune_link character varying, comune_ripgeo_fk integer, comune_capoluogo_fk integer, comune_estero character) | Restituisce tutti i comuni ordinati per descrizione. Sostituisce il SELECT inline in comuni.py::get_all_comuni(). |
| `fn_wizard_get_all_mezzi` |  | TABLE(ana_mezzi_id integer, ana_mezzi_descrizione character varying) |  |
| `fn_wizard_get_all_nazioni` |  | TABLE(country_id integer, name character varying, nationality character varying, country_code character varying, iso_alpha2 character varying, capital character varying, population bigint, area_km2 numeric, region_id integer, sub_region_id integer, intermediate_region_id integer, organization_region_id integer) | Restituisce tutte le nazioni ordinate per nome. Sostituisce il SELECT inline in nazioni.py::get_all_nazioni(). |
| `fn_wizard_get_all_province` |  | TABLE(provincia_id integer, provincia_descrizione character varying, provincia_sigla character varying, provincia_superficie numeric, provincia_residenti integer, provincia_num_comuni integer, regione_id_fk integer) | Restituisce tutte le province ordinate per descrizione. Sostituisce il SELECT inline in province.py::get_all_province(). |
| `fn_wizard_get_all_regioni` |  | TABLE(regione_id integer, regione_descrizione character varying, regione_nr_residenti integer, regione_perc_residenti numeric, regione_densita_kmq numeric, regione_nr_province integer, regione_nr_comuni integer, country_id_fk integer) | Restituisce tutte le regioni ordinate per descrizione. Sostituisce il SELECT inline in regioni.py::get_all_regioni(). |
| `fn_wizard_get_all_tipi_alloggio` |  | TABLE(tipo_alloggio_id integer, tipo_alloggio_descrizione character varying, tipo_alloggio_supplemento character, tipo_alloggio_numero_occupanti integer, tipo_alloggio_fk integer) |  |
| `fn_wizard_get_all_tipi_mezzi` |  | TABLE(ana_tipo_mezzo_id integer, ana_tipo_mezzo_descrizione character varying) | Restituisce tutti i tipi di mezzi ordinati per descrizione. Usato per popolare il combobox tipo mezzo nello Step 4. |
| `fn_wizard_get_alloggi_viaggio` | p_viaggio_id integer, p_data_viaggio_id integer | TABLE(mov_clienti_alloggio_pk integer, viaggio_id_fk integer, data_viaggio_id_fk integer, tipo_alloggio_id_fk integer, cliente_id1_fk integer, cliente_id2_fk integer, cliente_id3_fk integer, cliente_id4_fk integer, cliente_id5_fk integer, cliente_id6_fk integer) |  |
| `fn_wizard_get_azienda_email_principale` | p_azienda_id integer | character varying | Restituisce l'indirizzo email principale (is_principale=true) dell'azienda specificata. Usato per inviare la mail di riepilogo alla segreteria. |
| `fn_wizard_get_client_data` | p_cliente_id integer | TABLE(cliente_cognome character varying, cliente_nome character varying, cliente_data_nascita date, cliente_sesso character, comune_codfisc character varying, cliente_intolleranza text) | Restituisce i dati anagrafici di un cliente dato il suo ID, incluso il codice catastale del comune di nascita. Usato per la validazione del codice fiscale. |
| `fn_wizard_get_comune_by_id` | p_comune_id integer | TABLE(comune_id integer, comune_descrizione character varying, comune_istat character varying, comune_provincia_fk integer, comune_preftel character varying, comune_cap character varying, comune_codfisc character varying, comune_num_abitanti integer, comune_link character varying, comune_ripgeo_fk integer, comune_capoluogo_fk integer, comune_estero character) | Restituisce i dati di un comune dato il suo ID. Sostituisce il SELECT inline in comuni.py::get_comune_by_id(). |
| `fn_wizard_get_comune_by_istat` | p_istat character varying | TABLE(comune_codfisc character varying) | Restituisce il codice catastale (comune_codfisc) di un comune dato il codice ISTAT. Sostituisce il SELECT inline in comuni.py::get_comune_by_istat(). |
| `fn_wizard_get_comuni_by_cliente` | p_cliente_id integer | TABLE(cliente_comune_nascita_fk integer, cliente_comune_residenza_fk integer) | Restituisce i FK dei comuni di nascita e residenza di un cliente. Sostituisce il SELECT inline in comuni.py::get_comuni_by_cliente(). |
| `fn_wizard_get_date_by_id` | p_data_viaggio_id integer | TABLE(data_viaggio_id integer, viaggio_id_fk integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_effettuato_sino character, data_viaggio_costo_pilota integer, data_viaggio_costo_passeggero integer, data_viaggio_costo_passeggero_auto_guida integer, data_viaggio_costo_bambino_0_2 integer, data_viaggio_costo_bambino_2_6 integer, data_viaggio_costo_bambino_6_12 integer, data_viaggio_note character varying) |  |
| `fn_wizard_get_date_viaggio` | p_viaggio_id integer | TABLE(data_viaggio_id integer, viaggio_id_fk integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_effettuato_sino character, data_viaggio_costo_pilota integer, data_viaggio_costo_passeggero integer, data_viaggio_costo_passeggero_auto_guida integer, data_viaggio_costo_bambino_0_2 integer, data_viaggio_costo_bambino_2_6 integer, data_viaggio_costo_bambino_6_12 integer, data_viaggio_note character varying) |  |
| `fn_wizard_get_mezzi_by_ids` | p_ids integer[] | TABLE(ana_mezzi_id integer, ana_mezzi_descrizione character varying) |  |
| `fn_wizard_get_mezzi_by_tipo` | p_tipo_id integer | TABLE(ana_mezzi_id integer, ana_mezzi_descrizione character varying) | Restituisce tutte le marche che hanno almeno un modello del tipo specificato, ordinate per descrizione. Usato per filtrare il combobox marca in base al tipo selezionato. |
| `fn_wizard_get_mezzo_by_id` | p_mezzo_id integer | TABLE(ana_mezzi_id integer, ana_mezzi_descrizione character varying) |  |
| `fn_wizard_get_modelli_by_ids` | p_ids integer[] | TABLE(mezzo_modello_id integer, mezzo_modello_descrizione character varying, mezzo_modello_mezzo_fk integer, mezzo_modello_tipo_fk integer) |  |
| `fn_wizard_get_modelli_by_mezzo` | p_mezzo_id integer | TABLE(mezzo_modello_id integer, mezzo_modello_descrizione character varying, mezzo_modello_mezzo_fk integer, mezzo_modello_tipo_fk integer) |  |
| `fn_wizard_get_modelli_by_mezzo_and_tipo` | p_mezzo_id integer, p_tipo_id integer | TABLE(mezzo_modello_id integer, mezzo_modello_descrizione character varying, mezzo_modello_mezzo_fk integer, mezzo_modello_tipo_fk integer) | Restituisce tutti i modelli per una marca specifica filtrati per tipo, ordinati per descrizione. Usato per popolare il combobox modello con solo i modelli pertinenti al tipo selezionato. |
| `fn_wizard_get_modello_by_id` | p_modello_id integer | TABLE(mezzo_modello_id integer, mezzo_modello_descrizione character varying, mezzo_modello_mezzo_fk integer, mezzo_modello_tipo_fk integer) |  |
| `fn_wizard_get_nazione_by_regione` | p_regione_id integer | TABLE(country_id integer, name character varying, nationality character varying, country_code character varying, iso_alpha2 character varying, capital character varying, population bigint, area_km2 numeric, region_id integer, sub_region_id integer, intermediate_region_id integer, organization_region_id integer) | Restituisce la nazione associata a una regione tramite JOIN. Sostituisce il SELECT inline in nazioni.py::get_nazione_by_regione(). |
| `fn_wizard_get_partecipanti` | p_ids integer[] | TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying) |  |
| `fn_wizard_get_partecipanti_details` | p_ids integer[] | TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying, cliente_email character varying, cliente_data_nascita date, cliente_intolleranza text) | Restituisce i dettagli (ID, cognome, nome, email, data nascita, intolleranze) per una lista di ID partecipanti. Usato per comporre il riepilogo iscrizione e l'email di conferma. |
| `fn_wizard_get_provincia_by_comune` | p_comune_id integer | TABLE(provincia_id integer, provincia_descrizione character varying, provincia_sigla character varying, provincia_superficie numeric, provincia_residenti integer, provincia_num_comuni integer, regione_id_fk integer) | Restituisce la provincia associata a un comune tramite JOIN. Sostituisce il SELECT inline in province.py::get_provincia_by_comune(). |
| `fn_wizard_get_regione_by_provincia` | p_provincia_id integer | TABLE(regione_id integer, regione_descrizione character varying, regione_nr_residenti integer, regione_perc_residenti numeric, regione_densita_kmq numeric, regione_nr_province integer, regione_nr_comuni integer, country_id_fk integer) | Restituisce la regione associata a una provincia tramite JOIN. Sostituisce il SELECT inline in regioni.py::get_regione_by_provincia(). |
| `fn_wizard_get_registrazioni_viaggio` | p_viaggio_id integer, p_data_viaggio_id integer | TABLE(viaggio_id_fk integer, data_viaggio_id_fk integer, cliente_id_fk integer, tipo_partecipante_id_fk integer, cliente_pilota_id_fk integer, ana_mezzi_id_fk integer, mezzo_modello_id_fk integer, mov_cliente_viaggio_targa_mezzo character varying, mov_cliente_viaggio_cane_sino character varying, mov_cliente_viaggio_note text) |  |
| `fn_wizard_get_smtp_config` | p_azienda_id integer | TABLE(host character varying, port integer, username character varying, password_value text, use_tls boolean, use_starttls boolean, from_name character varying, from_email text, reply_to text, security_method character varying) |  |
| `fn_wizard_get_tipi_alloggio_by_ids` | p_ids integer[] | TABLE(tipo_alloggio_id integer, tipo_alloggio_descrizione character varying, tipo_alloggio_supplemento character, tipo_alloggio_numero_occupanti integer, tipo_alloggio_fk integer) |  |
| `fn_wizard_get_viaggi_disponibili` | p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_link character varying, nome_nazione character varying) |  |
| `fn_wizard_get_viaggio_by_id` | p_viaggio_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_link character varying, viaggio_tipo_pernottamento_fk integer, azienda_id integer, nome_nazione character varying, ana_tipo_pernottamento_con_albergo character) |  |
| `fn_wizard_insert_alloggio_assegnato` | p_viaggio_id integer, p_data_viaggio_id integer, p_tipo_alloggio_id integer, p_cli1 integer, p_cli2 integer, p_cli3 integer, p_cli4 integer, p_cli5 integer, p_cli6 integer, p_created_by character varying | void | Inserisce un assegnazione alloggio in mov_clienti_alloggi con fino a 6 partecipanti. Usato da insert_alloggi_assegnati() in mov_clienti_alloggi_dao.py. |
| `fn_wizard_insert_cliente` | p_azienda_id integer, p_titolo character varying, p_cognome character varying, p_nome character varying, p_sesso character varying, p_comune_residenza_fk integer, p_indirizzo_residenza character varying, p_comune_nascita_fk integer, p_data_nascita date, p_preftelint character varying, p_telefono character varying, p_email character varying, p_codicefiscale character varying, p_intolleranza text, p_tipodoc_identita character varying, p_documento_numero character varying, p_documento_rilasciato_da character varying, p_documento_rilasciato_data date, p_documento_rilasciato_scadenza date, p_created_by character varying DEFAULT 'WIZARD'::character varying | integer | Inserisce un nuovo cliente in ana_clienti e restituisce il nuovo cliente_id. Usato da insert_cliente() in cliente.py. |
| `fn_wizard_insert_prenotazione` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer, p_tipo_partecipante integer, p_pilota_id integer, p_mezzo_id integer, p_modello_id integer, p_targa character varying, p_has_cane character varying, p_notes text | void | Inserisce una riga di partecipazione in mov_clienti_viaggi (pilota o passeggero). Usato da insert_prenotazione() in mov_clienti_viaggi_dao.py. |
| `fn_wizard_is_cliente_registrato` | p_cliente_id integer, p_viaggio_id integer, p_data_viaggio_id integer | boolean |  |
| `fn_wizard_leggi_dati_cliente` | p_email character varying, p_azienda_id integer | TABLE(cliente_id integer, cliente_titolo character varying, cliente_cognome character varying, cliente_nome character varying, cliente_sesso character, cliente_comune_residenza_fk integer, descrizione_comune_residenza character varying, cliente_indirizzo_residenza character varying, cliente_comune_nascita_fk integer, descrizione_comune_nascita character varying, cliente_data_nascita date, cliente_preftelint character varying, cliente_telefono character varying, cliente_email character varying, cliente_codicefiscale character varying, cliente_intolleranza text, cliente_tipodoc_identita character varying, cliente_documento_numero character varying, cliente_documento_rilasciato_da character varying, cliente_documento_rilasciato_data date, cliente_documento_rilasciato_scadenza date) |  |
| `fn_wizard_search_comuni` | p_term text, p_limit integer | TABLE(comune_id integer, comune_descrizione character varying) | Ricerca comuni per prefisso (ILIKE p_term||%). Il caller passa p_term as-is (senza uppercase). Sostituisce il SELECT inline in comuni.py::search_comuni(). |
| `fn_wizard_update_cliente` | p_cliente_id integer, p_titolo character varying, p_cognome character varying, p_nome character varying, p_sesso character varying, p_comune_residenza_fk integer, p_indirizzo_residenza character varying, p_comune_nascita_fk integer, p_data_nascita date, p_preftelint character varying, p_telefono character varying, p_email character varying, p_codicefiscale character varying, p_intolleranza text, p_tipodoc_identita character varying, p_documento_numero character varying, p_documento_rilasciato_da character varying, p_documento_rilasciato_data date, p_documento_rilasciato_scadenza date | boolean | Aggiorna i dati anagrafici di un cliente esistente in ana_clienti. Restituisce TRUE se almeno una riga e stata aggiornata (FOUND). Usato da update_cliente() in cliente.py. |
| `fn_wizard_verifica_cliente` | p_email character varying, p_azienda_id integer | TABLE(cliente_exists boolean) |  |
| `generate_reset_token` |  | character varying | Genera un token univoco per il reset password basato su timestamp e random |
| `get_all_participants_travel` | p_data_viaggio_id integer | TABLE(nominativo text) | Restituisce la lista semplice dei nominativi partecipanti per una data viaggio |
| `get_all_travel_detail` | p_data_viaggio_id integer | TABLE(data_viaggio_id integer, viaggio_id integer, azienda_id integer, titolo text, descrizione_estesa text, tipo text, nazione text, data_inizio date, data_fine date, effettuato_sino character, km integer, giorni integer, notti integer, trattamento text, pernottamento text, costo_pilota integer, costo_passeggero integer, costo_passeggero_auto_guida integer, costo_bambino_0_2 integer, costo_bambino_2_6 integer, costo_bambino_6_12 integer, pasti_al_sacco character, tipo_avvicinamento text, note_viaggio text, note_data_viaggio text, link text) |  |
| `get_client_travel_history` | p_cliente_id integer, p_azienda_id integer | TABLE(data_viaggio_id integer, titolo text, tipo text, data_inizio date, data_fine date, km integer, giorni integer, notti integer, status_code integer, status_desc text, ruolo text, trattamento text, pernottamento text, costo_pilota integer, costo_passeggero integer) | Recupera lo storico viaggi di un cliente con dettagli su destinazione e data |
| `get_cliente_detail` | p_cliente_id integer | TABLE(cliente_id integer, cliente_titolo character varying, cliente_cognome character varying, cliente_nome character varying, cliente_sesso character, cliente_comune_residenza_fk integer, cliente_indirizzo_residenza character varying, cliente_comune_nascita_fk integer, cliente_data_nascita date, cliente_preftelint character varying, cliente_telefono character varying, cliente_email character varying, cliente_codicefiscale character varying, cliente_iban character varying, cliente_foto bytea, cliente_carta_identita bytea, cliente_tipodoc_identita character varying, cliente_documento_numero character varying, cliente_documento_rilasciato_da character varying, cliente_documento_rilasciato_data date, cliente_documento_rilasciato_scadenza date, cliente_note text, cliente_foto_mimetype character varying, cliente_foto_filename character varying, cliente_foto_charset character varying, cliente_foto_upd_date date, cliente_documento_mimetype character varying, cliente_documento_filename character varying, cliente_documento_chartset character varying, cliente_documento_upd_date date, cliente_intolleranza text, azienda_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, azienda_ragione_sociale character varying, comune_nascita_nome character varying, comune_nascita_provincia character varying, comune_residenza_nome character varying, comune_residenza_provincia character varying) | Recupera tutti i dati anagrafici e documenti di un cliente specifico |
| `get_company_print_info` | p_azienda_id integer | TABLE(ragione_sociale character varying, telefono character varying, email character varying, sito_web character varying, piva character varying, logo_data text) |  |
| `get_count_travel_future` | p_cliente_id integer, p_azienda_id integer | integer | Conta i viaggi futuri prenotati per un cliente |
| `get_count_travel_made` | p_cliente_id integer, p_azienda_id integer | integer | Conta i viaggi passati effettuati da un cliente |
| `get_customer_nationality` | p_cliente_id integer | text | Determina la nazionalità (ISO) del cliente basandosi su nascita o residenza |
| `get_datetrips_fromtrip` | p_viaggio_id integer | TABLE(data_viaggio_id integer, viaggio_id_fk integer, data_viaggio_data_inizio timestamp without time zone, data_viaggio_data_fine timestamp without time zone, data_viaggio_effettuato_sino character varying, data_viaggio_costo_pilota integer, data_viaggio_costo_passeggero integer, data_viaggio_costo_passeggero_auto_guida integer, data_viaggio_costo_bambino_0_2 integer, data_viaggio_costo_bambino_2_6 integer, data_viaggio_costo_bambino_6_12 integer, data_viaggio_note character varying, azienda_id integer, tot_mezzi integer, tot_clienti integer) | Restituisce tutte le date pianificate associate a un viaggio principale |
| `get_exist_travel_customer_by_year` | p_cliente_id integer | TABLE(anno integer) | Restituisce gli anni in cui un cliente ha effettuato viaggi |
| `get_max_old_year_company` | p_azienda_id integer | integer |  |
| `get_mezzi_count` | p_data_viaggio_id integer | integer |  |
| `get_mezzo_by_pilot` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer | text |  |
| `get_participants_count` | p_data_viaggio_id integer | integer | Conta il numero totale di partecipanti per una specifica data viaggio |
| `get_participants_sorted` | p_data_viaggio_id integer | TABLE(viaggio_id integer, data_id integer, cliente_id integer, nominativo text, tipo_partecipante_id integer, ruolo text, note text, cane_sino character varying, intolleranze text, mezzo_dettagli text, cliente_pilota_id integer, grouping_key integer, is_pilot boolean, telefono text, email text, residenza text, codice_fiscale text, data_nascita date, luogo_nascita text, nazionalita text, tipo_documento text, numero_documento text, rilasciato_da text, data_rilascio date, data_scadenza date) |  |
| `get_participants_without_accommodation` | p_data_viaggio_id integer | TABLE(viaggio_id integer, data_id integer, cliente_id integer, nominativo text, tipo_partecipante_id integer, ruolo text, note text, cane_sino character varying, intolleranze text, mezzo_dettagli text, cliente_pilota_id integer, grouping_key integer) |  |
| `get_pilots_grouped_by_vehicle` | p_data_viaggio_id integer | TABLE(viaggio_id integer, data_id integer, cliente_id integer, nominativo text, marca text, modello text, targa text, telefono text, email text, residenza text, codice_fiscale text, data_nascita date, luogo_nascita text) |  |
| `get_reset_stats` | p_days integer DEFAULT 30 | character varying | Genera statistiche sistema reset password per periodo specificato |
| `get_rooming_list_data` | p_data_viaggio_id integer | TABLE(cliente_id integer, room_id integer, nominativo text, eta integer, data_nascita date, luogo_nascita text, indirizzo_residenza text, citta_residenza text, residenza_completa text, country_code text, country_name text, nationality text, tipo_documento text, numero_documento text, ente_rilascio text, data_rilascio date, data_scadenza date, intolleranze text, tipo_alloggio_id integer, tipo_alloggio_descrizione text, max_occupanti integer, sort_order integer, position_number integer, is_pilot boolean) |  |
| `get_rooms_count` | p_data_viaggio_id integer | integer |  |
| `get_rooms_with_occupants` | p_data_viaggio_id integer | TABLE(alloggio_pk integer, tipo_alloggio text, max_occupants integer, current_occupants integer, occupant_names text[], occupant_ids integer[], has_supplement boolean, pilot_cognome text) | Restituisce camere con occupanti aggregati. Ordinamento: pilota primo, poi passeggeri per cognome/nome. Colonna pilot_cognome usata per ordinare le camere all'interno della tipologia. |
| `get_totmezzi_dataviaggio` | p_viaggio_id integer, p_data_viaggio_id integer | integer | Conta i veicoli assegnati ed effettivi per una data viaggio |
| `get_travel_passengers` | p_data_viaggio_id integer, p_exclude_client_id integer | TABLE(nominativo text, ruolo text) | Restituisce la lista passeggeri per un viaggio escludendo un ID cliente specifico |
| `get_travel_stats` | p_data_viaggio_id integer | TABLE(total_participants integer, total_crews integer, total_vehicles integer) |  |
| `get_viaggi_grouped_by_year` | p_azienda_id integer | TABLE(anno integer, viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_inizio date, data_fine date, effettuato_sino character) |  |
| `get_viaggio_partecipanti` | p_data_viaggio_id integer | TABLE(gruppo_id integer, pilota_nominativo text, passeggeri_nominativi text) | Restituisce lista partecipanti raggruppati per pilota con formattazione dettagliata |
| `get_viaggio_partecipanti_summary` | p_data_viaggio_id integer | text |  |
| `hash_password` | p_password text | character varying | Genera hash bcrypt sicuro per una password in chiaro |
| `mov_clienti_alloggi_trg1_func` |  | trigger |  |
| `mov_clienti_viaggi_trg1_func` |  | trigger |  |
| `request_password_reset_retool` | p_email character varying, p_ip_address inet DEFAULT NULL::inet, p_user_agent character varying DEFAULT NULL::character varying | void | Procedura principale per Retool con messaggi italiani |
| `reset_password_with_token` | p_token character varying, p_new_password_plain text | character varying |  |
| `reset_password_with_token` | p_token character varying, p_new_password_hash character varying | character varying | Esegue reset password con token e invalida tutti i token utente |
| `set_user_context` | p_user_id uuid, p_azienda_id integer | void |  |
| `set_user_context` | p_user_id uuid | TABLE(tenant_id text, azienda_id integer, role_code text) | Imposta contesto completo utente: tenant, azienda e ruolo |
| `sp_ana_aliquote_iva_create` | p_azienda_fk integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_created_by character varying, p_updated_by character varying | integer | Crea nuova aliquota IVA con validazione e normalizzazione UPPER CASE. Ritorna iva_id. |
| `sp_ana_aliquote_iva_delete` | p_iva_id integer | void | Elimina aliquota IVA. Solleva eccezione se in uso da altre tabelle. |
| `sp_ana_aliquote_iva_set_default` | p_iva_id integer, p_azienda_id integer | void | Imposta un'aliquota come default per azienda. Il trigger rimuove automaticamente il flag dalle altre. |
| `sp_ana_aliquote_iva_update` | p_iva_id integer, p_iva_codice character varying, p_iva_descrizione character varying, p_iva_percentuale numeric, p_iva_natura character varying, p_is_default boolean, p_is_active boolean, p_ordinamento smallint, p_updated_by character varying | void | Aggiorna aliquota IVA esistente con validazione e normalizzazione UPPER CASE. |
| `sp_ana_api_config_create` | p_service_code character varying, p_service_name character varying, p_config_key character varying, p_config_value text DEFAULT NULL::text, p_config_type character varying DEFAULT 'TEXT'::character varying, p_config_description character varying DEFAULT NULL::character varying, p_is_secret boolean DEFAULT false, p_is_active boolean DEFAULT true, p_display_order smallint DEFAULT 0, p_created_by character varying DEFAULT NULL::character varying | integer | Crea nuova configurazione API con validazione completa e normalizzazione automatica UPPER CASE su service_code, config_key, config_type. |
| `sp_ana_api_config_delete` | p_config_id integer | void | Elimina una singola configurazione API per ID. |
| `sp_ana_api_config_delete_service` | p_service_code character varying | void | Elimina tutte le configurazioni di un servizio specifico. Usato per rimuovere un intero servizio. |
| `sp_ana_api_config_update` | p_config_id integer, p_service_code character varying, p_service_name character varying, p_config_key character varying, p_config_value text, p_config_type character varying, p_config_description character varying, p_is_secret boolean, p_is_active boolean, p_display_order smallint, p_updated_by character varying | void | Aggiorna configurazione API esistente con validazione completa e normalizzazione automatica UPPER CASE. |
| `sp_ana_aziende_smtp_test_connection` | p_smtp_id uuid | TABLE(success boolean, message text, response_time_ms integer, connection_status character varying) | Store Procedure per testare la connessione SMTP e aggiornare i log |
| `sp_ana_clienti_create` | p_cliente_titolo character varying, p_cliente_cognome character varying, p_cliente_nome character varying, p_cliente_sesso character varying, p_cliente_comune_residenza_fk integer, p_cliente_indirizzo_residenza character varying, p_cliente_comune_nascita_fk integer, p_cliente_data_nascita date, p_cliente_preftelint character varying, p_cliente_telefono character varying, p_cliente_email character varying, p_cliente_codicefiscale character varying, p_cliente_iban character varying, p_cliente_foto bytea, p_cliente_carta_identita bytea, p_cliente_tipodoc_identita character varying, p_cliente_documento_numero character varying, p_cliente_documento_rilasciato_da character varying, p_cliente_documento_rilasciato_data date, p_cliente_documento_rilasciato_scadenza date, p_cliente_note text, p_cliente_foto_mimetype character varying, p_cliente_foto_filename character varying, p_cliente_foto_charset character varying, p_cliente_foto_upd_date timestamp without time zone, p_cliente_documento_mimetype character varying, p_cliente_documento_filename character varying, p_cliente_documento_chartset character varying, p_cliente_documento_upd_date timestamp without time zone, p_cliente_intolleranza character varying, p_azienda_fk integer | json | DB-First: Create new cliente and return full record |
| `sp_ana_clienti_delete` | p_cliente_id integer, p_azienda_fk integer | void | DB-First: Delete cliente with referential integrity checks |
| `sp_ana_clienti_update` | p_cliente_id integer, p_cliente_titolo character varying, p_cliente_cognome character varying, p_cliente_nome character varying, p_cliente_sesso character varying, p_cliente_comune_residenza_fk integer, p_cliente_indirizzo_residenza character varying, p_cliente_comune_nascita_fk integer, p_cliente_data_nascita date, p_cliente_preftelint character varying, p_cliente_telefono character varying, p_cliente_email character varying, p_cliente_codicefiscale character varying, p_cliente_iban character varying, p_cliente_foto bytea, p_cliente_carta_identita bytea, p_cliente_tipodoc_identita character varying, p_cliente_documento_numero character varying, p_cliente_documento_rilasciato_da character varying, p_cliente_documento_rilasciato_data date, p_cliente_documento_rilasciato_scadenza date, p_cliente_note text, p_cliente_foto_mimetype character varying, p_cliente_foto_filename character varying, p_cliente_foto_charset character varying, p_cliente_foto_upd_date timestamp without time zone, p_cliente_documento_mimetype character varying, p_cliente_documento_filename character varying, p_cliente_documento_chartset character varying, p_cliente_documento_upd_date timestamp without time zone, p_cliente_intolleranza character varying, p_azienda_fk integer | json | DB-First: Update existing cliente and return full record |
| `sp_ana_date_viaggi_create` | p_viaggio_id_fk integer, p_data_viaggio_data_inizio date, p_data_viaggio_data_fine date, p_data_viaggio_effettuato_sino character, p_data_viaggio_costo_pilota integer, p_data_viaggio_costo_passeggero integer, p_data_viaggio_costo_passeggero_auto_guida integer, p_data_viaggio_costo_bambino_0_2 integer, p_data_viaggio_costo_bambino_2_6 integer, p_data_viaggio_costo_bambino_6_12 integer, p_data_viaggio_note character varying, p_azienda_id integer, p_created_by character varying | integer |  |
| `sp_ana_date_viaggi_delete` | p_data_viaggio_id integer | TABLE(deleted boolean, error_message text) |  |
| `sp_ana_date_viaggi_update` | p_data_viaggio_id integer, p_data_viaggio_data_inizio date, p_data_viaggio_data_fine date, p_data_viaggio_effettuato_sino character, p_data_viaggio_costo_pilota integer, p_data_viaggio_costo_passeggero integer, p_data_viaggio_costo_passeggero_auto_guida integer, p_data_viaggio_costo_bambino_0_2 integer, p_data_viaggio_costo_bambino_2_6 integer, p_data_viaggio_costo_bambino_6_12 integer, p_data_viaggio_note character varying, p_azienda_id integer, p_updated_by character varying, p_updated timestamp with time zone | void |  |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false | integer |  |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying | integer | Crea nuova causale con validazione completa e normalizzazione automatica UPPER CASE. |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false, p_tipo_documento_sdi character varying DEFAULT NULL::character varying | integer |  |
| `sp_ana_tipi_causali_delete` | p_causale_id integer | void | Elimina causale. Blocca eliminazione se in uso da transazioni. |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_updated_by character varying | void | Aggiorna causale esistente con validazione completa e normalizzazione automatica UPPER CASE. |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false, p_tipo_documento_sdi character varying DEFAULT NULL::character varying | void |  |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false | void |  |
| `sp_ana_tipo_fornitore_create` | p_azienda_fk integer, p_descrizione character varying, p_categoria character varying DEFAULT NULL::character varying, p_conto_contabile_default character varying DEFAULT NULL::character varying | integer | Crea nuovo tipo fornitore con normalizzazione UPPER CASE e validazioni business logic |
| `sp_ana_tipo_fornitore_delete` | p_tipo_fornitore_id integer | void | Elimina tipo fornitore. Blocca eliminazione se in uso da controparti (FK violation) |
| `sp_ana_tipo_fornitore_update` | p_tipo_fornitore_id integer, p_descrizione character varying, p_categoria character varying DEFAULT NULL::character varying, p_conto_contabile_default character varying DEFAULT NULL::character varying | void | Aggiorna tipo fornitore esistente con normalizzazione UPPER CASE e validazioni |
| `sp_ana_viaggi_create` | p_viaggio_descrizione_breve character varying, p_viaggio_descrizione_estesa text, p_viaggio_numero_giorni integer, p_viaggio_numero_notti integer, p_viaggio_pasti_al_sacco character, p_viaggio_num_km integer, p_viaggio_tipo_avvicinamento_fk integer, p_viaggio_note text, p_viaggio_link character varying, p_viaggio_nazione_fk integer, p_viaggio_tipo_viaggio_fk integer, p_viaggio_tipo_trattamento_fk integer, p_viaggio_tipo_pernottamento_fk integer, p_azienda_id integer, p_created_by character varying, p_created timestamp with time zone, p_updated_by character varying, p_updated timestamp with time zone | integer |  |
| `sp_ana_viaggi_delete` | p_viaggio_id integer | TABLE(deleted boolean, error_message text) |  |
| `sp_ana_viaggi_update` | p_viaggio_id integer, p_viaggio_descrizione_breve character varying, p_viaggio_descrizione_estesa text, p_viaggio_numero_giorni integer, p_viaggio_numero_notti integer, p_viaggio_pasti_al_sacco character, p_viaggio_num_km integer, p_viaggio_tipo_avvicinamento_fk integer, p_viaggio_note text, p_viaggio_link character varying, p_viaggio_nazione_fk integer, p_viaggio_tipo_viaggio_fk integer, p_viaggio_tipo_trattamento_fk integer, p_viaggio_tipo_pernottamento_fk integer, p_azienda_id integer, p_updated_by character varying, p_updated timestamp with time zone | void |  |
| `sp_assegna_protocollo_iva` | p_transazione_id integer | integer | Assegna atomicamente un numero di protocollo IVA progressivo a una transazione qualificante. Idempotente. |
| `sp_assign_to_first_free_slot` | p_alloggio_pk integer, p_cliente_id integer | boolean |  |
| `sp_mov_clienti_alloggi_create` | p_viaggio_id integer, p_data_viaggio_id integer, p_tipo_alloggio_id integer, p_cliente_id1 integer, p_cliente_id2 integer DEFAULT NULL::integer, p_cliente_id3 integer DEFAULT NULL::integer, p_cliente_id4 integer DEFAULT NULL::integer, p_cliente_id5 integer DEFAULT NULL::integer, p_cliente_id6 integer DEFAULT NULL::integer | integer |  |
| `sp_mov_clienti_alloggi_delete` | p_pk integer | void |  |
| `sp_mov_clienti_alloggi_update` | p_pk integer, p_viaggio_id integer, p_data_viaggio_id integer, p_tipo_alloggio_id integer, p_cliente_id1 integer, p_cliente_id2 integer DEFAULT NULL::integer, p_cliente_id3 integer DEFAULT NULL::integer, p_cliente_id4 integer DEFAULT NULL::integer, p_cliente_id5 integer DEFAULT NULL::integer, p_cliente_id6 integer DEFAULT NULL::integer | void |  |
| `sp_mov_clienti_viaggi_create` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer, p_tipo_partecipante_id integer, p_ana_mezzi_id integer DEFAULT NULL::integer, p_mezzo_modello_id integer DEFAULT NULL::integer, p_sconto_val_totale numeric DEFAULT NULL::numeric, p_targa_mezzo character varying DEFAULT NULL::character varying, p_cane_sino character varying DEFAULT 'N'::character varying, p_note text DEFAULT NULL::text, p_cliente_pilota_id integer DEFAULT NULL::integer | void |  |
| `sp_mov_clienti_viaggi_delete` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer | void |  |
| `sp_mov_clienti_viaggi_update` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer, p_tipo_partecipante_id integer, p_ana_mezzi_id integer DEFAULT NULL::integer, p_mezzo_modello_id integer DEFAULT NULL::integer, p_sconto_val_totale numeric DEFAULT NULL::numeric, p_targa_mezzo character varying DEFAULT NULL::character varying, p_cane_sino character varying DEFAULT NULL::character varying, p_note text DEFAULT NULL::text, p_cliente_pilota_id integer DEFAULT NULL::integer | void |  |
| `sp_registra_pagamento` | p_transazione_id integer, p_importo_pagamento numeric DEFAULT NULL::numeric, p_data_pagamento date DEFAULT NULL::date, p_note_pagamento text DEFAULT NULL::text, p_current_user character varying DEFAULT 'System'::character varying | TABLE(pg_transazione_id integer, nuovo_stato character varying, importo_effettivo numeric, error_message text) | Registra un pagamento immediato per una transazione DA_PAGARE o PARZIALMENTE_PAGATO. Crea automaticamente una transazione PG (Pagamento) o IN (Incasso) collegata e aggiorna lo stato. |
| `sp_remove_client_from_room` | p_room_id integer, p_cliente_id integer | void |  |
| `sp_resolve_room_violation_move` | p_old_room_id integer, p_new_tipo_alloggio_id integer, p_survivor_ids integer[] | void |  |
| `sp_resolve_room_violation_park` | p_room_id integer, p_survivor_ids integer[] | void |  |
| `sync_date_viaggi_azienda_id` |  | trigger |  |
| `trg_ana_clienti_audit_unified` |  | trigger |  |
| `trg_ana_date_viaggi_audit` |  | trigger |  |
| `trg_ana_viaggi_audit` |  | trigger |  |
| `trg_app_users_login_count` |  | trigger |  |
| `trg_app_users_updated_at` |  | trigger |  |
| `trg_check_delete_tipo_avvicinamento` |  | trigger |  |
| `trg_log_clienti_events` |  | trigger |  |
| `trg_log_date_viaggi_events` |  | trigger |  |
| `trg_log_partecipanti_events` |  | trigger |  |
| `trg_log_viaggi_events` |  | trigger |  |
| `trg_mov_clienti_alloggi_audit` |  | trigger |  |
| `trg_mov_clienti_viaggi_audit` |  | trigger |  |
| `trg_prevent_client_delete_alloggi_func` |  | trigger |  |
| `trg_prevent_client_delete_func` |  | trigger |  |
| `trg_user_roles_delete_protection` |  | trigger |  |
| `trg_user_roles_updated_at` |  | trigger |  |
| `trg_web_audit` |  | trigger |  |
| `update_changetimestamp_column` |  | trigger |  |
| `update_modified_column` |  | trigger |  |
| `update_updated_at_column` |  | trigger |  |
| `validate_codice_fiscale` | cf text | boolean | Valida lunghezza e formato base del Codice Fiscale italiano |
| `validate_fiscal_data` |  | trigger |  |
| `validate_partita_iva` | piva text | boolean | Valida formato e checksum della Partita IVA italiana |
| `validate_reset_token` | p_token character varying | character varying | Valida token di reset verificando validità, scadenza e stato attivo |

### Funzioni nel DB non citate nella parte curata sopra

- `ana_geo_capoluogo_trg1_func`
- `ana_geo_capoluogo_trg2_func`
- `ana_geo_ita_ripgeo_trg1_func`
- `ana_geo_ita_ripgeo_trg2_func`
- `ana_geo_regioni_ita_trg1_func`
- `ana_geo_regioni_ita_trg2_func`
- `ana_mezzi_modelli_trg1_func`
- `ana_mezzi_modelli_trg2_func`
- `ana_mezzi_tgr1_func`
- `ana_mezzi_tgr2_func`
- `ana_tipo_alloggio_trg1_func`
- `ana_tipo_alloggio_trg2_func`
- `ana_tipo_pernottamento_check_delete`
- `ana_tipo_trattamento_check_delete`
- `ana_tipo_viaggi_check_delete`
- `ana_viaggi_trg1_func`
- `ana_viaggi_trg2_func`
- `check_delete_ana_tipo_partecipante`
- `cleanup_audit_login`
- `eba_countries_biu_func`
- `eba_countries_trg2_func`
- `eba_country_intermediates_biu_func`
- `eba_country_organizations_biu_func`
- `eba_country_regions_biu_func`
- `eba_country_sub_regions_biu_func`
- `fn_app_create_country_organization`
- `fn_app_create_geo_capoluogo`
- `fn_app_create_geo_comuni`
- `fn_app_create_geo_ita_ripgeo`
- `fn_app_create_geo_province`
- `fn_app_create_geo_regioni_ita`
- `fn_app_delete_country_organization`
- `fn_app_delete_geo_capoluogo`
- `fn_app_delete_geo_comuni`
- `fn_app_delete_geo_ita_ripgeo`
- `fn_app_delete_geo_province`
- `fn_app_delete_geo_regioni_ita`
- `fn_app_get_all_country_organizations`
- `fn_app_get_all_geo_capoluogos`
- `fn_app_get_all_geo_ita_ripgeos`
- `fn_app_get_aziende_distinct_values`
- `fn_app_get_comune_formatted`
- `fn_app_get_country_intermediate_by_id`
- `fn_app_get_country_organization_by_id`
- `fn_app_get_country_organizations_lookup`
- `fn_app_get_country_region_by_id`
- `fn_app_get_country_sub_region_by_id`
- `fn_app_get_geo_capoluogo`
- `fn_app_get_geo_capoluogos_lookup`
- `fn_app_get_geo_comuni`
- `fn_app_get_geo_ita_ripgeo`
- `fn_app_get_geo_ita_ripgeos_lookup`
- `fn_app_get_geo_province`
- `fn_app_get_geo_regioni_ita`
- `fn_app_get_tipo_sede_by_id`
- `fn_app_logo_create_backup_20250909`
- `fn_app_update_country_organization`
- `fn_app_update_geo_capoluogo`
- `fn_app_update_geo_comuni`
- `fn_app_update_geo_ita_ripgeo`
- `fn_app_update_geo_province`
- `fn_app_update_geo_regioni_ita`
- `fn_calcola_dati_riga`
- `fn_enforce_user_azienda_integrity`
- `fn_get_calendar_data`
- `fn_get_date_viaggi_with_transazioni`
- `fn_get_debug_v2`
- `fn_get_logo_field_help`
- `fn_get_menu_breadcrumbs`
- `fn_get_viaggi_with_transazioni`
- `fn_is_pec_domain`
- `fn_logo_calculate_hash`
- `fn_logo_update_access_stats`
- `fn_logo_validate_mime_type`
- `fn_set_azienda_id`
- `fn_touch_data_ultima_modifica`
- `fn_touch_updated_at`
- `fn_touch_updated_at_menu`
- `fn_touch_updated_at_regimi_fiscali`
- `fn_touch_updated_at_simple`
- `fn_touch_updated_at_smtp_enhanced`
- `fn_trg_user_roles_protect_system`
- `fn_trg_user_roles_update_audit`
- `fn_trip_dates`
- `fn_trip_details`
- `fn_trips_available`
- `fn_update_mov_transazioni_totals`
- `fn_validate_config_type_requirements`
- `fn_validate_date_viaggio_duration`
- `fn_validate_email_format`
- `fn_validate_logo_before_insert`
- `fn_validate_protocol_requirements`
- `fn_validate_security_port_consistency`
- `fn_validate_transazione_metadata`
- `get_all_participants_travel`
- `get_cliente_detail`
- `get_count_travel_future`
- `get_count_travel_made`
- `get_customer_nationality`
- `get_exist_travel_customer_by_year`
- `get_max_old_year_company`
- `get_mezzo_by_pilot`
- `get_rooms_count`
- `get_totmezzi_dataviaggio`
- `get_travel_passengers`
- `get_viaggio_partecipanti_summary`
- `hash_password`
- `mov_clienti_alloggi_trg1_func`
- `mov_clienti_viaggi_trg1_func`
- `sp_registra_pagamento`
- `sp_resolve_room_violation_park`
- `sync_date_viaggi_azienda_id`
- `trg_ana_clienti_audit_unified`
- `trg_app_users_login_count`
- `trg_app_users_updated_at`
- `trg_check_delete_tipo_avvicinamento`
- `trg_log_clienti_events`
- `trg_log_date_viaggi_events`
- `trg_log_partecipanti_events`
- `trg_log_viaggi_events`
- `trg_mov_clienti_alloggi_audit`
- `trg_mov_clienti_viaggi_audit`
- `trg_prevent_client_delete_alloggi_func`
- `trg_prevent_client_delete_func`
- `trg_user_roles_delete_protection`
- `trg_user_roles_updated_at`
- `trg_web_audit`
- `update_changetimestamp_column`
- `update_modified_column`
- `update_updated_at_column`
- `validate_fiscal_data`
<!-- AUTO-GENERATED-END -->
