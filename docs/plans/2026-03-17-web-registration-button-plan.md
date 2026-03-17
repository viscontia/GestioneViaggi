# Web Registration Button Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use @superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add "Iscrizione WEB" button to Admin/SuperAdmin dashboards that opens company registration website in system browser

**Architecture:** Service-based with BrowserLauncherService for cross-platform browser opening, WebRegistrationDialog for SuperAdmin company selection, button integration in both dashboards

**Tech Stack:** .NET MAUI, Blazor, MudBlazor, MAUI.Essentials.Browser

---

## Task 1: Create BrowserLauncherService

**Files:**
- Create: `Services/Shared/BrowserLauncherService.cs`

**Step 1: Create interface and implementation**

Create the complete service file with interface, implementation, validation, and error handling:

```csharp
using MudBlazor;

namespace GestioneViaggi.Services.Shared;

/// <summary>
/// Service for opening URLs in the system default browser.
/// Cross-platform compatible (Windows, macOS sandbox).
/// </summary>
public interface IBrowserLauncherService
{
    /// <summary>
    /// Opens a URL in the system default browser.
    /// </summary>
    /// <param name="url">The URL to open (must be http/https)</param>
    /// <param name="mode">Browser launch mode (default: SystemPreferred)</param>
    /// <returns>True if browser opened successfully, false otherwise</returns>
    Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred);
}

public class BrowserLauncherService : IBrowserLauncherService
{
    private readonly ISnackbar _snackbar;

    public BrowserLauncherService(ISnackbar snackbar)
    {
        _snackbar = snackbar;
    }

    public async Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred)
    {
        // Validation: null/empty check
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        // Validation: URL format check
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            return false;
        }

        // Security: only http/https schemes allowed
        if (uri.Scheme != "http" && uri.Scheme != "https")
        {
            _snackbar.Add("Solo URL http/https sono supportati", Severity.Warning);
            return false;
        }

        // Open browser using MAUI.Essentials (cross-platform)
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
}
```

**Step 2: Verify file compiles**

Run: Build project to verify no syntax errors

Expected: Clean compilation, no errors

**Step 3: Commit**

```bash
git add Services/Shared/BrowserLauncherService.cs
git commit -m "feat: add BrowserLauncherService for cross-platform browser opening

- Interface IBrowserLauncherService with OpenUrlAsync method
- URL validation (null, format, http/https only)
- Security: prevent javascript:, file:, data: schemes
- Error handling with user-friendly Snackbar messages
- Cross-platform compatible (Windows, macOS sandbox)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Register BrowserLauncherService in DI Container

**Files:**
- Modify: `MauiProgram.cs` (around line 80-120, Services registration section)

**Step 1: Find Services.Shared registration section**

Locate the section where other shared services are registered (look for `FileOpenerService`, `PdfOpenerService`)

**Step 2: Add BrowserLauncherService registration**

Add this line in the Services.Shared section:

```csharp
builder.Services.AddScoped<IBrowserLauncherService, BrowserLauncherService>();
```

Place it after `AddScoped<IFileOpenerService, FileOpenerService>()` for logical grouping.

**Step 3: Verify build**

Run: Build project to verify DI registration is correct

Expected: Clean compilation

**Step 4: Commit**

```bash
git add MauiProgram.cs
git commit -m "feat: register BrowserLauncherService in DI container

- Add scoped service registration for IBrowserLauncherService
- Positioned after FileOpenerService for logical grouping

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Create WebRegistrationDialog for SuperAdmin

**Files:**
- Create: `Components/Shared/WebRegistrationDialog.razor`

**Step 1: Create Razor component markup**

