# 📋 Changelog: Integrazione Automatica Tassi di Cambio

**Data**: 2026-02-08
**Autore**: Antigravity (Claude Code)
**Versione**: 1.0.0

---

## 🎯 Obiettivo

Implementare un sistema automatico di recupero e gestione dei tassi di cambio per le transazioni contabili in valuta estera, utilizzando:
- La **data del documento** (non la data di registrazione) per il tasso di cambio corretto
- **Frankfurter API** per recupero tassi in tempo reale con supporto date storiche
- **Fallback** automatico su ultimo tasso disponibile in caso di timeout/errore API
- **Storicizzazione completa** del tasso applicato per ogni transazione

---

## ✅ Modifiche Implementate

### 📦 **1. Database (PostgreSQL)**

#### **A) Nuovi Campi Tabella `mov_transazioni`**

Aggiunti 3 nuovi campi per tracciare il tasso di cambio utilizzato:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `transazione_tasso_cambio_applicato` | NUMERIC(15,6) | Tasso di cambio effettivamente utilizzato |
| `transazione_tasso_fonte` | VARCHAR(50) | Fonte del tasso (FRANKFURTER_API, FALLBACK_DB, EUR_BASE) |
| `transazione_tasso_data_validita` | DATE | Data di validità del tasso applicato |

**Script**: [SqlScripts/Migration_AddTassoCambioFields.sql](../SqlScripts/Migration_AddTassoCambioFields.sql)

---

#### **B) Nuovo Trigger di Validazione**

Aggiunto trigger `trg_validate_data_documento` che **BLOCCA** l'inserimento/aggiornamento di transazioni in valuta estera se `transazione_data_documento` è NULL.

**Messaggio di errore**:
```
ERRORE: Per transazioni in valuta estera è OBBLIGATORIO inserire la Data Documento.
La Data Documento viene utilizzata per recuperare il tasso di cambio corretto dalla Frankfurter API.
Impossibile procedere senza questo dato.
```

**Script**: [SqlScripts/Migration_AddDataDocumentoConstraint.sql](../SqlScripts/Migration_AddDataDocumentoConstraint.sql)

---

#### **C) Trigger Aggiornato: `fn_calcola_importo_eur`**

Il trigger esistente è stato **completamente rielaborato** per:

1. ✅ Usare `transazione_data_documento` invece di `transazione_data` per il tasso di cambio
2. ✅ Cercare il tasso **ESATTO** per la data documento
3. ✅ Se non trovato, applicare **FALLBACK** all'ultimo tasso disponibile prima della data documento
4. ✅ Gestire anche i **tassi inversi** (es. se ho solo EUR→USD, calcola USD→EUR come 1/tasso)
5. ✅ **Memorizzare** nei nuovi campi:
   - Tasso applicato
   - Fonte (API, FALLBACK_DB, FALLBACK_DB_INVERSO, EUR_BASE)
   - Data validità del tasso

**Script**: [SqlScripts/Migration_UpdateTriggerCalcolaImportoEur.sql](../SqlScripts/Migration_UpdateTriggerCalcolaImportoEur.sql)

---

### 🔧 **2. Backend C# (.NET MAUI)**

#### **A) Model `MovTransazioni.cs`**

Aggiunte 3 nuove proprietà:

```csharp
[Column("transazione_tasso_cambio_applicato")]
public decimal? TransazioneTassoCambioApplicato { get; set; }

[Column("transazione_tasso_fonte")]
public string? TransazioneTassoFonte { get; set; }

[Column("transazione_tasso_data_validita")]
public DateTime? TransazioneTassoDataValidita { get; set; }
```

**File**: [Models/MovTransazioni.cs](../Models/MovTransazioni.cs)

---

#### **B) `ExchangeRateService.cs` - Nuove Funzionalità**

1. **Timeout API impostato a 5 secondi**
   ```csharp
   private const int API_TIMEOUT_SECONDS = 5;
   ```

