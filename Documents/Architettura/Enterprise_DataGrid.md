# Enterprise DataGrid - Guida Completa

## Panoramica

`EnterpriseDataGrid<T>` è un componente custom che estende `MudDataGrid<T>` con funzionalità enterprise-grade e styling premium SaaS.

## Caratteristiche Principali

### 1. **Configurazione Automatica**
- **Bordered**: false
- **Dense**: false (importante per padding CSS corretto)
- **Striped**: false (colori gestiti da CSS custom)
- **Hover**: true (effetti hover personalizzati)
- **Elevation**: 0 (design flat)
- **MultiSelection**: false
- **ReadOnly**: true
- **SelectOnRowClick**: true
- **Class**: "enterprise-grid" (per styling CSS)

### 2. **Toolbar Integrata**
- Titolo personalizzabile
- Barra di ricerca con filtro real-time
- Componente `EnterpriseGridToolbar` automatico

### 3. **Actions Column Sticky**
- Colonna azioni sempre posizionata come prima colonna
- Riposizionamento automatico via `EnsureActionsColumnPosition()`
- Sticky positioning con z-index ottimizzati (header: 11, body: 10)

## Utilizzo Base

```razor
<EnterpriseDataGrid T="Provincia"
                    Items="@_items"
                    Title="Gestione Province"
                    SearchFunction="@Search"
                    @bind-SelectedItem="_selectedItem"
                    Breakpoint="Breakpoint.None">

    <Columns>
        <EnterpriseActionsColumn T="Provincia"
                                 OnEdit="@OpenEditDialog"
                                 OnDelete="@DeleteItem" />

        <PropertyColumn Property="x => x.Descrizione"
                        Title="Provincia" />

        <PropertyColumn Property="x => x.Sigla"
                        Title="Sigla"
                        HeaderClass="col-xs justify-center"
                        CellClass="col-xs"
                        CellStyle="text-align: center;" />
    </Columns>

    <PagerContent>
        <MudDataGridPager T="Provincia" PageSizeOptions="new int[] { 10, 25, 50, 100 }" />
    </PagerContent>
</EnterpriseDataGrid>
```

## Ottimizzazione Larghezza Colonne

### Classi CSS per Colonne Compatte

Per evitare overflow orizzontale, usa le classi predefinite:

| Classe | Larghezza | Padding Orizzontale | Uso Consigliato |
|--------|-----------|---------------------|------------------|
| `col-xs` | 60px | 6px | Sigla, ID, Flag |
| `col-sm` | 75px | 6px | Contatori piccoli |
| `col-md` | 95px | 8px | Numeri medi (residenti, etc) |
| `col-lg` | 110px | 8px | Numeri grandi (superficie, etc) |

**Esempio:**

```razor
<PropertyColumn Property="x => x.Sigla"
                Title="Sigla"
                HeaderClass="col-xs justify-center"
                CellClass="col-xs"
                CellStyle="text-align: center;" />

<PropertyColumn Property="x => x.Residenti"
                Title="Residenti"
                Format="N0"
                HeaderClass="col-md justify-end"
                CellClass="col-md"
                CellStyle="text-align: right;" />
```

### Allineamento Header

Usa `HeaderClass` per allineare le intestazioni:

- `justify-center` - Centro (per sigle, flag)
- `justify-end` - Destra (per numeri)
- Default - Sinistra (testo)

## Full-Width DataGrid

Per DataGrid con molte colonne che richiedono massimo spazio:

```razor
<EnterpriseDataGrid T="MyEntity"
                    Items="@_items"
                    Class="full-width"
                    ...>
```

La classe `full-width`:
- Riduce margini laterali a ~2px effettivi
- Usa margini negativi per estendersi oltre il container
- Ottimale per tabelle con 8+ colonne

## Search Function

Implementa sempre una funzione di ricerca personalizzata:

```csharp
private bool Search(Provincia item, string searchString)
{
    if (string.IsNullOrWhiteSpace(searchString)) return true;
    if (item.Descrizione?.Contains(searchString, StringComparison.OrdinalIgnoreCase) == true) return true;
    if (item.Sigla?.Contains(searchString, StringComparison.OrdinalIgnoreCase) == true) return true;
    if (item.RegioneDescrizione?.Contains(searchString, StringComparison.OrdinalIgnoreCase) == true) return true;
    return false;
}
```

**Best Practice:**
- Case-insensitive con `StringComparison.OrdinalIgnoreCase`
- Cerca in tutte le colonne visibili rilevanti
- Usa null-conditional operator `?.` per sicurezza

## EnterpriseActionsColumn

Colonna azioni preconfigurata con pulsanti Edit e Delete:

```razor
<EnterpriseActionsColumn T="Provincia"
                         OnEdit="@OpenEditDialog"
                         OnDelete="@DeleteItem" />
```

**Caratteristiche:**
- Sticky positioning automatico (sempre prima colonna)
- Larghezza fissa 120px
- Background sincronizzato con stato riga (normal/hover/selected)
- Pulsanti con hover colorati:
  - Edit: giallo/arancione
  - Delete: rosso

### Implementazione Actions

