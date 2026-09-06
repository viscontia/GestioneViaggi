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
| `fn_ana_aziende_smtp_secrets_get` | Decifra con `pgp_sym_decrypt` (pgcrypto) le password outbound/inbound di una config SMTP puntuale (`ana_aziende_smtp.password_enc` / `inbound_password_enc`, colonne `bytea`). Sostituisce la vecchia lettura inline rotta `password_enc->>'value'` (era JSONB, ora bytea cifrato). Ogni colonna `NULL` restituisce `NULL` senza sollevare eccezioni. | `p_smtp_id uuid, p_master text` | `TABLE(password text, inbound_password text)` | `SqlScripts/483_Smtp_Secrets_Get.sql` |
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
| `sp_ana_viaggi_create` | Crea un nuovo viaggio con tutti i campi obbligatori e opzionali | 23 parametri: `p_viaggio_descrizione_breve VARCHAR(255), p_viaggio_descrizione_estesa TEXT, p_viaggio_numero_giorni INTEGER, p_viaggio_numero_notti INTEGER, p_viaggio_pasti_al_sacco CHAR(1), p_viaggio_num_km INTEGER, p_viaggio_difficolta VARCHAR(20), p_viaggio_incluso TEXT, p_viaggio_escluso TEXT, p_viaggio_capienza_max INTEGER, p_viaggio_capienza_alert INTEGER, p_viaggio_tipo_avvicinamento_fk INTEGER, p_viaggio_note TEXT, p_viaggio_link VARCHAR(500), p_viaggio_nazione_fk INTEGER, p_viaggio_tipo_viaggio_fk INTEGER, p_viaggio_tipo_trattamento_fk INTEGER, p_viaggio_tipo_pernottamento_fk INTEGER, p_azienda_id INTEGER, p_created_by VARCHAR(50), p_created TIMESTAMPTZ, p_updated_by VARCHAR(50), p_updated TIMESTAMPTZ` | `INTEGER` (viaggio_id del record creato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql`, `SqlScripts/467_Blocco13_AnaViaggi_Difficolta.sql`, `SqlScripts/476_AnaViaggi_InclusoEscluso.sql`, `SqlScripts/478_AnaViaggi_Capienza_Trigger.sql` |
| `sp_ana_viaggi_update` | Aggiorna un viaggio esistente | 22 parametri (include `p_viaggio_id`, `p_viaggio_difficolta`, `p_viaggio_incluso`, `p_viaggio_escluso`, `p_viaggio_capienza_max`, `p_viaggio_capienza_alert`) | `VOID` (solleva EXCEPTION se record non trovato) | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/400_Create_SpAnaViaggiCrud.sql`, `SqlScripts/476_AnaViaggi_InclusoEscluso.sql`, `SqlScripts/478_AnaViaggi_Capienza_Trigger.sql` |
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
| `sp_ana_date_viaggi_delete` | Elimina una data viaggio dopo validazione dipendenze. **Guardie (script `507`)**, in ordine: *(a)* **storico aziendale** — rifiuta le partenze segnate come effettuate e quelle con `data_inizio <= CURRENT_DATE` (stesso confine della pubblicabilità: si elimina solo ciò che deve ancora iniziare); *(b)* **contenuti web** — rifiuta se esiste una `web_tour_contenuti`, distinguendo bozza da pubblicato (prima il blocco arrivava dalla FK come eccezione, con messaggio generico e in rosso); *(c)* `mov_clienti_viaggi` e `mov_clienti_alloggi` collegati (controllo preesistente). Restituisce sempre `(deleted, error_message)` senza sollevare eccezioni, così la UI mostra un **avviso** e non un errore. | `p_data_viaggio_id INTEGER` | `TABLE(deleted BOOLEAN, error_message TEXT)` | `Services/CRUD/AnaViaggiService.cs`, `SqlScripts/401_Create_SpAnaDateViaggiCrud.sql`, `SqlScripts/507_SpAnaDateViaggiDelete_Guardie.sql` |

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
| `fn_sys_utente_pref_get` | Legge una preferenza utente "nascosta" (key-value) da `sys_utente_preferenze`; NULL se non impostata | `p_utente_id uuid, p_chiave varchar` | `text` | `Services/CRUD/UserPreferenzeService.cs` |
| `fn_sys_utente_pref_set` | UPSERT di una preferenza utente in `sys_utente_preferenze` (`ON CONFLICT (utente_id, chiave)`) | `p_utente_id uuid, p_chiave varchar, p_valore text` | `void` | `Services/CRUD/UserPreferenzeService.cs` |

`sys_utente_preferenze (utente_id UUID FK→app_users.user_id, chiave VARCHAR(100), valore TEXT, updated_at)`, PK `(utente_id, chiave)`. Nessuna UI CRUD dedicata: preferenza "nascosta" usata per la prima volta dallo slider "dimensione miniature" condiviso tra `WebTourGalleriaTab` e `WebTourPassoEditDialog` (chiave `galleria.thumb_size`). **Script**: `SqlScripts/489_SysUtentePreferenze.sql`.

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

## 8.7. Iscrizione al viaggio (`SqlScripts/551`)

**Fase 4.** `MovClientiViaggiService` non ha **mai** avuto una validazione: solo traduzione in italiano
degli errori del database. Si poteva iscrivere come pilota una persona senza email e nulla lo
impediva — su PROD è successo 9 volte. E i due percorsi di scrittura si comportavano diversamente
sulla stessa tabella: `sp_mov_clienti_viaggi_create` (MAUI) controllava il doppio inserimento e lo
diceva in italiano, `fn_wizard_insert_prenotazione` (sito) inseriva e basta.

| Funzione | Scopo |
| :--- | :--- |
| `fn_mov_clienti_viaggi_valida(dati, [modifica])` | Segnalazioni con gravità **e `riferimento`** |
| `fn_mov_clienti_viaggi_insert(dati, [conferme_accettate])` | Iscrizione |
| `fn_mov_clienti_viaggi_update(dati, [conferme_accettate])` | Aggiornamento parziale |
| `fn_mov_clienti_viaggi_delete(viaggio, data, cliente)` | Cancellazione |

### Perché l'obbligo dell'email sta qui e non su `ana_clienti`

Dipende dal **ruolo** — pilota sì, accompagnatore no — e il ruolo **non è una proprietà della
persona**: sta sull'iscrizione. Su PROD **7 clienti su 687** sono pilota in un viaggio e passeggero in
un altro. Un campo «è un pilota» sull'anagrafica sarebbe giusto per il 99% e **falso in silenzio** su
quei sette. Qui il ruolo si conosce con certezza.

### I dati del mezzo, quando il ruolo li richiede (`SqlScripts/553`)

`ana_tipo_partecipante.tipo_partecipante_dati_mezzo_obb` dichiara, per ogni ruolo, se i dati del mezzo
servono. La colonna esiste da sempre e si può spuntare dall'interfaccia — **e non la leggeva nessuno**:
cercandone gli usi si trovano solo il dialogo che la modifica e la griglia che la mostra. Una regola
scritta nei dati e applicata da nessuna parte, che su PROD aveva lasciato 14 iscrizioni senza mezzo su
ruoli che lo richiedono.

«Dati del mezzo» significa **marca, modello e targa**, e lo dicono i dati: si valorizzano insieme —
su 611 iscrizioni come *pilota mezzo proprio* ne mancano rispettivamente 3, 5 e 4, in pratica le stesse
righe. La segnalazione dice **quale** manca (*«manca la marca, il modello e la targa»*), perché «dati
del mezzo mancanti» costringerebbe a indovinare.

⚠️ Scatta all'inserimento **e alla modifica**: le iscrizioni storiche incomplete non si potranno
modificare senza completare il mezzo. È una bonifica graduale, voluta.

### Il `riferimento`: la segnalazione dice *chi*

`PILOTA_SENZA_EMAIL` restituisce il `cliente_id` nel campo `riferimento`. Serve al client per aprire
la richiesta dell'email **sulla persona giusta**, invece di lasciare l'operatore a cercarla in
anagrafica. L'email si scrive poi con `fn_ana_clienti_update(id, '{"cliente_email":"..."}')`, che la
valida — e il flusso si chiude senza uscire dalla schermata dei partecipanti.

> **Nota (`SqlScripts/552`).** `fn_ana_clienti_valida` anticipa anche i **formati** (email, IBAN,
> minimi di nome e cognome) che i `CHECK` di `541`/`542` impongono comunque. Non è una duplicazione:
> è la stessa regola detta bene. Se l'errore arriva solo dal vincolo, il messaggio è quello grezzo di
> PostgreSQL — che oltre a essere incomprensibile **riversa nel log l'intera riga**, dati personali
> compresi. Visto dal vivo provando il flusso dell'email del pilota.

---

## 8.6. Anagrafiche - Il CRUD unico di `ana_clienti` (`SqlScripts/550`)

**Fase 3 del piano.** «Inserisci un cliente» era implementato **tre volte**:
`ClienteRepository.InsertAsync` (SQL inline, 31 colonne), `sp_ana_clienti_create` (33 colonne, **mai
chiamata da nessuno**) e `fn_wizard_insert_cliente` (23 colonne, usata dal sito — le mancavano foto,
documento, IBAN e note). Nessuna delle tre scriveva consenso e lingua. Qui ce n'è **una sola**.

| Funzione | Scopo |
| :--- | :--- |
| `fn_ana_clienti_valida(dati, [cliente_id])` | Tutte le segnalazioni con la loro gravità, **senza scrivere**. Serve al client per sapere *prima* di salvare |
| `fn_ana_clienti_insert(dati, [conferme_accettate])` | Inserimento. Restituisce il nuovo `cliente_id` |
| `fn_ana_clienti_update(cliente_id, dati, [conferme_accettate])` | Aggiornamento **parziale** |
| `fn_ana_clienti_delete(cliente_id, azienda_id)` | Cancellazione. L'azienda è obbligatoria: è la difesa dei silos |

### I dati passano in JSONB, con i nomi delle colonne come chiavi

Non è pigrizia: sono ~30 campi, e trenta parametri posizionali chiamati da **due linguaggi diversi**
sono un invito a scambiarne due adiacenti — esattamente l'errore che il codice fiscale ci ha fatto
scoprire su tre anagrafiche reali (nome e cognome invertiti). Usando i nomi delle colonne non c'è
nessuna corrispondenza da ricordare, e un campo nuovo domani non costringe ad aggiornare i due client
nello stesso momento.

```sql
SELECT fn_ana_clienti_insert(jsonb_build_object(
  'azienda_fk', 2, 'cliente_titolo_fk', 6,
  'cliente_cognome', 'ROSSI', 'cliente_nome', 'MARIO',
  'cliente_comune_residenza_fk', 70582, 'cliente_comune_nascita_fk', 70582,
  'cliente_data_nascita', '1980-01-01', 'cliente_email', 'mario@example.com',
  'consenso_marketing', true, 'consenso_marketing_fonte', 'SITO_ISCRIZIONE'));
```

Foto e documento viaggiano in **base64**. Il **sesso non è un parametro**: lo porta il titolo
(`SqlScripts/538`). Il **consenso è un parametro dell'inserimento**, non di una chiamata successiva:
va raccolto nel momento in cui l'anagrafica nasce, o non è dimostrabile.

### Aggiornamento parziale

Chiave **assente** = campo invariato. Chiave **presente a null** = campo svuotato. È la differenza che
permette al sito di aggiornare tre campi senza dover rimandare indietro foto e documenti che non ha
mai avuto.

### Validare e scrivere sono due gesti diversi

`fn_ana_clienti_valida` non scrive: il client la chiama per sapere e poter chiedere conferma. Insert e
update **rivalidano comunque**, perché la guardia autoritativa non può stare nel client.

| Gravità | Comportamento della scrittura |
|---|---|
| `ERRORE` | non si salva, mai |
| `CONFERMA` | non si salva **a meno che** il chiamante dichiari di aver chiesto conferma (`p_conferme_accettate`) |
| `AVVISO` | si salva; il client decide se mostrarlo |

Le regole che vivono qui e non in un `CHECK` sono quelle che guardano **l'oggi**, e che PostgreSQL
rifiuterebbe in un vincolo perché `CURRENT_DATE` non è `IMMUTABLE`: data di rilascio non nel futuro,
data di nascita non nel futuro, documento scaduto (avviso), prefisso mancante con un telefono
presente (conferma).

---

## 8.5. Anagrafiche - Gravità e anti-duplicato (`SqlScripts/548`, `549`)

### La gravità: un vocabolario solo per due software

Le funzioni di verifica non restituiscono «valido sì/no» ma **quanto è grave**, perché fra il valido
e il non valido c'è una terza cosa che il progetto conosce già (`DateValidator.MotivoDaConfermare`,
nato col bug delle date: *«non vieta ma chiede conferma»*).

| Gravità | Significato |
|---|---|
| `OK` | nulla da dire |
| `AVVISO` | si segnala, si prosegue senza chiedere niente |
| `CONFERMA` | si chiede «vuoi davvero?», e si può proseguire |
| `ERRORE` | non si salva |

**Sta nel database e non nei client** perché la politica «questo blocca, quello chiede conferma»
dev'essere una sola: scriverla due volte è il modo in cui i controlli si sono sparpagliati finora.

> **Perché `INVERTITI` è `CONFERMA` e non `ERRORE`.** Che un codice fiscale sbagliato corrisponda per
> caso all'anagrafica scambiata è praticamente impossibile, quindi la diagnosi è certa. Ma la
> conclusione no: **i codici fiscali emessi con i campi invertiti esistono**, soprattutto per gli
> stranieri, dove l'ordine nome/cognome del documento d'origine è rovesciato. Un blocco renderebbe
> quella persona non registrabile per sempre. Stessa ragione per `NON_CORRISPONDE`: senza conoscere
> la correzione, un blocco lascerebbe l'operatore con un codice preso da un documento vero e nessun
> modo di registrarlo.

### `fn_ana_clienti_verifica_duplicato` — l'anti-omonimia

| Coincidenza | Gravità | Esito |
|---|---|---|
| Stesso **codice fiscale** | `ERRORE` | `STESSO_CF` |
| Stessi cognome, nome, **data e comune di nascita** | `ERRORE` | `STESSA_ANAGRAFICA` |
| Stessi cognome e nome soltanto | `AVVISO` | `OMONIMO` |

Restituisce **una riga per riscontro, la più grave per prima**. Filtra per azienda (i silos restano
silos) ed esclude la scheda che si sta modificando.

> ⚠️ **Nessuno dei tre livelli richiede il codice fiscale per funzionare.** Era l'errore del controllo
> precedente, racchiuso in `if (DataNascita.HasValue && !IsNullOrWhiteSpace(CodiceFiscale))` e con una
> query che pretendeva pure l'uguaglianza del CF: girava solo sulle schede complete ed era cieco
> proprio su quelle più a rischio — **327 clienti su 778 non avevano il codice fiscale**. Qui il
> codice fiscale, quando c'è, *rafforza* il controllo; quando manca, non lo spegne.

---

## 8.4. Anagrafiche - Codice fiscale: il motore (`SqlScripts/544`)

Fase 1 del piano `docs/plans/2026-08-20-ana-clienti-un-controllo-un-posto-solo.md`.

**Perché sta nel database.** L'algoritmo esisteva **due volte**, in due linguaggi: in
`Validation/Fiscal/CodiceFiscaleValidator.cs` (MAUI, completo di omocodia, con i tre metodi
principali **orfani**) e in `codice_fiscale_utils.py` (sito Flask, in uso). Stesso algoritmo, destini
opposti. E i codici catastali su cui entrambi si appoggiano sono **già qui**, in
`ana_geo_comuni.comune_codfisc`: il database è l'unico posto che li conosce.

| Funzione | Scopo |
| :--- | :--- |
| `fn_cf_calcola(cognome, nome, data_nascita, sesso, comune_id)` | Il codice atteso dall'anagrafica |
| `fn_cf_verifica(cf, [cognome, nome, data, sesso, comune_id])` | Forma · carattere di controllo · corrispondenza · omocodia · **nome e cognome invertiti**. Esito: `MANCANTE`, `FORMA`, `CARATTERE_CONTROLLO`, `FORMA_OK`, `CORRISPONDE`, `OMOCODIA`, **`INVERTITI`** (`SqlScripts/547`), `NON_CORRISPONDE` |
| `fn_cf_decodifica(cf)` | Dal codice all'anagrafica: data di nascita, sesso, comune |
| `fn_cf_omocodia_a_base(cf)` | Riporta a cifre le lettere sostituite per omocodia (posizioni 7, 8, 10, 11, 13, 14, 15) |
| `fn_cf_normalizza` · `fn_cf_consonanti` · `fn_cf_vocali` · `fn_cf_codice_cognome` · `fn_cf_codice_nome` · `fn_cf_carattere_controllo` | Ausiliarie, `IMMUTABLE` |

> ⚠️ **Sugli accenti le due implementazioni esistenti non concordavano.** Python scarta le lettere
> accentate (lista bianca `BCDFGHJKLMNPQRSTVWXYZ`), C# le conta come consonanti (*«è una lettera e non
> è AEIOU»*). Su `NICOLÒ` la prima dà `NCL`, la seconda `NCLÒ`. Qui vale la regola ufficiale:
> l'accento si ripiega sulla vocale base (`À`→`A`), e ciò che non è lettera si ignora
> (`DE LUCA`→`DELUCA`, `D'ANGELO`→`DANGELO`).

**Verifica eseguita il 2026-08-20** su **426 anagrafiche reali di PROD**, confronto a tre fra motore
DB, motore Python e codice fiscale memorizzato:

| | |
|---|---|
| Disaccordi fra motore DB e motore Python | **0** |
| Entrambi ricostruiscono il codice memorizzato | 413 su 426 |
| Codici che non corrispondono all'anagrafica | **13** — non difetti del motore, incoerenze nei dati |

> **`INVERTITI` (`SqlScripts/547`).** Prima di dichiarare che un codice non corrisponde, la funzione
> prova a **scambiare cognome e nome**: se cosi' torna, lo dice — *«Nome e cognome sembrano invertiti:
> il codice fiscale corrisponde leggendo «SCIASCIA» come cognome e «LUCIA» come nome»*. E' un errore
> di digitazione che nessuno vedeva, perche' le due stringhe sono entrambe plausibili e **solo il
> codice fiscale sa quale sia quale**. Resta un errore da correggere (`valido = FALSE`), ma con una
> diagnosi che si risolve in un gesto.

Le 13 in tre famiglie: **3 con nome e cognome invertiti** (dimostrato: scambiando i due campi il
codice torna esatto), **3 con la data di nascita sbagliata** (il codice dice quale è giusta), **4 con
il comune di nascita sbagliato**, **3 da guardare a mano**.

---

## 8.3. Anagrafiche - Titoli Persone (`ana_titolo_persone`)

Lookup **GLOBALE** (nessun `azienda_id`, come tutte le altre del progetto) dei titoli di cortesia.
Ogni titolo porta il proprio sesso: è la **sorgente** di `ana_clienti.cliente_sesso`, che non è più
un campo digitabile. Per questo esistono solo forme di genere non ambigue — `SIG.`/`SIG.RA`,
`DOTT.`/`DOTT.SSA`, `PROF.`/`PROF.SSA`, `AVV.`/`AVV.SSA`, `ING.`/`ING.RA`: una riga valida per
entrambi renderebbe casuale il sesso derivato.

