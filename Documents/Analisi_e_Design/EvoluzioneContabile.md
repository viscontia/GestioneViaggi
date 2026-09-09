# Evoluzione Contabile: Sistema Multi-Regime Fiscale

**Data inizio**: 01/03/2026
**Stato**: COMPLETATO

---

## Contesto

La logica forfettaria e attualmente hardcoded in `MovTransazioniEditDialog.razor:101` (`AziendaId == 2 || AziendaId == 6`) con valori fissi (INPS 4%, bollo 77.47, bollo 2.00). Per scalare verso un modello SaaS con clienti in regimi diversi (ordinario, forfettario, semplificato), serve un sistema data-driven configurabile da DB.

## Approccio

Tabella di configurazione `ana_regimi_fiscali` system-level (NON multi-tenant, i regimi sono definiti dalla legge italiana). FK da `ana_aziende`. Service C# dedicato (`FiscalCalculationService`) che sostituisce la logica hardcoded.

**Decisioni chiave:**
- Parametri di calcolo configurabili da DB (modificabili dal SuperAdmin senza deploy)
- Scope solo Italia (ORDINARIO, FORFETTARIO, SEMPLIFICATO)
- Soglia bollo calcolata su Prestazione + Cassa Previdenziale
- Ordine righe coerente: 1=PRESTAZIONE, 2=CASSA_PREV, 3=BOLLO
- `is_iva_detraibile` impatta calcolo margine (follow-up separato per `vw_margini_viaggi`)

---

## FASE 1: Database [x]

### 1.1 Creare tabella `ana_regimi_fiscali` [x]
**File**: `SqlScripts/210_Create_AnaRegimiFiscali.sql`

Colonne:
| Colonna | Tipo | Descrizione |
|---------|------|-------------|
| `regime_id` | SERIAL PK | Identificativo |
| `regime_codice` | VARCHAR(20) UNIQUE | FORFETTARIO, ORDINARIO, SEMPLIFICATO |
| `regime_descrizione` | VARCHAR(100) | Descrizione estesa |
| `show_helper_calcolo` | BOOLEAN | Mostra bottone "Applica Forfettario" |
| `default_aliquota_iva_codice` | VARCHAR(10) | Codice IVA default ("N2.2", "22") |
| `is_iva_detraibile` | BOOLEAN | FALSE per forfettario |
| `cassa_prev_percentuale` | NUMERIC(5,2) | 4.00 per forfettario |
| `cassa_prev_descrizione` | VARCHAR(50) | "RIVALSA INPS 4%" |
| `cassa_prev_aliquota_codice` | VARCHAR(10) | "N2.2" per forfettario |
| `bollo_soglia` | NUMERIC(10,2) | 77.47 per forfettario |
| `bollo_importo` | NUMERIC(10,2) | 2.00 per forfettario |
| `bollo_aliquota_codice` | VARCHAR(10) | "N1" per forfettario |
| `attivo` | BOOLEAN | Regime attivo |
| Audit fields | TIMESTAMPTZ/VARCHAR | created_at, created_by, updated_at, updated_by |

Seed data: ORDINARIO, FORFETTARIO, SEMPLIFICATO

### 1.2 Aggiungere FK a `ana_aziende` [x]
**File**: `SqlScripts/211_Add_RegimeFiscale_To_AnaAziende.sql`

- ADD COLUMN `regime_fiscale_fk` INTEGER REFERENCES `ana_regimi_fiscali(regime_id)`
- Backfill: aziende 2 e 6 -> FORFETTARIO, tutte le altre -> ORDINARIO
- SET NOT NULL dopo backfill

---

## FASE 2: Model Layer [x]

### 2.1 Creare `AnaRegimeFiscale.cs` [x]
**File**: `Models/AnaRegimeFiscale.cs`
- Pattern: come `AnaAliquotaIva.cs` (Dapper-compatible)
- Extends `BaseEntity`, implements `IAuditable`

### 2.2 Creare `FiscalCalculationResult.cs` [x]
**File**: `Models/FiscalCalculationResult.cs`
- DTO: `List<MovTransazioniRighe> Righe`, `bool Success`, `string? ErrorMessage`

### 2.3 Aggiornare `Azienda.cs` [x]
**File**: `Models/Azienda.cs`
- +`RegimeFiscaleFk` (int, Required)
- +`RegimeFiscaleCodice` (string?, NotMapped)
- +`RegimeFiscaleDescrizione` (string?, NotMapped)

---

## FASE 3: Service Layer [x]

### 3.1 Creare `AnaRegimiFiscaliService.cs` [x]
**File**: `Services/CRUD/AnaRegimiFiscaliService.cs`
- Pattern Dapper-based (NON BaseCrudService, tabella system-level)
- Metodi: `GetAllAsync()`, `GetActiveAsync()`, `GetByIdAsync()`, `GetByCodiceAsync()`, `CreateAsync()`, `UpdateAsync()`, `DeleteAsync()`

### 3.2 Creare `FiscalCalculationService.cs` [x]
**File**: `Services/CRUD/FiscalCalculationService.cs`

Logica chiave:
1. Legge il regime dell'azienda tramite `regime_fiscale_fk`
2. Cerca le aliquote IVA per CODICE (non ID) nella `ana_aliquote_iva` dell'azienda
3. Genera le righe: PRESTAZIONE + CASSA_PREV (se configurata) + BOLLO (se totale > soglia)

