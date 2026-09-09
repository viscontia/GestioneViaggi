# FASE 3: Dashboard UI/UX Improvements - Design Document

**Data:** 2026-02-17
**Versione:** 1.0
**Stato:** Approvato

---

## 📋 Panoramica

La Fase 3 completa il ciclo di miglioramenti UI/UX delle dashboard dopo:
- ✅ **Fase 1:** Hover transitions per card interattive
- ✅ **Fase 2:** Skeleton loading e fade-in animations

Questa fase si concentra su **4 aree critiche**:
1. Mini-grafici troppo piccoli (120x50 → 140x60)
2. NavMenu non responsive su mobile
3. Gerarchia tipografica debole
4. Densità eccessiva nella Recent Activity list

---

## 🎯 Obiettivi

### Obiettivo Primario
Migliorare **usabilità** e **leggibilità** delle dashboard su tutti i dispositivi (desktop, tablet, mobile).

### Metriche di Successo
- [ ] Mini-grafici cliccabili con maggiore precisione (barre +20% più larghe)
- [ ] NavMenu funzionante su touch devices (drawer temporaneo)
- [ ] Gerarchia visiva chiara tra valori principali e label
- [ ] Recent Activity leggibile senza affollamento visivo

---

## 🏗️ Approccio Scelto: Per Feature (Raggruppato)

### Feature Group 1: Visual Refinement
Migliora l'aspetto visivo delle dashboard esistenti:
- Mini-grafici 140x60px
- Typography gerarchica (h3 bold per valori principali)
- Spacing aumentato nella Recent Activity

### Feature Group 2: Responsive NavMenu
Rende il menu laterale utilizzabile su mobile/tablet:
- DrawerVariant.Temporary su schermi < 960px
- DrawerVariant.Mini su desktop (comportamento attuale)
- Hamburger menu button per apertura/chiusura

---

## 🎨 Design Dettagliato

### 1. Mini-Grafici (140x60 + 12 mesi)

#### Problema
I grafici SVG 120x50px con 12 barre mensili hanno:
- Barre troppo strette (~8px) difficili da targettare con hover
- Altezza ridotta rende difficile interpretare le variazioni
- Tooltip richiedono precisione eccessiva

#### Soluzione

**Ridimensionamento:**
```razor
<!-- PRIMA -->
<MudPaper Width="120px" Height="50px" Elevation="0" Class="d-flex align-end ml-4"
          Style="background: transparent;">
    <svg width="100%" height="100%" viewBox="0 0 120 50" preserveAspectRatio="none">
        @{
            var barWidth = 120.0 / 12.0;  // ~10px
            var gap = 2.0;
            barWidth -= gap;  // ~8px
        }
    </svg>
</MudPaper>

<!-- DOPO -->
<MudPaper Width="140px" Height="60px" Elevation="0" Class="d-flex align-end ml-4"
          Style="background: transparent;">
    <svg width="100%" height="100%" viewBox="0 0 140 60" preserveAspectRatio="none">
        @{
            var barWidth = 140.0 / 12.0;  // ~11.67px
            var gap = 2.0;
            barWidth -= gap;  // ~9.67px (+20% larghezza)
        }
    </svg>
</MudPaper>
```

**Calcolo Y-axis aggiornato:**
```csharp
// Altezza disponibile aumenta da 50 a 60
var height = (val / max) * 60.0;  // era 50.0
var y = 60.0 - height;  // era 50.0
```

**File modificati:**
- `Components/Pages/DashboardAdmin.razor` (5 card statistiche con grafici)
- `Components/Pages/DashboardSuperAdmin.razor` (3 card statistiche con grafici)

**Impatto visivo:**
- Barre +20% più larghe → hover più facile
- Area grafico +20% più alta → trend più evidenti
- Mantiene 12 mesi di granularità (Jan-Dec)

---

### 2. Typography - Gerarchia Visiva

#### Problema
Tutti i valori principali usano `Typo.h4` con peso uniforme:
- Nessuna differenziazione tra metrica principale e label
- Caption date troppo piccole (11px)
- Contrasto insufficiente per testo secondario

#### Soluzione

**Valori Principali (h4 → h3 bold):**
```razor
<!-- PRIMA -->
<MudText Typo="Typo.h4">@(_statsClienti?.MainValue ?? 0)</MudText>

<!-- DOPO -->
<MudText Typo="Typo.h3" Style="font-weight: 700; line-height: 1.2;">
    @(_statsClienti?.MainValue ?? 0)
</MudText>
```

**Label Secondarie (body2 medium):**
```razor
<!-- PRIMA -->
<MudText Typo="Typo.body2">Clienti Totali</MudText>

<!-- DOPO -->
<MudText Typo="Typo.body2" Style="font-weight: 500;">
    Clienti Totali
</MudText>
```