**Perché esiste** (`SqlScripts/538`): il titolo era testo libero scelto da una tendina cablata nel
dialog. Non funzionava — `ClienteService.NormalizeCliente` forzava il maiuscolo al salvataggio
(`Sig.` → `SIG.`) e alla riapertura il valore non corrispondeva più a nessuna voce, quindi il campo
appariva vuoto; i 728 clienti importati da Oracle avevano poi codici (`SIG`, `SRA`) mai presenti in
tendina. Con una FK numerica il maiuscolo non può più rompere il collegamento.

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_ana_titolo_persone_list` | Elenco completo. **`SIG.` e `SIG.RA` forzati in testa, in quest'ordine** (`SqlScripts/540`): sono 741 clienti su 742, e l'alfabetico li seppelliva sotto `AVV.`. Il resto alfabetico. | — | `SETOF ana_titolo_persone` | `Services/CRUD/AnaTitoloPersoneService.cs`, `SqlScripts/538`, `540` |
| `fn_ana_titolo_persone_get` | Singolo titolo per codice. | `p_cod INTEGER` | `SETOF ana_titolo_persone` | idem |
| `fn_ana_titolo_persone_insert` | Crea un titolo. Unicità sulla descrizione (`uq_ana_titolo_persone_descrizione`, su `UPPER()`). | `p_descrizione VARCHAR, p_sesso CHAR` | `INTEGER` (codice) | idem |
| `fn_ana_titolo_persone_update` | Aggiorna descrizione e sesso. **Riallinea anche `cliente_sesso`** di chi porta quel titolo: il trigger su `ana_clienti` scatta solo sulle sue UPDATE. | `p_cod INTEGER, p_descrizione VARCHAR, p_sesso CHAR` | `INTEGER` (righe) | idem |
| `fn_ana_titolo_persone_delete` | Elimina un titolo. **Rifiuta** (P0001, messaggio in italiano) se ci sono clienti che lo portano. | `p_cod INTEGER` | `INTEGER` (righe) | idem |
| `fn_ana_titolo_persone_conta_clienti` | Quanti clienti portano un titolo. Serve alla pagina per **avvisare prima** di chiedere conferma dell'eliminazione: scoprire il blocco dopo «sei sicuro?» è scoprirlo tardi. Il rifiuto di `_delete` resta la guardia autoritativa. | `p_cod INTEGER` | `INTEGER` | `SqlScripts/540`, `Components/Pages/Tabelle/AnaTitoloPersonePage.razor` |
| `fn_ana_titolo_persone_da_testo` | **Ponte di compatibilità** (`SqlScripts/539`): risolve il codice dal vecchio testo libero. Dove testo e sesso si contraddicono **vince il sesso**. Da eliminare insieme alla colonna `cliente_titolo`. | `p_testo VARCHAR, p_sesso CHAR` | `INTEGER` | `SqlScripts/539` |

**Trigger `trg_ana_clienti_sesso_dal_titolo`** (`BEFORE INSERT OR UPDATE ON ana_clienti`,
`SqlScripts/538` e `539`) — è qui che vive l'invariante, non nell'interfaccia, perché `ana_clienti`
si scrive anche dal wizard partecipanti, dagli `sp_ana_clienti_*` e dagli import. Fa tre cose:

1. se manca `cliente_titolo_fk` la ricava dal vecchio testo (`fn_ana_titolo_persone_da_testo`), così
   le nove function che scrivono ancora `cliente_titolo` continuano a funzionare senza modifiche;
2. imposta `cliente_sesso` dal titolo, **da qualunque strada si arrivi**;
3. tiene `cliente_titolo` come specchio della descrizione — non è una seconda verità, serve solo a
   `fn_get_all_clienti`, `fn_get_cliente_by_id`, `fn_get_clienti_export`, `get_cliente_detail` e
   `fn_wizard_leggi_dati_cliente`, che leggono ancora il testo.

> **Sito di iscrizione ai viaggi** (Flask, §12): scrive via `fn_wizard_insert_cliente` /
> `fn_wizard_update_cliente` passando il titolo come testo (`SIG.`, `SIG.RA`, in maiuscolo come tutti
> i suoi campi) e un sesso separato. Continua a funzionare **senza modifiche**: il punto 1 del trigger
> gli assegna la FK, e le sue stringhe coincidono già con le descrizioni della lookup, quindi anche la
> rilettura gli restituisce esattamente ciò che aveva scritto. Verificato il 2026-08-19 su inserimento,
> rilettura e aggiornamento, anche con titolo e sesso in contraddizione fra loro (vince il sesso).

> **Debito dichiarato:** `ana_clienti.cliente_titolo` è **deprecata** dal 2026-08-19. Si elimina dopo
> la verifica in produzione, insieme al punto 1 e 3 del trigger e a `fn_ana_titolo_persone_da_testo`.

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

### 📌 Letture completate DB-first (2026-08-20, `SqlScripts/558`–`560`)

Le funzioni di lettura qui sopra **esistevano dal 2026-03-16 ma nessuno le chiamava**: il
repository si scriveva le SELECT a mano. Questa tabella descriveva quindi un progetto, non il
codice in esecuzione. Da oggi corrisponde alla realta': `Repositories/ClienteRepository.cs`
non contiene piu' nemmeno una SELECT.

Per collegarle sono state completate (`558`) con cio' che il model si aspetta:
`TitoloFk` (la chiave del titolo, non piu' solo il testo deprecato), `Lingua`, `Consenso` e i
comuni annidati `ComuneNascita`/`ComuneResidenza` (`Id`, `Nome`, `ProvinciaDescrizione`) —
costruiti sui join che nelle funzioni **c'erano gia'**, inutilizzati.

⚠️ La foto e il documento viaggiano **solo** nel dettaglio: `fn_get_all_clienti` non li porta,
e non deve iniziare a portarli (169 clienti pesano 189 kB senza).

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_get_cliente_detail` | Dettaglio cliente per sola chiave. **Delega** a `fn_get_cliente_by_id` prendendo l'azienda dal cliente stesso: la forma del JSON resta definita in un punto solo | `p_cliente_id INT` | `JSON` | `Repositories/ClienteRepository.cs` (GetDetailAsync), `Components/Shared/TravelStatsDialog.razor` |
| `fn_get_cliente_by_email` | Cliente per email nel silos dell'azienda. Delega a `fn_get_cliente_by_id`. **`ORDER BY cliente_id`**: l'email non e' univoca (le coppie condividono la casella), prima quale scheda tornasse era arbitrario | `p_email VARCHAR, p_azienda_fk INT` | `JSON` (NULL se assente) | `Repositories/ClienteRepository.cs` (GetByEmailAsync) |
| `fn_get_cliente_by_codice_fiscale` | Come sopra, per codice fiscale | `p_codice_fiscale VARCHAR, p_azienda_fk INT` | `JSON` (NULL se assente) | `Repositories/ClienteRepository.cs` (GetByCodiceFiscaleAsync) |
| `fn_cliente_ha_iscrizioni` | Guardia alla cancellazione: il cliente ha iscrizioni a viaggi? Filtra per azienda passando da `ana_clienti` — il C# il parametro lo riceveva e **non lo usava** | `p_cliente_id INT, p_azienda_fk INT` | `BOOLEAN` | `Repositories/ClienteRepository.cs` (HasRelatedBookingsAsync) |
| `fn_cliente_ha_alloggi` | Come sopra per gli alloggi; copre tutte e sei le colonne `cliente_idN_fk` | `p_cliente_id INT, p_azienda_fk INT` | `BOOLEAN` | `Repositories/ClienteRepository.cs` (HasRelatedAccommodationsAsync) |

### 🧭 Avviso nome/sesso (`SqlScripts/561`, `562`)

La regola che segnala «SIG. + FRANCESCA» viveva **solo in C#**, in
`Validation/Semantic/CoerenzaNomeSessoValidator.cs`, con la lista dei nomi maschili in -a scritta
nel codice. Chi si registrava dal sito quel controllo non ce l'aveva: la stessa persona, due
comportamenti diversi a seconda della porta da cui entrava.

| Oggetto | Cosa fa |
| :--- | :--- |
| `ana_nomi_maschili_in_a` (tabella, **GLOBALE**) | Le eccezioni: ANDREA, LUCA, NICOLA, ELIA, MATTIA, ENEA, ISAIA, GEREMIA, ZACCARIA, BATTISTA, EVANGELISTA, COSMA + i composti attaccati. È lingua italiana, non politica commerciale: non è per azienda. Sta in tabella e non nel codice della funzione perché è un dato che cambia, e non deve servire un rilascio per aggiungere un nome |
| `fn_nome_sesso_avviso(p_nome VARCHAR, p_sesso CHAR)` → `TEXT` | Il messaggio d'avviso, o `NULL` se non c'è nulla da segnalare. Guarda **l'ultima parola** del nome: «GIUSEPPE MARIA» è maschile, «MARIA» da sola no |
| `fn_ana_clienti_valida` (esteso) | Restituisce l'avviso come `AVVISO`/`NOME_SESSO`. È la porta comune: da qui lo ricevono sia il gestionale (`ValidaAsync`) sia il sito (`/api/cliente/valida`) |

Senza la lista l'avviso sarebbe **dannoso**: misurato sui clienti reali scattava 53 volte su 53 a
torto, e 38 erano Andrea e Luca. Un avviso che sbaglia sempre insegna solo a ignorarlo.

Resta un **avviso**, mai un blocco.

---

## Cercare invece di filtrare (`SqlScripts/570`, `571`)

Tre elenchi cercano ormai nel database invece di filtrare la lista già letta — **clienti**
(`fn_search_clienti`), **viaggi** (`fn_ana_viaggi_get_all`, parametro `p_search_text`) e
**controparti** (`fn_ana_controparti_get_all`). Il criterio non è la dimensione della lista ma
**quante persone la scrivono**: se due utenti inseriscono fornitori nello stesso momento, quello
appena scritto dal collega nella lista aperta non c'è, e nessun filtro a valle può trovarlo.

| Funzione | Cerca su |
| :--- | :--- |
| `fn_search_clienti(azienda, testo)` | cognome, nome, email, codice fiscale, telefono |
| `fn_ana_viaggi_get_all(…, p_search_text)` | descrizione, nazione, tipo di viaggio, trattamento |
| `fn_ana_controparti_get_all(azienda, solo_fornitori, solo_clienti, testo)` | ragione sociale, nome breve, email, partita IVA, tipo fornitore |

Il `571` non nasce però solo per la ricerca: `ContropartiService.GetAllAsync` **costruiva la query
in C# concatenando stringhe**, filtro azienda compreso —
`sql += $" AND c.azienda_fk = {currentAziendaId.Value}"`. Oltre a violare il DB-first, significava
che **il confine fra i silos delle aziende era scritto con un'interpolazione di stringa**: regge
perché quel valore è un intero, ma non è una riga che si vuole trovare in un audit. Ora è un
parametro come tutti gli altri.

`fn_ana_viaggi_get_all` accetta un parametro in più, **`p_search_text`**, che filtra su
descrizione, nazione, tipo di viaggio e trattamento — gli stessi campi su cui filtrava la griglia
in memoria. In ufficio il gestionale lo usano più persone insieme: un viaggio inserito poco fa da
un collega nella lista già letta non c'è, e nessuna ricerca a valle può trovarlo.

Non è nata una `fn_search_viaggi` separata: avrebbe dovuto ricopiare per intero questa SELECT, con
i suoi sei join e i suoi trentacinque campi, diventando la solita seconda copia da tenere allineata.

> ⚠️ **Aggiungere un parametro a una funzione esistente richiede il `DROP` della vecchia firma.**
> `CREATE OR REPLACE` con un argomento in più non sostituisce nulla: crea un **secondo overload**, e
> da quel momento la chiamata con gli argomenti di prima diventa ambigua — *«could not choose a best
> candidate function»* — cioè il software smette di leggere. È la stessa famiglia dell'inciampo di
> `544`/`547` annotato nella Checklist Go-Live, ed è per questo che il `570` comincia con un
> `DROP FUNCTION IF EXISTS` sulla firma a quattro parametri.

---

## Documento valido *per quel viaggio* (`SqlScripts/574`–`576`)

Nessuno controllava che il documento di un partecipante fosse valido **alla data del viaggio**.
Le conseguenze non sono informatiche: all'estero non si parte affatto, in Italia l'albergo può
rifiutare la registrazione — dove i documenti di tutti gli occupanti si presentano per legge.

Due precisazioni che cambiano il controllo, e che valgono più della sua implementazione:

1. **Non conta «scaduto oggi», conta «scaduto alla fine del viaggio».** Un documento che scade il
   20 ottobre è validissimo adesso e non serve a niente per una partenza che rientra il 24.
2. **Non basta controllare all'iscrizione.** Ci si iscrive mesi prima: un documento valido a giugno
   può essere scaduto a ottobre. Il controllo va rifatto guardando la **partenza**, il giorno in cui
   serve.

```
fn_documento_stato_per_viaggio(scadenza, inizio, fine)   ← la regola, e nient'altro
     ├── fn_partecipanti_documento_non_valido(partenza)  → lista partecipanti, stampe
     └── fn_mov_clienti_viaggi_valida(...)               → iscrizione
```

| Funzione | Cosa restituisce |
| :--- | :--- |
| `fn_documento_stato_per_viaggio` | `MANCANTE` · `SCADUTO` · `SCADE_DURANTE` · `VALIDO`, col messaggio già scritto |
| `fn_partecipanti_documento_non_valido` | chi di quella partenza non è a posto, **con email e telefono** per avvisarlo, e il flag `viaggio_estero` |

**All'iscrizione la gravità dipende dalla destinazione** (deciso il 2026-09-02): all'**estero**
`ERRORE` — iscrivere qualcuno a un viaggio che non potrà fare non è un servizio; in **Italia**
`AVVISO`. Nazione non indicata = si assume estero: è il caso più severo, e sui documenti di chi
parte non si tira a indovinare.

---

## Il filtro azienda è un parametro, non una stringa (`SqlScripts/571`, `572`)

`fn_ana_controparti_get_all` e `fn_ana_aziende_get_all` sostituiscono due query che i servizi C#
costruivano concatenando stringhe, **filtro azienda compreso**:

```csharp
sql += $" AND c.azienda_fk = {currentAziendaId.Value}";   // ContropartiService
sql += $" AND a.azienda_id = {currentAziendaId.Value}";   // AziendaService
```

L'invariante che tiene separate le aziende ([[multitenancy-invariant-silos]]) dipendeva da come
veniva incollata una stringa. Non c'era un buco sfruttabile — quei valori sono interi presi dalla
sessione — ma non è una riga che si vuole trovare in un audit. In entrambe le funzioni
**`NULL` vale «tutte le aziende»**, ed è il caso del SuperAdmin: la decisione sta nel chiamante, il
confine nel database.

> Cercati apposta in tutto il gestionale dopo il primo ritrovamento: i punti erano **due**, e sono
> stati chiusi entrambi. Rimossi anche i **generatori di frammenti SQL per tenant**
> (`TenantContext.GetTenantFilterSqlAsync` e i due metodi di `BaseCrudService` che lo avvolgevano):
> non li chiamava nessuno, ma erano un invito a rifare la stessa cosa. **Il filtro azienda si passa
> come parametro a una funzione del database, punto.**

---

## I campi obbligatori dell'anagrafica (`SqlScripts/563`)

Deciso il 2026-08-31. I dati del documento d'identità servono a **ogni** partecipante, non solo a
chi guida: alla registrazione in albergo si presentano per legge i documenti di tutti gli occupanti
della stanza. L'obbligo quindi non è una regola di ruolo, e non poteva restare nei `[Required]` del
modello C#, che il sito di iscrizione non vede.

| Oggetto | Cosa fa |
| :--- | :--- |
| `fn_ana_clienti_campi_mancanti(p_dati JSONB, p_pilota BOOLEAN)` → `TABLE(campo VARCHAR, etichetta TEXT)` | Una riga per ogni dato obbligatorio assente. Il **codice** (`DOC_NUMERO`) serve al gestionale per illuminare il campo, l'**etichetta** («il numero del documento») per scrivere una frase leggibile. Prende un JSONB e non un `cliente_id` perché deve giudicare anche dati non ancora salvati |
| `fn_ana_clienti_valida` (esteso) | Emette un `ERRORE` **per ogni campo**, con esito `MANCA_<CAMPO>`. Separati e non riuniti in una frase sola perché il gestionale li rimappa sul campo: un elenco unico direbbe cosa manca, non dove |
| `fn_mov_clienti_viaggi_valida` (esteso) | Rilegge la scheda del cliente e la giudica con la **stessa** funzione, emettendo un solo `ERRORE`/`ANAGRAFICA_INCOMPLETA` con l'elenco. Blocca l'iscrizione |

**Obbligatori per tutti:** titolo, cognome, nome, data e comune di nascita, comune e indirizzo di
residenza, e i cinque del documento (tipo, numero, ente, rilascio, scadenza).

**Solo per il pilota** (`p_pilota = TRUE`): prefisso internazionale e telefono. È l'unica parte che
dipende dal ruolo, accanto all'email (`PILOTA_SENZA_EMAIL`) e ai dati del mezzo. Un passeggero che
non lascia il proprio numero sta facendo una scelta legittima, non nascondendo un dato.

Il controllo all'iscrizione **non è un doppione** di quello sull'anagrafica: intercetta le schede
storiche, quelle che nessuno ha più aperto da quando la regola non c'era, e che non sono mai passate da un
salvataggio con le regole di oggi. Sul DB **locale di prova** erano 578 su 742 al 2026-08-31; su
PROD il numero è da misurare, ed è quello a dire quanto sanamento comporta.

---

### 🗑️ Elenco di ritiro — da eseguire al go-live, non prima

Queste funzioni non hanno più chiamanti, ma restano nel database finché non si è verificato che
nessun altro software le usi. Eliminarle prima significherebbe rompere qualcosa senza saperlo.

| Oggetto | Sostituito da | Perché resta in piedi |
| :--- | :--- | :--- |
| `get_cliente_detail` | `fn_get_cliente_detail` | La vecchia TABLE a 41 colonne, ferma al titolo testuale |
| `sp_ana_clienti_create` / `_update` / `_delete` | `fn_ana_clienti_insert` / `_update` / `_delete` | Erano scritte e **non collegate a nessuno** già prima di questo lavoro |
| `fn_wizard_get_smtp_config` | `fn_get_smtp_config_for_email` | Seconda copia rimasta indietro rispetto alla cifratura: leggeva `password_enc->>'value'` su una colonna `bytea`. Era **rotta**, non solo doppia |
| `fn_wizard_insert_cliente` / `_update_cliente` | il CRUD canonico | Il sito ora chiama le funzioni comuni |
| `fn_wizard_check_cf_esistenza`, `fn_wizard_find_email_by_anagrafica`, `fn_wizard_find_email_by_cf` | `fn_ana_clienti_verifica_duplicato` | Tre controlli parziali sostituiti da uno a quattro livelli |