Metodi:
- `GetRegimeForAziendaAsync(int aziendaId)` -> `AnaRegimeFiscale?`
- `ShouldShowHelperCalcoloAsync(int aziendaId)` -> `bool`
- `ApplyRegimeCalculationAsync(int aziendaId, decimal baseImponibile, string? descrizione)` -> `FiscalCalculationResult`

**Attenzione**: messaggio errore IVA non trovata deve includere: "Verificare la configurazione delle Aliquote IVA in Tabelle Contabili."

### 3.3 Registrare servizi in `MauiProgram.cs` [x]
- `builder.Services.AddScoped<AnaRegimiFiscaliService>()`
- `builder.Services.AddScoped<FiscalCalculationService>()`

---

## FASE 4: Aggiornamento Azienda [x]

### 4.1 Aggiornare `AziendaService.cs` [x]
**File**: `Services/CRUD/AziendaService.cs`
- `GetAllAsync()`: JOIN con `ana_regimi_fiscali`
- `CreateAsync()`/`UpdateAsync()`: includere `regime_fiscale_fk`
- `MapFromReader()`: mappare i nuovi campi

### 4.2 Aggiornare `AziendaDialog.razor` [x]
**File**: `Components/Shared/AziendaDialog.razor`
- Iniettare `AnaRegimiFiscaliService`
- `MudSelect<int>` per regime (sia creazione che modifica)
- Default per nuove aziende: ORDINARIO

---

## FASE 5: Refactoring MovTransazioniEditDialog [x]

**File**: `Components/Pages/MovTransazioniEditDialog.razor`

1. [x] Sostituire `@if (AziendaId == 2 || AziendaId == 6)` con `@if (_showHelperCalcolo)`
2. [x] Iniettare `FiscalCalculationService`
3. [x] `OnInitializedAsync`: caricare `_showHelperCalcolo`
4. [x] Sostituire metodo `ApplicaForfettario()` con `ApplicaCalcoloRegime()` che chiama il service

---

## FASE 6: Pagina Gestione SuperAdmin [x]

### 6.1 Creare `AnaRegimiFiscaliPage.razor` [x]
**File**: `Components/Pages/Tabelle/AnaRegimiFiscaliPage.razor`
- Route: `/tabelle/regimi-fiscali`
- Solo SuperAdmin
- `EnterpriseDataGrid<AnaRegimeFiscale>`

### 6.2 Creare `AnaRegimiFiscaliEditDialog.razor` [x]
**File**: `Components/Pages/Tabelle/AnaRegimiFiscaliEditDialog.razor`
- Form completo con warning parametri incompleti

### 6.3 Aggiornare `NavMenu.razor` [x]
- "Regimi Fiscali" sotto "Tabelle Contabili"
- Icona: `Gavel`
- Solo SuperAdmin (AuthorizeView Roles="superadmin")

### 6.4 Aggiornare `DatabaseExceptionHelper.cs` [x]
- `"ana_regimi_fiscali" => "regime fiscale"`

---

## FASE 7: Build e Verifica [x]

1. [x] Compilare l'applicazione (`dotnet build`) - 0 errori
2. [ ] Verificare aziende 2 e 6 con regime FORFETTARIO (test manuale)
3. [ ] Bottone "Applica Calcolo Regime" visibile solo per aziende forfettarie (test manuale)
4. [ ] Calcolo con importo > 77.47 (3 righe) e < 77.47 (2 righe) (test manuale)
5. [ ] Pagina gestione regimi accessibile solo a SuperAdmin (test manuale)
6. [ ] Nuova azienda con regime default ORDINARIO (test manuale)

---

## Riepilogo File

### Da creare (8)
| File | Scopo |
|------|-------|
| `SqlScripts/210_Create_AnaRegimiFiscali.sql` | Tabella + seed data |
| `SqlScripts/211_Add_RegimeFiscale_To_AnaAziende.sql` | FK + backfill |
| `Models/AnaRegimeFiscale.cs` | Entity model |
| `Models/FiscalCalculationResult.cs` | DTO risultato calcolo |
| `Services/CRUD/AnaRegimiFiscaliService.cs` | CRUD regime fiscale |
| `Services/CRUD/FiscalCalculationService.cs` | Logica calcolo |
| `Components/Pages/Tabelle/AnaRegimiFiscaliPage.razor` | Pagina SuperAdmin |
| `Components/Pages/Tabelle/AnaRegimiFiscaliEditDialog.razor` | Dialog modifica |

### Da modificare (7)
| File | Modifica |
|------|----------|
| `Models/Azienda.cs` | +3 proprieta |
| `Services/CRUD/AziendaService.cs` | JOIN, SQL, mapping |
| `Components/Shared/AziendaDialog.razor` | Dropdown regime |
| `Components/Pages/MovTransazioniEditDialog.razor` | Rimuovere hardcoded |
| `Components/Shared/NavMenu.razor` | +1 voce menu |
| `MauiProgram.cs` | +2 servizi |
| `Helpers/DatabaseExceptionHelper.cs` | +1 traduzione |

---

## Note Follow-up

- Aggiornare `vw_margini_viaggi` per usare `is_iva_detraibile` (forfettario=LORDO, ordinario=NETTO)