**Caption/Date (caption → body2):**
```razor
<!-- PRIMA -->
<MudText Typo="Typo.caption" Color="Color.Secondary">
    (% @_selectedYear su @(_selectedYear - 1))
</MudText>

<!-- DOPO -->
<MudText Typo="Typo.body2" Style="font-size: 12px; color: var(--mud-palette-text-secondary);">
    (% @_selectedYear su @(_selectedYear - 1))
</MudText>
```

**Miglioramenti:**
- Font size: h3 (24px) vs h4 (20px) = +20% prominenza
- Font weight: 700 (bold) vs 400 (normal) = maggiore enfasi
- Label: 500 (medium) per bilanciare
- Caption: 12px (da 11px) + CSS variable per dark mode

---

### 3. Spacing - Recent Activity

#### Problema
La lista Recent Activity è troppo densa:
- `Dense="true"` riduce padding/margine
- `max-height: 400px` mostra troppi item (15-20)
- Difficile scansione visiva, affollamento

#### Soluzione

**Rimuovere Dense + Ridurre Altezza:**
```razor
<!-- PRIMA -->
<div style="max-height: 400px; overflow-y: auto; padding-right: 4px;">
    <MudList T="string" Dense="true">
        @foreach (var item in _activities)
        {
            <MudListItem Icon="@GetActivityIcon(item.EventType)"
                         IconColor="@GetActivityColor(item.EventType)">
                <!-- contenuto -->
            </MudListItem>
            <MudDivider />
        }
    </MudList>
</div>

<!-- DOPO -->
<div style="max-height: 300px; overflow-y: auto; padding-right: 4px;">
    <MudList T="string" Dense="false">
        @foreach (var item in _activities)
        {
            <MudListItem Icon="@GetActivityIcon(item.EventType)"
                         IconColor="@GetActivityColor(item.EventType)"
                         Style="padding: 12px 16px;">
                <!-- contenuto -->
            </MudListItem>
            <MudDivider />
        }
    </MudList>
</div>
```

**Risultato:**
- Spacing normale: padding 12px invece di 8px
- Altezza ridotta: 300px (mostra ~8-10 item invece di 15-20)
- Focus sugli ultimi eventi più rilevanti
- Leggibilità migliorata

---

### 4. Responsive NavMenu

#### Problema
`DrawerVariant.Mini` con `OpenMiniOnHover` non funziona su touch devices:
- Hover non esiste su mobile/tablet
- Menu nested groups richiedono troppi tap
- Drawer sempre visibile occupa spazio prezioso

#### Soluzione: Variant Condizionale

**Architettura:**
```razor
<!-- MainLayout.razor -->
@code {
    private bool _drawerOpen = false;
    private bool _isMobile = false;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            // Detect screen width usando JS Interop
            var width = await JSRuntime.InvokeAsync<int>("getWindowWidth");
            _isMobile = width < 960;  // Breakpoint.Md di MudBlazor
            StateHasChanged();
        }
    }
}

<MudDrawer @bind-Open="_drawerOpen"
           Variant="@(_isMobile ? DrawerVariant.Temporary : DrawerVariant.Mini)"
           OpenMiniOnHover="@(!_isMobile)"
           CloseOnEscape="@_isMobile"
           Anchor="Anchor.Left">
    <NavMenu OnItemClick="@(() => { if (_isMobile) _drawerOpen = false; })" />
</MudDrawer>
```

**Hamburger Menu Button (solo mobile):**
```razor
<!-- MainLayout.razor - AppBar -->
<MudAppBar Elevation="1">
    @if (_isMobile)
    {
        <MudIconButton Icon="@Icons.Material.Filled.Menu"
                       Color="Color.Inherit"
                       Edge="Edge.Start"
                       OnClick="@(() => _drawerOpen = !_drawerOpen)"
                       aria-label="Apri menu" />
    }
    <MudSpacer />
    <!-- resto AppBar -->
</MudAppBar>
```

**JavaScript Interop:**
```javascript
// wwwroot/js/site.js (o file esistente)
window.getWindowWidth = () => window.innerWidth;
```

**Comportamento:**
| Dispositivo | Breakpoint | Variant | Comportamento |
|-------------|-----------|---------|---------------|
| Desktop | ≥960px | Mini | Hover to expand, sempre visibile |
| Tablet | <960px | Temporary | Hamburger menu, auto-close on click |
| Mobile | <960px | Temporary | Hamburger menu, auto-close on click |

**File modificati:**
- `Components/Layout/MainLayout.razor` - Logic responsive + hamburger button
- `Components/Shared/NavMenu.razor` - Callback OnItemClick per auto-close
- `wwwroot/js/site.js` - Helper JS per window width

---

## 📦 File Modificati (Riepilogo)

### Feature Group 1: Visual Refinement
| File | Modifiche |
|------|-----------|
| `Components/Pages/DashboardAdmin.razor` | Grafici 140x60, Typography h3, Spacing Activity |
| `Components/Pages/DashboardSuperAdmin.razor` | Grafici 140x60, Typography h3, Spacing Activity |