```razor
@using GestioneViaggi.Services.CRUD
@using GestioneViaggi.Services.Shared
@inject IAziendaService AziendaService
@inject IBrowserLauncherService BrowserLauncher
@inject ISnackbar Snackbar
@implements IDisposable

<MudDialog>
    <TitleContent>
        <MudText Typo="Typo.h6">
            <MudIcon Icon="@Icons.Material.Filled.Language" Class="mr-2" />
            Iscrizione WEB
        </MudText>
    </TitleContent>

    <DialogContent>
        <MudStack Spacing="3">
            <!-- 1. Selezione Azienda -->
            <AziendaSelect @bind-SelectedAziendaId="_selectedAziendaId"
                          SelectedAziendaIdChanged="OnAziendaChanged"
                          Required="true"
                          Label="Seleziona Azienda"
                          AutoFocus="true" />

            <!-- 2. Loading indicator -->
            @if (_isLoading)
            {
                <MudProgressCircular Color="Color.Primary" Indeterminate="true" Size="Size.Small" />
            }

            <!-- 3. URL Preview (visibile solo se URL valorizzato) -->
            @if (!string.IsNullOrWhiteSpace(_currentUrl))
            {
                <MudTextField Value="@_currentUrl"
                             Label="Sito Web Iscrizione"
                             Variant="Variant.Outlined"
                             ReadOnly="true"
                             Adornment="Adornment.Start"
                             AdornmentIcon="@Icons.Material.Filled.Link" />
            }

            <!-- 4. Alert Warning (visibile solo se azienda selezionata ma URL vuoto) -->
            @if (_selectedAziendaId > 0 && !_isLoading && string.IsNullOrWhiteSpace(_currentUrl))
            {
                <MudAlert Severity="Severity.Warning" Variant="Variant.Outlined">
                    L'azienda selezionata non ha configurato un sito web di iscrizione.
                </MudAlert>
            }
        </MudStack>
    </DialogContent>

    <DialogActions>
        <MudButton OnClick="Cancel" Color="Color.Default">Annulla</MudButton>
        <MudButton OnClick="OpenWebsite"
                   Color="Color.Primary"
                   Variant="Variant.Filled"
                   Disabled="@string.IsNullOrWhiteSpace(_currentUrl)"
                   StartIcon="@Icons.Material.Filled.OpenInNew">
            Apri Sito
        </MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter] MudDialogInstance MudDialog { get; set; } = default!;

    private int _selectedAziendaId = 0;
    private string? _currentUrl = null;
    private bool _isLoading = false;
    private CancellationTokenSource? _cts;

    private async Task OnAziendaChanged(int aziendaId)
    {
        // Cancel previous request if user changes selection quickly
        _cts?.Cancel();
        _cts = new CancellationTokenSource();

        _selectedAziendaId = aziendaId;
        _isLoading = true;
        _currentUrl = null;

        try
        {
            var azienda = await AziendaService.GetByIdAsync(aziendaId);
            if (azienda != null)
            {
                _currentUrl = azienda.SitoWebIscrizione;
            }
        }
        catch (OperationCanceledException)
        {
            // Request was cancelled, ignore
        }
        catch (Exception ex)
        {
            Snackbar.Add($"Errore caricamento azienda: {ex.Message}", Severity.Error);
        }
        finally
        {
            _isLoading = false;
            StateHasChanged();
        }
    }

    private async Task OpenWebsite()
    {
        if (string.IsNullOrWhiteSpace(_currentUrl))
            return;

        var success = await BrowserLauncher.OpenUrlAsync(_currentUrl);
        if (success)
        {
            Snackbar.Add("Browser aperto. Torna all'applicazione dopo l'iscrizione.", Severity.Success);
            MudDialog.Close(DialogResult.Ok(true));
        }
    }

    private void Cancel()
    {
        MudDialog.Cancel();
    }

    public void Dispose()
    {
        _cts?.Cancel();
        _cts?.Dispose();
    }
}
```

**Step 2: Verify component compiles**

Run: Build project

Expected: Clean compilation

**Step 3: Commit**