**Rimosso invece dal codice C#** (agosto 2026), perché lì il ritiro è immediato e verificabile dal
compilatore: `CoerenzaNomeSessoValidator` per intero; da `CodiceFiscaleValidator` i tre metodi che
calcolavano il codice atteso, l'omocodia e il confronto con l'anagrafica (la seconda copia
dell'algoritmo, ~265 righe); da `ClienteValidator` nove metodi senza chiamanti.

---

**Da ritirare al go-live, non prima:** `get_cliente_detail` (la vecchia TABLE a 41 colonne) resta
nel database ma non ha piu' chiamanti in MAUI. Va eliminata solo dopo aver verificato che nessun
altro software la usi. Stessa sorte per `sp_ana_clienti_create/_update/_delete`, sostituite da
`fn_ana_clienti_insert/_update/_delete`.

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

Ruolo di sola lettura per il traffico pubblico del sito (equivalente locale dell'`anon` di Supabase): `NOLOGIN`, non superuser, **subisce le RLS** (`rolbypassrls=f`). Ha solo `USAGE` su `schema public`; i `GRANT` specifici (di colonna) e le policy vivono negli script del Blocco 3 (`SqlScripts/450`–`453`, vedi sezione dedicata). **Script**: `SqlScripts/406_Setup_RoleAnon.sql`.

### Tabella `web_tipi_viaggio_descrizioni` — descrizioni web dei tipi di viaggio (GLOBALE, Blocco 8)

Lookup **globale** (ex `web_categorie_sport`, reshaped nel Blocco 8) delle descrizioni pubbliche dei tipi di viaggio (es. "Viaggi 4x4", "Enduro"). N righe di `ana_tipo_viaggi` puntano alla stessa descrizione via `ana_tipo_viaggi.descrizione_web_fk` → evita testo libero ripetuto sui tipi (3NF / niente falsi raggruppamenti). Globale come `ana_tipo_viaggi` (nessun `azienda_id`), il che risolve anche l'incoerenza multi-tenant di una FK su riga globale verso categoria per-azienda.

- **Colonne**: `web_tipi_viaggio_descrizioni_id` (PK identity), `descrizione_web` VARCHAR(50) NOT NULL, `slug` VARCHAR(50) NOT NULL, `ordine` INTEGER, più coda audit `created_by/created/updated_by/updated`.
- **Vincoli**: unique **globale** `(slug)`.
- **Audit/RLS**: trigger `trg_web_tipi_viaggio_descrizioni_audit` (`trg_web_audit()`); RLS `anon_read_all` (SELECT anon) + `superadmin_bypass_all`.
- **FK a monte**: `ana_tipo_viaggi.descrizione_web_fk → web_tipi_viaggio_descrizioni(...)` ON DELETE SET NULL.
- **Script**: reshape in-place `SqlScripts/459_Reshape_WebCategorieSport_To_TipiViaggioDescrizioni.sql` (rename tabella/colonne, drop `azienda_id`/`codice`, unique globale su slug).

### Funzioni CRUD web — `fn_web_tipi_viaggio_descrizioni_*` (Blocco 8, GLOBALI)

CRUD **senza** `p_azienda_id` (tabella globale). **Script**: `SqlScripts/460_Create_FnWebTipiViaggioDescrizioni_Crud.sql`.

- **`fn_web_tipi_viaggio_descrizioni_insert(p_descrizione_web, p_slug, p_ordine DEFAULT 0)` → `BIGINT`**.
- **`fn_web_tipi_viaggio_descrizioni_list()` → `SETOF`** — tutte, ordinate per `ordine, descrizione_web`.
- **`fn_web_tipi_viaggio_descrizioni_get(p_id)` / `_update(p_id, p_descrizione_web, p_slug, p_ordine)` → `INTEGER` / `_delete(p_id)` → `INTEGER`**.
- Esposta al sito da **`fn_web_tour_pubblicati`** come `descrizione_web`/`descrizione_slug` (join via `ana_tipo_viaggi.descrizione_web_fk`), script `461`.

**Convenzione CRUD web (valida per le entità per-azienda; eccezione: `web_tipi_viaggio_descrizioni` è GLOBALE, senza `p_azienda_id`):** ogni funzione prende `p_azienda_id` ed è scoped su di esso (`WHERE ... AND azienda_id = p_azienda_id`) → isolamento multi-tenant totale, un'azienda non può leggere/modificare/eliminare righe di un'altra. `SECURITY INVOKER` (default, mai `SECURITY DEFINER`). Le colonne di audit (`created/created_by/updated/updated_by`) **non** sono mai passate: le valorizza il trigger `trg_web_audit()` dalla GUC `my.app_user`. `insert` ritorna il nuovo id; `update`/`delete` ritornano il numero di righe interessate (0/1). Le unique violation (23505) **non** sono gestite: propagano e vengono tradotte da `DbErrorTranslator` lato C#.

### Funzioni CRUD cluster tour web — `fn_web_tour_*` (Blocco 2)

Set CRUD standard per le 5 entità del cluster contenuti tour (stessa convenzione web sopra). `insert(p_azienda_id, …)`/`get(p_id, p_azienda_id)`/`update(p_id, p_azienda_id, …)`/`delete(p_id, p_azienda_id)` per tutte; la scoping della `list`/`get_by_viaggio` cambia per entità:

- **`fn_web_tour_contenuti_*`** (`SqlScripts/432`) — 1:1 col viaggio. Oltre a `list(p_azienda_id)` (tutta l'azienda), c'è **`fn_web_tour_contenuti_get_by_viaggio(p_viaggio_id, p_azienda_id)`** (la UI carica per viaggio, 1:1). insert/update gestiscono le colonne editabili (sottotitolo, `*_html`, difficolta, durata_testo, luoghi_visitati, slug, meta SEO, stato_pubblicazione, ordine, data_pubblicazione, viaggio_id_fk).
- **`fn_web_tour_itinerario_*`** (`SqlScripts/433`) — N giornate per viaggio. **`fn_web_tour_itinerario_list(p_viaggio_id, p_azienda_id)`** ordinata per `giorno_numero, ordine`. Colonne: viaggio_id_fk, giorno_numero, titolo_giornata, ordine.
- **`fn_web_tour_itinerario_reorder(p_azienda_id, p_viaggio_id_fk, p_ids BIGINT[])`** (`SqlScripts/454`, Blocco 6) — riordino atomico delle giornate: la posizione nell'array (`UNNEST WITH ORDINALITY`) diventa il nuovo `giorno_numero`/`ordine`. Scoped per azienda+viaggio. Ritorna righe aggiornate.
- **`fn_web_tour_itinerario_passaggi_*`** (`SqlScripts/434`) — N passaggi per giornata. **`fn_web_tour_itinerario_passaggi_list(p_itinerario_id BIGINT, p_azienda_id)`** ordinata per `ordine`. Colonne: itinerario_id_fk, testo_html, immagine (url/storage_path/didascalia), ordine.
- **`fn_web_tour_itinerario_passaggi_reorder(p_azienda_id, p_itinerario_id_fk BIGINT, p_ids BIGINT[])`** (`SqlScripts/455`, Blocco 6) — riordino atomico dei passi di UNA giornata: ogni id è (ri)assegnato a `p_itinerario_id_fk` (gestisce lo spostamento **cross-day**) con `ordine` = posizione nell'array. Scoped per azienda. Chiamare per la zona di arrivo e di partenza su un cross-day. Ritorna righe aggiornate.
- **`fn_web_tour_immagini_*`** (`SqlScripts/435`) — N immagini per viaggio. **`fn_web_tour_immagini_list(p_viaggio_id, p_azienda_id)`** ordinata per `tipo, ordine`. Colonne: viaggio_id_fk, tipo, url, storage_path, alt_text, titolo, larghezza, altezza, mime, ordine. `tipo IN ('principale','galleria')`; indice unique parziale `uq_web_tour_immagini_principale UNIQUE(viaggio_id_fk) WHERE tipo='principale'` (una sola copertina per viaggio).
- **`fn_web_tour_immagini_reorder(p_azienda_id, p_viaggio_id_fk, p_ids BIGINT[])`** (`SqlScripts/457`, Blocco 7) — riordino atomico `ordine` via UNNEST WITH ORDINALITY. Nessun unique su `ordine` → niente deferrable. Ritorna righe aggiornate.
- **`fn_web_tour_immagini_set_principale(p_id, p_azienda_id, p_viaggio_id_fk)`** (`SqlScripts/458`, Blocco 7) — imposta la copertina. **Due pass** nella stessa transazione (retrocedi l'eventuale principale → promuovi la target): l'indice unique parziale non è deferrable, un singolo UPDATE con CASE lo violerebbe transitoriamente. Ritorna 1 se la target è stata promossa.
- **`web_tour_immagini.nome_file VARCHAR(255)`** (`SqlScripts/487`) — nome originale del file caricato (`IBrowserFile.Name`), usato lato UI per il dedup upload (stessa foto ricaricata per lo stesso contenuto → skip con warning, confronto case-insensitive in memoria sulla lista già caricata). Nullable, nessun backfill sulle righe esistenti. `fn_web_tour_immagini_insert`/`fn_web_tour_immagini_update` hanno un nuovo parametro finale `p_nome_file VARCHAR DEFAULT NULL` (firma precedente droppata con `DROP FUNCTION` esplicito, vedi convenzione Blocco 13).
- **`fn_web_immagini_in_uso(p_contenuto_id BIGINT, p_azienda_id INTEGER)`** (`SqlScripts/488`, Blocco 7) — `RETURNS TABLE(storage_path VARCHAR)`: storage_path distinct delle immagini referenziate da un passaggio dell'itinerario (`web_tour_itinerario_passaggi.immagine_storage_path`, **nessuna FK** verso `web_tour_immagini` — legame debole per valore di `storage_path`) di un contenuto (join `web_tour_itinerario_passaggi.itinerario_id_fk → web_tour_itinerario.web_tour_itinerario_id → web_tour_itinerario.web_tour_contenuti_id_fk`). Usata lato UI per disabilitare preventivamente il pulsante "Elimina" sulle foto in uso.
- **`fn_web_tour_immagini_delete`** (aggiornata da `SqlScripts/488`) — ora **blocca** l'eliminazione (RAISE EXCEPTION ERRCODE `P0001`, "Immagine in uso in un passaggio dell'itinerario: non eliminabile.") se lo `storage_path` dell'immagine risulta usato in un passaggio dell'itinerario (stessa join di `fn_web_immagini_in_uso`, scoped per azienda). Difesa DB anche se la UI non pre-controlla.
- **`fn_web_tour_stato_sezioni(p_contenuto_id BIGINT, p_azienda_id INTEGER, p_lingue VARCHAR[])`** (`SqlScripts/492`) — `RETURNS TABLE(ha_slug, ha_sottotitolo, ha_descrizione BOOLEAN, n_immagini INTEGER, ha_principale BOOLEAN, n_giornate INTEGER, n_traducibili, n_tradotte INTEGER)`: **fatti grezzi** per il semaforo dei sotto-tab di `WebEdizioniManager`, in **una sola query**. Serve perché `MudTabs` non tiene vivi i pannelli (`KeepPanelsAlive=false`): all'apertura del dialog i sotto-tab non visitati non esistono e non possono notificare il proprio stato, quindi restavano tutti "Vuoto" (gialli) anche se completi — e con essi il pulsante Anteprima e il gating di pubblicazione. `n_traducibili` conta i campi valorizzati traducibili replicando `WebTraduzioneOrchestratorService.GetTranslatableItemsAsync` (campi di `web_tour_contenuti` + `ana_viaggi.viaggio_incluso`/`viaggio_escluso` + `testo_html` dei passi); il test "valorizzato" è `~ '[^[:space:]]'` per equivalere a `string.IsNullOrWhiteSpace`. Le **soglie** Vuoto/Parziale/Completo NON sono in SQL: restano in C# (`Models/Web/WebTabStato.cs` → `WebTabStatoRules`), condivise tra il prefetch del manager e i sotto-tab. Scoped per azienda; 0 righe se il contenuto non esiste o è di altra azienda. Se si aggiunge/toglie un campo traducibile in C#, aggiornare anche questa funzione.
- **`fn_web_tour_mappa_*`** (`SqlScripts/436`, ri-ancorate al contenuto dal Blocco 13, **multiple** da `SqlScripts/494`) — colonne: web_tour_contenuti_id_fk, gpx (originale/filename/**bytes**), bbox `NUMERIC`, provider, stile, `parametri_render JSONB`, immagine (url/storage_path), data_generazione, **web_tour_itinerario_id_fk**, **descrizione**.
  - **Mappe multiple per edizione** (`SqlScripts/493`): ogni mappa è o dell'**intero viaggio** (`web_tour_itinerario_id_fk IS NULL`, descrizione obbligatoria) o di **una giornata** dell'itinerario. I GPX che coprono porzioni di giornata sono esclusi **dal DB**: `uq_web_tour_mappa_giornata` (una mappa per giornata), `uq_web_tour_mappa_insieme` (una sola mappa d'insieme per edizione, indice parziale), `ck_web_tour_mappa_descrizione_insieme` (usa `COALESCE(descrizione,'')`: senza, con NULL il CHECK varrebbe NULL e passerebbe), `uq_web_tour_mappa_gpx_dedup` su `(contenuto, lower(gpx_filename), gpx_bytes)` (stesso GPX non ricaricabile). La FK verso la giornata è **composita** `(web_tour_itinerario_id_fk, web_tour_contenuti_id_fk)` → `web_tour_itinerario(web_tour_itinerario_id, web_tour_contenuti_id_fk)`: una FK sul solo id permetterebbe di abbinare la mappa a una giornata di un'**altra** edizione. `ON DELETE RESTRICT` (eliminare una giornata con mappa è bloccato: altrimenti sparirebbe una mappa generata lasciando il WebP orfano nel bucket). Messaggi in italiano in `DatabaseExceptionHelper`.
  - **`fn_web_tour_mappa_list_by_contenuto(p_contenuto_id BIGINT, p_azienda_id)`** — elenco di una edizione, ordinato: prima l'insieme, poi le giornate per `giorno_numero`. Nessun campo `ordine`: l'ordinamento discende dall'abbinamento.
  - **`fn_web_tour_mappa_get_by_contenuto(p_contenuto_id, p_azienda_id)`** — ora ritorna **solo la mappa dell'intero viaggio** (con N mappe la vecchia semantica sarebbe ambigua); **`fn_web_tour_mappa_get_by_giornata(p_itinerario_id, p_azienda_id)`** ritorna quella di una giornata.
  - `insert`/`update` hanno tre parametri nuovi **in coda** (`p_web_tour_itinerario_id_fk`, `p_descrizione`, `p_gpx_bytes`); firme precedenti droppate esplicitamente (convenzione Blocco 13) per non lasciare overload ambigui (42883).

### Funzioni CRUD traduzioni + newsletter — `fn_web_traduzioni_*`, `fn_web_newsletter_*` (Blocco 2)

Stessa convenzione CRUD web (scoping `p_azienda_id`, audit da trigger, 0/1 su update/delete):

- **`fn_web_traduzioni_*`** (`SqlScripts/437`) — CRUD standard + **`fn_web_traduzioni_list_by_entita(p_entita, p_entita_id, p_azienda_id)`** (tutte le lingue/campi di un'entità).
- **`fn_web_traduzioni_upsert(p_azienda_id, p_entita, p_entita_id, p_campo, p_lingua, p_testo)` → `BIGINT`** (`SqlScripts/462`, Blocco 10) — upsert su unique `(entita,entita_id,campo,lingua)`; ri-tradurre resetta i flag (`tradotto_auto=true, revisionato=false, obsoleto=false`, `data_traduzione=now`).
- **`fn_web_traduzioni_marca_obsolete(p_azienda_id, p_entita, p_entita_id, p_campo)` → `INTEGER`** (`SqlScripts/462`, Blocco 10) — marca `obsoleto=true` tutte le lingue del campo quando l'IT sorgente cambia (per-azienda).
- **`fn_web_traduzioni_marca_obsolete_global(p_entita, p_entita_id, p_campo)` → `INTEGER`** (`SqlScripts/464`, Blocco 10) — come sopra ma **senza filtro azienda**, per entità globali (es. `web_tipi_viaggio_descrizioni.descrizione_web`): l'unique di `web_traduzioni` ignora l'azienda.
- **`fn_ana_aziende_get_claude_key(p_azienda_id)` / `fn_ana_aziende_set_claude_key(p_azienda_id, p_key)`** (`SqlScripts/463`, Blocco 10) — get/set della chiave Claude per-azienda (`ana_aziende.claude_api_key`, in chiaro → cifrare pre-rilascio).
- **`fn_web_newsletter_iscritti_*`** (`SqlScripts/438`) — CRUD standard + **`fn_web_newsletter_iscritti_by_token(p_token)`** (lookup per link di disiscrizione, senza azienda: il token è il segreto).
- **`fn_web_newsletter_invii_*`** (`SqlScripts/439`), **`fn_web_newsletter_invii_destinatari_*`** (`SqlScripts/440`, list per `p_invio_id`), **`fn_web_newsletter_soppressioni_*`** (`SqlScripts/441`) — CRUD standard.
- **Chi marca l'obsolescenza dei testi newsletter.** Le traduzioni non si invalidano da sole: sono le funzioni di update a chiamare `fn_web_traduzioni_marca_obsolete`, **prima** della UPDATE (l'ordine conta, vedi `SqlScripts/536`).
  - `fn_web_newsletter_blocchi_update` (`SqlScripts/536`) → i 5 campi del blocco (`titolo`, `sottotitolo`, `corpo_html`, `link_etichetta`, `immagine_alt`), ognuno col proprio confronto `IS DISTINCT FROM`.
  - `fn_web_newsletter_invii_update` (`SqlScripts/537`) → il campo `oggetto`. **Mancava fino al 2026-08-18:** l'oggetto veniva riscritto lasciando valide le traduzioni del testo precedente, e la newsletter partiva con l'oggetto vecchio tradotto per i destinatari stranieri e quello nuovo per gli italiani. Il confronto protegge il motore d'invio, che chiama la stessa funzione con l'oggetto invariato per aggiornare stato/data/destinatari.
  - Aggiungendo un campo traducibile a queste tabelle, va aggiunto qui il suo confronto: senza, il campo si traduce ma non si invalida mai.

### Funzioni CRUD config per-azienda — `fn_web_aziende_funzioni_*`, `fn_ana_aziende_esp_*` (Blocco 2)

Stessa convenzione CRUD web. Completano le CRUD del 1° rilascio:

- **`fn_web_aziende_funzioni_*`** (`SqlScripts/442`) — `insert(p_azienda_id, p_funzione, p_attiva DEFAULT false, p_parametri JSONB DEFAULT NULL)`, `list`, `get`, `update`, `delete` + **`fn_web_aziende_funzioni_get_by_funzione(p_azienda_id, p_funzione)`** (lookup del toggle per chiave logica `(azienda, funzione)`). Il JSONB `parametri` è ora usato da `WebAziendeFunzioniService` (insert/update/map) — vedi §A.4 recensioni.
- **`fn_web_recensioni_config(p_azienda_id) → JSONB`** (§A.4, `SqlScripts/481`, **SECURITY DEFINER**, `EXECUTE` a `anon`) — ritorna il JSONB `parametri` della riga `funzione='recensioni'` **solo se `attiva`**, altrimenti `NULL`. Config per-azienda delle schede recensioni (es. `{"google_place_id":"…","tripadvisor_url":"…"}`) impostata dal tab **Funzioni Web** (`WebAziendeFunzioniService.Save/GetRecensioniConfigAsync`). Nessuna tabella recensioni interna: il sito (Fase 3) usa le schede Google/TripAdvisor. SECURITY DEFINER perché `web_aziende_funzioni` è multi-tenant e `anon` non vi accede direttamente; la funzione espone solo gli identificativi pubblici quando la funzione è attiva.
- **`fn_ana_aziende_esp_*`** (`SqlScripts/443`) — `insert(p_azienda_id, p_provider, p_api_key_enc JSONB, p_sender_email, p_sender_name, p_sender_domain, p_attivo DEFAULT false)`, `get`, `update`, `delete` + **`fn_ana_aziende_esp_get_by_azienda(p_azienda_id)`** (relazione 1:1 → 0/1 righe; niente `list`). `p_api_key_enc` arriva **già cifrata** dall'app (pattern `password_enc`).

### Consumi Claude e soglia di spesa (`SqlScripts/500`)

L'API Anthropic **non espone il credito residuo** di una chiave (nessun endpoint di saldo; l'Admin API riporta consumi e costi, non il residuo, e richiede una chiave di organizzazione). Il consumo si conta quindi lato gestionale: ogni risposta Messages include già il blocco `usage` con i token, che prima veniva scartato — tracciarlo **non costa chiamate né crediti**. ⚠️ Il totale è una **stima dei consumi di questo gestionale**: se la stessa chiave è usata altrove, quel consumo non compare.

- **`web_ai_consumi`** — una riga per chiamata: `modello`, `contesto` (es. "Descrizione (EN)"), `input_tokens`, `output_tokens`, `costo_stimato NUMERIC(12,6)`, `valuta`. Il costo è **congelato all'inserimento** con i prezzi allora configurati (`ClaudeOptions.PrezzoInputPerMilione`/`PrezzoOutputPerMilione`, sezione `Claude` in appsettings): così lo storico resta corretto anche se il listino cambia.
- **`web_ai_config`** — per azienda: `soglia_spesa` (NULL = nessun avviso), `conteggio_da` (da quando contare ai fini della soglia), `avvisato_il`.
- **`fn_web_ai_consumo_insert(...)`** / **`fn_web_ai_consumo_riepilogo(p_azienda_id, p_da)`** — registrazione e totali (chiamate, token, costo, ultima chiamata).
- **`fn_web_ai_config_get`/`fn_web_ai_config_set(p_azienda_id, p_soglia, p_riparti)`** — `p_riparti=true` sposta `conteggio_da` a ora (nuova ricarica). Cambiare la soglia **riarma** l'avviso, altrimenti alzando il tetto non si verrebbe più avvisati.
- **`fn_web_ai_soglia_da_avvisare(p_azienda_id)`** → `(da_avvisare, speso, soglia)`: true **una sola volta per periodo** quando la spesa raggiunge il 90%. Controllo e marcatura stanno **nello stesso UPDATE**: se fossero due istruzioni, due traduzioni ravvicinate potrebbero entrambe leggere "non ancora avvisato" e far partire due email.
- **`fn_ana_aziende_email_principale(p_azienda_id)`** — destinatario dell'avviso: l'indirizzo `is_principale`, altrimenti il primo disponibile (l'avviso arriva comunque invece di perdersi perché nessuno ha spuntato "principale").

### Funzioni di servizio web (Blocco 2 — Task 2.11)

Tutte `SECURITY INVOKER` (chiamate dal sito come `anon` rispettano le RLS del Blocco 3). **Script**: `SqlScripts/444_Create_FnWebServizio.sql`.

- **`fn_web_prezzo_da(p_viaggio_id)` → `INTEGER`** — prezzo "da" del tour: minimo tra **tutte le tariffe** (pilota, passeggero, passeggero auto guida, bambino 0-2/2-6/6-12; zeri/NULL esclusi) delle sole **partenze future** (`data_inizio >= CURRENT_DATE`) in `ana_date_viaggi`. `NULL` se nessuna partenza futura con tariffa.
- **`fn_web_tour_pubblicati(p_azienda_id, p_lingua CHAR(2) DEFAULT 'IT')` → `TABLE`** — lista tour per il sito: solo `stato_pubblicazione='pubblicato'`, scoped per azienda, **e solo partenze non ancora iniziate** (`data_viaggio_data_inizio > CURRENT_DATE`, script `506`). Il filtro sulla data è la contropartita in lettura della regola di scrittura (`StatoPartenzaRules.MotivoNonPubblicabile`: si pubblica solo una partenza che deve ancora iniziare): senza, una scheda pubblicata resterebbe sul sito per sempre, perché nessun processo la ritira allo scadere e un trigger non potrebbe farlo — il tempo che passa non produce eventi DML. Ritorna viaggio/contenuto id, titolo (= `ana_viaggi.viaggio_descrizione_breve`, sempre IT fino al Blocco 10), sottotitolo/descrizione_html/durata_testo **in lingua** da `web_traduzioni` (entità `web_tour_contenuti`, traduzioni non `obsoleto`, fallback IT), slug, difficoltà, numero_giorni, categoria sport (via `ana_tipo_viaggi.web_categoria_fk`), `prezzo_da`, immagine principale (url/storage_path), data_pubblicazione, ordine, **`incluso`/`escluso`** (da `ana_viaggi.viaggio_incluso`/`viaggio_escluso`, tradotti per lingua con entità `ana_viaggi`, fallback IT — script `477`), **`posti_rimasti`/`posti_stato`** (§A.2, script `479`), **`is_tour_breve`** (§A.3, script `480`: `ana_tipo_viaggi.tipo_viaggio_breve` del tipo del viaggio — marca "esperienza breve/giornaliero"), **`meta_title`/`meta_description`** (Blocco 5 Fase 2, script `486`, colonne aggiunte **in coda**: `COALESCE(NULLIF(btrim(web_tour_contenuti.meta_title/meta_description),''), <titolo>/<sottotitolo>)` — se l'editor non ha compilato i campi SEO, il sito riceve comunque un fallback sensato. Meta **non tradotti** in questo pass (restano IT anche con `p_lingua` diverso da IT); nessun consumer C# nel gestionale mappa questa funzione — è letta solo dal frontend pubblico via RPC).
  - **`posti_rimasti`** = `max(viaggio_capienza_max − mezzi_occupati(data), 0)`; `NULL` se `viaggio_capienza_max` non è impostata (capienza non gestita). **`posti_stato`** = `NULL` (non gestita) · `'sold_out'` (0 posti) · `'ultimi'` (0 < rimasti ≤ `viaggio_capienza_alert`) · `'disponibile'`. Il frontend rende: `sold_out`→"SOLD OUT", `ultimi`→"Rimangono solo N posti".
  - **`fn_web_ha_tour_brevi_pubblicati(p_azienda_id) → BOOLEAN`** (§A.3, script `480`, `EXECUTE` a `anon`): `true` se esiste almeno un tour **pubblicato**, con partenza non ancora iniziata (script `506`, stesso taglio di `fn_web_tour_pubblicati`: senza filtro la sezione del sito comparirebbe vuota, basata su partenze passate), di un tipo marcato `tipo_viaggio_breve`. Guida la **sezione condizionale "Tour giornalieri"** del sito (compare solo se `true`); `is_tour_breve` per-edizione serve a filtrare i tour dentro quella sezione.
  - **`fn_web_mezzi_occupati_data(p_data_viaggio_id) → INTEGER`** (script `479`, **SECURITY DEFINER**, `EXECUTE` a `anon`): mezzi occupati per una data = numero di **piloti** (`mov_clienti_viaggi.tipo_partecipante_id_fk IN (4,5)`). SECURITY DEFINER perché `anon` non ha (e non deve avere) accesso a `mov_clienti_viaggi`: la funzione espone solo il conteggio, mai le prenotazioni.
  - **Trigger `trg_mov_clienti_viaggi_posti`** (AFTER INS/UPD/DEL su `mov_clienti_viaggi`, script `478`): fa **solo** `pg_notify('web_tour_revalidate', {viaggio_id, data_viaggio_id})` come hook di revalidation on-demand della Fase 3 (Next.js). Nessuna scrittura su altre tabelle → nessuna cache da mantenere, nessuna collisione con `trg_validate_date_viaggio_duration`. `posti_rimasti` è calcolato **live**.
- **`fn_web_destinatari_newsletter(p_azienda_id)` → `TABLE`** — destinatari newsletter: UNION con dedup per email (CITEXT, case-insensitive) di `ana_clienti` con `consenso_marketing=true` + `web_newsletter_iscritti` `stato='attivo'` e `consenso=true`, **meno** `web_newsletter_soppressioni`. `fonte` = `cliente`/`iscritto`/`entrambi`; su `entrambi` prevalgono lingua e `token_disiscrizione` dell'iscritto ma resta anche `cliente_id`. Duplicati interni ad `ana_clienti`: vince il `cliente_id` minore. **Blocco 11 (multilingua):** la `lingua` effettiva è `COALESCE(iscritto.lingua, cliente_lingua, fn_lingua_da_comune(comune), 'IT')` (`SqlScripts/465`). **`SqlScripts/511`:** aggiunta in coda la colonna `telefono` (`cliente_preftelint` + `cliente_telefono` concatenati), per l'anteprima dell'elenco destinatari nella pagina Newsletter — **NULL per `fonte='iscritto'`**, perché chi si iscrive dal sito lascia la sola email. Colonna in coda apposta: i consumer che selezionano per nome non si accorgono del cambio.
- **`fn_lingua_da_comune(p_comune_id)` → `CHAR(2)`** (`SqlScripts/465`, Blocco 11) — deriva la lingua dalla nazione di residenza (comune → provincia → regione → `eba_countries.iso_alpha2`): `IT→IT`; `DE/AT/CH→DE`; `FR/BE/LU/MC→FR`; `ES/AR/MX/…→ES`; anglofoni→`EN`; non coperti/NULL→`EN`/`IT`. Usata per il backfill di `ana_clienti.cliente_lingua` (nuovo campo **editabile** nella scheda cliente) e come fallback in `fn_web_destinatari_newsletter`.
- **`fn_ana_clienti_get_lingua(p_cliente_id)` / `fn_ana_clienti_set_lingua(p_cliente_id, p_lingua)`** (`SqlScripts/466`, Blocco 11) — get/set della lingua preferita del cliente, usati da `ClienteLinguaService` come **side-field** nella scheda cliente (evita di toccare la grande `ClienteRepository`). **`SqlScripts/485`:** `set` con `p_lingua` vuoto/NULL **auto-deriva** da `fn_lingua_da_comune(cliente_comune_residenza_fk)` (fallback `IT`) → `cliente_lingua` **mai NULL** (colonna ora `NOT NULL DEFAULT 'IT'`); la newsletter la legge senza ragionare. Nota: il vecchio cast `@L::char` in `ClienteLinguaService` (troncava `IT`→`I`) è stato corretto a `::varchar` (script 484 ripara i dati già troncati).
### Newsletter a blocchi (`SqlScripts/512`, Fase 1)

Design: `Estensione Progetto WEB/Documenti/2026-08-09-Newsletter_Blocchi_design.md`. La newsletter smette di essere una casella di testo dentro un template fisso e diventa una **sequenza di blocchi ordinati** (`web_newsletter_blocchi`, figlia di `web_newsletter_invii` con `ON DELETE CASCADE`). Tabella e **campi espliciti** anziché JSONB perché `web_traduzioni` indirizza `(entita, entita_id, campo, lingua)` e ha bisogno di id e nomi di campo **stabili**: un indirizzamento per posizione si romperebbe al primo riordino.

- **`fn_web_newsletter_tipi_blocco()` → `TABLE`** — catalogo dei tipi (`intestazione`, `testata`, `testo`, `tour`, `immagine`, `pulsante`, `separatore`, `footer`) con `etichetta`, `obbligatorio` e `max_occorrenze`. Non è una tabella ma una function: è un catalogo di **codice**, non dati aziendali, e così resta un'unica fonte di verità interrogabile dalla UI. `intestazione` e `footer` sono **obbligatori e unici** (indici parziali `uq_..._intestazione`/`_footer` + guardia nella delete).
- **`fn_web_newsletter_blocchi_list` / `_get` / `_insert` / `_update` / `_delete`** — CRUD per-azienda. La `insert` **verifica che la newsletter appartenga all'azienda** (senza, si potrebbe appendere un blocco alla newsletter di un altro tenant conoscendone l'id), applica `max_occorrenze` e, se `p_ordine` è NULL, accoda **prima del footer**. La `delete` rifiuta i tipi obbligatori. La `update` **non** cambia tipo (immutabile) né ordine (passa dalla reorder), e i NULL **azzerano** i campi di contenuto.
- **`fn_web_newsletter_blocchi_reorder(p_azienda_id, p_invio_id_fk, p_ids[])`** — stesso schema di `fn_web_tour_itinerario_reorder`. Dopo il riordino **rimette forzatamente** `intestazione` a `ordine=0` e `footer` a `999999`: la loro posizione non dipende da cosa ha trascinato l'utente.
- **`fn_web_newsletter_crea_bozza(p_azienda_id, p_oggetto, p_is_modello)` → `BIGINT`** — crea la riga in `stato='bozza'` **con dentro già i due blocchi obbligatori**. Sta nel DB e non in C# perché l'invariante "ogni newsletter ha intestazione e footer" deve valere anche per le newsletter create da altri percorsi.
- **`fn_web_newsletter_clona(p_invio_id, p_azienda_id, p_nuovo_oggetto, p_come_modello)` → `BIGINT`** — clona **sempre in bozza**, anche da una già inviata o da un modello. **`corpo_html` non si copia**: è l'istantanea di ciò che è partito, non un contenuto modificabile; la copia riparte dai blocchi.
- **`fn_web_newsletter_elenco(p_azienda_id, p_modelli)` → `TABLE`** — elenco separato per newsletter e **modelli** (`is_modello`), con conteggio blocchi.

**Modifiche a `web_newsletter_invii`:** `corpo_html` diventa **NULLable** (ora è l'HTML renderizzato **al momento dell'invio**, quindi NULL su bozze e modelli — prima era NOT NULL perché si scriveva solo all'invio); nuova colonna **`is_modello`** (struttura riutilizzabile con nome: l'`oggetto` fa da nome, esclusa dallo storico, si clona invece di inviarsi). Lo stato `'bozza'` era **già ammesso** dal CHECK e non lo scriveva nessuno.

### Supporto alla newsletter a blocchi (`SqlScripts/513`–`517`)

- **`fn_web_newsletter_dati_azienda(p_azienda_id)` → `TABLE`** (`513`) — ragione sociale, P.IVA, indirizzo (dalla sede **principale**, con comune e CAP), email (sede principale, altrimenti email aziendale principale), telefono e sito. Restituisce **tutti** i campi disponibili in una lettura sola: la composizione del footer è per-azienda e decide quali mostrare, quindi sei letture separate a ogni anteprima sarebbero sprecate.
- **`fn_web_newsletter_dati_tour(p_data_viaggio_id, p_azienda_id)` → `TABLE`** (`514`) — contenuto di un riquadro tour da un'edizione. **Titolo** = nome del viaggio (`ana_viaggi.viaggio_descrizione_breve`): `web_tour_contenuti` non ha un titolo proprio, ha un sottotitolo editoriale e i meta SEO. **Periodo** in forma **leggibile** — *"Dal 2 al 7 maggio 2026"*, con quattro casi distinti (giorno singolo, stesso mese, stesso anno, a cavallo d'anno) perché è come le scrive una persona; i mesi vengono da `fn_mese_italiano` e non da `TO_CHAR`, che li darebbe in inglese o dipendenti dal `lc_time` del server. **Copertina** = immagine `principale`, altrimenti la prima della galleria; può essere NULL e non deve impedire di creare il blocco. Torna anche `storage_path`, perché la versione email (JPEG) si deriva dall'originale WebP. **`pubblicato`** dice se la scheda è visibile: un link a una bozza porta a una pagina inesistente, ma **avvisare è compito della UI**.
- **`fn_mese_italiano(p_mese)` → `VARCHAR`** (`514`) — nome del mese in italiano, indipendente dalla configurazione del server.
- **`fn_web_immagini_azienda(p_azienda_id)` → `TABLE`** (`515`) — **tutte** le foto della galleria dell'azienda, con il nome del viaggio (+ data) come `contesto`. Il picker dell'itinerario pesca da un tour perché un passo appartiene a quel tour; una newsletter attinge a tutto il repertorio. Il contesto finisce in tooltip e nel filtro: senza, è una parete di miniature indistinguibili.
- **`web_indirizzi` + `fn_web_indirizzi_list` / `_get` / `_insert` / `_update` / `_delete`** (`517`) — **rubrica per-azienda degli indirizzi web** riutilizzabili (sito attuale, sito nuovo, pagine esistenti, link esterni), usata dai pulsanti della newsletter. Nasce da un limite reale: le destinazioni predefinite (home, pagina di un tour) coprono i casi comuni e non gli altri, e chiedere un URL a mano non funziona perché l'utente non sa cosa sia né dove prenderlo. **Il caso che la giustifica:** quando il sito nuovo sarà pronto gli indirizzi cambiano tutti insieme — con la rubrica si correggono in un posto solo. Vincoli: `descrizione` unica per azienda (è ciò che si sceglie in tendina: due voci uguali sarebbero indistinguibili) e `url` che deve iniziare per `http(s)://`. **Legame coi blocchi (`518`)**: `web_newsletter_blocchi.indirizzo_id_fk` → `web_indirizzi`, **ON DELETE SET NULL**. Riferimento e copia **convivono**, e la ragione è che servono a due cose opposte: la copia (`link_url`) rende immutabile una newsletter **inviata** — correggere un indirizzo non deve cambiare retroattivamente ciò che è stato spedito — mentre il riferimento tiene aggiornate **bozze e modelli**, che è il motivo per cui la rubrica esiste (al passaggio al sito nuovo gli indirizzi cambiano tutti insieme, e i modelli sono il meccanismo con cui si costruisce il patrimonio di newsletter avendo escluso l'import da Drupal). Il rendering risolve dalla rubrica **solo se lo stato non è `inviata`**; **`fn_web_newsletter_congela_indirizzi(p_invio_id, p_azienda_id)`** scrive l'URL corrente nei blocchi **prima** di comporre l'invio. `SET NULL` e non `RESTRICT`: cancellando una voce il blocco perde il legame ma **tiene l'ultimo URL noto**, quindi non si rompe.

- **`fn_ana_clienti_get_consenso(p_cliente_id)` → `TABLE(consenso, data, fonte)` / `fn_ana_clienti_set_consenso(p_cliente_id, p_consenso, p_fonte DEFAULT 'gestionale')` → `INTEGER`** (`SqlScripts/510`, Blocco 11-B) — get/set del **consenso marketing** del cliente, side-field nella scheda cliente come la lingua (usati da `ClienteConsensoService`). Colmano una lacuna: le colonne esistevano dal `428` ma nessun codice le scriveva, quindi il consenso poteva arrivare solo dal sito pubblico (Fase 3) o via SQL a mano. È il flag che filtra `fn_web_destinatari_newsletter`. **Semantica delle tre colonne:** `consenso_marketing` = stato attuale; `consenso_marketing_data` = data dell'**ultimo cambio di stato** (concessione *o* revoca); `consenso_marketing_fonte` = causa dell'ultimo cambio (`gestionale`, `iscrizione`, `import`, `revoca_gestionale`). **Punto chiave:** se lo stato non cambia la `set` esce con `0` **senza toccare data/fonte** — altrimenti ogni risalvataggio della scheda cliente riscriverebbe la data del consenso e la tracciabilità andrebbe persa. Cliente inesistente → `0`.

### Colonna `ana_tipo_viaggi.web_categoria_fk` — mappatura tipo viaggio → categoria sport web

Colonna `BIGINT NULL` aggiunta a `ana_tipo_viaggi` che associa un tipo viaggio a una categoria sport del sito (allineata alla PK `BIGINT` identity di `web_categorie_sport`). FK `web_categoria_fk → web_categorie_sport(web_categorie_sport_id)` ON DELETE SET NULL (se la categoria viene eliminata, il tipo viaggio resta senza mappatura). **Script**: `SqlScripts/409_Alter_AnaTipoViaggi_WebCategoria.sql`.

### CRUD `ana_tipo_viaggi` — DB-first (`fn_ana_tipo_viaggi_create`/`update`)

- **`fn_ana_tipo_viaggi_create(p_tipo, p_descrizione, p_breve DEFAULT false) → SETOF ana_tipo_viaggi`** e **`fn_ana_tipo_viaggi_update(p_id, p_tipo, p_descrizione, p_descrizione_web_fk, p_breve) → SETOF ana_tipo_viaggi`** (`SqlScripts/482`). Ritornano la riga completa (`RETURNING *`) mappata da `TipoViaggioService.MapFromReader`. Convertono la vecchia CRUD **inline** del service in funzioni DB (regola DB-first). Comportamento invariato: `create` non imposta `descrizione_web_fk` (resta NULL, si valorizza in `update` — mapping Blocco 8). Read via base `SELECT *` (scaffolding `BaseCrudService`); delete governato dal trigger `ana_tipo_viaggi_check_delete`.

### Cluster contenuti tour web (1° rilascio)

Tutte con coda standard (`azienda_id` FK `ana_aziende` ON DELETE RESTRICT, audit `created/created_by/updated/updated_by`), trigger `trg_web_audit()`, RLS `superadmin_bypass_all`. Nessun grant ad `anon` (rimandato al Blocco 3).

- **`web_tour_contenuti`** (`SqlScripts/410`) — contenuti editoriali del tour, **1:1** con `ana_viaggi` (`viaggio_id_fk INTEGER UNIQUE`). Campi: sottotitolo, `descrizione_html`, `difficolta` (CHECK `turistica/media/medio_alta/alta`), durata_testo, luoghi_visitati, `info_*_html`, `slug`, meta SEO, `stato_pubblicazione` (CHECK `bozza/pubblicato/archiviato`, default `bozza`), ordine, data_pubblicazione. UNIQUE `(azienda_id, slug)`; indice `(azienda_id, stato_pubblicazione)`.
- **`web_tour_itinerario`** (`SqlScripts/411`) — giornate dell'itinerario (N per tour). `viaggio_id_fk INTEGER`, giorno_numero, titolo_giornata, ordine. UNIQUE `(viaggio_id_fk, giorno_numero)` **DEFERRABLE INITIALLY DEFERRED** (`SqlScripts/456`, Blocco 6): il riordino riscrive `giorno_numero` per più righe in un solo UPDATE → verifica posticipata a fine transazione, altrimenti violazione transitoria.
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

> **Correzioni da review consolidata** (`SqlScripts/430`): CHECK `lingua IN ('IT','FR','EN','DE','ES')` su `web_newsletter_iscritti`, `web_newsletter_invii_destinatari`, `web_pagamenti_reminder_log`; `ON DELETE SET NULL` sulle FK di arricchimento `web_newsletter_iscritti.cliente_fk` e `web_pagamenti_reminder_regole.ccn_email_fk`.

### Strato lettura pubblica + RLS `anon` (Blocco 3)

Confine di sicurezza del sito pubblico: `anon` legge **solo contenuti pubblicati**, tutto il resto è negato. Policy role-based pure (`TO anon`, niente `auth.*`): identiche su Postgres liscio e Supabase. Le funzioni pubbliche sono `SECURITY INVOKER` → anche attraverso di esse valgono le RLS.

- **`SqlScripts/450`** — lettura anon sulle tabelle-contenuto web. GRANT **a livello di colonna** (mai `created_by`/`updated_by`: contengono le email degli operatori). Policy: `web_tour_contenuti` e `web_blog_articoli` gated su `stato_pubblicazione='pubblicato'`; `web_tour_itinerario`/`_passaggi`/`_immagini`/`_mappa` gated via tour pubblicato (`EXISTS` su contenuti); `web_categorie_sport` e `web_traduzioni` `USING(true)` (deciso nel design doc). Su `web_tour_mappa` esclusi anche `gpx_originale`/`gpx_filename`/`parametri_render` (GPX mai al browser).
- **`SqlScripts/451`** — unico caso di scrittura pubblica: `INSERT` su `web_newsletter_iscritti` (form iscrizione del sito). Grant di colonna (niente `stato`, `cliente_fk`, audit) + policy `WITH CHECK (stato='attivo' AND consenso=true)`. `created_by` risulta `'anon'` (nessuna GUC dal sito) → gli iscritti dal form pubblico si riconoscono a colpo d'occhio.
- **`SqlScripts/452`** — lettura anon **gated** sul minimo di tabelle operative richiesto dalle funzioni pubbliche SECURITY INVOKER: `ana_viaggi` (10 colonne descrittive, no note/mappa legacy) e `ana_date_viaggi` (date+tariffe, no note) con policy `EXISTS` tour pubblicato; `ana_tipo_viaggi` solo `(tipo_viaggi_id, web_categoria_fk)` senza abilitare RLS (soli id di mapping, nessun dato descrittivo).
- **`SqlScripts/453`** — hardening EXECUTE: `REVOKE EXECUTE ON ALL ROUTINES ... FROM PUBLIC` (**ROUTINES**, non FUNCTIONS: copre anche le procedure `sp_app_*` di gestione utenti/ruoli), `ALTER DEFAULT PRIVILEGES` per le routine future, `REVOKE CREATE ON SCHEMA public FROM PUBLIC`. Ad `anon` restano SOLO `fn_web_tour_pubblicati` e `fn_web_prezzo_da`. Il gestionale (postgres, superuser) non è impattato; i ruoli `app_*` non sono usati da alcuna connection string. ⚠️ Al deploy su Supabase riverificare l'impatto su `authenticated`/`service_role`.

> **Rollback:** `SqlScripts/499_Rollback_EstensioneWeb.sql` annulla l'intera estensione Blocchi 0–3 (alter + 19 tabelle + funzioni `fn_web_*`/`fn_ana_aziende_esp_*` + `trg_web_audit` + policy RLS su tabelle legacy + revert hardening EXECUTE + ruolo `anon` via `DROP OWNED`), idempotente `IF EXISTS`. Solo locale, con backup.





























































































































































































































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
| `ana_tipo_alloggio_trg1_func` |  | trigger | Assegna la chiave solo se chi scrive non l'ha data. Prima la sovrascriveva sempre, e |
| `questo rendeva inutile ogni ON CONFLICT: al posto di un aggiornamento arrivava un` |  |  |  |
| `duplicato, senza che nessuno protestasse (difetto 97).` |  |  |  |
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
| `fn_alloggi_assegnazione_valida` | p_data_viaggio_id integer, p_assegnazioni jsonb | TABLE(gravita character varying, esito character varying, messaggio text) | Verifica un'assegnazione completa: tipi ammessi dal viaggio, capienza rispettata, nessuno |
| `ripetuto, nessuno dimenticato. La chiamano il sito e il gestionale — una regola sola, due` |  |  |  |
| `interfacce.` |  |  |  |
| `fn_alloggi_combinazioni` | p_data_viaggio_id integer, p_persone integer | TABLE(forma integer, gruppi integer[], camere integer, chiedere_chi boolean) | Le forme in cui N persone possono dividersi fra le sistemazioni disponibili su questa |
| `partenza, con l'indicazione se serve chiedere chi sta con chi. ⚠️ N sono le persone che una` |  |  |  |
| `sistemazione la vogliono: chi sceglie «nessuna» esce dal conto prima.` |  |  |  |
| `fn_alloggi_tipi_ammessi` | p_data_viaggio_id integer | TABLE(tipo_id integer, descrizione character varying, posti integer, supplemento boolean, genere character varying) | I tipi di sistemazione assegnabili su questa partenza: quelli del genere che il viaggio |
| `prevede, piu' NESSUNA che vale sempre. Sostituisce l'elenco intero filtrato a mano dal` |  |  |  |
| `JavaScript — filtro che il gestionale non applicava affatto.` |  |  |  |
| `fn_ana_aliquote_iva_get_active` | p_azienda_id integer | SETOF ana_aliquote_iva | Recupera solo le aliquote IVA attive per azienda (per dropdown UI) |
| `fn_ana_aliquote_iva_get_all` | p_azienda_id integer | SETOF ana_aliquote_iva | Recupera tutte le aliquote IVA per azienda, ordinate per ordinamento e descrizione |
| `fn_ana_aliquote_iva_get_default` | p_azienda_id integer | ana_aliquote_iva | Recupera l'aliquota IVA default per azienda (preselezionata in UI) |
| `fn_ana_alloggio_generi_delete` | p_id integer | integer | Elimina un genere solo se nessuno lo riferisce — ne' i tipi di sistemazione ne' i tipi di |
| `pernottamento che lo ammettono. Il messaggio dice CHI lo usa: un rifiuto senza il motivo` |  |  |  |
| `lascia l'operatore bloccato senza sapere dove guardare.` |  |  |  |
| `fn_ana_alloggio_generi_get_all` | p_solo_attivi boolean DEFAULT false | TABLE(genere_id integer, codice character varying, descrizione character varying, ordine smallint, attivo boolean) |  |
| `fn_ana_alloggio_generi_upsert` | p_id integer, p_codice character varying, p_descrizione character varying, p_ordine smallint, p_attivo boolean | integer |  |
| `fn_ana_api_config_get_all` |  | SETOF ana_api_config | Recupera tutte le configurazioni API ordinate per servizio e ordine di visualizzazione. Usato dalla griglia principale. |
| `fn_ana_api_config_get_by_service` | p_service_code character varying | SETOF ana_api_config | Recupera le configurazioni per un servizio specifico. Usato per lettura API key da codice. |
| `fn_ana_aziende_email_principale` | p_azienda_id integer | character varying |  |
| `fn_ana_aziende_esp_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_ana_aziende_esp_get` | p_id bigint, p_azienda_id integer | SETOF ana_aziende_esp |  |
| `fn_ana_aziende_esp_get_by_azienda` | p_azienda_id integer | SETOF ana_aziende_esp |  |
| `fn_ana_aziende_esp_get_key` | p_azienda_id integer, p_master text | text |  |
| `fn_ana_aziende_esp_insert` | p_azienda_id integer, p_provider character varying, p_api_key text, p_master text, p_sender_email character varying DEFAULT NULL::character varying, p_sender_name character varying DEFAULT NULL::character varying, p_sender_domain character varying DEFAULT NULL::character varying, p_attivo boolean DEFAULT false | bigint |  |
| `fn_ana_aziende_esp_update` | p_id bigint, p_azienda_id integer, p_provider character varying, p_api_key text, p_master text, p_sender_email character varying, p_sender_name character varying, p_sender_domain character varying, p_attivo boolean | integer |  |
| `fn_ana_aziende_get_all` | p_azienda_id integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer | TABLE(azienda_id integer, ragione_sociale character varying, forma_giuridica character varying, data_costituzione date, data_inizio_attivita date, capitale_sociale numeric, socio_unico boolean, in_liquidazione boolean, partita_iva character varying, codice_fiscale character varying, rea_provincia_fk integer, rea_numero character varying, rea_data_iscrizione date, codice_destinatario_sdi character varying, pec character varying, sito_web character varying, sito_web_iscrizione character varying, telefono_principale character varying, attivo boolean, regime_fiscale_fk integer, data_creazione timestamp with time zone, data_ultima_modifica timestamp with time zone, rea_provincia_sigla character varying, regime_fiscale_codice character varying, regime_fiscale_descrizione character varying) | Elenco aziende con provincia REA e regime fiscale. Sostituisce la query che AziendaService |
| `costruiva in C#, dove il filtro azienda era concatenato nella stringa mentre il filtro anno` |  |  |  |
| `era gia' un parametro. NULL su p_azienda_id vale "tutte": e' il caso del SuperAdmin.` |  |  |  |
| `fn_ana_aziende_get_claude_key` | p_azienda_id integer, p_master text | text |  |
| `fn_ana_aziende_set_claude_key` | p_azienda_id integer, p_key text, p_master text | integer |  |
| `fn_ana_aziende_smtp_secrets_get` | p_smtp_id uuid, p_master text | TABLE(password text, inbound_password text) |  |
| `fn_ana_clienti_aggancia_email` | p_cliente_id integer, p_azienda_id integer, p_email character varying | boolean | Completa con un'email la scheda di un cliente che ne e' privo, e solo in quel caso. |
| `Serve a chi e' gia' in anagrafica senza indirizzo e si presenta sul sito: senza questo` |  |  |  |
| `verrebbe riconosciuto e respinto, perche' il sito identifica le persone dall'email.` |  |  |  |
| `⚠️ Non sovrascrive mai un recapito che c'e' gia'.` |  |  |  |
| `fn_ana_clienti_campi_mancanti` | p_dati jsonb, p_pilota boolean DEFAULT false | TABLE(campo character varying, etichetta text) | Elenca i dati obbligatori assenti da un'anagrafica. Una riga per campo: il codice per |
| `illuminare il campo, l'etichetta per scrivere la frase. p_pilota aggiunge prefisso e` |  |  |  |
| `telefono, che servono solo a chi guida. Chiamata sia dal salvataggio dell'anagrafica sia` |  |  |  |
| `dall'iscrizione al viaggio: la definizione di "completa" e' una sola.` |  |  |  |
| `fn_ana_clienti_delete` | p_cliente_id integer, p_azienda_id integer | integer |  |
| `fn_ana_clienti_get_consenso` | p_cliente_id integer | TABLE(consenso boolean, data timestamp with time zone, fonte character varying) |  |
| `fn_ana_clienti_get_lingua` | p_cliente_id integer | character |  |
| `fn_ana_clienti_guardia` | p_dati jsonb, p_cliente_id integer, p_conferme_accettate boolean | void |  |
| `fn_ana_clienti_insert` | p_dati jsonb, p_conferme_accettate boolean DEFAULT false | integer | CRUD unico (SqlScripts/550): unica scrittura di ana_clienti per gestionale e sito. Sostituisce ClienteRepository.InsertAsync, sp_ana_clienti_create e fn_wizard_insert_cliente. |
| `fn_ana_clienti_nascita_modificata` | p_cliente_id integer, p_dati jsonb | boolean | Se questi dati cambiano la data o il comune di nascita gia' registrati. Riempire un |
| `campo vuoto non conta: quella e' una scheda che si completa, non un'identita' che si` |  |  |  |
| `riscrive.` |  |  |  |
| `fn_ana_clienti_set_consenso` | p_cliente_id integer, p_consenso boolean, p_fonte character varying DEFAULT 'gestionale'::character varying | integer |  |
| `fn_ana_clienti_set_lingua` | p_cliente_id integer, p_lingua character | integer |  |
| `fn_ana_clienti_titolo_fk` | p_dati jsonb | integer | Chiave del titolo: quella esplicita se c'e', altrimenti ricavata dal testo e dal sesso (ponte per il sito di iscrizione, SqlScripts/556). Si elimina quando il sito passa alla lookup. |
| `fn_ana_clienti_update` | p_cliente_id integer, p_dati jsonb, p_conferme_accettate boolean DEFAULT false | integer | Aggiornamento PARZIALE: chiave assente = campo invariato, chiave presente a null = campo svuotato. |
| `fn_ana_clienti_valida` | p_dati jsonb, p_cliente_id integer DEFAULT NULL::integer | TABLE(gravita character varying, esito character varying, messaggio text) | Tutte le segnalazioni su un'anagrafica, con gravita', senza scrivere. Serve al client per sapere PRIMA di salvare. Chiavi JSONB = nomi delle colonne. |
| `fn_ana_clienti_verifica_duplicato` | p_azienda_id integer, p_cognome character varying, p_nome character varying, p_data_nascita date DEFAULT NULL::date, p_comune_nascita_id integer DEFAULT NULL::integer, p_cf character varying DEFAULT NULL::character varying, p_escludi_cliente_id integer DEFAULT NULL::integer | TABLE(gravita character varying, esito character varying, messaggio text, cliente_id integer) | Anti-duplicato anagrafico a tre livelli (SqlScripts/549). NESSUN livello richiede il codice fiscale per funzionare: era l'errore del controllo precedente, cieco sul 42% dei clienti. Unico punto di verita' per gestionale e sito. |
| `fn_ana_clienti_verifica_duplicato` | p_azienda_id integer, p_cognome character varying, p_nome character varying, p_data_nascita date DEFAULT NULL::date, p_comune_nascita_id integer DEFAULT NULL::integer, p_cf character varying DEFAULT NULL::character varying, p_escludi_cliente_id integer DEFAULT NULL::integer, p_email character varying DEFAULT NULL::character varying | TABLE(gravita character varying, esito character varying, messaggio text, cliente_id integer) |  |
| `fn_ana_controparti_get_all` | p_azienda_fk integer DEFAULT NULL::integer, p_solo_fornitori boolean DEFAULT NULL::boolean, p_solo_clienti boolean DEFAULT NULL::boolean, p_search_text character varying DEFAULT NULL::character varying | TABLE(controparte_id integer, azienda_fk integer, ragione_sociale character varying, nome_breve character varying, is_fornitore boolean, is_cliente boolean, partita_iva character varying, codice_fiscale character varying, codice_destinatario_sdi character varying, indirizzo character varying, comune_fk integer, telefono_prefisso character varying, telefono_numero character varying, email character varying, pec character varying, sito_web character varying, tipo_fornitore_fk integer, fornitore_estero boolean, attivo boolean, priorita smallint, note text, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, tipo_fornitore_desc character varying, comune_descrizione character varying, provincia_sigla character varying) | Elenco controparti con le descrizioni collegate (tipo fornitore, comune, provincia) e la |
| `ricerca dentro. Sostituisce la query che ContropartiService costruiva in C# concatenando` |  |  |  |
| `stringhe, filtro azienda compreso. Cercare qui e non a valle e' cio' che permette di` |  |  |  |
| `trovare un fornitore appena inserito da un altro utente.` |  |  |  |
| `fn_ana_controparti_get_by_id` | p_controparte_id integer | TABLE(controparte_id integer, azienda_fk integer, ragione_sociale character varying, nome_breve character varying, is_fornitore boolean, is_cliente boolean, partita_iva character varying, codice_fiscale character varying, codice_destinatario_sdi character varying, indirizzo character varying, comune_fk integer, telefono_prefisso character varying, telefono_numero character varying, email character varying, pec character varying, sito_web character varying, tipo_fornitore_fk integer, fornitore_estero boolean, attivo boolean, priorita smallint, note text, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, tipo_fornitore_desc character varying, comune_descrizione character varying, provincia_sigla character varying) |  |
| `fn_ana_date_viaggi_effettuato_guardia` |  | trigger | Impedisce di segnare «effettuata» una partenza non ancora cominciata. Serve un trigger e |
| `non un CHECK: il confronto e' con la data di oggi, e un CHECK ammette solo espressioni` |  |  |  |
| `immutabili.` |  |  |  |
| `fn_ana_date_viaggi_get_by_id` | p_data_viaggio_id integer | SETOF ana_date_viaggi | Una partenza sola, riga intera, per riaprirla in modifica com'e' adesso e non com'era |
| `quando la scheda del viaggio e' stata aperta. Riga intera e non il DTO di riepilogo:` |  |  |  |
| `quello ha sei campi su diciannove, e riscriverci sopra azzererebbe costi e note.` |  |  |  |
| `fn_ana_mezzi_marche_per_tipo` | p_tipo_mezzo_id integer DEFAULT NULL::integer | TABLE(ana_mezzi_id integer, ana_mezzi_descrizione character varying) | Marche (ana_mezzi) che hanno almeno un modello del tipo richiesto. Con NULL le restituisce |
| `tutte. Il tipo sta sul modello, non sulla marca: una marca puo' fare sia moto che 4x4.` |  |  |  |
| `fn_ana_tel_pref_int_get_all` |  | TABLE(codice character varying, iso2 character, paese character varying, descrizione text) | I prefissi telefonici selezionabili, con il nome italiano del paese. Italia in |
| `testa, poi alfabetico. Unica fonte per il gestionale e per il sito di iscrizione.` |  |  |  |
| `fn_ana_tipi_causali_get_active` | p_azienda_id integer | SETOF ana_tipi_causali | Recupera solo le causali attive per azienda. Usato nei dropdown/combobox. |
| `fn_ana_tipi_causali_get_active_by_ciclo` | p_azienda_id integer, p_ciclo character varying | SETOF ana_tipi_causali | Recupera causali attive filtrate per ciclo contabile (ATTIVO/PASSIVO). Usato nei filtri transazioni. |
| `fn_ana_tipi_causali_get_all` | p_azienda_id integer | SETOF ana_tipi_causali | Recupera tutte le causali per azienda, ordinate per ciclo e descrizione. Usato dalla griglia principale. |
| `fn_ana_tipo_alloggio_get_all` |  | TABLE(tipo_alloggio_id integer, tipo_alloggio_descrizione character varying, tipo_alloggio_numero_occupanti integer, tipo_alloggio_supplemento character varying, genere_fk integer, genere_descrizione character varying, genere_codice character varying) |  |
| `fn_ana_tipo_alloggio_upsert` | p_id integer, p_descrizione character varying, p_numero_occupanti integer, p_supplemento character varying, p_genere_fk integer | integer | Salva un tipo di sistemazione. ⚠️ Rifiuta il cambio di genere che renderebbe incoerenti |
| `assegnazioni gia' registrate, dicendo quante e su quali viaggi. Non vieta il cambio su un` |  |  |  |
| `tipo «usato» — quello impedirebbe di correggere una classificazione sbagliata, che e'` |  |  |  |
| `proprio il caso in cui serve.` |  |  |  |
| `fn_ana_tipo_documento_get_all` |  | TABLE(codice character varying, descrizione character varying) | I tipi di documento selezionabili. Unica fonte: il gestionale e il sito leggono questa, |
| `e non possono piu' proporre elenchi diversi.` |  |  |  |
| `fn_ana_tipo_pernottamento_generi_get` | p_pernottamento_id integer | TABLE(genere_id integer, codice character varying, descrizione character varying, ammesso boolean) |  |
| `fn_ana_tipo_pernottamento_generi_set` | p_pernottamento_id integer, p_generi integer[], p_conferma boolean DEFAULT false | integer | Imposta i generi ammessi da un pernottamento. ⚠️ Se la scelta lascia scoperte assegnazioni |
| `gia' registrate lo dice e si ferma; con `p_conferma` procede. Il punto non e' impedirlo —` |  |  |  |
| `a volte i dati sono gia' sporchi e bisogna poter tornare indietro — ma che non succeda di` |  |  |  |
| `nascosto.` |  |  |  |
| `fn_ana_tipo_viaggi_create` | p_tipo character varying, p_descrizione character varying, p_breve boolean DEFAULT false | SETOF ana_tipo_viaggi |  |
| `fn_ana_tipo_viaggi_update` | p_id integer, p_tipo character varying, p_descrizione character varying, p_descrizione_web_fk bigint, p_breve boolean | SETOF ana_tipo_viaggi |  |
| `fn_ana_titolo_persone_conta_clienti` | p_cod integer | integer | Quanti clienti portano un titolo. Serve alla pagina per avvisare PRIMA di chiedere conferma dell'eliminazione: il rifiuto di fn_ana_titolo_persone_delete resta la guardia autoritativa. |
| `fn_ana_titolo_persone_da_testo` | p_testo character varying, p_sesso character | integer | Ponte di compatibilita': risolve il codice del titolo dal vecchio testo libero. Da eliminare con la colonna ana_clienti.cliente_titolo. |
| `fn_ana_titolo_persone_delete` | p_cod integer | integer |  |
| `fn_ana_titolo_persone_get` | p_cod integer | SETOF ana_titolo_persone |  |
| `fn_ana_titolo_persone_insert` | p_descrizione character varying, p_sesso character | integer |  |
| `fn_ana_titolo_persone_list` |  | SETOF ana_titolo_persone | Elenco dei titoli. SIG. e SIG.RA forzati in testa (in quest'ordine): sono la quasi totalita' dei clienti, l'alfabetico li seppelliva. Il resto alfabetico. |
| `fn_ana_titolo_persone_update` | p_cod integer, p_descrizione character varying, p_sesso character | integer |  |
| `fn_ana_viaggi_get_all` | p_azienda_id integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer, p_only_completed boolean DEFAULT NULL::boolean, p_future_only boolean DEFAULT NULL::boolean, p_search_text character varying DEFAULT NULL::character varying | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_difficolta character varying, viaggio_incluso text, viaggio_escluso text, viaggio_capienza_max integer, viaggio_capienza_alert integer, viaggio_note text, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_nazione_fk integer, viaggio_tipo_pernottamento_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, viaggio_link character varying, viaggio_mappa bytea, viaggio_mappa_mimetype character varying, viaggio_mappa_filename character varying, viaggio_mappa_charset character varying, viaggio_mappa_upd_date date, azienda_id integer, viaggio_tipo_avvicinamento_fk integer, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying, matching_dates_count bigint) |  |
| `fn_ana_viaggi_get_by_id` | p_viaggio_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_difficolta character varying, viaggio_incluso text, viaggio_escluso text, viaggio_capienza_max integer, viaggio_capienza_alert integer, viaggio_note text, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_nazione_fk integer, viaggio_tipo_pernottamento_fk integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, viaggio_link character varying, viaggio_mappa bytea, viaggio_mappa_mimetype character varying, viaggio_mappa_filename character varying, viaggio_mappa_charset character varying, viaggio_mappa_upd_date date, azienda_id integer, viaggio_tipo_avvicinamento_fk integer, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying) |  |
| `fn_app_create_azienda` | p_tenant_id character varying, p_ragione_sociale character varying, p_partita_iva character varying, p_forma_giuridica character varying DEFAULT NULL::character varying, p_codice_fiscale character varying DEFAULT NULL::character varying, p_capitale_sociale numeric DEFAULT NULL::numeric, p_socio_unico boolean DEFAULT false, p_in_liquidazione boolean DEFAULT false, p_pec character varying DEFAULT NULL::character varying, p_sito_web character varying DEFAULT NULL::character varying, p_telefono_principale character varying DEFAULT NULL::character varying, p_attivo boolean DEFAULT true | jsonb | Crea nuova azienda/tenant (solo SuperAdmin) |
| `fn_app_create_azienda` | p_data jsonb | jsonb |  |
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
| `fn_cf_calcola` | p_cognome character varying, p_nome character varying, p_data_nascita date, p_sesso character, p_comune_id integer | character varying | Codice fiscale atteso dall'anagrafica. Sta nel DB perche' i codici catastali stanno in ana_geo_comuni: e' l'unico posto che li conosce. Sostituisce le implementazioni duplicate in C# e Python. |
| `fn_cf_carattere_controllo` | p_primi15 text | character |  |
| `fn_cf_codice_cognome` | p_cognome text | text |  |
| `fn_cf_codice_nome` | p_nome text | text |  |
| `fn_cf_consonanti` | p_testo text | text |  |
| `fn_cf_decodifica` | p_cf character varying | TABLE(data_nascita date, sesso character, comune_id integer, comune_descrizione character varying, comune_codfisc character varying) |  |
| `fn_cf_normalizza` | p_testo text | text |  |
| `fn_cf_omocodia_a_base` | p_cf text | text |  |
| `fn_cf_verifica` | p_cf character varying, p_cognome character varying DEFAULT NULL::character varying, p_nome character varying DEFAULT NULL::character varying, p_data_nascita date DEFAULT NULL::date, p_sesso character DEFAULT NULL::bpchar, p_comune_id integer DEFAULT NULL::integer | TABLE(gravita character varying, esito character varying, messaggio text, cf_atteso character varying) | Verifica del codice fiscale con GRAVITA' (OK/AVVISO/CONFERMA/ERRORE, SqlScripts/548). Esiti: MANCANTE, FORMA, CARATTERE_CONTROLLO, FORMA_OK, CORRISPONDE, OMOCODIA, INVERTITI, NON_CORRISPONDE. Unico punto di verita' per gestionale e sito. |
| `fn_cf_verifica_cliente` | p_cf character varying, p_cliente_id integer DEFAULT NULL::integer | TABLE(gravita character varying, esito character varying, messaggio text, cf_atteso character varying) | Verifica del codice fiscale partendo da un cliente gia' a database. Con p_cliente_id nullo resta la sola verifica di forma. |
| `fn_cf_vocali` | p_testo text | text |  |
| `fn_check_email_unique_across_companies` |  | trigger | Garantisce che una email non possa essere usata da aziende diverse. |
| `La stessa azienda può usare la stessa email per reparti diversi.` |  |  |  |
| `fn_check_single_default_iva` |  | trigger | Garantisce che solo 1 aliquota per azienda abbia is_default = TRUE. Eseguito BEFORE INSERT/UPDATE quando is_default = TRUE. |
| `fn_cliente_gemello_in_azienda` | p_cliente_id integer, p_azienda_id integer | integer | La stessa persona nell'anagrafica di un'altra azienda: per codice fiscale, o per |
| `cognome+nome+data di nascita. NULL se non esiste o se i candidati sono piu' d'uno —` |  |  |  |
| `su un'anagrafica si preferisce non fare, che fare a caso.` |  |  |  |
| `fn_cliente_ha_alloggi` | p_cliente_id integer, p_azienda_fk integer | boolean |  |
| `fn_cliente_ha_iscrizioni` | p_cliente_id integer, p_azienda_fk integer | boolean |  |
| `fn_consenso_da_chiedere` | p_cliente_id integer, p_azienda_id integer | boolean | Se a questo cliente DI QUESTA AZIENDA va chiesto il consenso alla newsletter: solo a chi |
| `non ha MAI risposto e ha un indirizzo. Una risposta si riconosce da tre segni — la domanda` |  |  |  |
| `gia' posta, il consenso in corso, oppure un consenso concesso e poi revocato. ⚠️ La revoca` |  |  |  |
| `e' la risposta piu' esplicita di tutte: richiedere il consenso a chi ha disdetto e'` |  |  |  |
| `esattamente l'insistenza che la regola vuole evitare.` |  |  |  |
| `fn_consenso_registra_risposta` | p_cliente_id integer, p_azienda_id integer, p_risposta boolean, p_fonte character varying DEFAULT 'iscrizione_web'::character varying | boolean | Registra la risposta al consenso — anche il NO — su un cliente DI QUESTA AZIENDA. |
| `Restituisce FALSE se il cliente non e' suo: senza il vincolo sull'azienda bastava` |  |  |  |
| `cambiare un numero nella richiesta per falsificare il consenso di chiunque.` |  |  |  |
| `fn_count_clienti_by_azienda` | p_azienda_fk integer | integer | DB-First: Count total clienti for specific azienda |
| `fn_documento_esito_per_partenza` | p_data_viaggio_id integer, p_scadenza date, p_nome text DEFAULT NULL::text | TABLE(gravita character varying, esito character varying, messaggio text) | Se questa data di scadenza basta per questa partenza, e con quale gravità: ERRORE |
| `all'estero, AVVISO in Italia. Nessuna riga = documento a posto. Si può chiedere PRIMA` |  |  |  |
| `di comporre l'iscrizione, quindi il sito la usa per fermare chi non potrebbe partire` |  |  |  |
| `senza fargli compilare tutto il resto.` |  |  |  |
| `fn_documento_stato_per_viaggio` | p_scadenza date, p_viaggio_inizio date, p_viaggio_fine date | TABLE(stato character varying, messaggio text) | Come sta un documento rispetto a un viaggio: MANCANTE, SCADUTO, SCADE_DURANTE, VALIDO. |
| `Non conta se e' scaduto oggi: conta se arriva valido alla FINE del viaggio. Regola unica,` |  |  |  |
| `usata dalla lista partecipanti, dalle stampe e dalla validazione dell'iscrizione.` |  |  |  |
| `fn_e_iscritto` | p_data_viaggio_id integer, p_cliente_id integer | boolean |  |
| `fn_enforce_user_azienda_integrity` |  | trigger |  |
| `fn_exists_cliente_anagrafica` | p_cognome character varying, p_nome character varying, p_data_nascita date, p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if cliente with same anagrafica data already exists |
| `fn_exists_cliente_codice_fiscale` | p_codice_fiscale character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if codice fiscale already exists for another cliente |
| `fn_exists_cliente_email` | p_email character varying, p_exclude_cliente_id integer DEFAULT 0, p_azienda_fk integer DEFAULT NULL::integer | boolean | DB-First: Check if email already exists for another cliente |
| `fn_fatturapa_get_next_progressivo` | p_azienda_id integer | character varying | Restituisce il prossimo progressivo invio FatturaPA per l'azienda (formato 5 cifre). UPSERT atomico. |
| `fn_get_all_clienti` | p_azienda_fk integer DEFAULT NULL::integer, p_filter_year integer DEFAULT NULL::integer, p_search_text character varying DEFAULT NULL::character varying | json |  |
| `fn_get_all_transazioni` | p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_transazione date DEFAULT NULL::date, p_solo_da_pagare boolean DEFAULT false, p_causale_tipo_id integer DEFAULT NULL::integer | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_causale_tipo_id integer, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_data_documento date, transazione_fattura_fk integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita date, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, causale_descrizione character varying, causale_segno integer, causale_ciclo character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_ana_tipo_fornitore` | p_azienda_id integer DEFAULT NULL::integer | TABLE(tipo_fornitore_id integer, azienda_fk integer, descrizione character varying, categoria character varying, conto_contabile_default character varying, created_at timestamp with time zone, updated_at timestamp with time zone) | Recupera i tipi fornitore filtrati per azienda. Se p_azienda_id è NULL, restituisce tutti i record (SuperAdmin). |
| `fn_get_anni_bilancio_viaggi` | p_azienda_id integer | TABLE(anno integer, numero_viaggi integer) |  |
| `fn_get_anni_fatture_attive` | p_azienda_id integer | TABLE(anno integer) |  |
| `fn_get_api_config_value` | p_service_code character varying, p_config_key character varying | text | Recupera il valore di una singola configurazione API attiva per service_code e config_key. Validazioni: parametri obbligatori, esistenza record, stato attivo, valore non vuoto. Usato da CurrencyApiService per recuperare API key dinamicamente dal DB invece che dal codice. |
| `fn_get_azienda_badge_counts` | p_azienda_id integer | TABLE(sedi integer, contatti integer, banche integer, email integer, reparti integer, smtp integer, logo integer) |  |
| `fn_get_bilancio_annuale_viaggi` | p_azienda_id integer, p_anno integer | TABLE(viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_numero_partecipanti integer, data_viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_annuale_viaggi` | p_azienda_id integer, p_anno integer, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_viaggio_data_inizio date, data_viaggio_data_fine date, data_viaggio_numero_partecipanti integer, data_viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_id integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_id integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, viaggio_numero_mezzi integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_bilancio_viaggio` | p_azienda_id integer, p_viaggio_ids integer[], p_data_da date DEFAULT NULL::date, p_data_a date DEFAULT NULL::date | TABLE(viaggio_id integer, viaggio_descrizione text, viaggio_data_inizio date, viaggio_data_fine date, viaggio_numero_partecipanti integer, transazione_id integer, data_documento date, data_registrazione date, numero_documento character varying, transazione_descrizione text, controparte_ragione_sociale character varying, categoria_nome character varying, categoria_tipo character varying, importo_netto_eur numeric, importo_iva_eur numeric, importo_lordo_eur numeric, importo_pagato_eur numeric, stato_pagamento character varying) |  |
| `fn_get_calendar_data` | p_year integer, p_month integer, p_azienda_id integer DEFAULT NULL::integer | TABLE(data_viaggio_id integer, viaggio_id integer, descrizione_viaggio text, data_inizio date, data_fine date, tot_clienti integer, effettuato_sino character, azienda_id integer, azienda_nome text) | Recupera viaggi che intersecano un mese specifico per il calendario. |
| `Un viaggio viene incluso se: data_inizio <= fine_mese AND data_fine >= inizio_mese.` |  |  |  |
| `Include conteggio partecipanti e nome azienda per tooltip.` |  |  |  |
| `fn_get_cliente_by_codice_fiscale` | p_codice_fiscale character varying, p_azienda_fk integer | json |  |
| `fn_get_cliente_by_email` | p_email character varying, p_azienda_fk integer | json |  |
| `fn_get_cliente_by_id` | p_cliente_id integer, p_azienda_fk integer | json | DB-First: Get cliente by ID with all related data (azienda, comuni) |
| `fn_get_cliente_detail` | p_cliente_id integer | json |  |
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
| `fn_get_smtp_config_for_email` | p_azienda_id integer, p_master text | jsonb |  |
| `fn_get_tasso_cambio` | p_valuta_da integer, p_valuta_a integer, p_data date | numeric | Restituisce il tasso di cambio più recente (<= data) calcolando anche l'inverso. Core function. |
| `fn_get_tasso_cambio` | p_iso_da character varying, p_iso_a character varying, p_data date | numeric | Wrapper che accetta codici ISO e invoca la core function. |
| `fn_get_transazioni_by_azienda` | p_azienda_id integer, p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_data_transazione date DEFAULT NULL::date, p_solo_da_pagare boolean DEFAULT false, p_causale_tipo_id integer DEFAULT NULL::integer | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_causale_tipo_id integer, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_data_documento date, transazione_fattura_fk integer, transazione_aliquota_iva_fk integer, transazione_imponibile_eur numeric, transazione_iva_eur numeric, transazione_lordo_eur numeric, transazione_iva_modalita_input character varying, transazione_tasso_cambio_applicato numeric, transazione_tasso_fonte character varying, transazione_tasso_data_validita date, created_at timestamp with time zone, created_by character varying, updated_at timestamp with time zone, updated_by character varying, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, causale_descrizione character varying, causale_segno integer, causale_ciclo character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_per_stampa` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_tipo_movimento character varying DEFAULT NULL::character varying, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'DATA_DOCUMENTO'::character varying | TABLE(transazione_id integer, transazione_azienda_id integer, transazione_viaggio_id integer, transazione_data_viaggio_id integer, transazione_controparte_id integer, transazione_tipo_movimento character varying, transazione_importo numeric, transazione_valuta_id integer, transazione_importo_eur numeric, transazione_data date, transazione_data_scadenza date, transazione_data_pagamento date, transazione_data_documento date, transazione_stato character varying, transazione_causale text, transazione_note text, transazione_numero_documento character varying, transazione_fattura_fk integer, azienda_codice text, controparte_ragione_sociale character varying, valuta_codice_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_dettaglio` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, transazione_id integer, transazione_data date, transazione_data_documento date, transazione_data_scadenza date, transazione_data_pagamento date, controparte_ragione_sociale character varying, tipo_movimento_codice character varying, tipo_movimento_descrizione character varying, causale_segno integer, transazione_causale text, causale_ciclo character varying, transazione_stato character varying, transazione_numero_documento character varying, valuta_codice_iso character varying, imponibile_eur numeric, iva_eur numeric, lordo_eur numeric, aliquota_iva_codice character varying, aliquota_iva_percentuale numeric, importo_valuta_target numeric, valuta_target_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_dettaglio` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, transazione_id integer, transazione_data date, transazione_data_documento date, transazione_data_scadenza date, transazione_data_pagamento date, controparte_ragione_sociale character varying, tipo_movimento_codice character varying, tipo_movimento_descrizione character varying, causale_segno integer, transazione_causale text, transazione_stato character varying, transazione_numero_documento character varying, valuta_codice_iso character varying, transazione_importo numeric, importo_valuta_target numeric, valuta_target_iso character varying, viaggio_descrizione character varying, data_viaggio_inizio date) |  |
| `fn_get_transazioni_stampa_subtotali` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, valuta_codice_iso character varying, totale_valuta_originale numeric, totale_valuta_target numeric, totale_fatturato_target numeric, totale_pagato_target numeric, valuta_target_iso character varying, conteggio_transazioni integer, is_totale_generale boolean) |  |
| `fn_get_transazioni_stampa_subtotali` | p_azienda_id integer DEFAULT NULL::integer, p_controparte_id integer DEFAULT NULL::integer, p_causale_tipo_id integer DEFAULT NULL::integer, p_stati character varying[] DEFAULT NULL::character varying[], p_viaggio_id integer DEFAULT NULL::integer, p_data_viaggio_id integer DEFAULT NULL::integer, p_valuta_id integer DEFAULT NULL::integer, p_data_transazione_da date DEFAULT NULL::date, p_data_transazione_a date DEFAULT NULL::date, p_data_documento_da date DEFAULT NULL::date, p_data_documento_a date DEFAULT NULL::date, p_importo_da numeric DEFAULT NULL::numeric, p_importo_a numeric DEFAULT NULL::numeric, p_numero_documento character varying DEFAULT NULL::character varying, p_solo_con_documento boolean DEFAULT false, p_solo_scadute boolean DEFAULT false, p_solo_con_viaggio boolean DEFAULT false, p_solo_senza_viaggio boolean DEFAULT false, p_solo_con_fattura boolean DEFAULT false, p_ordinamento character varying DEFAULT 'FORNITORE'::character varying, p_valuta_target_id integer DEFAULT NULL::integer, p_causale_ciclo character varying DEFAULT NULL::character varying | TABLE(gruppo_chiave text, gruppo_display text, gruppo_ordine integer, valuta_codice_iso character varying, totale_valuta_originale numeric, totale_valuta_target numeric, totale_fatturato_target numeric, totale_pagato_target numeric, totale_imponibile_target numeric, totale_iva_target numeric, valuta_target_iso character varying, conteggio_transazioni integer, is_totale_generale boolean) |  |
| `fn_get_travel_print_data` | p_data_viaggio_id integer | jsonb |  |
| `fn_get_trip_header_string` | p_viaggio_id integer, p_data_viaggio_id integer | text | Genera intestazione viaggio formattata: "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)". Usato per header UI. |
| `fn_get_viaggi_init_data` | p_viaggio_id integer DEFAULT NULL::integer | json |  |
| `fn_get_viaggi_with_transactions` | p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_link character varying, viaggio_nazione_fk integer, viaggio_tipo_viaggio_fk integer, viaggio_tipo_trattamento_fk integer, viaggio_tipo_pernottamento_fk integer, viaggio_tipo_avvicinamento_fk integer, azienda_id integer, created_by character varying, created timestamp with time zone, updated_by character varying, updated timestamp with time zone, nazione_nome character varying, tipo_viaggi_descrizione character varying, tipo_trattamento_descrizione character varying, ana_tipo_pernottamento_descrizione character varying, tipo_avvicinamento_descrizione character varying, azienda_nome character varying, matching_dates_count integer) |  |
| `fn_get_viaggi_with_transazioni` | p_azienda_id integer | TABLE("Id" integer, "DescrizioneBreve" character varying, "DescrizioneEstesa" text, "NazioneNome" character varying, "NumeroGiorni" integer) |  |
| `fn_get_viaggio_partecipanti_init_data` | p_viaggio_id integer, p_data_viaggio_id integer | json |  |
| `fn_guardia_alloggio_coerente` |  | trigger | Rifiuta le sistemazioni di un genere che il viaggio non prevede: una tenda su un viaggio in |
| `albergo, una camera su uno in campo tendato. ⚠️ NON controlla la capienza — una doppia con` |  |  |  |
| `un occupante solo e' una situazione reale quando l'albergo non ha singole.` |  |  |  |
| `fn_guardia_pernottamento_viaggio` |  | trigger |  |
| `fn_guardia_silo_azienda` |  | trigger | Rifiuta i movimenti in cui il cliente appartiene a un'azienda diversa da quella del |
| `viaggio. Le aziende sono silos: fino al 2026-09-05 era un'intenzione scritta nei` |  |  |  |
| `documenti e in nessun vincolo, e i dati importati da Oracle l'avevano attraversata.` |  |  |  |
| `fn_is_pec_domain` | p_email text | boolean | Verifica se un indirizzo email appartiene a un dominio PEC noto |
| `fn_lingua_da_comune` | p_comune_id integer | character |  |
| `fn_log_business_event` | p_event_type character varying, p_description text, p_entity_table character varying, p_entity_id integer, p_azienda_id integer, p_created_by character varying | void |  |
| `fn_logo_calculate_hash` | p_binary_data bytea | character varying | Calcola l'hash SHA256 di un blob binario per verifica integrità |
| `fn_logo_setup_master_detail_relation` |  | jsonb | Configura la relazione master-detail e i metadati per la gestione dei loghi aziendali |
| `fn_logo_update_access_stats` | p_logo_id uuid | void | Aggiorna le statistiche di accesso (timestamp e contatore) per un logo |
| `fn_logo_validate_mime_type` | p_file_format character varying, p_mime_type character varying | boolean | Valida che il formato file corrisponda al MIME type dichiarato |
| `fn_mese_italiano` | p_mese integer | character varying |  |
| `fn_mov_clienti_alloggi_togli_cliente` | p_data_viaggio_id integer, p_cliente_id integer | integer | Libera il posto letto di un cliente su una partenza. Se la camera resta vuota la riga |
| `viene eliminata: una camera prenotata e senza occupanti falserebbe il conto verso` |  |  |  |
| `l'albergo.` |  |  |  |
| `fn_mov_clienti_viaggi_cancellazione_effetti` | p_data_viaggio_id integer, p_cliente_id integer | TABLE(cliente_id integer, nominativo text, ruolo character varying, motivo character varying, email character varying) | Chi esce dal viaggio se si cancella questo partecipante: lui, e — se e' un pilota — i |
| `suoi passeggeri, che senza di lui non hanno un mezzo. Da chiamare PRIMA di cancellare,` |  |  |  |
| `per mostrare all'operatore chi altro sta per togliere.` |  |  |  |
| `fn_mov_clienti_viaggi_delete` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer | integer | Cancella un partecipante e cio' che dipendeva da lui: i passeggeri, se e' un pilota, e |
| `il posto letto di ognuno. Prima cancellava una riga sola, lasciando passeggeri agganciati` |  |  |  |
| `a un pilota non piu' iscritto e persone in camera senza iscrizione. Restituisce quante` |  |  |  |
| `iscrizioni sono state cancellate.` |  |  |  |
| `fn_mov_clienti_viaggi_guardia` | p_dati jsonb, p_modifica boolean, p_conferme_accettate boolean | void |  |
| `fn_mov_clienti_viaggi_insert` | p_dati jsonb, p_conferme_accettate boolean DEFAULT false | integer | Iscrizione al viaggio, unica per gestionale e sito. Sostituira' sp_mov_clienti_viaggi_create e fn_wizard_insert_prenotazione. |
| `fn_mov_clienti_viaggi_update` | p_dati jsonb, p_conferme_accettate boolean DEFAULT false | integer |  |
| `fn_mov_clienti_viaggi_valida` | p_dati jsonb, p_modifica boolean DEFAULT false | TABLE(gravita character varying, esito character varying, messaggio text, riferimento integer) | Regole dell'iscrizione al viaggio (SqlScripts/551, 553): email obbligatoria per i PILOTI e dati del mezzo obbligatori quando ana_tipo_partecipante.tipo_partecipante_dati_mezzo_obb lo richiede. Entrambe dipendono dal RUOLO, che sta sull'iscrizione e non sulla persona. |
| `fn_nome_sesso_avviso` | p_nome character varying, p_sesso character | text |  |
| `fn_partecipanti_documento_non_valido` | p_data_viaggio_id integer | TABLE(cliente_id integer, cognome character varying, nome character varying, email character varying, prefisso character varying, telefono character varying, documento_scadenza date, stato character varying, viaggio_estero boolean, messaggio text) | Partecipanti a una partenza da sistemare prima di partire, con email e telefono per |
| `avvisarli: documento che non arriva valido alla fine del viaggio (MANCANTE, SCADUTO,` |  |  |  |
| `SCADE_DURANTE) oppure pilota senza alcun recapito (SENZA_RECAPITO). Interroga la PARTENZA` |  |  |  |
| `e non l'iscrizione: un documento valido quando ci si e' iscritti puo' non esserlo piu'` |  |  |  |
| `al momento di partire.` |  |  |  |
| `fn_partenza_conclusa` | p_data_viaggio_id integer | boolean | Se una partenza e' conclusa: marcata effettuata, oppure con la data di rientro passata. |
| `Definizione unica, usata dalla validazione dell'iscrizione e dall'interfaccia.` |  |  |  |
| `fn_partenza_etichetta` | p_data_viaggio_id integer, p_azienda_id integer | text | Come si nomina una partenza quando la si mostra all'utente. NULL se non esiste per quell'azienda. |
| `fn_partenza_iscrivibile` | p_data_viaggio_id integer | boolean | Se a questa partenza ci si puo' ancora iscrivere: non e' cominciata e non e' segnata |
| `come effettuata. E' la regola che decide sia cosa il sito PROPONE sia cosa il database` |  |  |  |
| `ACCETTA — una sola, cosi' non possono allontanarsi. Diversa da fn_partenza_conclusa, che` |  |  |  |
| `dice se il viaggio e' finito: a un viaggio in corso non ci si iscrive, ma concluso non e'.` |  |  |  |
| `fn_partenza_motivo_non_iscrivibile` | p_data_viaggio_id integer | text | Perche' a questa partenza non ci si puo' iscrivere, con le parole giuste per il caso: |
| `gia' effettuata, conclusa, o cominciata. NULL se invece e' iscrivibile.` |  |  |  |
| `fn_search_clienti` | p_azienda_fk integer, p_search_text character varying | json | DB-First: Full-text search clienti by cognome, nome, email, CF, telefono |
| `fn_set_azienda_id` |  | trigger |  |
| `fn_silos_movimenti_fuori_azienda` |  | TABLE(tabella character varying, azienda_viaggio integer, partenza integer, cliente_id integer, nominativo text, azienda_cliente integer, gemello_id integer, rimediabile character varying) | I movimenti in cui il cliente appartiene a un'azienda diversa da quella del viaggio, |
| `con l'esito possibile: RIMAPPABILE (esiste il gemello), GEMELLO_ASSENTE (l'anagrafica` |  |  |  |
| `nell'azienda del viaggio non c'e' e andrebbe creata), GEMELLO_GIA_ISCRITTO (rimappare` |  |  |  |
| `creerebbe un doppione). Referto: non modifica niente.` |  |  |  |
| `fn_silos_rimappa_movimenti` |  | integer | Fa puntare i movimenti al cliente dell'azienda del viaggio, dove il gemello esiste ed e' |
| `uno solo. Lascia intatto cio' che e' GEMELLO_ASSENTE o GEMELLO_GIA_ISCRITTO.` |  |  |  |
| `fn_solo_testo` | p_html text | text | Testo leggibile di un frammento HTML: tag rimossi, spazi normalizzati. Per confronti di contenuto. |
| `fn_superadmin_delete_from_table` | p_user_id uuid, p_table_name character varying, p_where_clause character varying | jsonb | DELETE generico per SuperAdmin su qualsiasi tabella |
| `fn_superadmin_describe_table` | p_user_id uuid, p_table_name character varying | jsonb | DESCRIBE schema tabella per SuperAdmin |
| `fn_superadmin_get_all_companies` | p_user_id uuid, p_tenant_filter character varying DEFAULT NULL::character varying | jsonb | Recupera tutte le aziende cross-tenant per SuperAdmin |
| `fn_superadmin_get_all_companies` |  | jsonb |  |
| `fn_superadmin_query_table` | p_user_id uuid, p_table_name character varying, p_where_clause character varying DEFAULT NULL::character varying, p_limit_count integer DEFAULT NULL::integer | jsonb | SELECT generico per SuperAdmin su qualsiasi tabella |
| `fn_superadmin_update_table` | p_user_id uuid, p_table_name character varying, p_set_clause character varying, p_where_clause character varying | jsonb | UPDATE generico per SuperAdmin su qualsiasi tabella |
| `fn_sys_utente_pref_get` | p_utente_id uuid, p_chiave character varying | text |  |
| `fn_sys_utente_pref_set` | p_utente_id uuid, p_chiave character varying, p_valore text | void |  |
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
| `fn_web_ai_config_get` | p_azienda_id integer | TABLE(soglia_spesa numeric, conteggio_da timestamp with time zone, avvisato_il timestamp with time zone, prezzi_verificati_il date) |  |
| `fn_web_ai_config_set` | p_azienda_id integer, p_soglia numeric, p_riparti boolean DEFAULT false | integer |  |
| `fn_web_ai_consumo_insert` | p_azienda_id integer, p_modello character varying, p_contesto character varying, p_input_tokens integer, p_output_tokens integer, p_costo numeric, p_valuta character varying DEFAULT 'USD'::character varying | bigint |  |
| `fn_web_ai_consumo_riepilogo` | p_azienda_id integer, p_da timestamp with time zone DEFAULT NULL::timestamp with time zone | TABLE(n_chiamate integer, tot_input bigint, tot_output bigint, costo_totale numeric, valuta character varying, ultima_chiamata timestamp with time zone) |  |
| `fn_web_ai_prezzi_verificati` | p_azienda_id integer | integer | Registra che oggi l'operatore ha confermato i prezzi contro il listino Anthropic (azzera il promemoria). |
| `fn_web_ai_soglia_da_avvisare` | p_azienda_id integer | TABLE(da_avvisare boolean, speso numeric, soglia numeric) | true (una sola volta per periodo) quando la spesa raggiunge il 90% della soglia: controllo e marcatura nello stesso UPDATE per non generare email doppie. |
| `fn_web_aziende_funzioni_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_aziende_funzioni_get` | p_id bigint, p_azienda_id integer | SETOF web_aziende_funzioni |  |
| `fn_web_aziende_funzioni_get_by_funzione` | p_azienda_id integer, p_funzione character varying | SETOF web_aziende_funzioni |  |
| `fn_web_aziende_funzioni_insert` | p_azienda_id integer, p_funzione character varying, p_attiva boolean DEFAULT false, p_parametri jsonb DEFAULT NULL::jsonb | bigint |  |
| `fn_web_aziende_funzioni_list` | p_azienda_id integer | SETOF web_aziende_funzioni |  |
| `fn_web_aziende_funzioni_update` | p_id bigint, p_azienda_id integer, p_funzione character varying, p_attiva boolean, p_parametri jsonb | integer |  |
| `fn_web_destinatari_newsletter` | p_azienda_id integer, p_invio_id bigint DEFAULT NULL::bigint | TABLE(email citext, nome character varying, cognome character varying, lingua character, fonte character varying, cliente_id integer, iscritto_id bigint, token_disiscrizione character varying, telefono character varying) |  |
| `fn_web_edizioni_per_viaggio` | p_viaggio_id integer, p_azienda_id integer | TABLE(data_viaggio_id integer, data_inizio date, data_fine date, effettuato_sino character, web_tour_contenuti_id bigint, stato_pubblicazione character varying) |  |
| `fn_web_ha_tour_brevi_pubblicati` | p_azienda_id integer | boolean |  |
| `fn_web_immagini_azienda` | p_azienda_id integer | TABLE(url character varying, storage_path character varying, alt_text character varying, contesto character varying) |  |
| `fn_web_immagini_in_uso` | p_contenuto_id bigint, p_azienda_id integer | TABLE(storage_path character varying) |  |
| `fn_web_immagini_libreria_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_immagini_libreria_in_uso` | p_id bigint, p_azienda_id integer | TABLE(oggetto character varying, stato character varying, blocchi integer) |  |
| `fn_web_immagini_libreria_insert` | p_azienda_id integer, p_descrizione character varying, p_url character varying, p_storage_path character varying, p_mime character varying DEFAULT NULL::character varying, p_larghezza integer DEFAULT NULL::integer, p_altezza integer DEFAULT NULL::integer | bigint |  |
| `fn_web_immagini_libreria_list` | p_azienda_id integer | SETOF web_immagini_libreria |  |
| `fn_web_immagini_libreria_rinomina` | p_id bigint, p_azienda_id integer, p_descrizione character varying | integer |  |
| `fn_web_indirizzi_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_indirizzi_get` | p_id bigint, p_azienda_id integer | SETOF web_indirizzi |  |
| `fn_web_indirizzi_insert` | p_azienda_id integer, p_descrizione character varying, p_url character varying, p_note text DEFAULT NULL::text, p_ordine integer DEFAULT NULL::integer, p_attivo boolean DEFAULT true, p_social character varying DEFAULT NULL::character varying, p_icona_url character varying DEFAULT NULL::character varying, p_icona_path character varying DEFAULT NULL::character varying | bigint |  |
| `fn_web_indirizzi_list` | p_azienda_id integer, p_solo_attivi boolean DEFAULT false | SETOF web_indirizzi |  |
| `fn_web_indirizzi_update` | p_id bigint, p_azienda_id integer, p_descrizione character varying, p_url character varying, p_note text DEFAULT NULL::text, p_ordine integer DEFAULT NULL::integer, p_attivo boolean DEFAULT true, p_social character varying DEFAULT NULL::character varying, p_icona_url character varying DEFAULT NULL::character varying, p_icona_path character varying DEFAULT NULL::character varying | integer |  |
| `fn_web_mezzi_occupati_data` | p_data_viaggio_id integer | integer |  |
| `fn_web_nazioni_clienti` | p_azienda_id integer | TABLE(country_id integer, nome character varying, estero boolean, clienti bigint) |  |
| `fn_web_newsletter_blocchi_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_blocchi_get` | p_id bigint, p_azienda_id integer | SETOF web_newsletter_blocchi |  |
| `fn_web_newsletter_blocchi_insert` | p_azienda_id integer, p_invio_id_fk bigint, p_tipo character varying, p_ordine integer DEFAULT NULL::integer, p_layout character varying DEFAULT 'pieno'::character varying, p_colonne smallint DEFAULT 1, p_titolo character varying DEFAULT NULL::character varying, p_sottotitolo character varying DEFAULT NULL::character varying, p_corpo_html text DEFAULT NULL::text, p_immagine_url character varying DEFAULT NULL::character varying, p_immagine_storage_path character varying DEFAULT NULL::character varying, p_immagine_alt character varying DEFAULT NULL::character varying, p_link_url character varying DEFAULT NULL::character varying, p_link_etichetta character varying DEFAULT NULL::character varying, p_data_viaggio_id_fk integer DEFAULT NULL::integer, p_indirizzo_id_fk bigint DEFAULT NULL::bigint, p_social character varying DEFAULT NULL::character varying, p_icona_url character varying DEFAULT NULL::character varying, p_layout_pulsante character varying DEFAULT NULL::character varying, p_colore_titolo character varying DEFAULT NULL::character varying, p_colore_sottotitolo character varying DEFAULT NULL::character varying | bigint |  |
| `fn_web_newsletter_blocchi_list` | p_invio_id bigint, p_azienda_id integer | SETOF web_newsletter_blocchi |  |
| `fn_web_newsletter_blocchi_reorder` | p_azienda_id integer, p_invio_id_fk bigint, p_ids bigint[] | integer |  |
| `fn_web_newsletter_blocchi_update` | p_id bigint, p_azienda_id integer, p_layout character varying DEFAULT NULL::character varying, p_colonne smallint DEFAULT NULL::smallint, p_titolo character varying DEFAULT NULL::character varying, p_sottotitolo character varying DEFAULT NULL::character varying, p_corpo_html text DEFAULT NULL::text, p_immagine_url character varying DEFAULT NULL::character varying, p_immagine_storage_path character varying DEFAULT NULL::character varying, p_immagine_alt character varying DEFAULT NULL::character varying, p_link_url character varying DEFAULT NULL::character varying, p_link_etichetta character varying DEFAULT NULL::character varying, p_data_viaggio_id_fk integer DEFAULT NULL::integer, p_indirizzo_id_fk bigint DEFAULT NULL::bigint, p_social character varying DEFAULT NULL::character varying, p_icona_url character varying DEFAULT NULL::character varying, p_layout_pulsante character varying DEFAULT NULL::character varying, p_colore_titolo character varying DEFAULT NULL::character varying, p_colore_sottotitolo character varying DEFAULT NULL::character varying | integer |  |
| `fn_web_newsletter_blocco_eredita_traduzioni` | p_blocco_id bigint, p_azienda_id integer | integer | Il riquadro tour eredita le traduzioni del tour, ma solo se il suo testo italiano è ancora quello del tour. |
| `fn_web_newsletter_clona` | p_invio_id bigint, p_azienda_id integer, p_nuovo_oggetto character varying DEFAULT NULL::character varying, p_come_modello boolean DEFAULT false | bigint |  |
| `fn_web_newsletter_collegamenti_da_verificare` | p_invio_id bigint, p_azienda_id integer | TABLE(ordine integer, tipo character varying, descrizione text, motivo text) | Blocchi il cui collegamento a un tour non porta più da nessuna parte. Vuoto = si può spedire. |
| `fn_web_newsletter_congela_indirizzi` | p_invio_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_conteggio` | p_azienda_id integer, p_invio_id bigint DEFAULT NULL::bigint | TABLE(destinatari bigint, clienti bigint, iscritti bigint, iscritti_esclusi bigint) |  |
| `fn_web_newsletter_corpi_list` | p_invio_id bigint, p_azienda_id integer | TABLE(lingua character, oggetto character varying, corpo_html text, destinatari integer) |  |
| `fn_web_newsletter_corpo_archivia` | p_invio_id bigint, p_azienda_id integer, p_lingua character varying, p_oggetto character varying, p_corpo text, p_destinatari integer | bigint |  |
| `fn_web_newsletter_crea_bozza` | p_azienda_id integer, p_oggetto character varying, p_is_modello boolean DEFAULT false | bigint |  |
| `fn_web_newsletter_dati_azienda` | p_azienda_id integer | TABLE(ragione_sociale character varying, partita_iva character varying, indirizzo character varying, email character varying, telefono character varying, sito_web character varying) |  |
| `fn_web_newsletter_dati_tour` | p_data_viaggio_id integer, p_azienda_id integer | TABLE(titolo character varying, periodo character varying, testo character varying, slug character varying, pubblicato boolean, immagine_url character varying, immagine_storage_path character varying) |  |
| `fn_web_newsletter_elenco` | p_azienda_id integer, p_modelli boolean DEFAULT false | TABLE(web_newsletter_invii_id bigint, oggetto character varying, stato character varying, data_invio timestamp with time zone, numero_destinatari integer, canale character varying, is_modello boolean, n_blocchi integer, created timestamp with time zone) |  |
| `fn_web_newsletter_filtri_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_filtri_insert` | p_azienda_id integer, p_invio_id bigint, p_criterio character varying, p_param_data date DEFAULT NULL::date, p_param_int integer DEFAULT NULL::integer | bigint |  |
| `fn_web_newsletter_filtri_list` | p_invio_id bigint, p_azienda_id integer | TABLE(id bigint, criterio character varying, descrizione character varying, param_data date, param_int integer) |  |
| `fn_web_newsletter_invii_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_invii_destinatari_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_invii_destinatari_get` | p_id bigint, p_azienda_id integer | SETOF web_newsletter_invii_destinatari |  |
| `fn_web_newsletter_invii_destinatari_insert` | p_azienda_id integer, p_invio_id_fk bigint, p_email citext, p_lingua character varying DEFAULT NULL::character varying, p_stato_consegna character varying DEFAULT NULL::character varying, p_data timestamp with time zone DEFAULT NULL::timestamp with time zone | bigint |  |
| `fn_web_newsletter_invii_destinatari_list` | p_invio_id bigint, p_azienda_id integer | SETOF web_newsletter_invii_destinatari |  |
| `fn_web_newsletter_invii_destinatari_update` | p_id bigint, p_azienda_id integer, p_invio_id_fk bigint, p_email citext, p_lingua character varying, p_stato_consegna character varying, p_data timestamp with time zone | integer |  |
| `fn_web_newsletter_invii_get` | p_id bigint, p_azienda_id integer | SETOF web_newsletter_invii |  |
| `fn_web_newsletter_invii_insert` | p_azienda_id integer, p_oggetto character varying, p_corpo_html text, p_stato character varying DEFAULT 'bozza'::character varying, p_data_invio timestamp with time zone DEFAULT NULL::timestamp with time zone, p_numero_destinatari integer DEFAULT NULL::integer, p_canale character varying DEFAULT NULL::character varying | bigint |  |
| `fn_web_newsletter_invii_list` | p_azienda_id integer | SETOF web_newsletter_invii |  |
| `fn_web_newsletter_invii_update` | p_id bigint, p_azienda_id integer, p_oggetto character varying, p_corpo_html text, p_stato character varying, p_data_invio timestamp with time zone, p_numero_destinatari integer, p_canale character varying | integer | Aggiorna una newsletter. Se l'oggetto cambia, marca obsolete le sue traduzioni prima di scrivere (script 537). |
| `fn_web_newsletter_iscritti_by_token` | p_token character varying | SETOF web_newsletter_iscritti |  |
| `fn_web_newsletter_iscritti_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_iscritti_get` | p_id bigint, p_azienda_id integer | SETOF web_newsletter_iscritti |  |
| `fn_web_newsletter_iscritti_insert` | p_azienda_id integer, p_email citext, p_nome character varying DEFAULT NULL::character varying, p_cognome character varying DEFAULT NULL::character varying, p_lingua character varying DEFAULT 'IT'::character varying, p_consenso boolean DEFAULT true, p_consenso_data timestamp with time zone DEFAULT NULL::timestamp with time zone, p_consenso_fonte character varying DEFAULT NULL::character varying, p_stato character varying DEFAULT 'attivo'::character varying, p_cliente_fk integer DEFAULT NULL::integer | bigint |  |
| `fn_web_newsletter_iscritti_list` | p_azienda_id integer | SETOF web_newsletter_iscritti |  |
| `fn_web_newsletter_iscritti_update` | p_id bigint, p_azienda_id integer, p_email citext, p_nome character varying, p_cognome character varying, p_lingua character varying, p_consenso boolean, p_consenso_data timestamp with time zone, p_consenso_fonte character varying, p_stato character varying, p_cliente_fk integer | integer |  |
| `fn_web_newsletter_periodi` | p_invio_id bigint, p_azienda_id integer | TABLE(blocco_id bigint, data_inizio date, data_fine date) | Date delle partenze agganciate ai riquadri tour: servono a rigenerare il periodo nella lingua del destinatario. |
| `fn_web_newsletter_set_oggetto` | p_invio_id bigint, p_azienda_id integer, p_oggetto character varying | integer |  |
| `fn_web_newsletter_soppressioni_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_newsletter_soppressioni_get` | p_id bigint, p_azienda_id integer | SETOF web_newsletter_soppressioni |  |
| `fn_web_newsletter_soppressioni_insert` | p_azienda_id integer, p_email citext, p_motivo character varying, p_data timestamp with time zone DEFAULT NULL::timestamp with time zone | bigint |  |
| `fn_web_newsletter_soppressioni_list` | p_azienda_id integer | SETOF web_newsletter_soppressioni |  |
| `fn_web_newsletter_soppressioni_update` | p_id bigint, p_azienda_id integer, p_email citext, p_motivo character varying, p_data timestamp with time zone | integer |  |
| `fn_web_newsletter_tipi_blocco` |  | TABLE(tipo character varying, etichetta character varying, obbligatorio boolean, max_occorrenze integer, ordine_catalogo integer) |  |
| `fn_web_newsletter_traduzioni` | p_invio_id bigint, p_azienda_id integer, p_lingua character varying DEFAULT NULL::character varying | TABLE(lingua character, entita character varying, entita_id bigint, campo character varying, testo text) | Traduzioni valide (non obsolete) di una newsletter: oggetto e campi dei blocchi. p_lingua NULL = tutte. |
| `fn_web_newsletter_traduzioni_stato` | p_invio_id bigint, p_azienda_id integer | TABLE(lingua character, traducibili integer, tradotti integer, obsoleti integer, mancanti integer) | Copertura delle traduzioni di una newsletter per lingua: traducibili, tradotti, obsoleti, mancanti. |
| `fn_web_prezzo_da` | p_viaggio_id integer | integer |  |
| `fn_web_prezzo_da_data` | p_data_viaggio_id integer | integer |  |
| `fn_web_recensioni_config` | p_azienda_id integer | jsonb |  |
| `fn_web_tipi_viaggio_descrizioni_delete` | p_id bigint | integer |  |
| `fn_web_tipi_viaggio_descrizioni_get` | p_id bigint | SETOF web_tipi_viaggio_descrizioni |  |
| `fn_web_tipi_viaggio_descrizioni_insert` | p_descrizione_web character varying, p_slug character varying, p_ordine integer DEFAULT 0 | bigint |  |
| `fn_web_tipi_viaggio_descrizioni_list` |  | SETOF web_tipi_viaggio_descrizioni |  |
| `fn_web_tipi_viaggio_descrizioni_update` | p_id bigint, p_descrizione_web character varying, p_slug character varying, p_ordine integer | integer |  |
| `fn_web_tour_campi_traducibili` | p_contenuto_id bigint, p_azienda_id integer | TABLE(entita character varying, entita_id bigint, campo character varying) | Campi traducibili di una edizione (entita, entita_id, campo), titoli delle giornate inclusi (503). Unica definizione: la usano fn_web_tour_stato_sezioni, fn_web_traduzioni_approva_contenuto e fn_web_traduzioni_per_contenuto. Va tenuta allineata a WebTraduzioneOrchestratorService.GetTranslatableItemsAsync. |
| `fn_web_tour_contenuti_clona` | p_contenuto_sorgente bigint, p_data_viaggio_dest integer, p_azienda_id integer, p_max_giornate integer DEFAULT NULL::integer | bigint | Clona la scheda web di una edizione su un'altra data dello STESSO viaggio: editoriale, immagini, itinerario, mappe (con abbinamento giornata rimappato) e tutte le traduzioni, conservando revisionato/obsoleto. La copia nasce sempre in bozza. I file su Storage restano condivisi con l'originale. p_max_giornate limita la copia alle prime N giornate, per partenze di durata inferiore. |
| `fn_web_tour_contenuti_delete` | p_id bigint, p_azienda_id integer | integer | Elimina una scheda di contenuti web con giornate, passaggi, immagini, mappe e TUTTE le relative traduzioni (web_traduzioni è polimorfica e nessuna CASCADE la raggiunge). Scopata per azienda. I file su Storage non vengono toccati: possono essere condivisi con una scheda clonata. |
| `fn_web_tour_contenuti_get` | p_id bigint, p_azienda_id integer | SETOF web_tour_contenuti |  |
| `fn_web_tour_contenuti_get_by_data_viaggio` | p_data_viaggio_id integer, p_azienda_id integer | SETOF web_tour_contenuti |  |
| `fn_web_tour_contenuti_get_by_viaggio` | p_viaggio_id integer, p_azienda_id integer | SETOF web_tour_contenuti |  |
| `fn_web_tour_contenuti_insert` | p_azienda_id integer, p_viaggio_id_fk integer, p_data_viaggio_id_fk integer, p_slug character varying, p_sottotitolo character varying DEFAULT NULL::character varying, p_descrizione_html text DEFAULT NULL::text, p_durata_testo character varying DEFAULT NULL::character varying, p_luoghi_visitati text DEFAULT NULL::text, p_info_pernottamento_html text DEFAULT NULL::text, p_info_pasti_html text DEFAULT NULL::text, p_info_equipaggiamento_html text DEFAULT NULL::text, p_altre_info_html text DEFAULT NULL::text, p_meta_title character varying DEFAULT NULL::character varying, p_meta_description character varying DEFAULT NULL::character varying, p_stato_pubblicazione character varying DEFAULT 'bozza'::character varying, p_ordine integer DEFAULT 0, p_data_pubblicazione timestamp with time zone DEFAULT NULL::timestamp with time zone | bigint |  |
| `fn_web_tour_contenuti_list` | p_azienda_id integer | SETOF web_tour_contenuti |  |
| `fn_web_tour_contenuti_update` | p_id bigint, p_azienda_id integer, p_viaggio_id_fk integer, p_data_viaggio_id_fk integer, p_slug character varying, p_sottotitolo character varying, p_descrizione_html text, p_durata_testo character varying, p_luoghi_visitati text, p_info_pernottamento_html text, p_info_pasti_html text, p_info_equipaggiamento_html text, p_altre_info_html text, p_meta_title character varying, p_meta_description character varying, p_stato_pubblicazione character varying, p_ordine integer, p_data_pubblicazione timestamp with time zone | integer |  |
| `fn_web_tour_immagini_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_tour_immagini_get` | p_id bigint, p_azienda_id integer | SETOF web_tour_immagini |  |
| `fn_web_tour_immagini_insert` | p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_url text, p_storage_path character varying, p_tipo character varying DEFAULT 'galleria'::character varying, p_alt_text character varying DEFAULT NULL::character varying, p_titolo character varying DEFAULT NULL::character varying, p_larghezza integer DEFAULT NULL::integer, p_altezza integer DEFAULT NULL::integer, p_mime character varying DEFAULT NULL::character varying, p_ordine integer DEFAULT 0, p_nome_file character varying DEFAULT NULL::character varying | bigint |  |
| `fn_web_tour_immagini_list` | p_web_tour_contenuti_id bigint, p_azienda_id integer | SETOF web_tour_immagini |  |
| `fn_web_tour_immagini_reorder` | p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_ids bigint[] | integer |  |
| `fn_web_tour_immagini_set_principale` | p_id bigint, p_azienda_id integer, p_web_tour_contenuti_id_fk bigint | integer |  |
| `fn_web_tour_immagini_update` | p_id bigint, p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_tipo character varying, p_url text, p_storage_path character varying, p_alt_text character varying, p_titolo character varying, p_larghezza integer, p_altezza integer, p_mime character varying, p_ordine integer, p_nome_file character varying DEFAULT NULL::character varying | integer |  |
| `fn_web_tour_itinerario_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_tour_itinerario_get` | p_id bigint, p_azienda_id integer | SETOF web_tour_itinerario |  |
| `fn_web_tour_itinerario_insert` | p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_giorno_numero integer, p_titolo_giornata character varying, p_ordine integer DEFAULT 0 | bigint |  |
| `fn_web_tour_itinerario_list` | p_web_tour_contenuti_id bigint, p_azienda_id integer | SETOF web_tour_itinerario |  |
| `fn_web_tour_itinerario_passaggi_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_tour_itinerario_passaggi_get` | p_id bigint, p_azienda_id integer | SETOF web_tour_itinerario_passaggi |  |
| `fn_web_tour_itinerario_passaggi_insert` | p_azienda_id integer, p_itinerario_id_fk bigint, p_testo_html text, p_immagine_url text DEFAULT NULL::text, p_immagine_storage_path character varying DEFAULT NULL::character varying, p_immagine_didascalia character varying DEFAULT NULL::character varying, p_ordine integer DEFAULT 0 | bigint |  |
| `fn_web_tour_itinerario_passaggi_list` | p_itinerario_id bigint, p_azienda_id integer | SETOF web_tour_itinerario_passaggi |  |
| `fn_web_tour_itinerario_passaggi_reorder` | p_azienda_id integer, p_itinerario_id_fk bigint, p_ids bigint[] | integer |  |
| `fn_web_tour_itinerario_passaggi_update` | p_id bigint, p_azienda_id integer, p_itinerario_id_fk bigint, p_testo_html text, p_immagine_url text, p_immagine_storage_path character varying, p_immagine_didascalia character varying, p_ordine integer | integer |  |
| `fn_web_tour_itinerario_reorder` | p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_ids bigint[] | integer |  |
| `fn_web_tour_itinerario_update` | p_id bigint, p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_giorno_numero integer, p_titolo_giornata character varying, p_ordine integer | integer |  |
| `fn_web_tour_mappa_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_tour_mappa_get` | p_id bigint, p_azienda_id integer | SETOF web_tour_mappa |  |
| `fn_web_tour_mappa_get_by_contenuto` | p_web_tour_contenuti_id bigint, p_azienda_id integer | SETOF web_tour_mappa | Mappa dell'INTERO VIAGGIO di una edizione (web_tour_itinerario_id_fk IS NULL). Per l'elenco completo usare fn_web_tour_mappa_list_by_contenuto. |
| `fn_web_tour_mappa_get_by_giornata` | p_web_tour_itinerario_id bigint, p_azienda_id integer | SETOF web_tour_mappa |  |
| `fn_web_tour_mappa_insert` | p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_gpx_originale text DEFAULT NULL::text, p_gpx_filename character varying DEFAULT NULL::character varying, p_bbox_min_lat numeric DEFAULT NULL::numeric, p_bbox_min_lon numeric DEFAULT NULL::numeric, p_bbox_max_lat numeric DEFAULT NULL::numeric, p_bbox_max_lon numeric DEFAULT NULL::numeric, p_provider character varying DEFAULT 'geoapify'::character varying, p_stile character varying DEFAULT 'osm-bright'::character varying, p_parametri_render jsonb DEFAULT NULL::jsonb, p_immagine_url text DEFAULT NULL::text, p_immagine_storage_path character varying DEFAULT NULL::character varying, p_data_generazione timestamp with time zone DEFAULT NULL::timestamp with time zone, p_web_tour_itinerario_id_fk bigint DEFAULT NULL::bigint, p_descrizione character varying DEFAULT NULL::character varying, p_gpx_bytes integer DEFAULT NULL::integer | bigint |  |
| `fn_web_tour_mappa_list` | p_azienda_id integer | SETOF web_tour_mappa |  |
| `fn_web_tour_mappa_list_by_contenuto` | p_web_tour_contenuti_id bigint, p_azienda_id integer | SETOF web_tour_mappa | Mappe di una edizione: prima quella dell'intero viaggio, poi le giornate in ordine di giorno_numero. |
| `fn_web_tour_mappa_update` | p_id bigint, p_azienda_id integer, p_web_tour_contenuti_id_fk bigint, p_gpx_originale text, p_gpx_filename character varying, p_bbox_min_lat numeric, p_bbox_min_lon numeric, p_bbox_max_lat numeric, p_bbox_max_lon numeric, p_provider character varying, p_stile character varying, p_parametri_render jsonb, p_immagine_url text, p_immagine_storage_path character varying, p_data_generazione timestamp with time zone, p_web_tour_itinerario_id_fk bigint DEFAULT NULL::bigint, p_descrizione character varying DEFAULT NULL::character varying, p_gpx_bytes integer DEFAULT NULL::integer | integer |  |
| `fn_web_tour_prossime_partenze` | p_contenuto_id bigint, p_azienda_id integer | TABLE(data_viaggio_id integer, data_inizio date, data_fine date, e_questa_edizione boolean) | Partenze future (data_inizio >= oggi) del viaggio a cui appartiene il contenuto, con il flag dell'edizione in lavorazione. Usata dal promemoria in testa all'anteprima. |
| `fn_web_tour_pubblicati` | p_azienda_id integer, p_lingua character DEFAULT 'IT'::bpchar | TABLE(viaggio_id integer, contenuto_id bigint, titolo character varying, sottotitolo character varying, descrizione_html text, slug character varying, difficolta character varying, durata_testo character varying, numero_giorni integer, descrizione_web character varying, descrizione_slug character varying, prezzo_da integer, data_inizio date, data_fine date, immagine_url text, immagine_storage_path character varying, data_pubblicazione timestamp with time zone, ordine integer, incluso text, escluso text, posti_rimasti integer, posti_stato text, is_tour_breve boolean, meta_title character varying, meta_description character varying) |  |
| `fn_web_tour_stato_sezioni` | p_contenuto_id bigint, p_azienda_id integer, p_lingue character varying[] | TABLE(ha_slug boolean, ha_sottotitolo boolean, ha_descrizione boolean, n_immagini integer, ha_principale boolean, n_giornate integer, n_traducibili integer, n_tradotte integer, n_revisionate integer) | Fatti grezzi per il semaforo dei sotto-tab contenuti web di una edizione. n_tradotte = righe presenti; n_revisionate = revisionate e non obsolete (è questo che rende Completo il tab Traduzioni e sblocca la pubblicazione). Soglie in C# (WebTabStatoRules). |
| `fn_web_tour_verifiche` | p_contenuto_id bigint, p_azienda_id integer | TABLE(n_giornate integer, n_giornate_senza_passi integer, n_giornate_senza_foto integer, n_giornate_senza_mappa integer, ha_mappa_insieme boolean, n_immagini integer, ha_meta_title boolean, ha_meta_description boolean, ha_incluso boolean, ha_escluso boolean, ha_capienza boolean) | Fatti grezzi per le verifiche NON bloccanti sui contenuti web di una edizione (giornate senza foto/mappa/passi, galleria vuota, SEO, incluso/escluso, capienza). Soglie e messaggi in C# (WebVerificheRules). |
| `fn_web_traduzioni_approva_contenuto` | p_contenuto_id bigint, p_azienda_id integer, p_lingue character varying[] | integer | Approva in blocco le traduzioni di una edizione (revisionato=true, obsoleto=false). Ritorna quante righe sono cambiate. La condizione "almeno una revisionata a mano per lingua" è applicata dalla UI. |
| `fn_web_traduzioni_delete` | p_id bigint, p_azienda_id integer | integer |  |
| `fn_web_traduzioni_get` | p_id bigint, p_azienda_id integer | SETOF web_traduzioni |  |
| `fn_web_traduzioni_insert` | p_azienda_id integer, p_entita character varying, p_entita_id bigint, p_campo character varying, p_lingua character varying, p_testo text, p_tradotto_auto boolean DEFAULT true, p_revisionato boolean DEFAULT false, p_obsoleto boolean DEFAULT false, p_data_traduzione timestamp with time zone DEFAULT NULL::timestamp with time zone | bigint |  |
| `fn_web_traduzioni_list` | p_azienda_id integer | SETOF web_traduzioni |  |
| `fn_web_traduzioni_list_by_entita` | p_entita character varying, p_entita_id bigint, p_azienda_id integer | SETOF web_traduzioni |  |
| `fn_web_traduzioni_marca_obsolete` | p_azienda_id integer, p_entita character varying, p_entita_id bigint, p_campo character varying | integer |  |
| `fn_web_traduzioni_marca_obsolete_global` | p_entita character varying, p_entita_id bigint, p_campo character varying | integer |  |
| `fn_web_traduzioni_per_contenuto` | p_contenuto_id bigint, p_azienda_id integer | TABLE(entita character varying, entita_id bigint, campo character varying, lingua character, testo text, revisionato boolean, obsoleto boolean) | Traduzioni (tutte le lingue) dei campi traducibili di una edizione. L'anteprima le usa per mostrare il contenuto in lingua e per capire quali lingue sono complete. |
| `fn_web_traduzioni_update` | p_id bigint, p_azienda_id integer, p_entita character varying, p_entita_id bigint, p_campo character varying, p_lingua character varying, p_testo text, p_tradotto_auto boolean, p_revisionato boolean, p_obsoleto boolean, p_data_traduzione timestamp with time zone | integer |  |
| `fn_web_traduzioni_upsert` | p_azienda_id integer, p_entita character varying, p_entita_id bigint, p_campo character varying, p_lingua character varying, p_testo text | bigint |  |
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
| `fn_wizard_get_viaggi_disponibili` | p_azienda_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_link character varying, nome_nazione character varying) | I viaggi che il sito puo' proporre: quelli con almeno una partenza iscrivibile secondo |
| `fn_partenza_iscrivibile — la stessa regola che decide se l'iscrizione viene accettata.` |  |  |  |
| `fn_wizard_get_viaggio_by_id` | p_viaggio_id integer | TABLE(viaggio_id integer, viaggio_descrizione_breve character varying, viaggio_descrizione_estesa text, viaggio_numero_giorni integer, viaggio_numero_notti integer, viaggio_pasti_al_sacco character, viaggio_num_km integer, viaggio_note text, viaggio_link character varying, viaggio_tipo_pernottamento_fk integer, azienda_id integer, nome_nazione character varying, ana_tipo_pernottamento_con_albergo character) |  |
| `fn_wizard_insert_alloggio_assegnato` | p_viaggio_id integer, p_data_viaggio_id integer, p_tipo_alloggio_id integer, p_cli1 integer, p_cli2 integer, p_cli3 integer, p_cli4 integer, p_cli5 integer, p_cli6 integer, p_created_by character varying | void | Inserisce un assegnazione alloggio in mov_clienti_alloggi con fino a 6 partecipanti. Usato da insert_alloggi_assegnati() in mov_clienti_alloggi_dao.py. |
| `fn_wizard_insert_cliente` | p_azienda_id integer, p_titolo character varying, p_cognome character varying, p_nome character varying, p_sesso character varying, p_comune_residenza_fk integer, p_indirizzo_residenza character varying, p_comune_nascita_fk integer, p_data_nascita date, p_preftelint character varying, p_telefono character varying, p_email character varying, p_codicefiscale character varying, p_intolleranza text, p_tipodoc_identita character varying, p_documento_numero character varying, p_documento_rilasciato_da character varying, p_documento_rilasciato_data date, p_documento_rilasciato_scadenza date, p_created_by character varying DEFAULT 'WIZARD'::character varying | integer | Inserisce un nuovo cliente in ana_clienti e restituisce il nuovo cliente_id. Usato da insert_cliente() in cliente.py. |
| `fn_wizard_insert_prenotazione` | p_viaggio_id integer, p_data_viaggio_id integer, p_cliente_id integer, p_tipo_partecipante integer, p_pilota_id integer, p_mezzo_id integer, p_modello_id integer, p_targa character varying, p_has_cane character varying, p_notes text | void | Inserisce una riga di partecipazione in mov_clienti_viaggi (pilota o passeggero). Usato da insert_prenotazione() in mov_clienti_viaggi_dao.py. |
| `fn_wizard_is_cliente_registrato` | p_cliente_id integer, p_viaggio_id integer, p_data_viaggio_id integer | boolean |  |
| `fn_wizard_leggi_dati_cliente` | p_email character varying, p_azienda_id integer | TABLE(cliente_id integer, cliente_titolo character varying, cliente_cognome character varying, cliente_nome character varying, cliente_sesso character, cliente_comune_residenza_fk integer, descrizione_comune_residenza character varying, cliente_indirizzo_residenza character varying, cliente_comune_nascita_fk integer, descrizione_comune_nascita character varying, cliente_data_nascita date, cliente_preftelint character varying, cliente_telefono character varying, cliente_email character varying, cliente_codicefiscale character varying, cliente_intolleranza text, cliente_tipodoc_identita character varying, cliente_documento_numero character varying, cliente_documento_rilasciato_da character varying, cliente_documento_rilasciato_data date, cliente_documento_rilasciato_scadenza date, cliente_titolo_fk integer, consenso_marketing boolean) |  |
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
| `get_viaggi_grouped_by_year` | p_azienda_id integer | TABLE(anno integer, viaggio_id integer, viaggio_descrizione text, data_viaggio_id integer, data_inizio date, data_fine date, effettuato_sino character, iscritti integer) |  |
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
| `sp_ana_date_viaggi_delete` | p_data_viaggio_id integer | TABLE(deleted boolean, error_message text) | Elimina una partenza previe guardie: rifiuta le partenze effettuate o già iniziate (storico aziendale), quelle con una scheda di contenuti web e quelle con prenotazioni o alloggi. Ritorna (deleted, error_message) invece di sollevare eccezioni, così la UI mostra un avviso e non un errore. |
| `sp_ana_date_viaggi_update` | p_data_viaggio_id integer, p_data_viaggio_data_inizio date, p_data_viaggio_data_fine date, p_data_viaggio_effettuato_sino character, p_data_viaggio_costo_pilota integer, p_data_viaggio_costo_passeggero integer, p_data_viaggio_costo_passeggero_auto_guida integer, p_data_viaggio_costo_bambino_0_2 integer, p_data_viaggio_costo_bambino_2_6 integer, p_data_viaggio_costo_bambino_6_12 integer, p_data_viaggio_note character varying, p_azienda_id integer, p_updated_by character varying, p_updated timestamp with time zone | void |  |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false, p_tipo_documento_sdi character varying DEFAULT NULL::character varying | integer |  |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false | integer |  |
| `sp_ana_tipi_causali_create` | p_azienda_fk integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_created_by character varying DEFAULT NULL::character varying, p_updated_by character varying DEFAULT NULL::character varying | integer | Crea nuova causale con validazione completa e normalizzazione automatica UPPER CASE. |
| `sp_ana_tipi_causali_delete` | p_causale_id integer | void | Elimina causale. Blocca eliminazione se in uso da transazioni. |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean, p_causale_giorni_scadenza_default integer, p_causale_genera_scadenza_auto boolean, p_causale_genera_iva boolean, p_causale_richiede_iva boolean, p_causale_aliquota_iva_default_fk integer, p_is_active boolean, p_updated_by character varying | void | Aggiorna causale esistente con validazione completa e normalizzazione automatica UPPER CASE. |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false | void |  |
| `sp_ana_tipi_causali_update` | p_causale_id integer, p_causale_codice character varying, p_causale_descrizione character varying, p_causale_segno integer, p_causale_is_documento boolean, p_causale_ciclo character varying, p_causale_richiede_scadenza boolean DEFAULT false, p_causale_giorni_scadenza_default integer DEFAULT NULL::integer, p_causale_genera_scadenza_auto boolean DEFAULT false, p_causale_genera_iva boolean DEFAULT false, p_causale_richiede_iva boolean DEFAULT false, p_causale_aliquota_iva_default_fk integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_updated_by character varying DEFAULT NULL::character varying, p_causale_concorre_fatturato boolean DEFAULT false, p_tipo_documento_sdi character varying DEFAULT NULL::character varying | void |  |
| `sp_ana_tipo_fornitore_create` | p_azienda_fk integer, p_descrizione character varying, p_categoria character varying DEFAULT NULL::character varying, p_conto_contabile_default character varying DEFAULT NULL::character varying | integer | Crea nuovo tipo fornitore con normalizzazione UPPER CASE e validazioni business logic |
| `sp_ana_tipo_fornitore_delete` | p_tipo_fornitore_id integer | void | Elimina tipo fornitore. Blocca eliminazione se in uso da controparti (FK violation) |
| `sp_ana_tipo_fornitore_update` | p_tipo_fornitore_id integer, p_descrizione character varying, p_categoria character varying DEFAULT NULL::character varying, p_conto_contabile_default character varying DEFAULT NULL::character varying | void | Aggiorna tipo fornitore esistente con normalizzazione UPPER CASE e validazioni |
| `sp_ana_viaggi_create` | p_viaggio_descrizione_breve character varying, p_viaggio_descrizione_estesa text, p_viaggio_numero_giorni integer, p_viaggio_numero_notti integer, p_viaggio_pasti_al_sacco character, p_viaggio_num_km integer, p_viaggio_difficolta character varying, p_viaggio_incluso text, p_viaggio_escluso text, p_viaggio_capienza_max integer, p_viaggio_capienza_alert integer, p_viaggio_tipo_avvicinamento_fk integer, p_viaggio_note text, p_viaggio_link character varying, p_viaggio_nazione_fk integer, p_viaggio_tipo_viaggio_fk integer, p_viaggio_tipo_trattamento_fk integer, p_viaggio_tipo_pernottamento_fk integer, p_azienda_id integer, p_created_by character varying, p_created timestamp with time zone, p_updated_by character varying, p_updated timestamp with time zone | integer |  |
| `sp_ana_viaggi_delete` | p_viaggio_id integer | TABLE(deleted boolean, error_message text) |  |
| `sp_ana_viaggi_update` | p_viaggio_id integer, p_viaggio_descrizione_breve character varying, p_viaggio_descrizione_estesa text, p_viaggio_numero_giorni integer, p_viaggio_numero_notti integer, p_viaggio_pasti_al_sacco character, p_viaggio_num_km integer, p_viaggio_difficolta character varying, p_viaggio_incluso text, p_viaggio_escluso text, p_viaggio_capienza_max integer, p_viaggio_capienza_alert integer, p_viaggio_tipo_avvicinamento_fk integer, p_viaggio_note text, p_viaggio_link character varying, p_viaggio_nazione_fk integer, p_viaggio_tipo_viaggio_fk integer, p_viaggio_tipo_trattamento_fk integer, p_viaggio_tipo_pernottamento_fk integer, p_azienda_id integer, p_updated_by character varying, p_updated timestamp with time zone | void |  |
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
| `trg_ana_clienti_sesso_dal_titolo` |  | trigger |  |
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
| `trg_mov_clienti_viaggi_posti_func` |  | trigger |  |
| `trg_prevent_client_delete_alloggi_func` |  | trigger |  |
| `trg_prevent_client_delete_func` |  | trigger |  |
| `trg_user_roles_delete_protection` |  | trigger |  |
| `trg_user_roles_updated_at` |  | trigger |  |
| `trg_web_audit` |  | trigger |  |
| `trg_web_newsletter_blocchi_pulizia_trad` |  | trigger |  |
| `trg_web_newsletter_blocco_eredita` |  | trigger |  |
| `trg_web_newsletter_invii_pulizia_trad` |  | trigger |  |
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
- `fn_alloggi_assegnazione_valida`
- `fn_alloggi_combinazioni`
- `fn_alloggi_tipi_ammessi`
- `fn_ana_alloggio_generi_delete`
- `fn_ana_alloggio_generi_get_all`
- `fn_ana_alloggio_generi_upsert`
- `fn_ana_aziende_email_principale`
- `fn_ana_aziende_esp_delete`
- `fn_ana_aziende_esp_get`
- `fn_ana_aziende_esp_get_by_azienda`
- `fn_ana_aziende_esp_get_key`
- `fn_ana_aziende_esp_insert`
- `fn_ana_aziende_esp_update`
- `fn_ana_aziende_get_claude_key`
- `fn_ana_aziende_set_claude_key`
- `fn_ana_clienti_aggancia_email`
- `fn_ana_clienti_campi_mancanti`
- `fn_ana_clienti_delete`
- `fn_ana_clienti_get_consenso`
- `fn_ana_clienti_get_lingua`
- `fn_ana_clienti_guardia`
- `fn_ana_clienti_nascita_modificata`
- `fn_ana_clienti_set_consenso`
- `fn_ana_clienti_set_lingua`
- `fn_ana_clienti_titolo_fk`
- `fn_ana_clienti_update`
- `fn_ana_controparti_get_by_id`
- `fn_ana_date_viaggi_effettuato_guardia`
- `fn_ana_date_viaggi_get_by_id`
- `fn_ana_mezzi_marche_per_tipo`
- `fn_ana_tel_pref_int_get_all`
- `fn_ana_tipo_alloggio_get_all`
- `fn_ana_tipo_alloggio_upsert`
- `fn_ana_tipo_documento_get_all`
- `fn_ana_tipo_pernottamento_generi_get`
- `fn_ana_tipo_pernottamento_generi_set`
- `fn_ana_tipo_viaggi_update`
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
- `fn_cf_calcola`
- `fn_cf_decodifica`
- `fn_cf_omocodia_a_base`
- `fn_cf_verifica`
- `fn_cf_verifica_cliente`
- `fn_cliente_gemello_in_azienda`
- `fn_consenso_da_chiedere`
- `fn_consenso_registra_risposta`
- `fn_documento_esito_per_partenza`
- `fn_e_iscritto`
- `fn_enforce_user_azienda_integrity`
- `fn_get_calendar_data`
- `fn_get_date_viaggi_with_transazioni`
- `fn_get_debug_v2`
- `fn_get_logo_field_help`
- `fn_get_menu_breadcrumbs`
- `fn_get_viaggi_with_transazioni`
- `fn_guardia_alloggio_coerente`
- `fn_guardia_pernottamento_viaggio`
- `fn_guardia_silo_azienda`
- `fn_is_pec_domain`
- `fn_lingua_da_comune`
- `fn_logo_calculate_hash`
- `fn_logo_update_access_stats`
- `fn_logo_validate_mime_type`
- `fn_mov_clienti_alloggi_togli_cliente`
- `fn_mov_clienti_viaggi_cancellazione_effetti`
- `fn_mov_clienti_viaggi_delete`
- `fn_mov_clienti_viaggi_guardia`
- `fn_mov_clienti_viaggi_insert`
- `fn_mov_clienti_viaggi_update`
- `fn_nome_sesso_avviso`
- `fn_partenza_conclusa`
- `fn_partenza_etichetta`
- `fn_partenza_iscrivibile`
- `fn_partenza_motivo_non_iscrivibile`
- `fn_set_azienda_id`
- `fn_silos_movimenti_fuori_azienda`
- `fn_silos_rimappa_movimenti`
- `fn_solo_testo`
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
- `fn_web_ai_config_set`
- `fn_web_ai_consumo_insert`
- `fn_web_ai_consumo_riepilogo`
- `fn_web_ai_prezzi_verificati`
- `fn_web_ai_soglia_da_avvisare`
- `fn_web_aziende_funzioni_delete`
- `fn_web_aziende_funzioni_get`
- `fn_web_aziende_funzioni_get_by_funzione`
- `fn_web_aziende_funzioni_insert`
- `fn_web_aziende_funzioni_list`
- `fn_web_aziende_funzioni_update`
- `fn_web_edizioni_per_viaggio`
- `fn_web_ha_tour_brevi_pubblicati`
- `fn_web_immagini_azienda`
- `fn_web_immagini_libreria_delete`
- `fn_web_immagini_libreria_in_uso`
- `fn_web_immagini_libreria_insert`
- `fn_web_immagini_libreria_list`
- `fn_web_immagini_libreria_rinomina`
- `fn_web_indirizzi_delete`
- `fn_web_indirizzi_get`
- `fn_web_indirizzi_insert`
- `fn_web_indirizzi_update`
- `fn_web_mezzi_occupati_data`
- `fn_web_nazioni_clienti`
- `fn_web_newsletter_blocchi_delete`
- `fn_web_newsletter_blocchi_get`
- `fn_web_newsletter_blocchi_insert`
- `fn_web_newsletter_blocchi_reorder`
- `fn_web_newsletter_blocco_eredita_traduzioni`
- `fn_web_newsletter_clona`
- `fn_web_newsletter_collegamenti_da_verificare`
- `fn_web_newsletter_congela_indirizzi`
- `fn_web_newsletter_conteggio`
- `fn_web_newsletter_corpi_list`
- `fn_web_newsletter_corpo_archivia`
- `fn_web_newsletter_crea_bozza`
- `fn_web_newsletter_dati_azienda`
- `fn_web_newsletter_dati_tour`
- `fn_web_newsletter_elenco`
- `fn_web_newsletter_filtri_delete`
- `fn_web_newsletter_filtri_insert`
- `fn_web_newsletter_filtri_list`
- `fn_web_newsletter_invii_delete`
- `fn_web_newsletter_invii_destinatari_delete`
- `fn_web_newsletter_invii_destinatari_get`
- `fn_web_newsletter_invii_destinatari_insert`
- `fn_web_newsletter_invii_destinatari_list`
- `fn_web_newsletter_invii_destinatari_update`
- `fn_web_newsletter_invii_get`
- `fn_web_newsletter_invii_insert`
- `fn_web_newsletter_invii_list`
- `fn_web_newsletter_iscritti_by_token`
- `fn_web_newsletter_iscritti_delete`
- `fn_web_newsletter_iscritti_get`
- `fn_web_newsletter_iscritti_insert`
- `fn_web_newsletter_iscritti_list`
- `fn_web_newsletter_iscritti_update`
- `fn_web_newsletter_periodi`
- `fn_web_newsletter_set_oggetto`
- `fn_web_newsletter_soppressioni_delete`
- `fn_web_newsletter_soppressioni_get`
- `fn_web_newsletter_soppressioni_insert`
- `fn_web_newsletter_soppressioni_list`
- `fn_web_newsletter_soppressioni_update`
- `fn_web_newsletter_tipi_blocco`
- `fn_web_newsletter_traduzioni`
- `fn_web_newsletter_traduzioni_stato`
- `fn_web_prezzo_da_data`
- `fn_web_recensioni_config`
- `fn_web_tipi_viaggio_descrizioni_delete`
- `fn_web_tipi_viaggio_descrizioni_get`
- `fn_web_tipi_viaggio_descrizioni_insert`
- `fn_web_tipi_viaggio_descrizioni_list`
- `fn_web_tipi_viaggio_descrizioni_update`
- `fn_web_tour_campi_traducibili`
- `fn_web_tour_contenuti_clona`
- `fn_web_tour_contenuti_delete`
- `fn_web_tour_contenuti_get`
- `fn_web_tour_contenuti_get_by_data_viaggio`
- `fn_web_tour_contenuti_get_by_viaggio`
- `fn_web_tour_contenuti_insert`
- `fn_web_tour_contenuti_list`
- `fn_web_tour_contenuti_update`
- `fn_web_tour_immagini_get`
- `fn_web_tour_immagini_list`
- `fn_web_tour_immagini_reorder`
- `fn_web_tour_immagini_set_principale`
- `fn_web_tour_itinerario_delete`
- `fn_web_tour_itinerario_get`
- `fn_web_tour_itinerario_insert`
- `fn_web_tour_itinerario_list`
- `fn_web_tour_itinerario_passaggi_delete`
- `fn_web_tour_itinerario_passaggi_get`
- `fn_web_tour_itinerario_passaggi_insert`
- `fn_web_tour_itinerario_passaggi_list`
- `fn_web_tour_itinerario_passaggi_reorder`
- `fn_web_tour_itinerario_passaggi_update`
- `fn_web_tour_itinerario_update`
- `fn_web_tour_mappa_delete`
- `fn_web_tour_mappa_get`
- `fn_web_tour_mappa_get_by_contenuto`
- `fn_web_tour_mappa_get_by_giornata`
- `fn_web_tour_mappa_insert`
- `fn_web_tour_mappa_list`
- `fn_web_tour_mappa_list_by_contenuto`
- `fn_web_tour_mappa_update`
- `fn_web_tour_prossime_partenze`
- `fn_web_tour_stato_sezioni`
- `fn_web_tour_verifiche`
- `fn_web_traduzioni_approva_contenuto`
- `fn_web_traduzioni_delete`
- `fn_web_traduzioni_get`
- `fn_web_traduzioni_insert`
- `fn_web_traduzioni_list`
- `fn_web_traduzioni_list_by_entita`
- `fn_web_traduzioni_marca_obsolete_global`
- `fn_web_traduzioni_per_contenuto`
- `fn_web_traduzioni_update`
- `fn_web_traduzioni_upsert`
- `get_all_participants_travel`
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
- `trg_mov_clienti_viaggi_posti_func`
- `trg_prevent_client_delete_alloggi_func`
- `trg_prevent_client_delete_func`
- `trg_user_roles_delete_protection`
- `trg_user_roles_updated_at`
- `trg_web_newsletter_blocchi_pulizia_trad`
- `trg_web_newsletter_blocco_eredita`
- `trg_web_newsletter_invii_pulizia_trad`
- `update_changetimestamp_column`
- `update_modified_column`
- `update_updated_at_column`
- `validate_fiscal_data`
<!-- AUTO-GENERATED-END -->
