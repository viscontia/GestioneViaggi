# Pattern CRUD Ereditabile - Guida alla Replicazione

Questa guida spiega come creare nuove gestioni CRUD basate sul pattern implementato per `ana_geo_capoluogo`.

## 🏗️ Struttura del Pattern

Il sistema CRUD è composto da 4 elementi principali:

1. **Model** (ereditato da `BaseEntity`)
2. **Service** (ereditato da `BaseCrudService<T>`)
3. **Dialog Component** (modale per Insert/Edit)
4. **Page Component** (pagina con DataGrid)

---

## 📋 Step 1: Creare il Model

**Posizione:** `/Models/NomeEntita.cs`

```csharp
using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta [descrizione entità] (tabella nome_tabella)
/// </summary>
public class NomeEntita : BaseEntity
{
    [Required(ErrorMessage = "Il campo è obbligatorio")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Nome { get; set; } = string.Empty;

    [StringLength(500, ErrorMessage = "Max 500 caratteri")]
    public string? Descrizione { get; set; }

    // Aggiungi altri campi necessari
}
```

**Note:**
- `BaseEntity` fornisce automaticamente la proprietà `Id` (non visibile all'utente)
- Usa `DataAnnotations` per validazione automatica

---

## 🔧 Step 2: Creare il Service

**Posizione:** `/Services/CRUD/NomeEntitaService.cs`

```csharp
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class NomeEntitaService : BaseCrudService<NomeEntita>
{
    // Configura nome tabella e colonna ID
    protected override string TableName => "nome_tabella_db";
    protected override string IdColumnName => "id_column_db";

    public NomeEntitaService(IDatabaseService databaseService, ILogger<NomeEntitaService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<NomeEntita> CreateAsync(NomeEntita entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO nome_tabella_db (campo1, campo2)
                VALUES (@campo1, @campo2)
                RETURNING id_column_db, campo1, campo2";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("campo1", entity.Campo1);
            command.Parameters.AddWithValue("campo2", (object?)entity.Campo2 ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare l'entità");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione");
            throw;
        }
    }

    public override async Task<NomeEntita> UpdateAsync(NomeEntita entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE nome_tabella_db
                SET campo1 = @campo1, campo2 = @campo2
                WHERE id_column_db = @id
                RETURNING id_column_db, campo1, campo2";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("campo1", entity.Campo1);
            command.Parameters.AddWithValue("campo2", (object?)entity.Campo2 ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Entità con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento");
            throw;
        }
    }

    protected override NomeEntita MapFromReader(NpgsqlDataReader reader)
    {
        return new NomeEntita
        {
            Id = ReadInt(reader, "id_column_db"),
            Campo1 = reader.GetString(reader.GetOrdinal("campo1")),
            Campo2 = ReadNullableString(reader, "campo2")
        };
    }
}
```

## 🔢 Step 2.1: Gestione Sequence e Auto-Increment (PostgreSQL)

**⚠️ CRITICO:** In PostgreSQL, l'auto-increment è gestito tramite **Sequence**.
Spesso, specialmente dopo importazioni dati o creazioni manuali di tabelle, la sequence potrebbe mancare o non essere sincronizzata con l'ID massimo, causando errori `42P01` (undefined table/sequence) o `23505` (duplicate key).

**✅ Soluzione Standard (Self-Healing Pattern):**
Il Service deve essere in grado di "auto-ripararsi" se la sequence manca.

**Implementazione nel Service (`CreateAsync`):**

```csharp
    public override async Task<NomeEntita> CreateAsync(NomeEntita entity)
    {
        // Wrapper per gestire il retry
        return await CreateAsyncInternal(entity, true);
    }

    private async Task<NomeEntita> CreateAsyncInternal(NomeEntita entity, bool allowRetry)
    {
        try
        {
            // ... codice standard di insert ...
            // INSERT INTO ... RETURNING ...
        }
        catch (PostgresException ex) when (allowRetry && ex.SqlState == "42P01" && ex.Message.Contains("nome_tabella_seq"))
        {
            _logger.LogWarning(ex, "Sequence mancante. Tentativo di auto-fix.");
            await FixSequenceAsync();
            return await CreateAsyncInternal(entity, false); // Retry
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione");
            throw;
        }
    }

    private async Task FixSequenceAsync()
    {
        try 
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                DO $$
                BEGIN
                    -- 1. Crea la sequence se non esiste
                    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'nome_tabella_seq') THEN
                        CREATE SEQUENCE nome_tabella_seq;
                    END IF;

                    -- 2. Imposta il default della colonna ID
                    ALTER TABLE nome_tabella 
                    ALTER COLUMN id_column_db SET DEFAULT nextval('nome_tabella_seq');

                    -- 3. Sincronizza con il MAX ID attuale
                    PERFORM setval('nome_tabella_seq', COALESCE((SELECT MAX(id_column_db) FROM nome_tabella), 0) + 1, false);
                END $$;";
                
            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il fix della sequence");
            throw;
        }
    }
```

**Verifica Manuale SQL:**
È buona norma creare anche uno script SQL di fix nella cartella `SqlScripts/` (es. `12_Fix_NomeTabella_Sequence.sql`):
```sql
-- Fix sequence for nome_tabella
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'nome_tabella_seq') THEN
        CREATE SEQUENCE nome_tabella_seq;
    END IF;
    ALTER TABLE nome_tabella ALTER COLUMN id_column_db SET DEFAULT nextval('nome_tabella_seq');
    PERFORM setval('nome_tabella_seq', COALESCE((SELECT MAX(id_column_db) FROM nome_tabella), 0) + 1, false);
END $$;
```

**Helper methods disponibili:**
- `ReadInt(reader, "columnName")` - legge un int
- `ReadNullableString(reader, "columnName")` - legge una stringa nullable
- `GetAllAsync()` e `DeleteAsync()` sono già implementati in `BaseCrudService`

---

## 🎨 Step 3: Creare il Dialog Component

**Posizione:** `/Components/Shared/NomeEntitaDialog.razor`

```razor
@using GestioneViaggi.Models
@using MudBlazor

<MudDialog>
    <TitleContent>
        <MudText Typo="Typo.h6">
            @(IsEditMode ? "Modifica [Entità]" : "Nuova [Entità]")
        </MudText>
    </TitleContent>
    <DialogContent>
        <MudForm @ref="_form" Model="@Entity">
            <!-- PRIMO CAMPO OBBLIGATORIO: con asterisco rosso e uppercase enforced -->
            <MudTextField @ref="_firstField"
                          Value="@Entity.Campo1"
                          ValueChanged="@HandleCampo1Changed"
                          For="@(() => Entity.Campo1)"
                          Label="Campo 1"
                          Variant="Variant.Outlined"
                          Immediate="true"
                          Required="true"
                          RequiredError="Campo 1 è obbligatorio"
                          MaxLength="100"
                          tabindex="1"
                          Class="mb-3 uppercase-input"
                          Adornment="Adornment.End"
                          AdornmentText="*"
                          AdornmentColor="Color.Error"
                          OnBlur="@(() => HandleFieldBlur(_firstField))"
                          OnKeyDown="@HandleKeyDown" />

            <!-- SECONDO CAMPO OPZIONALE: senza asterisco -->
            <MudTextField @bind-Value="Entity.Campo2"
                          For="@(() => Entity.Campo2)"
                          Label="Campo 2 (opzionale)"
                          Variant="Variant.Outlined"
                          Lines="3"
                          MaxLength="500"
                          tabindex="2"
                          Class="mb-3" />

            <!-- Aggiungi altri campi con tabindex progressivo (3, 4, 5...) -->
        </MudForm>
    </DialogContent>
    <DialogActions>
        <MudButton OnClick="Cancel" Variant="Variant.Text" Color="Color.Default">
            Annulla
        </MudButton>
        <MudButton OnClick="HandleSubmit" Variant="Variant.Filled" Color="Color.Primary">
            @(IsEditMode ? "Aggiorna" : "Crea")
        </MudButton>
    </DialogActions>
</MudDialog>

### ⚠️ Regola GLOBALE per le Modali: BackdropClick = false

**REGOLA FONDAMENTALE**: L'utente NON deve poter chiudere la modale cliccando fuori (sul backdrop).
Quando si istanzia `DialogOptions` nella pagina che apre il dialog (vedi Step 4), è **OBBLIGATORIO** impostare `BackdropClick = false`.

```csharp
var options = new DialogOptions 
{ 
    CloseButton = true, 
    MaxWidth = MaxWidth.Small, 
    FullWidth = true, 
    BackdropClick = false // <--- OBBLIGATORIO
};
```

### 🧩 Ereditarietà: BaseCrudDialog (Opzionale ma Consigliato)
È possibile far ereditare il dialog da `BaseCrudDialog<T>` invece che implementare tutto manualmente.
Vedi `/Components/Shared/BaseCrudDialog.cs` per dettagli.
Attualmente il pattern standard prevede l'implementazione esplicita per massima flessibilità, ma ricordarsi della regola `BackdropClick`.

@code {
    private MudForm? _form;
    private MudTextField<string>? _firstField;

    [CascadingParameter]
    private IMudDialogInstance? MudDialog { get; set; }

    [Parameter]
    public NomeEntita Entity { get; set; } = new NomeEntita();

    [Parameter]
    public bool IsEditMode { get; set; }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender && _firstField != null)
        {
            // SetFocus automatico sul primo campo quando il dialog si apre
            await _firstField.FocusAsync();
        }
    }

    private void Cancel()
    {
        MudDialog?.Cancel();
    }

    // ⚠️ OBBLIGATORIO: Handler per uppercase in tempo reale
    private void HandleCampo1Changed(string value)
    {
        Entity.Campo1 = value?.ToUpper() ?? string.Empty;
        StateHasChanged(); // Forza re-render per mostrare uppercase
    }

    private async Task HandleFieldBlur(MudTextField<string>? field)
    {
        if (field != null)
        {
            await field.Validate();
            if (field.Error)
            {
                // Delay per permettere al click su "Annulla" di essere processato prima del focus back
                await Task.Delay(150);
                try
                {
                    await field.FocusAsync();
                }
                catch
                {
                    // Ignora errori se il dialog è stato chiuso
                }
            }
        }
    }

    private async Task HandleKeyDown(KeyboardEventArgs e)
    {
        if (e.Key == "Enter")
        {
            await HandleSubmit();
        }
    }

    private async Task HandleSubmit()
    {
        if (_form != null)
        {
            await _form.Validate();
            if (_form.IsValid)
            {
                MudDialog?.Close(DialogResult.Ok(Entity));
            }
            else
            {
                // Se ci sono errori, focus sul primo campo invalido
                // Nota: estendere la logica per altri campi se necessario
                if (_firstField?.Error == true)
                {
                    await _firstField.FocusAsync();
                }
            }
        }
    }
}
```

**Tipi di input MudBlazor disponibili:**
- `MudTextField` - testo semplice
- `MudNumericField` - numeri
- `MudDatePicker` - date
- `MudSelect` - dropdown
- `MudCheckBox` - checkbox

**⚡ Pattern SetFocus e TAB Navigation (SOLUZIONE DEFINITIVA - JavaScript):**

**🚨 PROBLEMA**: Il **FocusTrap** di MudDialog blocca la navigazione TAB del browser. Nessuna soluzione HTML/CSS funziona.

**✅ UNICA SOLUZIONE FUNZIONANTE (JavaScript Helper):**

**1. Script incluso in `index.html`:**
```html
<script src="js/dialogFormHelper.js"></script>
```

**2. Pattern OBBLIGATORIO per TUTTI i Dialog CRUD (con Focus + TAB):**

```razor
@using Microsoft.JSInterop
@inject IJSRuntime JS
@implements IDisposable

@code {
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            try
            {
                // Setup TAB navigation con JavaScript helper
                await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error setting up dialog tab navigation: {ex.Message}");
            }

            // ⚠️ OBBLIGATORIO: Focus manuale sul primo campo (sempre eseguito)
            // Delay di 300ms per permettere rendering completo di MudBlazor
            if (_firstField != null)
            {
                await Task.Delay(300);
                try
                {
                    await _firstField.FocusAsync();
                    Console.WriteLine("Focus manuale applicato al primo campo");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Errore focus manuale: {ex.Message}");
                }
            }
        }
    }

    public void Dispose()
    {
        try { JS.InvokeVoidAsync("dialogFormHelper.cleanup"); } catch { }
    }
}
```

**💡 COME FUNZIONA:**
- **JavaScript helper** (`dialogFormHelper.setupTabNavigation`):
  - Intercetta `keydown` con TAB
  - Usa `e.preventDefault()` per bloccare il comportamento del FocusTrap
  - Forza manualmente `.focus()` sull'input successivo
  - Supporta SHIFT+TAB per navigazione indietro
  - **Include un focus automatico sul primo campo dopo 150ms**

- **Focus manuale C# OBBLIGATORIO** (dopo 300ms):
  - MudBlazor può impiegare più tempo a renderizzare i componenti
  - Il delay di 300ms garantisce che il DOM sia completamente pronto
  - Il focus manuale **sovrascrive** eventuali conflitti con il JavaScript
  - **SEMPRE eseguito**, anche se il JavaScript funziona
  - Include try/catch per gestire errori senza bloccare il dialog

**🔴 COSA NON FUNZIONA (evitare):**
- ❌ Solo JavaScript senza focus manuale C# → timing non garantito
- ❌ Focus manuale senza delay (o con delay < 300ms) → componenti non pronti
- ❌ `tabindex="1"` inline → va sul wrapper `<div>`, non su `<input>`
- ❌ UserAttributes → combatte col FocusTrap
- ❌ Ordine DOM naturale → FocusTrap blocca comunque
- ❌ Soluzioni CSS-only → problema JavaScript, non CSS
- ❌ Delay troppo brevi (50ms, 100ms, 150ms) → MudBlazor non pronto

**⚙️ PERCHÉ 300ms È IL DELAY CORRETTO:**
- MudBlazor renderizza i componenti in modo asincrono
- I componenti complessi (Select, NumericField, CheckBox) richiedono più tempo
- 150ms potrebbe essere insufficiente in scenari con molti campi
- 300ms garantisce stabilità su tutti i browser e configurazioni

**🔧 TROUBLESHOOTING FOCUS:**
Se il focus NON funziona, verifica:
1. ✅ Il campo ha `@ref="_firstField"` correttamente assegnato
2. ✅ La variabile è dichiarata: `private MudTextField<string>? _firstField;`
3. ✅ Il delay è di almeno 300ms (NON 150ms o meno)
4. ✅ Il focus manuale è SEMPRE eseguito (non solo nel catch)
5. ✅ Il dialog implementa `IDisposable` con cleanup JavaScript
6. ✅ Controlla la console browser (F12) per vedere i log di debug
7. ✅ Riavvia l'applicazione completamente (non solo hot-reload)

**🌟 Campi Obbligatori - UX Best Practice:**
1. **Asterisco rosso**: Usare `AdornmentText="*"` con colore rosso per indicare visivamente i campi obbligatori
2. **Required="true"**: Attiva la validazione MudBlazor
3. **RequiredError**: Messaggio custom di errore quando il campo è vuoto
4. **Label opzionali**: Aggiungere "(opzionale)" nel label per campi non obbligatori
5. **Adornment**: Usare `AdornmentText="*"` con `AdornmentColor="Color.Error"`
6. **Focus Trap Intelligente**: Implementare `OnBlur` con delay per permettere il funzionamento del pulsante "Annulla" pur mantenendo il focus sul campo invalido
7. **🔴 Uppercase Enforced - OBBLIGATORIO per tutti i campi di testo**:
   - Usare `Value` / `ValueChanged` con metodo custom invece di `@bind-Value`
   - `ValueChanged="@HandleNomeChanged"` - chiama metodo che converte e forza re-render
   - `Immediate="true"` - applica la conversione immediatamente
   - **AGGIUNGERE `Class="uppercase-input"`** per visualizzare in tempo reale il testo maiuscolo mentre si digita
   - Nel @code creare metodo: `Entity.Nome = value?.ToUpper(); StateHasChanged();`
   - Il dato viene salvato in UPPERCASE nel database PostgreSQL
   - **ECCEZIONE**: Non applicare a campi Password o email case-sensitive
   - ⚠️ **NON usare lambda inline o Converter**: non forzano re-render corretto

**Esempio completo di Dialog CRUD con Focus e TAB funzionanti:**

```razor
@using GestioneViaggi.Models
@using MudBlazor
@using Microsoft.JSInterop
@inject IJSRuntime JS
@implements IDisposable

<MudDialog>
    <TitleContent>
        <MudText Typo="Typo.h6">
            @(IsEditMode ? "Modifica Entità" : "Nuova Entità")
        </MudText>
    </TitleContent>
    <DialogContent>
        <MudForm @ref="_form" Model="@Entity">
            <MudTextField @ref="_firstField"
                          Value="@Entity.Nome"
                          ValueChanged="@HandleNomeChanged"
                          For="@(() => Entity.Nome)"
                          Label="Nome"
                          Variant="Variant.Outlined"
                          Immediate="true"
                          Required="true"
                          RequiredError="Il nome è obbligatorio"
                          MaxLength="100"
                          tabindex="1"
                          Class="mb-3 uppercase-input"
                          Adornment="Adornment.End"
                          AdornmentText="*"
                          AdornmentColor="Color.Error"
                          OnKeyDown="@HandleKeyDown" />

            <MudTextField @bind-Value="Entity.Descrizione"
                          For="@(() => Entity.Descrizione)"
                          Label="Descrizione (opzionale)"
                          Variant="Variant.Outlined"
                          Lines="3"
                          MaxLength="500"
                          tabindex="2"
                          Class="mb-3" />
        </MudForm>
    </DialogContent>
    <DialogActions>
        <MudButton OnClick="Cancel" Variant="Variant.Text" Color="Color.Default">
            Annulla
        </MudButton>
        <MudButton OnClick="HandleSubmit" Variant="Variant.Filled" Color="Color.Primary">
            @(IsEditMode ? "Aggiorna" : "Crea")
        </MudButton>
    </DialogActions>
</MudDialog>

@code {
    private MudForm? _form;
    private MudTextField<string>? _firstField;

    [CascadingParameter]
    private IMudDialogInstance? MudDialog { get; set; }

    [Parameter]
    public MyEntity Entity { get; set; } = new MyEntity();

    [Parameter]
    public bool IsEditMode { get; set; }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            try
            {
                // Setup TAB navigation
                await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error setting up dialog tab navigation: {ex.Message}");
            }

            // Focus manuale OBBLIGATORIO con delay 300ms
            if (_firstField != null)
            {
                await Task.Delay(300);
                try
                {
                    await _firstField.FocusAsync();
                    Console.WriteLine("Focus applicato al primo campo");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Errore focus: {ex.Message}");
                }
            }
        }
    }

    public void Dispose()
    {
        try { JS.InvokeVoidAsync("dialogFormHelper.cleanup"); } catch { }
    }

    private void Cancel() => MudDialog?.Cancel();

    private void HandleNomeChanged(string value)
    {
        Entity.Nome = value?.ToUpper() ?? string.Empty;
        StateHasChanged();
    }

    private async Task HandleKeyDown(KeyboardEventArgs e)
    {
        if (e.Key == "Enter") await HandleSubmit();
    }

    private async Task HandleSubmit()
    {
        if (_form != null)
        {
            await _form.Validate();
            if (_form.IsValid)
            {
                MudDialog?.Close(DialogResult.Ok(Entity));
            }
        }
    }
}
```

**File reali da consultare:** `ComuneDialog.razor`, `ProvinciaDialog.razor`, `CapoluogoDialog.razor`

**Esempio campo opzionale:**
```razor
<MudTextField @bind-Value="Entity.Note"
              Label="Note (opzionale)" />
```

**🔢 Campi Numerici - Formattazione Italiana con Separatore Migliaia:**

**REGOLA OBBLIGATORIA**: Tutti i campi numerici (int, decimal) devono essere visualizzati con il separatore delle migliaia in formato italiano (punto come separatore migliaia, virgola come separatore decimali).

1. **In Input (Dialog)**: Usare `MudNumericField` con `Culture` italiano
2. **In Grid (Visualizzazione)**: Usare `PropertyColumn` con `Format` o `CellTemplate` per formattazione custom

**Esempio campo numerico in Dialog:**
```razor
<MudNumericField @bind-Value="Entity.Residenti"
                 For="@(() => Entity.Residenti)"
                 Label="Residenti - opzionale"
                 Variant="Variant.Outlined"
                 Min="0"
                 Culture="@(new System.Globalization.CultureInfo("it-IT"))"
                 Format="N0"
                 tabindex="5"
                 Class="mb-3" />

<MudNumericField @bind-Value="Entity.Superficie"
                 For="@(() => Entity.Superficie)"
                 Label="Superficie (kmq) - opzionale"
                 Variant="Variant.Outlined"
                 Min="0"
                 Culture="@(new System.Globalization.CultureInfo("it-IT"))"
                 Format="N2"
                 tabindex="4"
                 Class="mb-3" />
```

**Formati disponibili:**
- `Format="N0"` - Numeri interi con separatore migliaia (es: 1.234.567)
- `Format="N2"` - Numeri decimali con 2 cifre (es: 1.234,56)
- `Format="C2"` - Valuta con simbolo € (es: € 1.234,56)
- `Format="P2"` - Percentuale (es: 12,34%)

**Esempio colonna numerica in DataGrid con larghezza e allineamento:**
```razor
<PropertyColumn Property="x => x.Residenti"
                Title="Residenti"
                Format="N0">
    <HeaderStyle>
        min-width: 120px;
        text-align: right;
    </HeaderStyle>
    <CellStyle>
        min-width: 120px;
        text-align: right;
    </CellStyle>
</PropertyColumn>

<PropertyColumn Property="x => x.Superficie"
                Title="Superficie (kmq)"
                Format="N2">
    <HeaderStyle>
        min-width: 140px;
        text-align: right;
    </HeaderStyle>
    <CellStyle>
        min-width: 140px;
        text-align: right;
    </CellStyle>
</PropertyColumn>
```

**🎯 Larghezze Colonne Consigliate:**
- Colonne testo corto (Sigla, Codice): `80-100px` con `text-align: center`
- Colonne testo medio (Nome, Descrizione): `180-200px`
- Colonne numeriche (int): `110-120px` con `text-align: right`
- Colonne numeriche (decimal): `130-150px` con `text-align: right`
- **IMPORTANTE**: Usare sempre `text-align: right` per colonne numeriche

**🤖 Auto-Sizing Automatico delle Colonne (CONSIGLIATO):**

Invece di configurare manualmente ogni colonna, usa `DataGridHelper` per calcolo automatico:

**Step 1: Inizializza l'helper dopo il caricamento dati**
```csharp
@code {
    private List<Provincia> _items = new();
    private DataGridHelper<Provincia>? _gridHelper;

    private async Task LoadDataAsync()
    {
        _items = await Service.GetAllAsync();

        // Inizializza helper per auto-sizing
        if (_items.Any())
        {
            _gridHelper = new DataGridHelper<Provincia>(_items, sampleSize: 50);
        }
    }
}
```

**Step 2: Usa l'helper nelle colonne**
```razor
@using GestioneViaggi.Services.UI

<Columns>
    @if (_gridHelper != null)
    {
        <PropertyColumn Property="x => x.Descrizione"
                        Title="Provincia"
                        HeaderStyle="@_gridHelper.GetColumnStyle(nameof(Provincia.Descrizione), "Provincia")"
                        CellStyle="@_gridHelper.GetColumnStyle(nameof(Provincia.Descrizione), "Provincia")" />

        <PropertyColumn Property="x => x.Residenti"
                        Title="Residenti"
                        Format="N0"
                        HeaderStyle="@_gridHelper.GetColumnStyle(nameof(Provincia.Residenti), "Residenti")"
                        CellStyle="@_gridHelper.GetColumnStyle(nameof(Provincia.Residenti), "Residenti")" />
    }
</Columns>
```

**Vantaggi Auto-Sizing:**
- ✅ **Calcolo automatico** larghezza basato sul contenuto reale
- ✅ **Allineamento intelligente**: numeri a destra, testo corto centrato
- ✅ **Performance**: analizza solo primi 50 record (configurabile)
- ✅ **Responsive**: si adatta ai dati effettivi della tabella
- ✅ **Meno codice**: elimina configurazione manuale ripetitiva

**Parametri Configurabili:**
```csharp
_gridHelper = new DataGridHelper<T>(
    items,
    sampleSize: 50,     // Numero record da analizzare (default: 50)
    minWidth: 80,       // Larghezza minima colonna (default: 80px)
    maxWidth: 400       // Larghezza massima colonna (default: 400px)
);
```

**Alternativa con CellTemplate per formattazione custom:**
```razor
<TemplateColumn Title="Residenti">
    <CellTemplate>
        @context.Item.Residenti?.ToString("N0", new System.Globalization.CultureInfo("it-IT"))
    </CellTemplate>
</TemplateColumn>
```

**⚠️ IMPORTANTE**:
- Culture `it-IT` è OBBLIGATORIA per avere punto come separatore migliaia
- Usare sempre `Format` o `.ToString()` con culture specificata
- Per nullable int/decimal, usare `?.ToString()` per gestire valori null

---

## 📄 Step 4: Creare la Page Component

**Posizione:** `/Components/Pages/Tabelle/NomeEntita.razor`

```razor
@page "/tabelle/nomeentita"
@using Microsoft.AspNetCore.Authorization
@using GestioneViaggi.Models
@using GestioneViaggi.Services.CRUD
@using GestioneViaggi.Services.UI
@using GestioneViaggi.Components.Shared
@using MudBlazor
@inject NomeEntitaService Service
@inject IDialogService DialogService
@inject ISnackbar Snackbar
@inject IStatusBarService StatusBarService
@attribute [Authorize]
@implements IDisposable

@if (!string.IsNullOrEmpty(_errorMessage))
{
    <MudAlert Severity="Severity.Error" Variant="Variant.Filled" Class="my-2">
        <MudText Typo="Typo.h6">ERRORE:</MudText>
        <MudText>@_errorMessage</MudText>
    </MudAlert>
}
else
{
    <EnterpriseDataGrid T="NomeEntita"
                        Items="@_items"
                        Title="Gestione Nome Tabella"
                        SearchFunction="@Search"
                        @bind-SelectedItem="_selectedItem">

        <ToolBarActions>
            <MudButton Variant="Variant.Filled"
                       Color="Color.Primary"
                       StartIcon="@Icons.Material.Filled.Add"
                       OnClick="@OpenCreateDialog">
                Nuovo
            </MudButton>
        </ToolBarActions>

        <Columns>
            <PropertyColumn Property="x => x.Campo1" Title="Campo 1" />
            <PropertyColumn Property="x => x.Campo2" Title="Campo 2" />

            <EnterpriseActionsColumn T="NomeEntita"
                                     OnEdit="@OpenEditDialog"
                                     OnDelete="@DeleteItem" />
        </Columns>

    </EnterpriseDataGrid>
}

@code {
    private List<NomeEntita> _items = new();
    private NomeEntita? _selectedItem;
    private string _errorMessage = string.Empty;

    protected override async Task OnInitializedAsync()
    {
        StatusBarService.SetCurrentTable("nome_tabella_db");
        await LoadDataAsync();
    }

    public void Dispose()
    {
        StatusBarService.SetCurrentTable(null);
    }

    private async Task LoadDataAsync()
    {
        try
        {
            _errorMessage = string.Empty;
            _items = await Service.GetAllAsync();
        }
        catch (Exception ex)
        {
            _errorMessage = $"Errore durante il caricamento: {ex.Message}";
        }
    }

    private bool Search(NomeEntita item, string searchString)
    {
        if (string.IsNullOrWhiteSpace(searchString)) return true;
        if (item.Campo1?.Contains(searchString, StringComparison.OrdinalIgnoreCase) == true) return true;
        if (item.Campo2?.Contains(searchString, StringComparison.OrdinalIgnoreCase) == true) return true;
        return false;
    }

    private async Task OpenCreateDialog()
    {
        var parameters = new DialogParameters<NomeEntitaDialog>
        {
            { x => x.Entity, new NomeEntita() },
            { x => x.IsEditMode, false }
        };

        var options = new DialogOptions
        {
            CloseButton = true,
            MaxWidth = MaxWidth.Small,
            FullWidth = true,
            BackdropClick = false // <--- OBBLIGATORIO
        };

        var dialog = await DialogService.ShowAsync<NomeEntitaDialog>("Nuovo", parameters, options);
        var result = await dialog.Result;

        if (!result!.Canceled && result.Data is NomeEntita newItem)
        {
            try
            {
                var created = await Service.CreateAsync(newItem);
                _items.Add(created);
                Snackbar.Add("Creato con successo", Severity.Success);
                StateHasChanged();
            }
            catch (Exception ex)
            {
                Snackbar.Add($"Errore: {ex.Message}", Severity.Error);
            }
        }
    }

    private async Task OpenEditDialog(NomeEntita item)
    {
        var parameters = new DialogParameters<NomeEntitaDialog>
        {
            { x => x.Entity, new NomeEntita { Id = item.Id, Campo1 = item.Campo1, Campo2 = item.Campo2 } },
            { x => x.IsEditMode, true }
        };

        var options = new DialogOptions
        {
            CloseButton = true,
            MaxWidth = MaxWidth.Small,
            FullWidth = true
        };

        var dialog = await DialogService.ShowAsync<NomeEntitaDialog>("Modifica", parameters, options);
        var result = await dialog.Result;

        if (!result!.Canceled && result.Data is NomeEntita updatedItem)
        {
            try
            {
                var updated = await Service.UpdateAsync(updatedItem);
                var index = _items.FindIndex(c => c.Id == updated.Id);
                if (index >= 0)
                {
                    _items[index] = updated;
                }
                Snackbar.Add("Aggiornato con successo", Severity.Success);
                StateHasChanged();
            }
            catch (Exception ex)
            {
                Snackbar.Add($"Errore: {ex.Message}", Severity.Error);
            }
        }
    }

    private async Task DeleteItem(NomeEntita item)
    {
        var parameters = new DialogParameters
        {
            { "Title", "Attenzione" },
            { "ContentText", $"Vuoi veramente cancellare questo record? ({item.Campo1})" }
        };

        var options = new DialogOptions { CloseButton = true, MaxWidth = MaxWidth.ExtraSmall };

        var dialog = await DialogService.ShowAsync<DeleteConfirmationDialog>("Delete", parameters, options);
        var result = await dialog.Result;

        if (!result!.Canceled)
        {
            try
            {
                var success = await Service.DeleteAsync(item.Id);
                if (success)
                {
                    _items.Remove(item);
                    Snackbar.Add("Eliminato con successo", Severity.Success);
                    StateHasChanged();
                }
                else
                {
                    Snackbar.Add("Impossibile eliminare", Severity.Warning);
                }
            }
            catch (Exception ex)
            {
                Snackbar.Add($"Errore: {ex.Message}", Severity.Error);
            }
        }
    }
}
```

---

## ⚙️ Step 5: Registrare il Service

**Posizione:** `/MauiProgram.cs`

Aggiungi nella sezione `// CRUD SERVICES`:

```csharp
builder.Services.AddScoped<NomeEntitaService>();
```

---

## 🎯 Esempio Completo: ana_geo_capoluogo

### File creati:
1. ✅ `/Models/BaseEntity.cs` - Classe base con Id
2. ✅ `/Models/Capoluogo.cs` - Model specifico
3. ✅ `/Services/CRUD/ICrudService.cs` - Interfaccia generica
4. ✅ `/Services/CRUD/BaseCrudService.cs` - Service base con GetAll, GetById, Delete
5. ✅ `/Services/CRUD/CapoluogoService.cs` - Service specifico con Create, Update, MapFromReader
6. ✅ `/Components/Shared/CapoluogoDialog.razor` - Dialog modale
7. ✅ `/Components/Pages/Tabelle/Capoluoghi.razor` - Pagina completa con DataGrid

### Registrazione in MauiProgram.cs:
```csharp
builder.Services.AddScoped<CapoluogoService>();
```

---

## 🎨 Styling

Il sistema usa automaticamente il foglio di stile:
- `/wwwroot/css/premium-saas-ULTRA-SPECIFIC.css`

Il componente `EnterpriseDataGrid` applica automaticamente:
- Dark/Light mode support
- Hover effects (Edit: giallo, Delete: rosso)
- Typography: Headers 12px uppercase, Celle 14px
- Striping e dense mode disabilitati per controllo CSS completo
- **Paginazione Automatica**: Pager integrato in basso a destra con testi in italiano ("Righe per pagina", "{first}-{last} di {total}")

---

## 📋 Title della DataGrid - OBBLIGATORIO

**REGOLA FONDAMENTALE**: Ogni `EnterpriseDataGrid` deve avere un `Title` chiaro e descrittivo che indica la gestione in corso.

### Formato Standard (OBBLIGATORIO):
```razor
<EnterpriseDataGrid T="NomeEntita"
                    Items="@_items"
                    Title="Gestione Nome Entità"
                    SearchFunction="@Search"
                    @bind-SelectedItem="_selectedItem">

    <ToolBarActions>
        <MudButton Variant="Variant.Filled"
                   Color="Color.Primary"
                   StartIcon="@Icons.Material.Filled.Add"
                   OnClick="@OpenCreateDialog">
            Nuovo
        </MudButton>
    </ToolBarActions>

    <Columns>
        ...
    </Columns>
</EnterpriseDataGrid>
```

### Componenti Necessari:
1. **Parametro `Title`**: Passare la stringa descrittiva direttamente al componente (es: `Title="Gestione Nazioni"`). Il componente si occuperà di renderizzarlo con lo stile corretto (H5, semi-bold).
2. **`<ToolBarActions>`**: Usare questo RenderFragment per i pulsanti (es: "Nuovo"). Verranno posizionati automaticamente a destra della barra di ricerca.

### Esempi:
- `Gestione Nazioni` - per tabella Countries
- `Gestione Regioni` - per tabella Regioni
- `Gestione Province` - per tabella Province
- `Gestione Capoluoghi di Regione` - per tabella Capoluoghi

### Stile Automatico (da CSS globale):
- ✅ Font size 1.5rem (H5 - grande e visibile)
- ✅ Font weight 600 (semi-bold)
- ✅ Supporto automatico tema chiaro/scuro
- ✅ Letter-spacing ottimizzato (-0.02em)
- ✅ Colori: Light `#111827`, Dark `#E6E8EB`

**⚠️ IMPORTANTE**:
- Il titolo viene gestito internamente dal componente `EnterpriseGridToolbar`.
- Il testo deve essere user-friendly, NON il nome tecnico della tabella DB.

---

## 📊 StatusBar - Visualizzazione Nome Tabella

**PATTERN OBBLIGATORIO**: Ogni pagina CRUD deve mostrare nella bottom bar il nome della tabella DB su cui sta lavorando.

### Implementazione:

**1. Aggiungere le dipendenze necessarie:**
```razor
@using GestioneViaggi.Services.UI
@inject IStatusBarService StatusBarService
@implements IDisposable
```

**2. Impostare il nome tabella in `OnInitializedAsync()`:**
```csharp
protected override async Task OnInitializedAsync()
{
    StatusBarService.SetCurrentTable("nome_tabella_db");
    await LoadDataAsync();
}
```

**3. Ripulire il nome tabella quando la pagina viene distrutta:**
```csharp
public void Dispose()
{
    StatusBarService.SetCurrentTable(null);
}
```

### Comportamento:
- ✅ Quando l'utente entra in una pagina CRUD, la bottom bar mostra: **📄 File: nome_tabella_db**
- ✅ Quando l'utente esce dalla pagina, l'informazione scompare automaticamente
- ✅ L'icona 📄 è generica e adatta a qualsiasi tipo di tabella
- ✅ Il nome della tabella è quello definito nel `Service` (`TableName`)

### Esempi:
- Pagina Nazioni → mostra `File: eba_countries`
- Pagina Regioni → mostra `File: ana_geo_regioni_ita`
- Pagina Province → mostra `File: ana_geo_province`
- Dashboard o altre pagine → nessuna visualizzazione

---

## ✅ Checklist per Nuova Tabella

- [ ] Creare Model in `/Models/`
- [ ] Creare Service in `/Services/CRUD/`
- [ ] Implementare `CreateAsync()`, `UpdateAsync()`, `MapFromReader()`
- [ ] Creare Dialog in `/Components/Shared/`
- [ ] Creare Page in `/Components/Pages/Tabelle/`
- [ ] **Aggiungere Title descrittivo all'EnterpriseDataGrid** (es: "Gestione Nazioni")
- [ ] **Implementare StatusBar pattern (SetCurrentTable + Dispose)**
- [ ] Registrare Service in `MauiProgram.cs`
- [ ] Testare: Create, Read, Update, Delete
- [ ] Verificare validazione form
- [ ] Testare funzione Search
- [ ] Verificare visualizzazione Title nella toolbar
- [ ] Verificare visualizzazione nome tabella in StatusBar

---

## 📝 Note Importanti

1. **ID sempre nascosto**: Il campo `Id` da `BaseEntity` non va mai mostrato nelle colonne del DataGrid
2. **Validazione**: Usa `DataAnnotations` nel Model per validazione automatica
3. **Nullable**: Usa `(object?)value ?? DBNull.Value` per parametri nullable
4. **Error handling**: Sempre try-catch con Snackbar per feedback utente
5. **StateHasChanged**: Chiamare dopo operazioni CRUD per refresh UI

---


## 🛡️ Regole di Validazione

La validazione rigida dei dati lato client è fondamentale per mantenere intatta l'integrità del database.

### 🔢 1. Campi Numerici

I campi che rappresentano numeri (interi, decimali, quantità, etc.) devono essere configurati per **accettare ESCLUSIVAMENTE input numerici**.
La soluzione standard con `MudNumericField` ha mostrato instabilità su MacCatalyst. L'approccio raccomandato è utilizzare `MudTextField` di tipo stringa con Maschera regex.

**SOLUZIONE TECNICA OBBLIGATORIA:**
1. Utilizzare `MudTextField` con `T="string"`.
2. Impostare `Mask` con `RegexMask(@"^\d*$")`.
3. **IMPORTANTE**: NON impostare `InputType="InputType.Number"` se si usa la `Mask`, altrimenti l'app potrebbe crashare su MacCatalyst.
4. Se la proprietà del Model è numerica (`int?`), utilizzare una **Proprietà Proxy** di tipo `string` nel componente per gestire il binding e la validazione.

```razor
<!-- Proprietà Proxy nel blocco @code -->
@code {
    private string NumAbitantiString
    {
        get => Entity.NumAbitanti?.ToString() ?? "";
        set
        {
            if (string.IsNullOrWhiteSpace(value)) Entity.NumAbitanti = null;
            else if (int.TryParse(value, out int result)) Entity.NumAbitanti = result;
        }
    }
}

<!-- Markup del componente -->
<MudTextField T="string" 
    @bind-Value="NumAbitantiString" 
    Label="Numero Abitanti"
    Variant="Variant.Outlined" 
    Required="true" 
    Mask="@(new RegexMask(@"^\d*$"))" 
    tabindex="7" /> 
<!-- NOTA: Rimosso InputType="InputType.Number" per evitare crash -->
```

**Spiegazione:**
- **`MudTextField<string>`**: Gestisce l'input come testo grezzo.
- **`Mask`**: La regex `^\d*$` impedisce fisicamente l'inserimento di caratteri non numerici.
- **Proxy**: Converte bidirezionalmente tra la stringa della UI e l'intero del Model.

---

## 🚀 Build e Test

```bash
dotnet build -f net9.0-maccatalyst
```

✅ **Build Status**: Completata con successo (0 errori)

## 🚨 Troubleshooting & Common Pitfalls

Se incontri problemi "inspiegabili" durante lo sviluppo, verifica questi tre punti critici:

### 1. Crash UI "An unhandled error has occurred" (Blazor Circuit Death)
**Sintomo:** L'app si blocca completamente con una barra gialla in basso ("Reload") appena provi ad aprirne un Dialog o eseguire un'azione.
**Causa Frequente:** Discrepanza dei parametri tra Componente Padre e il Dialog.
**Esempio:**
- Padre chiama: `DialogService.Show<MyDialog>("Titolo", new DialogParameters { ["Color"] = Color.Error })`
- Dialog (`MyDialog.razor`): **NON** ha dichiarato `[Parameter] public Color Color { get; set; }`
**Soluzione:** Verifica che **ogni chiave** passata nei `DialogParameters` abbia una corrispettiva property `[Parameter]` nel componente destinazione. Blazor lancia un'eccezione critica di rendering se provi a passare parametri sconosciuti.

### 2. Operazioni DB "Silenziosi" (Nessun errore, nessuna modifica)
**Sintomo:** Il codice C# completa l'esecuzione senza eccezioni (es. "Ruolo aggiornato"), ma i dati sul DB non cambiano (0 row affected reali, ma non rilevati).
**Causa Frequente:** Trigger `BEFORE UPDATE` o `BEFORE DELETE` mal implementati.
**Regola Aurea:**
- Un trigger `BEFORE UPDATE` deve restituire **`NEW`**.
- Un trigger `BEFORE DELETE` deve restituire **`OLD`**.
- Se restituisci `NULL` in un trigger `BEFORE`, l'operazione viene **annullata silenziosamente** da PostgreSQL, senza sollevare errori.

### 3. Debugging in Ambiente MAUI (No Console)
**Problema:** In ambiente MacCatalyst/iOS, `Console.WriteLine` non è sempre visibile e il debugger potrebbe non agganciarsi ai crash profondi.
**Soluzione ("Black Box Logger"):**
Se l'app crasha senza log, inserisci una scrittura su file temporaneo nel blocco `catch` più esterno:
```csharp
try {
    // codice a rischio
} catch (Exception ex) {
    var logPath = "/Users/tuo_utente/crash.txt";
    System.IO.File.AppendAllTextAttribute(logPath, `${DateTime.Now}: ${ex}`);
}
```
Questo è spesso l'unico modo per vedere lo StackTrace di un crash di rendering o di avvio.

---

## Una lista di campi sola (2026-09-01)

Se una griglia deve **cercare** e non solo elencare, la ricerca va aggiunta come **parametro alla
funzione che già legge la lista**, non messa in una funzione a parte.

Il motivo non è l'eleganza. Il 2026-09-01 la ricerca dei clienti è stata collegata a
`fn_search_clienti`, che restituiva **sedici campi in meno** di `fn_get_all_clienti`: i cinque del
documento, gli identificativi dei comuni, IBAN, note. Chi apriva un cliente trovato cercando
riceveva una scheda mutilata, e **salvandola quei campi sarebbero stati azzerati** — silenziosamente,
perché una colonna che manca non dà errore: dà `null`, e `null` salvato cancella.

Due funzioni che leggono la stessa entità sono due liste di campi da tenere allineate, e la prossima
colonna nuova finirà in una sola delle due. Il rimedio non è aggiungere i campi mancanti alla
seconda: è non avere una seconda funzione.

> **Verifica rapida quando si tocca una lettura:** confrontare le colonne che la funzione restituisce
> con quelle che il mapper C# legge (o con quelle della tabella, se il dialogo di modifica riceve
> l'entità dalla griglia e la risalva).