```bash
git add Components/Shared/WebRegistrationDialog.razor
git commit -m "feat: add WebRegistrationDialog for SuperAdmin company selection

- AziendaSelect dropdown for company selection
- URL preview when SitoWebIscrizione is configured
- Alert warning when URL is not configured
- CancellationToken support for rapid selection changes
- Proper cleanup in Dispose()
- Opens browser using BrowserLauncherService

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Add "Iscrizione WEB" Button to DashboardAdmin

**Files:**
- Modify: `Components/Pages/DashboardAdmin.razor` (lines ~800-804 for button, code section for logic)

**Step 1: Add service injection in code section**

In the `@code` section at the top, add:

```csharp
[Inject] public IBrowserLauncherService BrowserLauncher { get; set; } = default!;
[Inject] public Services.CRUD.IAziendaService AziendaService { get; set; } = default!;
```

**Step 2: Add button state variable**

In the private fields section (after other `_` variables), add:

```csharp
private bool _isIscrizioneWebDisabled = true;
```

**Step 3: Calculate button state in OnInitializedAsync**

At the end of `OnInitializedAsync()`, before `_isLoading = false;`, add:

```csharp
// Calculate Iscrizione WEB button state
if (_currentUser?.AziendaId != null)
{
    try
    {
        var azienda = await AziendaService.GetByIdAsync(_currentUser.AziendaId.Value);
        _isIscrizioneWebDisabled = string.IsNullOrWhiteSpace(azienda?.SitoWebIscrizione);
    }
    catch
    {
        // If error loading azienda, keep button disabled
        _isIscrizioneWebDisabled = true;
    }
}
```

**Step 4: Add button click handler method**

In the methods section (after other `private async Task` methods), add:

```csharp
private async Task OnIscrizioneWebClick()
{
    // Safety check: user must have azienda
    if (_currentUser?.AziendaId == null)
    {
        Snackbar.Add("Utente non associato ad un'azienda", Severity.Warning);
        return;
    }

    // Load azienda to get URL
    var azienda = await AziendaService.GetByIdAsync(_currentUser.AziendaId.Value);
    if (azienda == null)
    {
        Snackbar.Add("Azienda non trovata", Severity.Error);
        return;
    }

    // Verify URL is configured
    if (string.IsNullOrWhiteSpace(azienda.SitoWebIscrizione))
    {
        Snackbar.Add("Nessun sito web di iscrizione configurato per questa azienda", Severity.Warning);
        return;
    }

    // Open browser
    var success = await BrowserLauncher.OpenUrlAsync(azienda.SitoWebIscrizione);
    if (success)
    {
        Snackbar.Add("Browser aperto. Torna all'applicazione dopo l'iscrizione.", Severity.Success);
    }
}
```

**Step 5: Add button to UI**

Find line ~800-804 where "Iscrizione Veloce" button is defined. After that `</MudButton>`, add:

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

**Step 6: Verify build and visual check**

Run: Build project + Run app to verify button appears

Expected: Button visible after "Iscrizione Veloce", disabled if no URL configured

**Step 7: Commit**

```bash
git add Components/Pages/DashboardAdmin.razor
git commit -m "feat: add Iscrizione WEB button to DashboardAdmin

- Button positioned after Iscrizione Veloce in Azioni Rapide
- Disabled state when SitoWebIscrizione not configured
- Tooltip explaining why button is disabled
- Click handler loads azienda and opens browser
- Color.Info (blue) for web/internet semantic
- Language icon (globe) for visual clarity

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add "Iscrizione WEB" Button to DashboardSuperAdmin

**Files:**
- Modify: `Components/Pages/DashboardSuperAdmin.razor` (lines ~688 for button, code section for logic)

**Step 1: Add service injection**

In the `@code` section at the top, add:

```csharp
[Inject] public IBrowserLauncherService BrowserLauncher { get; set; } = default!;
```

**Step 2: Add button click handler method**

In the methods section (after other `private async Task` methods), add:

```csharp
private async Task OnIscrizioneWebSuperAdminClick()
{
    var options = new DialogOptions
    {
        CloseButton = true,
        MaxWidth = MaxWidth.Small,
        FullWidth = true,
        BackdropClick = false
    };

    var dialog = await DialogService.ShowAsync<GestioneViaggi.Components.Shared.WebRegistrationDialog>(
        "Iscrizione WEB",
        options);

    var result = await dialog.Result;

    // Dialog handles browser opening internally
    // No need to check result here
}
```

**Step 3: Add button to UI**

Find line ~688 where "Iscrizione Veloce" button is defined. After that `</MudButton>`, add:

```razor
<MudButton Variant="Variant.Filled"
           Color="Color.Info"
           StartIcon="@Icons.Material.Filled.Language"
           OnClick="OnIscrizioneWebSuperAdminClick">
    Iscrizione WEB
</MudButton>
```

**Step 4: Verify build and visual check**

Run: Build project + Run app as SuperAdmin to verify button appears and dialog opens

Expected: Button always enabled, clicking opens WebRegistrationDialog

**Step 5: Commit**

