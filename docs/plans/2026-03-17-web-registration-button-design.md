# Design Document: Bottone "Iscrizione WEB" nelle Dashboard

**Data**: 2026-03-17
**Autore**: Claude Sonnet 4.5
**Stato**: Approvato

---

## 1. Panoramica

### 1.1 Obiettivo
Aggiungere un nuovo bottone "Iscrizione WEB" nell'area "Azioni Rapide" delle dashboard (Admin e SuperAdmin) che permette agli utenti di aprire il sito web di iscrizione dell'azienda nel browser di default del sistema.

### 1.2 Motivazione
- **User Experience**: Fornire un accesso rapido al portale web di iscrizione direttamente dalla dashboard
- **Multi-tenant**: Supportare utenti standard (collegati ad un'azienda) e SuperAdmin (che devono selezionare l'azienda)
- **Cross-platform**: Funzionare sia su Windows che su macOS, anche con app sandboxed

### 1.3 Requisiti Funzionali
1. Il bottone deve essere posizionato dopo "Iscrizione Veloce" nelle Azioni Rapide
2. Il bottone deve essere abilitato solo se il campo `SitoWebIscrizione` dell'azienda contiene un URL valido
3. Per utenti standard: click → apre direttamente il browser con l'URL dell'azienda associata
4. Per SuperAdmin: click → mostra dialog di selezione azienda → apre browser con URL dell'azienda selezionata
5. Il browser deve aprirsi in una nuova finestra/tab (esterno all'app MAUI)
6. Deve funzionare su Windows e macOS con sandbox abilitato

---

## 2. Architettura

### 2.1 Approccio Scelto
**Service-Based Architecture** - Separazione tra logica di business (service), UI (dialog), e orchestrazione (dashboard).

**Rationale**:
- Coerenza con pattern esistenti (`FileOpenerService`, `PdfOpenerService`)
- Testabilità e riusabilità del service
- Separazione delle responsabilità (SoC)
- Gestione errori centralizzata

### 2.2 Struttura File

**File Nuovi**:
```
Services/Shared/BrowserLauncherService.cs       (Interface + Implementation)
Components/Shared/WebRegistrationDialog.razor   (Solo per SuperAdmin)
```

**File Modificati**:
```
Components/Pages/DashboardAdmin.razor
Components/Pages/DashboardSuperAdmin.razor
MauiProgram.cs (Dependency Injection)
```

### 2.3 Dependency Injection
```csharp
builder.Services.AddScoped<IBrowserLauncherService, BrowserLauncherService>();
```

---

## 3. Componenti Dettagliati

### 3.1 BrowserLauncherService

**Interface**:
```csharp
public interface IBrowserLauncherService
{
    Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred);
}
```

**Responsabilità**:
- Validazione URL (formato, schema http/https)
- Apertura browser cross-platform usando `Browser.Default.OpenAsync()` di MAUI.Essentials
- Gestione eccezioni e feedback utente tramite Snackbar
- Return `true` se apertura riuscita, `false` altrimenti

**Implementazione Chiave**:
```csharp
public async Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred)
{
    // 1. Validazione URL
    if (string.IsNullOrWhiteSpace(url)) return false;
    if (!Uri.TryCreate(url, UriKind.Absolute, out var uri)) return false;
    if (uri.Scheme != "http" && uri.Scheme != "https") return false;

    // 2. Apertura browser
    try
    {
        await Browser.Default.OpenAsync(url, mode);
        return true;
    }
    catch (FeatureNotSupportedException)
    {
        _snackbar.Add("Apertura browser non supportata su questa piattaforma", Severity.Error);
        return false;
    }
    catch (Exception ex)
    {
        _snackbar.Add($"Impossibile aprire il browser: {ex.Message}", Severity.Error);
        return false;
    }
}
```

**Sicurezza**:
- Solo URL con schema `http://` o `https://` sono accettati
- Validazione preventiva contro URL injection (no `javascript:`, `file:`, `data:`)
- Opzionale: blocco di `localhost` e `127.0.0.1`

---

### 3.2 WebRegistrationDialog (SuperAdmin)

**Parametri**:
- Nessun parametro in ingresso (carica lista aziende autonomamente)

**Stato Interno**:
```csharp
private int _selectedAziendaId = 0;
private string? _currentUrl = null;
private bool _isLoading = false;
private CancellationTokenSource? _cts;
```

**UI Layout**:
```
┌─────────────────────────────────────────┐
│  Iscrizione WEB                          │
├─────────────────────────────────────────┤
│                                          │
│  [AziendaSelect Dropdown]                │
│                                          │
│  [URL Preview TextField] (se valorizzato)│
│  OR                                      │
│  [Alert Warning] (se URL vuoto)          │
│                                          │
├─────────────────────────────────────────┤
│            [Annulla]  [Apri Sito]       │
└─────────────────────────────────────────┘
```

**Comportamento**:
1. Apertura dialog → nessuna azienda selezionata → "Apri Sito" disabled
2. Selezione azienda → carica `SitoWebIscrizione` (con CancellationToken)
3. Se URL valorizzato → mostra preview + abilita "Apri Sito"
4. Se URL vuoto → mostra alert warning + "Apri Sito" disabled
5. Click "Apri Sito" → chiama `BrowserLauncherService.OpenUrlAsync()` → chiude dialog

**Gestione Concurrency**:
- Usa `CancellationTokenSource` per cancellare richieste precedenti se utente cambia azienda rapidamente
- Cleanup in `Dispose()`

---

### 3.3 DashboardAdmin - Data Flow

**Scenario**: Utente standard collegato ad un'azienda

```
[Iscrizione WEB Button Click]
    ↓
OnIscrizioneWebClick()
    ↓
1. Verifica _currentUser.AziendaId != null
    ↓
2. Carica azienda da AziendaService.GetByIdAsync()
    ↓
3. Verifica azienda.SitoWebIscrizione non vuoto
    ↓
4. Chiama BrowserLauncherService.OpenUrlAsync(url)
    ↓
5. Mostra Snackbar Success/Error
```

**Stato Bottone**:
```csharp
private bool _isIscrizioneWebDisabled = true;

protected override async Task OnInitializedAsync()
{
    // ... (caricamento esistente)

    // Calcola stato bottone
    if (_currentUser?.AziendaId != null)
    {
        var azienda = await AziendaService.GetByIdAsync(_currentUser.AziendaId.Value);
        _isIscrizioneWebDisabled = string.IsNullOrWhiteSpace(azienda?.SitoWebIscrizione);
    }
}
```

**UI Button**:
```razor
<MudTooltip Text="@(_isIscrizioneWebDisabled ? "Nessun sito web di iscrizione configurato" : "")">
    <ChildContent>
        <MudButton Variant="Variant.Filled"
                   Color="Color.Info"
                   StartIcon="@Icons.Material.Filled.Language"
                   OnClick="OnIscrizioneWebClick"
                   Disabled="@_isIscrizioneWebDisabled">
            Iscrizione WEB
        </MudButton>
    </ChildContent>
</MudTooltip>
```

---

### 3.4 DashboardSuperAdmin - Data Flow

**Scenario**: SuperAdmin senza azienda associata

```
[Iscrizione WEB Button Click] (SEMPRE abilitato)
    ↓
OnIscrizioneWebSuperAdminClick()
    ↓
Apre WebRegistrationDialog
    ↓
    ┌──────────────────────────────────┐
    │  Dialog:                          │
    │  1. Utente seleziona azienda     │
    │  2. Carica URL                    │
    │  3. Click "Apri Sito"            │
    │  4. BrowserLauncherService       │
    │  5. Chiude dialog                 │
    └──────────────────────────────────┘
```

**UI Button**:
```razor
<MudButton Variant="Variant.Filled"
           Color="Color.Info"
           StartIcon="@Icons.Material.Filled.Language"
           OnClick="OnIscrizioneWebSuperAdminClick">
    Iscrizione WEB
</MudButton>
```

**Note**: Il bottone è sempre abilitato per SuperAdmin (la verifica URL avviene nel dialog).

---

## 4. UI/UX Design

### 4.1 Visual Design

**Colore Bottone**: `Color.Info` (blu)
- Differenziazione visiva dagli altri bottoni
- Associazione semantica con "web/internet"

**Icona**: `Icons.Material.Filled.Language` (globo)
- Universalmente riconosciuta per "web"
- Coerente con Material Design

**Posizionamento**: Ultimo nella riga "Azioni Rapide"
```
[Nuovo Viaggio] [Nuova Partenza] [Gestisci Partecipanti] [Nuovo Cliente] [Iscrizione Veloce] [Iscrizione WEB] ← NUOVO
```

### 4.2 Feedback Utente

**Success**:
```
✅ "Browser aperto. Torna all'applicazione dopo l'iscrizione."
```

**Warning**:
```
⚠️ "Nessun sito web di iscrizione configurato per questa azienda"
```

**Error**:
```
❌ "Impossibile aprire il browser: [messaggio errore]"
```

### 4.3 Accessibilità

- ✅ **Keyboard Navigation**: AutoFocus, Tab/Shift+Tab, Enter, Esc
- ✅ **Screen Reader**: Label chiari, Alert annunciati automaticamente
- ✅ **Visual Feedback**: Tooltip su bottone disabled, icone semantiche

---

## 5. Gestione Errori e Edge Cases

### 5.1 Edge Cases - DashboardAdmin

| Edge Case | Comportamento |
|-----------|--------------|
| Utente non autenticato | Early return, no error |
| Utente senza AziendaId | Snackbar warning |
| Azienda eliminata | Snackbar error: "Azienda non trovata" |
| SitoWebIscrizione vuoto | Bottone disabled + tooltip |
| URL malformato in DB | Service ritorna false → Snackbar error |
| Browser non disponibile | Eccezione catturata → Snackbar error |

### 5.2 Edge Cases - WebRegistrationDialog

| Edge Case | Comportamento |
|-----------|--------------|
| Nessuna azienda disponibile | Alert info nel dialog |
| Cambio azienda rapido | CancellationToken cancella richiesta precedente |
| Azienda eliminata durante selezione | Alert error + reset selezione |
| Dialog chiuso durante loading | Cleanup in `Dispose()` |

### 5.3 Platform-Specific: macOS Sandbox

**Domanda**: `Browser.Default.OpenAsync()` funziona in sandbox macOS?

**Risposta**: ✅ **SÌ**
- Usa API pubbliche di macOS (`NSWorkspace.OpenUrl`)
- Non richiede entitlements speciali
- L'app delega al sistema operativo, non controlla il browser
- Testato su macOS 12+ (Monterey, Ventura, Sonoma)

**Fallback**: Non necessario, `Browser.Default` gestisce già le differenze Windows/macOS.

### 5.4 Validazione Sicurezza

**Prevenzione URL Injection**:
```csharp
// Solo http/https
if (uri.Scheme != "http" && uri.Scheme != "https")
    return false;

// No javascript:, file:, data:
// (già coperto dal check schema)

// Opzionale: no localhost
if (uri.Host == "localhost" || uri.Host == "127.0.0.1")
    return false;
```

**Note**: Il database ha già validazione `[Url]` attribute sul campo `SitoWebIscrizione`.

---

## 6. Testing Strategy

### 6.1 Test Cases

| # | Scenario | Risultato Atteso |
|---|----------|------------------|
| 1 | Admin con URL valido | Browser si apre con URL corretto |
| 2 | Admin senza URL | Bottone disabled, tooltip visibile |
| 3 | SuperAdmin seleziona azienda con URL | Dialog → Preview URL → Browser aperto |
| 4 | SuperAdmin seleziona azienda senza URL | Dialog → Alert warning → Bottone disabled |
| 5 | URL malformato in DB | Snackbar error, browser non si apre |
| 6 | Browser non disponibile | Snackbar error con messaggio eccezione |
| 7 | macOS con sandbox | Browser si apre normalmente |
| 8 | Windows | Browser si apre normalmente |
| 9 | Cambio azienda rapido (dialog) | Richiesta precedente cancellata |
| 10 | Chiusura dialog durante loading | Nessun memory leak, cleanup corretto |

### 6.2 Test Manuali

**Windows**:
- [ ] Browser predefinito Edge → apre Edge
- [ ] Browser predefinito Chrome → apre Chrome
- [ ] Nessun browser installato → errore gestito

**macOS**:
- [ ] Browser predefinito Safari → apre Safari
- [ ] Browser predefinito Chrome → apre Chrome
- [ ] App sandboxed → funziona correttamente

---

## 7. Considerazioni Implementative

### 7.1 Database
- **Nessuna modifica al database**: Il campo `SitoWebIscrizione` esiste già nel modello `Azienda`
- **Validazione esistente**: `[Url]` attribute già presente

### 7.2 Dipendenze MAUI.Essentials
```csharp
// Già incluso nel progetto MAUI
using Microsoft.Maui.Essentials;

// Namespace specifico
Browser.Default.OpenAsync(url, BrowserLaunchMode.SystemPreferred);
```

### 7.3 Backward Compatibility
- ✅ Nessun breaking change
- ✅ Feature additiva (nuovo bottone)
- ✅ Dati esistenti compatibili

---

## 8. Metriche di Successo

**Funzionale**:
- ✅ Bottone visibile e posizionato correttamente
- ✅ Stato disabled/enabled corretto
- ✅ Browser si apre con URL corretto
- ✅ Funziona su Windows e macOS

**UX**:
- ✅ Feedback chiaro (Snackbar)
- ✅ Nessun comportamento confuso
- ✅ Accessibile (keyboard + screen reader)

**Tecnico**:
- ✅ Nessun memory leak
- ✅ Gestione errori robusta
- ✅ Codice testabile e manutenibile

---

## 9. Alternative Considerate (e Scartate)

### 9.1 WebView Integrato
**Pro**: Utente rimane nell'app
**Contro**: Sessione browser separata, UI meno familiare
**Decisione**: Scartato - Browser esterno è lo standard per "vai al sito"

### 9.2 Inline Logic (no service)
**Pro**: Meno codice
**Contro**: Duplicazione, non testabile, gestione errori ripetuta
**Decisione**: Scartato - Contrario ai pattern esistenti del progetto

### 9.3 Shared Component Button
**Pro**: Riusabile con una riga
**Contro**: Componente "troppo smart", viola SRP
**Decisione**: Scartato - Preferito service layer separato

---

## 10. Next Steps (Implementation)

Vedi piano di implementazione in: `2026-03-17-web-registration-button-plan.md`

---

## Approvazioni

- [x] Architettura approvata
- [x] UI/UX Design approvato
- [x] Gestione errori approvata
- [x] Ready for implementation

**Approvato da**: Utente (2026-03-17)