```csharp
private async Task OpenEditDialog(Provincia item)
{
    var parameters = new DialogParameters<ProvinciaDialog>
    {
        { x => x.Entity, new Provincia { /* copia proprietà */ } },
        { x => x.IsEditMode, true }
    };

    var options = new DialogOptions
    {
        CloseButton = true,
        MaxWidth = MaxWidth.Medium,
        FullWidth = true
    };

    var dialog = await DialogService.ShowAsync<ProvinciaDialog>("Modifica Provincia", parameters, options);
    var result = await dialog.Result;

    if (!result!.Canceled && result.Data is Provincia updatedItem)
    {
        await Service.UpdateAsync(updatedItem);
        await LoadDataAsync();
        Snackbar.Add("Provincia aggiornata con successo", Severity.Success);
    }
}

private async Task DeleteItem(Provincia item)
{
    var parameters = new DialogParameters
    {
        { "Title", "Attenzione" },
        { "ContentText", $"Vuoi veramente cancellare questo record? ({item.Descrizione})" }
    };

    var dialog = await DialogService.ShowAsync<DeleteConfirmationDialog>("Delete", parameters, new DialogOptions { CloseButton = true });
    var result = await dialog.Result;

    if (!result!.Canceled)
    {
        var success = await Service.DeleteAsync(item.Id);
        if (success)
        {
            _items.Remove(item);
            Snackbar.Add("Provincia eliminata con successo", Severity.Success);
            StateHasChanged();
        }
    }
}
```

## Formatting

### Numeri

```razor
<!-- Interi con separatore migliaia -->
<PropertyColumn Property="x => x.Residenti"
                Format="N0" />

<!-- Decimali con 2 cifre -->
<PropertyColumn Property="x => x.Superficie"
                Format="N2" />
```

### Testo Centrato/Allineato

```razor
<!-- Centro -->
<PropertyColumn Property="x => x.Sigla"
                CellStyle="text-align: center;" />

<!-- Destra (numeri) -->
<PropertyColumn Property="x => x.Residenti"
                CellStyle="text-align: right;" />
```

## Tema Light/Dark Mode

Il CSS gestisce automaticamente entrambi i temi:

### Light Mode
- Header: `#F7F8FA`
- Row: `#FFFFFF`
- Hover: `#F9FAFB`
- Selected: `rgba(14, 165, 233, 0.08)`

### Dark Mode
- Header: `#2A2D34`
- Row: `#30333B`
- Hover: `#35383F`
- Selected: `rgba(14, 165, 233, 0.15)`

La classe `.theme-dark` viene applicata automaticamente da `MainLayout.razor`.

## Layout Container

Il `DashboardLayout.razor` è configurato per massimizzare lo spazio:

```razor
<MudContainer MaxWidth="MaxWidth.False" Class="mt-4 mb-4" Style="padding: 0 8px;">
```

- `MaxWidth.False`: nessun limite larghezza
- Padding orizzontale ridotto a 8px
- Le tab hanno padding: 0

## CSS Custom Globali

Tutti gli stili sono in `/wwwroot/css/premium-saas-ULTRA-SPECIFIC.css`:

### Sezioni Rilevanti
1. **DATAGRID - LIGHT MODE** (righe 9-88)
2. **DATAGRID - DARK MODE** (righe 90-156)
3. **INLINE ACTION BUTTONS** (righe 247-292)
4. **COLUMN WIDTH OPTIMIZATION** (righe 606-644)
5. **MAIN CONTENT CONTAINER OPTIMIZATION** (righe 647-672)
6. **STICKY ACTIONS COLUMN** (righe 675-716)

## Pager

Usa sempre il pager standard con opzioni multiple:

```razor
<PagerContent>
    <MudDataGridPager T="Provincia" PageSizeOptions="new int[] { 10, 25, 50, 100 }" />
</PagerContent>
```

## Error Handling

```csharp
private string _errorMessage = string.Empty;

protected override async Task OnInitializedAsync()
{
    await LoadDataAsync();
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

// Nel template
@if (!string.IsNullOrEmpty(_errorMessage))
{
    <MudAlert Severity="Severity.Error" Variant="Variant.Filled" Class="my-2">
        <MudText Typo="Typo.h6">ERRORE:</MudText>
        <MudText>@_errorMessage</MudText>
    </MudAlert>
}
else
{
    <EnterpriseDataGrid ... />
}
```

## Checklist Implementazione

- [ ] Usa `EnterpriseDataGrid<T>` invece di `MudDataGrid<T>`
- [ ] Aggiungi `EnterpriseActionsColumn` come prima colonna
- [ ] Implementa `SearchFunction` personalizzata
- [ ] Usa classi `col-xs/sm/md/lg` per colonne numeriche/compatte
- [ ] Aggiungi `HeaderClass="justify-end"` per colonne numeriche
- [ ] Usa `Format="N0"` o `Format="N2"` per formattare numeri
- [ ] Implementa error handling con `_errorMessage`
- [ ] Aggiungi `MudDataGridPager` con opzioni multiple
- [ ] Per tabelle grandi, considera `Class="full-width"`
- [ ] Testa sia in light che dark mode

## Esempio Completo

Vedi `/Components/Pages/Tabelle/Province.razor` per un esempio completo funzionante.

---

**Ultimo aggiornamento:** 2025-01-19
**Versione CSS:** premium-saas-ULTRA-SPECIFIC.css v2.0