2. **Nuovo metodo `UpdateRateForDateAsync(isoCode, date)`**
   - Recupera tassi storici dalla Frankfurter API
   - Formato API: `https://api.frankfurter.app/YYYY-MM-DD?from=EUR&to=USD`
   - Gestisce timeout ed errori di rete
   - Restituisce `(bool Success, string Message)` per notificare l'utente

**Esempio di utilizzo**:
```csharp
var (success, message) = await _exchangeRateService.UpdateRateForDateAsync("USD", new DateTime(2026, 01, 15));

if (!success)
{
    // Mostra warning all'utente
    Snackbar.Add(message, Severity.Warning);
}
```

**File**: [Services/Shared/ExchangeRateService.cs](../Services/Shared/ExchangeRateService.cs)

---

#### **C) `MovTransazioniService.cs` - Logica Automatica**

Modificati i metodi `CreateAsync` e `UpdateAsync` per:

1. **STEP 1**: Prima del salvataggio, se `valuta != EUR`:
   - Chiama `ExchangeRateService.UpdateRateForDateAsync()`
   - Usa la `transazione_data_documento` per recuperare il tasso corretto
   - Gestisce timeout/errori con messaggio di fallback

2. **STEP 2**: Inserisce/aggiorna la transazione
   - Il trigger DB calcola automaticamente `transazione_importo_eur`
   - Popola i campi `tasso_cambio_applicato`, `tasso_fonte`, `tasso_data_validita`

**Nuova firma dei metodi**:
```csharp
// CreateAsync restituisce ID + messaggio warning opzionale
public async Task<(int TransazioneId, string? WarningMessage)> CreateAsync(MovTransazioni item)

// UpdateAsync restituisce messaggio warning opzionale
public async Task<string?> UpdateAsync(MovTransazioni item)
```

**File**: [Services/CRUD/MovTransazioniService.cs](../Services/CRUD/MovTransazioniService.cs)

---

#### **D) `MovTransazioniEditDialog.razor` - UI con Toast**

Aggiornato il metodo `Submit()` per:
- Gestire la nuova firma di `CreateAsync` e `UpdateAsync`
- Mostrare un **toast di warning** se il tasso è stato recuperato con fallback

```csharp
// Mostra warning se il tasso di cambio è stato recuperato con fallback
if (!string.IsNullOrWhiteSpace(warningMessage))
{
    Snackbar.Add(warningMessage, Severity.Warning, config =>
    {
        config.VisibleStateDuration = 5000; // 5 secondi
    });
}
```

**File**: [Components/Pages/MovTransazioniEditDialog.razor](../Components/Pages/MovTransazioniEditDialog.razor)

---

## 🧪 Come Testare

### **Test Manuale DB**

Esegui lo script di test completo:
```bash
psql -h 127.0.0.1 -p 5432 -U postgres -d gestione_viaggi -f SqlScripts/Test_ExchangeRateIntegration.sql
```

Questo script:
1. ✅ Verifica che i nuovi campi esistano
2. ✅ Mostra valute e tassi disponibili
3. ✅ Inserisce un tasso di test (EUR→USD)
4. ✅ Testa il **blocco** per transazioni senza `data_documento`
5. ✅ Testa l'**inserimento riuscito** con data documento
6. ✅ Mostra i dettagli della conversione

**File**: [SqlScripts/Test_ExchangeRateIntegration.sql](../SqlScripts/Test_ExchangeRateIntegration.sql)

---

### **Test Manuale UI**

1. **Avvia l'applicazione MAUI**
2. **Vai alla gestione transazioni**
3. **Crea una nuova transazione**:
   - Seleziona una **valuta estera** (es. USD, GBP, ZAR)
   - **NON inserire** la data documento → L'inserimento deve essere **BLOCCATO**
   - Inserisci **data documento** → L'inserimento deve **RIUSCIRE**
4. **Verifica**:
   - ✅ Toast di successo
   - ✅ Se API timeout/errore → Toast di warning con dettagli
   - ✅ Importo EUR calcolato correttamente
   - ✅ Tasso applicato visibile nel DB

