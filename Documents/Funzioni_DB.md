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
| `fn_get_viaggi_init_data` | **FAT INIT FUNCTION**: Recupera in un'unica chiamata tutti i lookups necessari per il dialog viaggi (Nazioni, TipiViaggio, TipiTrattamento, TipiPernottamento, TipiAvvicinamento, Aziende) + le date del viaggio (se `p_viaggio_id` fornito) con contatori `totMezzi` e `totClienti`. Restituisce JSON con chiavi in camelCase. **Fixed 2026-03-16**: Corretti campi date per includere tutti i costi bambini, note e campi audit necessari per deserializzazione corretta in AnaDataViaggio. | `p_viaggio_id integer DEFAULT NULL` | `json` (include dates con tutti i campi: id, viaggioIdFk, dataInizio, dataFine, effettuatoSino, costoPilota, costoPasseggero, costoPasseggeroAutoGuida, costoBambino02/26/612, note, totMezzi, totClienti, aziendaId, createdBy, created, updatedBy, updated) | `Services/CRUD/AnaViaggiService.cs`, `Components/Shared/AnaViaggiDialog.razor` |
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
| `sp_mov_clienti_viaggi_create` | Iscrive partecipante al viaggio | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_update` | Aggiorna dati iscrizione partecipante | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_viaggi_delete` | Rimuove partecipante dal viaggio (con cleanup alloggi) | `p_viaggio_id integer, ...` | `void` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_sorted` | Restituisce partecipanti ordinati per equipaggio, inclusi dati anagrafici e documenti completi. | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_count` | Conteggio totale partecipanti efficiente | `p_data_viaggio_id integer` | `integer` | `Services/CRUD/MovClientiViaggiService.cs` |
| `get_participants_without_accommodation` | Restituisce solo partecipanti senza camera assegnata | `p_data_viaggio_id integer` | `TABLE(...)` | `Services/CRUD/MovClientiViaggiService.cs` |
| `sp_mov_clienti_alloggi_create` | Crea associazione cliente-alloggio | `p_viaggio_id integer, ...` | `integer` | `Services/CRUD/MovClientiAlloggiService.cs` |
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

Le operazioni CRUD sul cliente (INSERT, UPDATE) e le verifiche di unicita (CF, email per anagrafica) usano **SQL diretto** nei DAO Python, non funzioni `fn_wizard_*`. Questo perche la logica e semplice e lineare (singolo INSERT/UPDATE con RETURNING).

**Tabelle coinvolte**: `ana_clienti`, `ana_geo_comuni`
**DAO**: `Classi_Tabelle_DB/cliente.py`

Operazioni:
- `insert_cliente()` → INSERT INTO ana_clienti ... RETURNING cliente_id
- `update_cliente()` → UPDATE ana_clienti SET ... WHERE cliente_id = ?
- `get_client_data()` → SELECT da ana_clienti JOIN ana_geo_comuni (per validazione CF)
- `find_existing_email_by_anagrafica()` → SELECT cliente_email WHERE cognome+nome+cf
- `find_existing_email_by_cf()` → SELECT cliente_email WHERE codicefiscale
- `check_codice_fiscale_esistenza()` → SELECT 1 WHERE codicefiscale (con esclusione ID)

**Gestione errori**: `UniqueViolation` su codice fiscale genera `UniqueConstraintViolationError` con email del cliente esistente.

**Dati geografici**: Riutilizzano le funzioni MAUI esistenti `fn_app_get_comuni_lookup` e `fn_app_get_comune_by_id` (sezione 3).

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

### 12.6 Finalizzazione e Email

| Nome della Function | Scopo | Input | Output | Files Coinvolti |
| :--- | :--- | :--- | :--- | :--- |
| `fn_wizard_get_smtp_config` | Recupera la configurazione SMTP per un'azienda dalla tabella `ana_aziende_smtp`. Restituisce host, porta, username, password (da `password_enc->>'value'`), metodo sicurezza, email e nome mittente. Usato da `create_app()` per configurare Flask-Mail. | `p_azienda_id INT` | `TABLE(host, port, username, password, security_method, from_email, from_name)` | `app.py` (funzione `create_app()`) |

La finalizzazione della prenotazione (INSERT in `mov_clienti_viaggi` e `mov_clienti_alloggi`) usa **SQL diretto** con transazione esplicita, non stored procedure. I campi audit (`created_by`, `updated_by`) sono gestiti tramite trigger di tabella che leggono `current_setting('my.app_user', true)`.

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

**Totale funzioni fn_wizard_***: 18 (7 Step 1 + 1 Step 3 + 6 Step 4 + 3 Step 5 + 1 Email)

### `fn_get_viaggi_init_data`
Recupera tutti i lookups (Nazioni, Tipi Viaggio, Trattamenti, Pernottamenti, Avvicinamenti, Aziende) e le date di un viaggio in un'unica chiamata JSON. Utilizzata per l'inizializzazione di `AnaViaggiDialog.razor`.

- **Parametri**:
  - `p_viaggio_id` (INT, default NULL): ID del viaggio per recuperare le date (modalità edit).
- **Ritorna**: `JSON` contenente gli array di lookup e le date.
- **Utilizzo**: `AnaViaggiService.GetViaggiInitDataAsync(int? viaggioId)`

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

### `fn_get_viaggi_init_data`
Recupera in un'unica chiamata JSON tutti i lookups (Nazioni, Tipi Viaggio, Trattamenti, Pernottamenti, Avvicinamenti, Aziende) e le date di un viaggio. Utilizzata per l'inizializzazione di `AnaViaggiDialog.razor`.

- **Parametri**:
  - `p_viaggio_id` (INT, default NULL): ID del viaggio per recuperare le date (modalità edit).
- **Ritorna**: `JSON` contenente gli array di lookup e le date.
- **Utilizzo**: `AnaViaggiService.GetViaggiInitDataAsync(int? viaggioId)`

### `fn_get_viaggio_partecipanti_init_data`
Recupera l'intero stato iniziale del dialog gestione partecipanti, inclusi partecipanti (ordinati e senza camera), contatori, riepiloghi, liste camere con occupanti, intestazione viaggio e lookups necessari. Consolidamento di circa 9 chiamate separate.

- **Parametri**:
  - `p_viaggio_id` (INT): ID del viaggio.
  - `p_data_viaggio_id` (INT): ID della data viaggio specifica.
- **Ritorna**: `JSON` con lo stato completo del dialog.
- **Utilizzo**: `MovClientiViaggiService.GetPartecipantiInitDataAsync(int viaggioId, int dataViaggioId)`

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