### Feature Group 2: Responsive NavMenu
| File | Modifiche |
|------|-----------|
| `Components/Layout/MainLayout.razor` | Variant condizionale, hamburger button, JS interop |
| `Components/Shared/NavMenu.razor` | Callback OnItemClick |
| `wwwroot/js/site.js` | Helper getWindowWidth |

---

## 🧪 Testing Plan

### Feature Group 1: Visual Refinement

**Test 1: Mini-Grafici 140x60**
- [ ] Verificare che tutti i grafici siano ridimensionati correttamente
- [ ] Hover tooltip funzionano con precisione migliorata
- [ ] Barre sono visibili e distinguibili
- [ ] Layout responsive non rompe (card rimangono allineate)

**Test 2: Typography**
- [ ] Valori principali sono h3 bold (24px, 700)
- [ ] Label sono body2 medium (14px, 500)
- [ ] Caption sono leggibili (12px)
- [ ] Contrasto sufficiente in light e dark mode

**Test 3: Spacing Activity**
- [ ] Recent Activity non è Dense
- [ ] Max-height 300px mostra ~8-10 item
- [ ] Scroll funziona correttamente
- [ ] Leggibilità migliorata

### Feature Group 2: Responsive NavMenu

**Test 4: Desktop (≥960px)**
- [ ] Drawer è Variant.Mini
- [ ] OpenMiniOnHover espande il menu
- [ ] Nessun hamburger button visibile

**Test 5: Mobile/Tablet (<960px)**
- [ ] Drawer è Variant.Temporary
- [ ] Hamburger button visibile e funzionante
- [ ] Drawer si chiude dopo click su voce
- [ ] CloseOnEscape funziona

**Test 6: Responsive Breakpoint**
- [ ] Resize finestra da desktop a mobile cambia variant
- [ ] Nessun glitch visivo durante transizione

---

## 🚀 Deployment Strategy

### Step 1: Visual Refinement
1. Branch: `feature/fase3-visual-refinement`
2. Modificare DashboardAdmin.razor e DashboardSuperAdmin.razor
3. Testing locale light + dark mode
4. Commit: `feat(dashboard): Fase 3 - Visual refinement (grafici 140x60, typography, spacing)`
5. Merge su main dopo review

### Step 2: Responsive NavMenu
1. Branch: `feature/fase3-responsive-navmenu`
2. Modificare MainLayout.razor, NavMenu.razor, site.js
3. Testing su desktop, tablet, mobile (browser DevTools)
4. Commit: `feat(layout): Fase 3 - Responsive NavMenu (temporary drawer su mobile)`
5. Merge su main dopo review

### Rollback Plan
- Se Feature Group 1 ha problemi: revert commit, grafici tornano 120x50
- Se Feature Group 2 ha problemi: revert commit, NavMenu torna sempre Mini

---

## 📊 Trade-offs e Considerazioni

### Mini-Grafici 140x60
**Pro:**
- Migliore usabilità hover/touch
- Trend più evidenti

**Contro:**
- Occupano +20% spazio orizzontale (marginale, card hanno spazio)

### Responsive NavMenu
**Pro:**
- Usabilità mobile/tablet finalmente funzionante
- Più spazio per contenuto principale su schermi piccoli

**Contro:**
- Richiede JS Interop (dipendenza leggera)
- Breakpoint fisso 960px (standard MudBlazor, ma potrebbe non adattarsi a tutti i tablet)

### Typography h3 Bold
**Pro:**
- Gerarchia visiva chiara
- Valori principali più prominenti

**Contro:**
- Font più grande potrebbe causare wrap su schermi molto piccoli (da testare)

### Spacing Activity Ridotto
**Pro:**
- Leggibilità migliorata
- Focus su eventi recenti

**Contro:**
- Utenti vedono meno item senza scroll (trade-off accettabile)

---

## ✅ Checklist Pre-Implementazione

- [x] Design approvato
- [x] File identificati
- [x] Testing plan definito
- [ ] Branch creati
- [ ] Modifiche implementate
- [ ] Testing completato
- [ ] Review code
- [ ] Merge su main
- [ ] Deploy

---

## 📝 Note Aggiuntive

### Dark Mode
Tutte le modifiche devono supportare dark mode:
- CSS variables (`--mud-palette-text-secondary`) invece di colori hardcoded
- Skeleton grafici già supporta `.mud-theme-dark`

### Accessibilità
- Hamburger button: `aria-label="Apri menu"`
- Grafici SVG: mantengono `aria-hidden="true"` (decorativi, info nelle tooltip)

### Performance
- JS Interop `getWindowWidth` chiamato solo `OnAfterRenderAsync(firstRender)`
- Nessun impatto performance significativo

---

**Design completato e approvato il 2026-02-17**