```bash
git add Components/Pages/DashboardSuperAdmin.razor
git commit -m "feat: add Iscrizione WEB button to DashboardSuperAdmin

- Button positioned after Iscrizione Veloce in Azioni Rapide
- Always enabled (validation happens in dialog)
- Opens WebRegistrationDialog for company selection
- Color.Info (blue) for consistency with DashboardAdmin
- Language icon (globe) for visual clarity

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Manual Testing on Windows

**Files:** None (testing only)

**Step 1: Test DashboardAdmin with URL configured**

1. Run app on Windows
2. Login as standard user (non-SuperAdmin) whose company has `SitoWebIscrizione` configured
3. Navigate to Dashboard
4. Verify "Iscrizione WEB" button is **enabled**
5. Click button
6. Verify browser opens with correct URL
7. Verify Snackbar shows success message

Expected: Browser opens in default Windows browser (Edge/Chrome)

**Step 2: Test DashboardAdmin without URL configured**

1. Login as standard user whose company does NOT have `SitoWebIscrizione` configured
2. Navigate to Dashboard
3. Verify "Iscrizione WEB" button is **disabled**
4. Hover button
5. Verify tooltip shows "Nessun sito web di iscrizione configurato"

Expected: Button disabled, tooltip visible

**Step 3: Test DashboardSuperAdmin**

1. Login as SuperAdmin
2. Navigate to Dashboard
3. Verify "Iscrizione WEB" button is **enabled**
4. Click button
5. Verify WebRegistrationDialog opens
6. Select company WITH URL configured
7. Verify URL preview appears
8. Click "Apri Sito"
9. Verify browser opens
10. Verify Snackbar shows success message

Expected: Dialog flow works, browser opens correctly

**Step 4: Test DashboardSuperAdmin - No URL scenario**

1. In WebRegistrationDialog, select company WITHOUT URL configured
2. Verify alert warning appears
3. Verify "Apri Sito" button is **disabled**

Expected: Warning alert visible, button disabled

**Step 5: Document test results**

Create file: `docs/testing/2026-03-17-web-registration-windows-tests.md`

Document all test results (pass/fail) with screenshots if needed.

---

## Task 7: Manual Testing on macOS

**Files:** None (testing only)

**Step 1: Test DashboardAdmin on macOS (sandboxed)**

1. Run app on macOS with sandbox enabled
2. Login as standard user with URL configured
3. Click "Iscrizione WEB" button
4. Verify Safari/Chrome opens (whatever is system default)
5. Verify no sandbox errors in console

Expected: Browser opens normally, no permission errors

**Step 2: Test DashboardSuperAdmin on macOS**

1. Login as SuperAdmin
2. Complete WebRegistrationDialog flow
3. Verify browser opens correctly

Expected: Same behavior as Windows

**Step 3: Test URL validation**

1. Manually insert invalid URL in database (e.g., `javascript:alert('xss')`)
2. Try to open it
3. Verify error Snackbar appears
4. Verify browser does NOT open

Expected: Security validation prevents malicious URLs

**Step 4: Document test results**

Append to: `docs/testing/2026-03-17-web-registration-windows-tests.md` (rename to `web-registration-tests.md`)

Document macOS-specific test results

---

## Task 8: Update Documentation

**Files:**
- Modify: `Documents/ComponentiShared.md` (add WebRegistrationDialog section)

**Step 1: Add WebRegistrationDialog documentation**

In the "Componenti Dialog" section, after SendEmailDialog, add:

```markdown
### WebRegistrationDialog
Dialog per la selezione dell'azienda e apertura sito web iscrizione (Solo SuperAdmin) (`Components/Shared/WebRegistrationDialog.razor`).
*   **Funzionalità**:
    *   Selezione azienda tramite `AziendaSelect` component
    *   Preview URL se `SitoWebIscrizione` valorizzato
    *   Alert warning se URL non configurato
    *   Apertura browser tramite `BrowserLauncherService`
    *   Gestione concurrency con `CancellationToken`
    *   Cleanup automatico in `Dispose()`
*   **Parametri**: Nessun parametro (carica lista aziende autonomamente)
*   **Valore Restituito**: `DialogResult.Ok(true)` se browser aperto con successo, `Canceled` se annullato
*   **Utilizzo** (da DashboardSuperAdmin):
    ```razor
    var options = new DialogOptions
    {
        CloseButton = true,
        MaxWidth = MaxWidth.Small,
        FullWidth = true,
        BackdropClick = false
    };

    var dialog = await DialogService.ShowAsync<WebRegistrationDialog>(
        "Iscrizione WEB",
        options);
    ```
*   **Contesto**: Utilizzato esclusivamente da SuperAdmin per selezionare l'azienda prima di aprire il sito web di iscrizione.
```

**Step 2: Add BrowserLauncherService documentation**

In the "Servizi Shared (Backend Logic)" section, after FileOpenerService, add:

```markdown
### BrowserLauncherService
Servizio per aprire URL nel browser di default del sistema (`Services/Shared/BrowserLauncherService.cs`).
*   **Interfaccia**: `IBrowserLauncherService`
*   **Metodo**: `Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred)`
*   **Funzionalità**:
    *   Validazione URL (formato, schema http/https)
    *   Apertura cross-platform usando `Browser.Default.OpenAsync()` di MAUI.Essentials
    *   Gestione errori con Snackbar user-friendly
    *   Prevenzione URL injection (solo http/https consentiti)
    *   Compatibile con sandbox macOS
