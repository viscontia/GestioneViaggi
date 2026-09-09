# 🎨 Sistema Design Premium SaaS - MudBlazor Implementation Guide

## 📋 Indice
1. [Color Palette Custom](#color-palette)
2. [Sistema Bottoni](#sistema-bottoni)
3. [Icone Inline (Edit/Delete)](#icone-inline)
4. [Tabella DataGrid](#tabella-datagrid)
5. [Status Badges](#status-badges)

---

## 🎨 Color Palette Custom {#color-palette}

### Aggiungi al `wwwroot/css/app.css` o crea `premium-saas-theme.css`:

```css
/* ========== PREMIUM SAAS PALETTE ========== */
:root {
    /* Primary (nero su light, bianco su dark) */
    --mud-palette-primary: #111827;
    --mud-palette-primary-lighten: #1F2937;
    --mud-palette-primary-darken: #030712;
    
    /* Secondary (grigio neutro) */
    --mud-palette-secondary: #6B7280;
    --mud-palette-secondary-lighten: #9CA3AF;
    --mud-palette-secondary-darken: #4B5563;
    
    /* Success (verde soft) */
    --mud-palette-success: #10B981;
    --mud-palette-success-lighten: #34D399;
    --mud-palette-success-darken: #059669;
    
    /* Error (rosso soft) */
    --mud-palette-error: #EF4444;
    --mud-palette-error-lighten: #F87171;
    --mud-palette-error-darken: #DC2626;
    
    /* Warning (arancione soft) */
    --mud-palette-warning: #F59E0B;
    --mud-palette-warning-lighten: #FBBF24;
    --mud-palette-warning-darken: #D97706;
    
    /* Info (blu freddo) */
    --mud-palette-info: #0EA5E9;
    --mud-palette-info-lighten: #38BDF8;
    --mud-palette-info-darken: #0284C7;
    
    /* Surface backgrounds */
    --mud-palette-surface: #FFFFFF;
    --mud-palette-background: #F7F8FA;
    --mud-palette-background-grey: #F9FAFB;
    
    /* Typography */
    --mud-typography-default-font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}

/* Dark mode overrides */
.mud-theme-dark {
    --mud-palette-primary: #E6E8EB;
    --mud-palette-surface: #30333B;
    --mud-palette-background: #1A1D23;
    --mud-palette-background-grey: #2A2D34;
}

/* ========== CUSTOM BUTTON STYLES ========== */
.mud-button-root {
    font-family: 'Inter', sans-serif;
    font-size: 13.5px;
    font-weight: 500;
    letter-spacing: -0.01em;
    text-transform: none;
    border-radius: 6px;
    padding: 0 16px;
    height: 36px;
}

.mud-button-filled {
    box-shadow: none;
}

.mud-button-filled:hover {
    box-shadow: none;
}

/* Ghost button style (Text variant) */
.mud-button-text {
    background: transparent;
}

.mud-button-text:hover {
    background: rgba(0,0,0,0.04);
}

.mud-theme-dark .mud-button-text:hover {
    background: rgba(255,255,255,0.06);
}

/* Secondary button custom background */
.mud-button-filled.mud-button-filled-secondary {
    background: rgba(0,0,0,0.04);
    color: #374151;
}

.mud-button-filled.mud-button-filled-secondary:hover {
    background: rgba(0,0,0,0.08);
}

.mud-theme-dark .mud-button-filled.mud-button-filled-secondary {
    background: rgba(255,255,255,0.06);
    color: #D1D5DB;
}

.mud-theme-dark .mud-button-filled.mud-button-filled-secondary:hover {
    background: rgba(255,255,255,0.1);
}

/* Error button with soft background */
.mud-button-filled.mud-button-filled-error {
    background: rgba(239, 68, 68, 0.08);
    color: #DC2626;
}

.mud-button-filled.mud-button-filled-error:hover {
    background: rgba(239, 68, 68, 0.12);
}

.mud-theme-dark .mud-button-filled.mud-button-filled-error {
    background: rgba(239, 68, 68, 0.12);
    color: #F87171;
}

.mud-theme-dark .mud-button-filled.mud-button-filled-error:hover {
    background: rgba(239, 68, 68, 0.18);
}

/* Success button with soft background */
.mud-button-filled.mud-button-filled-success {
    background: rgba(16, 185, 129, 0.08);
    color: #059669;
}

.mud-button-filled.mud-button-filled-success:hover {
    background: rgba(16, 185, 129, 0.12);
}

.mud-theme-dark .mud-button-filled.mud-button-filled-success {
    background: rgba(16, 185, 129, 0.12);
    color: #34D399;
}

.mud-theme-dark .mud-button-filled.mud-button-filled-success:hover {
    background: rgba(16, 185, 129, 0.18);
}
```

---

## 🔘 Sistema Bottoni {#sistema-bottoni}

### 1️⃣ **PRIMARY** - Azioni Principali (Salva, Crea Nuovo, Pubblica)

```razor
<MudButton Variant="Variant.Filled" 
           Color="Color.Primary" 
           StartIcon="@Icons.Material.Filled.Add">
    Nuovo Viaggio
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Primary" 
           StartIcon="@Icons.Material.Filled.Save">
    Salva Modifiche
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Primary" 
           StartIcon="@Icons.Material.Filled.Publish">
    Pubblica
</MudButton>
```

**Icone suggerite:**
- `add` - Nuovo/Aggiungi
- `save` - Salva
- `publish` - Pubblica/Attiva
- `send` - Invia

---

### 2️⃣ **SECONDARY** - Azioni Secondarie (Filtra, Cerca, Impostazioni)

```razor
<MudButton Variant="Variant.Filled" 
           Color="Color.Secondary" 
           StartIcon="@Icons.Material.Filled.FilterList">
    Filtra
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Secondary" 
           StartIcon="@Icons.Material.Filled.Search">
    Cerca
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Secondary" 
           StartIcon="@Icons.Material.Filled.Settings">
    Impostazioni
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Secondary" 
           StartIcon="@Icons.Material.Filled.Map">
    Visualizza Mappa
</MudButton>
```

**Icone suggerite:**
- `filter_list` - Filtra
- `search` - Cerca
- `settings` - Impostazioni
- `map` - Mappa/Navigazione
- `visibility` - Visualizza
- `edit` - Modifica (su singolo record)

---

### 3️⃣ **GHOST/TEXT** - Azioni Terziarie (Annulla, Esporta, Guida)

```razor
<MudButton Variant="Variant.Text" 
           Color="Color.Default" 
           StartIcon="@Icons.Material.Filled.Close">
    Annulla
</MudButton>

<MudButton Variant="Variant.Text" 
           Color="Color.Default" 
           StartIcon="@Icons.Material.Filled.FileDownload">
    Esporta CSV
</MudButton>

<MudButton Variant="Variant.Text" 
           Color="Color.Default" 
           StartIcon="@Icons.Material.Outlined.HelpOutline">
    Guida
</MudButton>
```

**Icone suggerite:**
- `close` - Annulla/Chiudi
- `file_download` - Esporta/Download
- `help_outline` - Guida/Help
- `info_outline` - Informazioni
- `refresh` - Ricarica

---

### 4️⃣ **DESTRUCTIVE** - Azioni Distruttive (Elimina, Cancella)

```razor
<MudButton Variant="Variant.Filled" 
           Color="Color.Error" 
           StartIcon="@Icons.Material.Filled.Delete">
    Elimina Viaggio
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Error" 
           StartIcon="@Icons.Material.Filled.Cancel">
    Cancella Prenotazione
</MudButton>
```

**Icone suggerite:**
- `delete` - Elimina (generico)
- `delete_forever` - Elimina permanente
- `cancel` - Annulla/Cancella
- `block` - Blocca/Disattiva
- `remove_circle` - Rimuovi

---

### 5️⃣ **SUCCESS** - Azioni Positive (Completa, Approva, Conferma)

```razor
<MudButton Variant="Variant.Filled" 
           Color="Color.Success" 
           StartIcon="@Icons.Material.Filled.CheckCircle">
    Completa Viaggio
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Success" 
           StartIcon="@Icons.Material.Filled.DoneAll">
    Approva
</MudButton>

<MudButton Variant="Variant.Filled" 
           Color="Color.Success" 
           StartIcon="@Icons.Material.Filled.Check">
    Conferma
</MudButton>
```

**Icone suggerite:**
- `check_circle` - Completa/Conferma (con icona)
- `done_all` - Approva/Tutto fatto
- `check` - Conferma (semplice)
- `verified` - Verifica
- `task_alt` - Task completato

---

### 6️⃣ **OUTLINED** - Variante con Bordo (Condividi, Stampa)

```razor
<MudButton Variant="Variant.Outlined" 
           Color="Color.Default" 
           StartIcon="@Icons.Material.Filled.Share">
    Condividi
</MudButton>

<MudButton Variant="Variant.Outlined" 
           Color="Color.Default" 
           StartIcon="@Icons.Material.Filled.Print">
    Stampa
</MudButton>
```

**Icone suggerite:**
- `share` - Condividi
- `print` - Stampa
- `link` - Copia link
- `upload` - Carica

---

## 🎯 Icone Inline (Edit/Delete nella Griglia) {#icone-inline}

### CSS per IconButton Inline

```css
/* ========== INLINE ACTION BUTTONS ========== */
.inline-action-btn {
    width: 28px !important;
    height: 28px !important;
    padding: 0 !important;
    min-width: 28px !important;
}

.inline-action-btn .mud-icon-root {
    font-size: 18px !important;
}

/* Hover states */
.mud-icon-button.inline-action-btn:hover {
    background: rgba(0,0,0,0.04);
}

.mud-theme-dark .mud-icon-button.inline-action-btn:hover {
    background: rgba(255,255,255,0.06);
}

/* Delete button hover - soft red */
.mud-icon-button.inline-action-btn.delete-btn:hover {
    background: rgba(239, 68, 68, 0.08) !important;
    color: #DC2626 !important;
}

.mud-theme-dark .mud-icon-button.inline-action-btn.delete-btn:hover {
    background: rgba(239, 68, 68, 0.12) !important;
    color: #F87171 !important;
}
```

### Codice MudBlazor per Inline Actions

```razor
@* All'interno di MudDataGrid CellTemplate *@

<MudStack Row="true" Spacing="1">
    @* Edit Button *@
    <MudIconButton Icon="@Icons.Material.Filled.Edit" 
                   Size="Size.Small"
                   Color="Color.Default"
                   Class="inline-action-btn"
                   Title="Modifica"
                   OnClick="@(() => EditTrip(context.Item))" />
    
    @* Delete Button *@
    <MudIconButton Icon="@Icons.Material.Filled.Delete" 
                   Size="Size.Small"
                   Color="Color.Default"
                   Class="inline-action-btn delete-btn"
                   Title="Elimina"
                   OnClick="@(() => DeleteTrip(context.Item))" />
</MudStack>
```

### Esempio completo con DataGrid

```razor
<MudDataGrid T="Trip" Items="@trips" Hover="true">
    <Columns>
        <PropertyColumn Property="x => x.Name" Title="Nome Viaggio" />
        <PropertyColumn Property="x => x.StartDate" Title="Data Partenza" />
        <PropertyColumn Property="x => x.Difficulty" Title="Difficoltà">
            <CellTemplate>
                <MudChip Size="Size.Small" 
                         Color="@GetDifficultyColor(context.Item.Difficulty)">
                    @context.Item.Difficulty
                </MudChip>
            </CellTemplate>
        </PropertyColumn>
        <PropertyColumn Property="x => x.Distance" Title="Distanza" />
        
        @* Colonna Azioni *@
        <TemplateColumn Title="Azioni" CellStyle="width: 80px;">
            <CellTemplate>
                <MudStack Row="true" Spacing="1">
                    <MudIconButton Icon="@Icons.Material.Filled.Edit" 
                                   Size="Size.Small"
                                   Color="Color.Default"
                                   Class="inline-action-btn"
                                   OnClick="@(() => EditTrip(context.Item))" />
                    
                    <MudIconButton Icon="@Icons.Material.Filled.Delete" 
                                   Size="Size.Small"
                                   Color="Color.Default"
                                   Class="inline-action-btn delete-btn"
                                   OnClick="@(() => DeleteTrip(context.Item))" />
                </MudStack>
            </CellTemplate>
        </TemplateColumn>
    </Columns>
</MudDataGrid>
```

---

## 📊 Tabella DataGrid Premium SaaS {#tabella-datagrid}

### CSS per Stile Premium

```css
/* ========== MUDBLAZOR DATAGRID PREMIUM STYLE ========== */
.mud-table-root {
    border-radius: 8px;
    overflow: hidden;
}

/* Header */
.mud-table-head .mud-table-cell {
    background-color: #F7F8FA;
    color: #6B7280;
    font-size: 11.5px;
    font-weight: 500;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    padding: 10px 16px;
    border-bottom: 1px solid rgba(0,0,0,0.06);
    box-shadow: inset 0 -1px 0 rgba(0,0,0,0.04);
}

/* Rows */
.mud-table-body .mud-table-row {
    background-color: #FFFFFF;
}

.mud-table-body .mud-table-row:hover {
    background-color: #F9FAFB !important;
}

.mud-table-body .mud-table-cell {
    color: #111827;
    font-size: 13.5px;
    font-weight: 400;
    padding: 14px 16px;
    border-bottom: 1px solid rgba(0,0,0,0.04);
}

/* Dark mode */
.mud-theme-dark .mud-table-head .mud-table-cell {
    background-color: #2A2D34;
    color: #9AA1AC;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    box-shadow: inset 0 -1px 0 rgba(255,255,255,0.04);
}

.mud-theme-dark .mud-table-body .mud-table-row {
    background-color: #30333B;
}

.mud-theme-dark .mud-table-body .mud-table-row:hover {
    background-color: #35383F !important;
}

.mud-theme-dark .mud-table-body .mud-table-cell {
    color: #E6E8EB;
    border-bottom: 1px solid rgba(255,255,255,0.04);
}

/* Remove default sorting icons decoration */
.mud-table-sort-label {
    opacity: 0.4;
}

.mud-table-sort-label:hover {
    opacity: 0.8;
}

.mud-table-sort-label.mud-direction-asc,
.mud-table-sort-label.mud-direction-desc {
    opacity: 1;
}
```

---

## 🏷️ Status Badges {#status-badges}

### CSS per Badge Custom

```css
/* ========== STATUS BADGES ========== */
.status-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 3px 10px;
    font-size: 11.5px;
    font-weight: 500;
    border-radius: 6px;
    letter-spacing: 0.02em;
}

.status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: currentColor;
}

/* Planned (Blu) */
.status-planned {
    background: rgba(14, 165, 233, 0.08);
    color: #0EA5E9;
}

/* Active (Verde) */
.status-active {
    background: rgba(16, 185, 129, 0.08);
    color: #10B981;
}

/* Completed (Grigio) */
.status-completed {
    background: rgba(107, 114, 128, 0.08);
    color: #6B7280;
}

/* Dark mode variants */
.mud-theme-dark .status-planned {
    background: rgba(14, 165, 233, 0.12);
    color: #38BDF8;
}

.mud-theme-dark .status-active {
    background: rgba(16, 185, 129, 0.12);
    color: #34D399;
}

.mud-theme-dark .status-completed {
    background: rgba(107, 114, 128, 0.12);
    color: #9CA3AF;
}
```

### Componente Razor per Status Badge

```razor
@* StatusBadge.razor *@
<div class="status-badge status-@Status.ToLower()">
    <span class="status-dot"></span>
    @Status
</div>

@code {
    [Parameter]
    public string Status { get; set; } = "Planned";
}
```

### Uso nel DataGrid

```razor
<PropertyColumn Property="x => x.Status" Title="Stato">
    <CellTemplate>
        <StatusBadge Status="@context.Item.Status" />
    </CellTemplate>
</PropertyColumn>
```

---

## 🎨 Difficulty Badges

```css
/* ========== DIFFICULTY BADGES ========== */
.difficulty-badge {
    padding: 2px 8px;
    font-size: 11px;
    font-weight: 500;
    border-radius: 4px;
}

/* Light mode */
.difficulty-easy {
    background: rgba(16, 185, 129, 0.08);
    color: #059669;
}

.difficulty-medium {
    background: rgba(245, 158, 11, 0.08);
    color: #D97706;
}

.difficulty-hard {
    background: rgba(239, 68, 68, 0.08);
    color: #DC2626;
}

/* Dark mode */
.mud-theme-dark .difficulty-easy {
    background: rgba(16, 185, 129, 0.12);
    color: #34D399;
}

.mud-theme-dark .difficulty-medium {
    background: rgba(245, 158, 11, 0.12);
    color: #FBBF24;
}

.mud-theme-dark .difficulty-hard {
    background: rgba(239, 68, 68, 0.12);
    color: #F87171;
}
```

### Uso con MudChip

```razor
<PropertyColumn Property="x => x.Difficulty" Title="Difficoltà">
    <CellTemplate>
        <MudChip Size="Size.Small" 
                 Class="@($"difficulty-badge difficulty-{context.Item.Difficulty.ToLower()}")">
            @context.Item.Difficulty
        </MudChip>
    </CellTemplate>
</PropertyColumn>
```

---

## 📦 Icone Material - Riferimento Rapido

### Navigazione & CRUD
- `add` - Aggiungi/Nuovo
- `edit` - Modifica
- `delete` - Elimina
- `save` - Salva
- `close` - Chiudi/Annulla
- `refresh` - Ricarica

### Azioni Positive
- `check` - Conferma
- `check_circle` - Completa
- `done_all` - Approva tutto
- `verified` - Verificato
- `task_alt` - Task completato

### Azioni Distruttive
- `delete_forever` - Elimina permanente
- `cancel` - Cancella
- `block` - Blocca
- `remove_circle` - Rimuovi

### Visualizzazione
- `visibility` - Visualizza
- `visibility_off` - Nascondi
- `map` - Mappa
- `table_chart` - Tabella
- `list` - Lista

### Utility
- `search` - Cerca
- `filter_list` - Filtra
- `sort` - Ordina
- `settings` - Impostazioni
- `help_outline` - Aiuto
- `info_outline` - Info

### File Operations
- `upload` - Carica
- `file_download` - Scarica
- `file_copy` - Copia
- `print` - Stampa
- `share` - Condividi

---

## 🚀 Quick Start Checklist

✅ Aggiungi CSS custom al progetto  
✅ Configura Material Icons in `_Host.cshtml`:
```html
<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

✅ Usa i button variants corretti:
- **Primary** → `Variant.Filled` + `Color.Primary`
- **Secondary** → `Variant.Filled` + `Color.Secondary`
- **Ghost** → `Variant.Text`
- **Destructive** → `Variant.Filled` + `Color.Error`
- **Success** → `Variant.Filled` + `Color.Success`

✅ Per inline actions usa `MudIconButton` con `Class="inline-action-btn"`

✅ Applica CSS custom alla MudDataGrid per look Premium SaaS

---

## 💡 Tips Finali

1. **Font Inter** è essenziale - senza quello perde tutto il carattere Premium
2. **Padding consistente** - header 10px/16px, celle 14px/16px
3. **Icone sempre 18px** nelle griglie, 20-24px nei bottoni grandi
4. **Mai colori saturi** - sempre rgba() con opacity <15%
5. **Hover sempre soft** - opacity o background molto leggero
6. **Border-radius uniformi** - 6px bottoni, 8px card, 4px chip

---

📌 **Nota**: Questi stili sono testati con MudBlazor 6.x e .NET MAUI. Per progetti Blazor WebAssembly/Server standard, tutto funziona identico.
