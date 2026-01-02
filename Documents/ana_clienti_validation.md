# Specifica Validazioni: ana_clienti

**Progetto**: Gestione Viaggi (MAUI/C#/PostgreSQL)
**Tabella**: ana_clienti (Anagrafica Clienti)
**Data Ultimo Aggiornamento**: 2026-01-02
**Scopo**: Definire i controlli e validazioni da implementare per la gestione anagrafica clienti
**Riferimento**: Progetto Iscrizione-Viaggi-Offroad (Oracle/Python/React) - Applicazione in produzione

---

## INDICE

1. [Scopo del Documento](#scopo-del-documento)
2. [Controlli da Implementare - Database](#controlli-da-implementare---database)
3. [Controlli da Implementare - Backend C#](#controlli-da-implementare---backend-c)
4. [Controlli da Implementare - Frontend MAUI](#controlli-da-implementare---frontend-maui)
5. [Validazione Codice Fiscale - Specifica](#validazione-codice-fiscale---specifica)
6. [Tabella Riepilogativa: Controlli, Motivazioni e Validatori](#tabella-riepilogativa-controlli-motivazioni-e-validatori)
7. [Flussi Operativi da Implementare](#flussi-operativi-da-implementare)
8. [Componenti Già Implementati](#componenti-già-implementati)
9. [Roadmap Implementazione](#roadmap-implementazione)

---

## SCOPO DEL DOCUMENTO

Questo documento definisce **tutti i controlli e validazioni** che devono essere implementati nel nuovo gestionale MAUI per la tabella `ana_clienti`.

### Contesto

L'applicazione **Iscrizione-Viaggi-Offroad** (Oracle/Python/React) gestisce con successo l'iscrizione autonoma dei clienti ai viaggi in produzione. Quella soluzione ha validazioni robuste e user experience eccellente che **dobbiamo replicare** nel nuovo gestionale aziendale.

### Differenze Chiave

| Aspetto | App Iscrizione (Riferimento) | Gestionale MAUI (Da Realizzare) |
|---------|------------------------------|----------------------------------|
| **Scopo** | Iscrizione autonoma clienti a viaggi | Gestione completa anagrafica aziendale |
| **Utenti** | Clienti finali (auto-registrazione) | Operatori aziendali (back-office) |
| **Stack** | Oracle, Python/Flask, React | PostgreSQL, C#/.NET, MAUI |
| **Validazioni** | Real-time con feedback immediato | Stesse validazioni + controlli aggiuntivi aziendali |
| **Multi-tenant** | No | Sì (azienda_fk obbligatorio) |

### Obiettivo

Garantire che **nessun errore possa essere commesso** nella gestione di `ana_clienti`, il file più critico del gestionale, replicando la robustezza del sistema in produzione e adattandola al contesto aziendale.

---

## CONTROLLI DA IMPLEMENTARE - DATABASE

### Constraint da Creare

#### 1. NOT NULL (Campi Obbligatori)

**Motivazione**: Completezza anagrafica minima richiesta per operatività

| Campo | Giustificazione Business |
|-------|--------------------------|
| cliente_cognome | Identificazione cliente essenziale |
| cliente_nome | Identificazione cliente essenziale |
| cliente_sesso | Necessario per calcolo codice fiscale |
| cliente_comune_residenza_fk | Obbligatorio per legge |
| cliente_comune_nascita_fk | Necessario per calcolo codice fiscale |
| azienda_fk | Multi-tenant: ogni cliente appartiene a un'azienda |

> [!NOTE]
> **Opzione B Implementata**:
> I seguenti campi sono resi **obbligatori SOLAMENTE nell'interfaccia utente (C#)** tramite `[Required]` attributi nel Model e nel Dialog, ma rimangono **Nullable sul DB** per compatibilità con i dati storici esistenti:
> *   `cliente_email`
> *   `cliente_titolo`
> *   `cliente_tipodoc_identita` (Sezione Documenti)
> *   `cliente_documento_numero` (Sezione Documenti)
> *   `cliente_documento_rilasciato_da` (Sezione Documenti)
> *   `cliente_documento_rilasciato_data` (Sezione Documenti)
> *   `cliente_documento_rilasciato_scadenza` (Sezione Documenti)

**Implementazione**: Constraint NOT NULL a livello DDL PostgreSQL

**Stato**:
- ✅ Già implementato nel database locale
- ✅ Backend C# gestisce errori NOT NULL
- ✅ Frontend applica attributi `[Required]` per enforcement visivo strict

---

#### 2. CHECK Constraint (Valori Ammessi)

**Constraint**: Sesso M/F
```sql
CHECK (cliente_sesso = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))
```

**Motivazione**:
- Calcolo codice fiscale richiede M o F
- Statistiche e reportistica
- Evitare valori inconsistenti

**Stato**:
- ✅ Già implementato nel database
- ✅ Backend valida PRIMA di tentare INSERT (Gestito da ClienteValidator)
- ✅ Frontend offre solo M/F

---

#### 3. FOREIGN KEY (Integrità Referenziale)

**Constraint da Verificare**:

| FK | Tabella Riferita | Motivazione |
|----|------------------|-------------|
| cliente_comune_residenza_fk | ana_geo_comuni | Solo comuni esistenti |
| cliente_comune_nascita_fk | ana_geo_comuni | Solo comuni esistenti |
| azienda_fk | ana_aziende | Multi-tenant: isolamento dati |

**Stato**:
- ✅ FK già create nel database
- ✅ Frontend usa `ComuneSelect` per selezione sicura
- ✅ Backend gestisce FK violation

---

#### 4. UNIQUE Constraint (Unicità Dati)

**4.1 Chiave Primaria**
- Campo: `cliente_id`
- Gestione: Auto-increment tramite sequence `ana_clienti_seq`
- Trigger: `trg_ana_clienti_audit_unified` assegna ID automaticamente

**Stato**:
- ✅ Sequence e trigger già implementati
- ✅ Backend NON passa cliente_id in INSERT

**4.2 Indice Univoco Composito Scoped (Multi-tenant)**
```sql
UNIQUE (azienda_fk, cliente_cognome, cliente_nome, cliente_data_nascita, cliente_codicefiscale)
```
*(Indice `ana_clienti_idx06` aggiornato)*

**Motivazione**: Evitare duplicati *all'interno della stessa azienda*. È permesso avere lo stesso cliente registrato (con stesso CF) in aziende (tenant) diverse.

**Scenario di Errore**:
- Utente inserisce "Mario Rossi, 01/01/1980, RSSMRA80A01H501Z"
- Constraint rileva duplicato
- Backend cattura eccezione PostgreSQL 23505
- Trova email del cliente esistente
- Mostra messaggio: "Cliente già presente con email: mario.rossi@example.com"

**Stato**:
- ✅ Constraint scoped aggiornato nel database
- ✅ Backend implementa gestione eccezione 23505 (ClienteService)
- ✅ `FindExistingEmailByAnagrafica` implementato
- ✅ Frontend mostra Toast Warning

---

### Trigger da Verificare/Creare

#### TRIGGER 1: trg_ana_clienti_audit_unified

**Scopo**: Auto-increment ID + Audit trail automatico
**Funzionalità**:
- **INSERT**: Assegna `cliente_id`, popola `created_by`, `created`, `updated_by`, `updated`
- **UPDATE**: Aggiorna sempre `updated`, popola `updated_by` se NULL
- **Priorità utente**: `my.app_user` → `current_user` → `'system'`

**Stato**:
- ✅ Trigger già implementato e ottimizzato

---

#### TRIGGER 2: trg_prevent_client_delete

**Scopo**: Impedire cancellazione clienti con storico viaggi
**Logica**: Verifica presenza in `mov_clienti_viaggi`

**Stato**:
- ✅ Trigger già implementato
- ✅ Frontend gestisce eccezione `42P01` corretta (table name fix)

---

#### TRIGGER 3: trg_prevent_client_delete_alloggi

**Scopo**: Impedire cancellazione clienti presenti in prenotazioni alloggi
**Logica**: Verifica presenza in uno qualsiasi dei 6 campi cliente di `mov_clienti_alloggi`

**Stato**:
- ✅ Trigger già implementato
- ✅ Frontend gestione eccezione corretta

---

### Indici da Creare/Verificare

**Indici per Performance Query Validazione**:

| Indice | Campo | Scopo |
|--------|-------|-------|
| idx_ana_clienti_email | cliente_email | Ricerca rapida per email (verifica esistenza) |
| idx_ana_clienti_codicefiscale | cliente_codicefiscale | Ricerca rapida per CF (verifica unicità) |

**Stato**:
- ✅ Indici già creati
- ✅ Service Layer usa campi indicizzati

---

## CONTROLLI DA IMPLEMENTARE - BACKEND C#

### Service Layer (Business Logic)

#### ClienteService.cs

**Responsabilità**: Orchestrare validazioni + operazioni database.

**Validazioni Avanzate Implementate**:

1.  **Clienti IT vs Esteri (Logica Condizionale CF)**
    *   **Regola**: Il Codice Fiscale è obbligatorio *solo* se il cliente è residente in Italia (o comune non specificato).
    *   **Implementazione**: Verifica `ComuneResidenza.ComuneEstero` (flag da DB). Se `true`, CF è opzionale.
    *   **Validazione Strict**: Se cliente è IT, il campo CF non può essere vuoto e deve rispettare formato/algoritmo.

2.  **Validazioni Campi Documento (Consistency)**
    *   **Rilascio vs Scadenza**: `DocumentoRilasciatoData` deve essere < `DocumentoRilasciatoScadenza`.
    *   **Rilascio vs Nascita**: `DocumentoRilasciatoData` deve essere > `DataNascita`.
    *   **Rilascio Futuro**: `DocumentoRilasciatoData` non può essere futura.

3.  **Unicità Scoped (Multi-Tenant)**
    *   Tutti i check unicità (Email, CF, Anagrafica) includono obbligatoriamente `aziendaFk` nella clausola WHERE.
    *   Permette la registrazione dello stesso cliente su Azienda A e Azienda B.

**Metodi Chiave (Completati)**:
- ✅ `VerificaClienteEsistenteAsync(email, aziendaFk)`
- ✅ `CheckCodiceFiscaleEsistenzaAsync(cf, aziendaFk)`
- ✅ `FindExistingByAnagraficaAsync(cognome, nome, data, cf, aziendaFk)`
- ✅ `CreateAsync(cliente)`: Validazione completa → Insert → Gestione duplicati

---

## CONTROLLI DA IMPLEMENTARE - FRONTEND MAUI

### Strategia Validazione UI

**Principi Applicati**:
1. **Validazione Real-Time**: Feedback immediato (DateMask, formattazione input).
2. **Validazione On-Blur**: Controllo completo formato CF, email, telefono.
3. **Validazione Pre-Save**: Blocco UI se form invalido.
4. **Enforcement Input**:
    *   **Uppercase Forzato**: Tutti i campi testuali (`Cognome`, `Nome`, `Indirizzo`, `Note`, `Intolleranza`) vengono automaticamente convertiti in maiuscolo.
    *   **Trim Automatico**: Rimozione spazi superflui.

### Form Anagrafica Cliente - Integrazioni Recenti

**Refactoring Input Date**:
*   **Problema**: Cursore "saltava" digitando l'anno velocemente.
*   **Soluzione**: Implementate istanze `DateMask` **dedicate per campo** (`_maskDataNascita`, `_maskDataRilascio`, ecc.) in `ClienteDialog` e `AziendaDialog` per isolare lo stato del cursore.

**Campi Obbligatori (Option B - UI Only)**:
I seguenti campi mostrano l'asterisco (*) e bloccano il salvataggio se vuoti, garantendo qualità dati anche se il DB è permissivo:
*   Titolo
*   Tipo Documento
*   Numero Documento (Se Tipo Doc selezionato)
*   Ente Rilascio (Se Tipo Doc selezionato)
*   Date Documento (Se Tipo Doc selezionato)

**Validazione Codice Fiscale - Aggiornata**:
*   **Client Side**: Controllo regex immediato.
*   **Server Side**: Controllo unicità con debounce (800ms) verso DB.
*   **Logica Estero**: Se `ComuneResidenza` è estero, il validatore CF viene bypassato (return empty errors).

---

## TABELLA RIEPILOGATIVA: CONTROLLI, MOTIVAZIONI E VALIDATORI

| # | Tipo Controllo | Campo/i | Motivazione Business | Validatore C# | Status |
|---|----------------|---------|----------------------|---------------|--------|
| 1 | **Lunghezza + Uppercase** | cognome, nome, indirizzo | Standardizzazione visuale | `FieldLengthValidator` + `NormalizeEntity` | ✅ |
| 2 | **Obbligatorietà UI** | titolo, documenti | Qualità dati senza lock DB | `[Required]` Attribute | ✅ |
| 3 | **Clienti Esteri** | codice_fiscale | CF non esiste estero | `ValidateCodiceFiscaleAsync` (conditional) | ✅ |
| 4 | **Date Consistency** | documento_date | No doc scaduti al rilascio | `ClienteValidator.ValidateDocumentoData...` | ✅ |
| 5 | **Input Mascherato** | date fields (nascita, doc) | UX digitazione | `DateMask` (istanze dedicate) | ✅ |
| 6 | **Unicità Scoped** | email, cf, anagrafica | Multi-tenant isolation | `ClienteService` (+ aziendaFk) | ✅ |
| 7 | **Sesso M/F** | cliente_sesso | Calcolo CF | `CheckConstraint` + RadioGroup | ✅ |
| 8 | **Range Data Nascita** | cliente_data_nascita | Età verosimile | `ClienteValidator` | ✅ |
| 9 | **CF Algoritmo** | cliente_codicefiscale | Anti-errore digitazione | `CodiceFiscaleValidator` | ✅ |
| 10 | **Prevenzione Delete** | trigger DB | Integrità storico viaggi | `Triggers` + Exception Handler | ✅ |
| 11 | **Refresh UI** | datagrid post-insert | Visualizzazione immediata dati | `GetByIdAsync` (full join) | ✅ |

---

## FLUSSI OPERATIVI DA IMPLEMENTARE

### Flusso Validazione + Inserimento (Stato Attuale)

1.  **UI**: Utente compila form. Date guidate da `DateMask`, testi forzati Uppercase.
2.  **UI**: Se Comune Residenza = Estero → Campo CF diventa opzionale.
3.  **UI**: Change su Documento → Campi Numero/Ente/Date diventano mandatory.
4.  **Submit**:
    *   Chiamata `ClienteService.CreateAsync`.
    *   Service effettua normalizzazione (Trim/Upper).
    *   Service valida business rules (Unicità Email/CF scope Azienda).
    *   Repository esegue INSERT.
    *   **Repository richiama `GetByIdAsync` con JOIN** per restituire oggetto completo (Nome Azienda, Province).
5.  **Return**:
    *   Dialog restituisce oggetto completo.
    *   DataGrid aggiunge row visualizzando correttamente tutte le colonne senza reload.

---