*   **Sicurezza**:
    *   Blocca schemi `javascript:`, `file:`, `data:`
    *   Validazione rigorosa del formato URL
*   **Cross-platform**:
    *   Windows: apre browser predefinito (Edge, Chrome, Firefox...)
    *   macOS: apre browser predefinito (Safari, Chrome, Firefox...)
    *   Funziona anche in sandbox senza entitlements speciali
*   **Utilizzo**:
    ```csharp
    var success = await BrowserLauncher.OpenUrlAsync("https://example.com");
    if (success)
    {
        Snackbar.Add("Browser aperto", Severity.Success);
    }
    ```
```

**Step 3: Commit**

```bash
git add Documents/ComponentiShared.md
git commit -m "docs: add WebRegistrationDialog and BrowserLauncherService to ComponentiShared

- Document WebRegistrationDialog usage and parameters
- Document BrowserLauncherService security features
- Add cross-platform compatibility notes
- Include code examples

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Final Verification and Cleanup

**Files:** All modified files

**Step 1: Run full build**

Run: Build entire solution in Release mode

Expected: Zero errors, zero warnings

**Step 2: Visual inspection checklist**

- [ ] DashboardAdmin: Button visible after "Iscrizione Veloce"
- [ ] DashboardAdmin: Button disabled when no URL
- [ ] DashboardAdmin: Tooltip shows on hover when disabled
- [ ] DashboardSuperAdmin: Button visible after "Iscrizione Veloce"
- [ ] DashboardSuperAdmin: Button always enabled
- [ ] WebRegistrationDialog: Opens correctly
- [ ] WebRegistrationDialog: AziendaSelect works
- [ ] WebRegistrationDialog: URL preview shows when available
- [ ] WebRegistrationDialog: Alert shows when URL missing
- [ ] Browser opens on both Windows and macOS

**Step 3: Code review self-check**

- [ ] No hardcoded strings (all in code, not config - acceptable for this feature)
- [ ] No memory leaks (CancellationTokenSource disposed)
- [ ] Error handling comprehensive
- [ ] Code follows existing patterns (FileOpenerService, other dialogs)
- [ ] No duplicate code

**Step 4: Git status check**

Run: `git status`

Expected: All files committed, working directory clean

**Step 5: Final commit (if any cleanup needed)**

If minor fixes were made during verification:

```bash
git add .
git commit -m "chore: final cleanup and verification for Web Registration feature

- Fix any minor issues found during testing
- Verify all files properly formatted

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Success Criteria

**Functional:**
- ✅ Button appears in both dashboards
- ✅ Button state (enabled/disabled) correct based on URL configuration
- ✅ Browser opens with correct URL
- ✅ Works on Windows and macOS (sandbox)

**UX:**
- ✅ Clear feedback via Snackbar
- ✅ Tooltip explains disabled state
- ✅ Dialog flow intuitive for SuperAdmin

**Technical:**
- ✅ No memory leaks
- ✅ Proper error handling
- ✅ Security: only http/https URLs accepted
- ✅ Code maintainable and testable

---

## Rollback Plan

If issues arise, rollback in reverse task order:

1. Revert Task 8 (docs only, safe)
2. Revert Task 5 (DashboardSuperAdmin button)
3. Revert Task 4 (DashboardAdmin button)
4. Revert Task 3 (WebRegistrationDialog)
5. Revert Task 2 (DI registration)
6. Revert Task 1 (BrowserLauncherService)

Each task is isolated, so partial rollback is safe.

---

## Notes

- **No database migrations needed** - `SitoWebIscrizione` field already exists
- **No breaking changes** - Feature is purely additive
- **Backward compatible** - Existing functionality untouched
- **Cross-platform tested** - Works on both Windows and macOS

---

## Estimated Time

- Task 1: 5 minutes
- Task 2: 2 minutes
- Task 3: 10 minutes
- Task 4: 10 minutes
- Task 5: 5 minutes
- Task 6: 15 minutes (manual testing)
- Task 7: 15 minutes (manual testing)
- Task 8: 5 minutes
- Task 9: 5 minutes

**Total: ~70 minutes (1 hour 10 minutes)**