---

## 📊 Flusso di Esecuzione

```
┌─────────────────────────────────────────────────────────────┐
│ 1. UTENTE inserisce transazione in valuta estera (es. USD) │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. UI chiama MovTransazioniService.CreateAsync()            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Service chiama ExchangeRateService.UpdateRateForDateAsync│
│    con data_documento                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
           ▼                       ▼
    ┌────────────┐         ┌──────────────┐
    │ API OK     │         │ API TIMEOUT  │
    │ Tasso      │         │ o ERRORE     │
    │ aggiornato │         │              │
    └─────┬──────┘         └──────┬───────┘
          │                       │
          │                       ▼
          │              ┌────────────────────┐
          │              │ Warning Message:   │
          │              │ "Verrà usato      │
          │              │ ultimo tasso DB"  │
          │              └────────┬───────────┘
          │                       │
          └───────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Service inserisce transazione nel DB                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. TRIGGER trg_validate_data_documento verifica:            │
│    - Se valuta != EUR && data_documento IS NULL → ERRORE!  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼ (OK)
┌─────────────────────────────────────────────────────────────┐
│ 6. TRIGGER trg_calcola_importo_eur:                         │
│    - Cerca tasso esatto per data_documento                  │
│    - Se non trovato → cerca ultimo tasso disponibile        │
│    - Calcola importo_eur                                    │
│    - Memorizza tasso_applicato, fonte, data_validita       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. UI mostra:                                               │
│    - Toast SUCCESS                                          │
│    - Toast WARNING (se fallback)                            │
│    - Dettagli conversione                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎁 Vantaggi della Soluzione

| Vantaggio | Descrizione |
|-----------|-------------|
| ✅ **Accuratezza** | Usa la data del documento, non la data di registrazione |
| ✅ **Automazione** | Recupero automatico dal web service, nessun intervento manuale |
| ✅ **Trasparenza** | Ogni transazione conserva il tasso, la fonte e la data validità |
| ✅ **Resilienza** | Fallback automatico su DB se API non disponibile |
| ✅ **User Experience** | Toast notification informa l'utente in caso di fallback |
| ✅ **Audit Trail** | Storico completo di quale tasso è stato applicato e quando |
| ✅ **DB-First** | Logica critica centralizzata nel database con trigger |
| ✅ **Performance** | Timeout di 5 secondi, nessun blocco prolungato |

---

## 📝 Note Tecniche

### **API Frankfurter**

- **Base URL**: `https://api.frankfurter.app`
- **Endpoint date storiche**: `/{YYYY-MM-DD}?from=EUR&to=USD`
- **Timeout**: 5 secondi
- **Gratuita**: Sì, nessun limite di rate
- **Date supportate**: Dal 1999-01-04 ad oggi

### **Gestione Errori**

- **Timeout API** → Usa ultimo tasso disponibile nel DB
- **Errore rete** → Usa ultimo tasso disponibile nel DB
- **Tasso non trovato** → Cerca tasso inverso (es. EUR→USD diventa 1/tasso)
- **Valuta estera senza data_documento** → **BLOCCO** con messaggio esplicito

---

## 🚀 Prossimi Passi (Opzionali)

- [ ] Dashboard per visualizzare tassi di cambio storici
- [ ] Report con analisi conversioni valutarie
- [ ] Batch job notturno per aggiornare tutti i tassi
- [ ] Integrazione con altre API di cambio (fallback su più fonti)
- [ ] Calcolo differenze cambio per analisi profitti/perdite

---

## 📞 Supporto

Per domande o problemi, contattare lo sviluppatore o consultare:
- [Documentazione Frankfurter API](https://www.frankfurter.app/docs/)
- [PostgreSQL Triggers](https://www.postgresql.org/docs/current/triggers.html)
- [.NET MAUI Documentation](https://learn.microsoft.com/en-us/dotnet/maui/)

---

**Fine Changelog** 🎉
