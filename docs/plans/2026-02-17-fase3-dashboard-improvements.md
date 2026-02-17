# Fase 3: Dashboard UI/UX Improvements - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve dashboard usability and readability by resizing mini-graphs, implementing responsive NavMenu, enhancing typography hierarchy, and optimizing Recent Activity spacing.

**Architecture:** Two-phase approach with isolated feature groups. Phase 1 (Visual Refinement) updates dashboard components for better visual hierarchy and readability. Phase 2 (Responsive NavMenu) adds conditional drawer variant for mobile/tablet support using JS Interop.

**Tech Stack:** Blazor/.NET MAUI, MudBlazor 6.x, JavaScript Interop, SVG graphics

---

## Prerequisites

- Design document: `docs/plans/2026-02-17-fase3-dashboard-improvements-design.md`
- Current branch: `main`
- All tests passing
- No uncommitted changes

---

## PHASE 1: Visual Refinement

### Task 1: Resize Mini-Graphs in DashboardAdmin (Clienti Card)

**Files:**
- Modify: `Components/Pages/DashboardAdmin.razor:195-239`

**Step 1: Update graph container dimensions**

Find the Clienti card SVG container (around line 197):

```razor
<!-- BEFORE -->
<MudPaper Width="120px" Height="50px" Elevation="0" Class="d-flex align-end ml-4" Style="background: transparent;">

<!-- AFTER -->
<MudPaper Width="140px" Height="60px" Elevation="0" Class="d-flex align-end ml-4" Style="background: transparent;">
```

**Step 2: Update SVG viewBox**

Change the viewBox attribute (around line 200):

```razor
<!-- BEFORE -->
<svg width="100%" height="100%" viewBox="0 0 120 50" preserveAspectRatio="none" aria-hidden="true">

<!-- AFTER -->
<svg width="100%" height="100%" viewBox="0 0 140 60" preserveAspectRatio="none" aria-hidden="true">
```

**Step 3: Update bar width calculation**

Update the calculation block (around line 202-206):

```csharp
@{
    var data = _statsClienti.TrendData;
    var max = data.Any() ? data.Max() : 1;
    if (max == 0) max = 1;
    var barWidth = 140.0 / 12.0;  // Changed from 120.0
    var gap = 2.0;
    barWidth -= gap;

    for (int i = 0; i < 12; i++)
    {
        var val = (i < data.Count) ? data[i] : 0;
        var height = (val / max) * 60.0;  // Changed from 50.0
        var x = i * (barWidth + gap);
        var y = 60.0 - height;  // Changed from 50.0
        var monthName = System.Globalization.CultureInfo.GetCultureInfo("it-IT").DateTimeFormat.GetAbbreviatedMonthName(i + 1);
        var toolTip = $"{monthName}: {val}";

        <!-- Background Bar (Placeholder) -->
        <rect x="@x" y="0" width="@barWidth" height="60" fill="#f0f0f0" rx="2">
            <title>@toolTip</title>
        </rect>

        <!-- Data Bar -->
        @if (val > 0)
        {
            <rect x="@x" y="@y" width="@barWidth" height="@height" fill="@Colors.Green.Default" rx="2">
                <title>@toolTip</title>
            </rect>
        }
    }
}
```

**Step 4: Update skeleton fallback dimensions**

Update the skeleton div (around line 236):

```razor
<!-- BEFORE -->
<div class="chart-skeleton" style="width: 120px; height: 50px;"></div>

<!-- AFTER -->
<div class="chart-skeleton" style="width: 140px; height: 60px;"></div>
```

**Step 5: Test visual appearance**

Run the app:
```bash
dotnet run
```

Navigate to Dashboard Admin, verify:
- Clienti card graph is larger (140x60)
- 12 bars are visible and wider (~9.67px each)
- Hover tooltips work correctly
- Light mode and dark mode both render correctly

**Step 6: Commit**

```bash
git add Components/Pages/DashboardAdmin.razor
git commit -m "feat(dashboard): resize Clienti mini-graph to 140x60px

- Update SVG viewBox from 120x50 to 140x60
- Adjust bar width calculation for larger canvas
- Update skeleton fallback dimensions

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Resize Remaining Mini-Graphs in DashboardAdmin

**Files:**
- Modify: `Components/Pages/DashboardAdmin.razor:266-310` (Viaggi)
- Modify: `Components/Pages/DashboardAdmin.razor:336-380` (Revenue)
- Modify: `Components/Pages/DashboardAdmin.razor:436-512` (Viaggi Da Fare)

**Step 1: Update Viaggi Totali graph (lines 266-310)**

Apply same pattern as Task 1:
- Container: `Width="140px" Height="60px"`
- ViewBox: `viewBox="0 0 140 60"`
- Bar calculation: `barWidth = 140.0 / 12.0`, heights use `60.0`
- Skeleton: `width: 140px; height: 60px;`

**Step 2: Update Fatturato graph (lines 336-380)**

Apply same pattern:
- Container: `Width="140px" Height="60px"`
- ViewBox: `viewBox="0 0 140 60"`
- Bar calculation: `barWidth = 140.0 / 12.0`, heights use `60.0`
- Skeleton: `width: 140px; height: 60px;`

**Step 3: Update Viaggi Da Fare graph (lines 436-512)**

This one uses polyline (line chart), update:
- Container: `Width="140px" Height="60px"`
- ViewBox: `viewBox="0 0 140 60"`
- Slot width: `double slotWidth = 11.67;  // 140 / 12`
- Y calculation: adjust for 60px height
- Background bars: `height="60"`

```csharp
// Build line points based on BAR CENTERS
var sb = new System.Text.StringBuilder();
for (int i = 0; i < 12; i++)
{
    var val = points[i];
    var x = (i * slotWidth) + (barWidth / 2.0);
    // Y scaling: Top Margin = 8, Bottom Margin = 5, Available = 60 - 8 - 5 = 47
    var y = 55.0 - ((val / max) * 47.0);  // Adjusted for 60px height

    sb.Append($"{x.ToString(System.Globalization.CultureInfo.InvariantCulture)},{y.ToString(System.Globalization.CultureInfo.InvariantCulture)} ");
}
```

**Step 4: Test all graphs**

Run app and verify all 4 graphs in DashboardAdmin are 140x60:
- Clienti Totali (bars)
- Viaggi Totali (bars)
- Fatturato (bars)
- Viaggi Da Fare (line chart)

**Step 5: Commit**

```bash
git add Components/Pages/DashboardAdmin.razor
git commit -m "feat(dashboard): resize remaining DashboardAdmin graphs to 140x60px

- Viaggi Totali: 140x60 bars
- Fatturato: 140x60 bars
- Viaggi Da Fare: 140x60 line chart with adjusted Y-axis

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Resize Mini-Graphs in DashboardSuperAdmin

**Files:**
- Modify: `Components/Pages/DashboardSuperAdmin.razor:134-178` (Aziende)
- Modify: `Components/Pages/DashboardSuperAdmin.razor:218-258` (Clienti)
- Modify: `Components/Pages/DashboardSuperAdmin.razor:299-339` (Viaggi)
- Modify: `Components/Pages/DashboardSuperAdmin.razor:427-495` (Viaggi Da Fare)

**Step 1: Update Aziende Totali graph (lines 134-178)**

Apply same pattern:
- Container: `Width="140px" Height="60px"`
- ViewBox: `viewBox="0 0 140 60"`
- Bar calculation: `barWidth = 140.0 / 12.0`, heights use `60.0`
- Skeleton: `width: 140px; height: 60px;`

**Step 2: Update Clienti Totali graph (lines 218-258)**

Same pattern as above.

**Step 3: Update Viaggi Totali graph (lines 299-339)**

Same pattern as above.

**Step 4: Update Viaggi Da Fare line chart (lines 427-495)**

Apply polyline adjustments like DashboardAdmin Task 2 Step 3.

**Step 5: Test SuperAdmin dashboard**

Run app, login as SuperAdmin, verify all graphs are 140x60.

**Step 6: Commit**

```bash
git add Components/Pages/DashboardSuperAdmin.razor
git commit -m "feat(dashboard): resize DashboardSuperAdmin graphs to 140x60px

- Aziende Totali: 140x60 bars
- Clienti Totali: 140x60 bars
- Viaggi Totali: 140x60 bars
- Viaggi Da Fare: 140x60 line chart

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Improve Typography Hierarchy in DashboardAdmin

**Files:**
- Modify: `Components/Pages/DashboardAdmin.razor:196` (Clienti value)
- Modify: `Components/Pages/DashboardAdmin.razor:241` (Clienti label)
- Modify: `Components/Pages/DashboardAdmin.razor:242` (Clienti caption)
- Similar changes for Viaggi (267), Revenue (337), ViaggiFatti (408), ViaggiDaFare (437)

**Step 1: Update Clienti card main value (h4 → h3 bold)**

Find line 196:

```razor
<!-- BEFORE -->
<MudText Typo="Typo.h4">@(_statsClienti?.MainValue ?? 0)</MudText>

<!-- AFTER -->
<MudText Typo="Typo.h3" Style="font-weight: 700; line-height: 1.2;">
    @(_statsClienti?.MainValue ?? 0)
</MudText>
```

**Step 2: Update Clienti card label (add medium weight)**

Find line 241:

```razor
<!-- BEFORE -->
<MudText Typo="Typo.body2">Clienti Totali</MudText>

<!-- AFTER -->
<MudText Typo="Typo.body2" Style="font-weight: 500;">
    Clienti Totali
</MudText>
```

**Step 3: Update Clienti card caption (improve readability)**

Find line 242:

```razor
<!-- BEFORE -->
<MudText Typo="Typo.caption" Color="Color.Secondary">(% @_selectedYear su @(_selectedYear - 1))
</MudText>

<!-- AFTER -->
<MudText Typo="Typo.body2" Style="font-size: 12px; color: var(--mud-palette-text-secondary);">
    (% @_selectedYear su @(_selectedYear - 1))
</MudText>
```

**Step 4: Repeat for all stat cards**

Apply same pattern to:
- Viaggi Totali (line ~267, ~311, ~313)
- Fatturato (line ~337, ~382, ~383)
- Viaggi Fatti (line ~408, ~410, ~411)
- Viaggi Da Fare (line ~437, ~514, ~515)

**Step 5: Test typography**

Run app and verify:
- Main values are larger and bolder (h3, 700)
- Labels have medium weight (500)
- Captions are more readable (12px, CSS variable color)
- Dark mode text color uses CSS variable correctly

**Step 6: Commit**

```bash
git add Components/Pages/DashboardAdmin.razor
git commit -m "feat(dashboard): improve typography hierarchy in DashboardAdmin

- Main values: h4 → h3 with font-weight 700
- Labels: add font-weight 500 for better hierarchy
- Captions: increase to 12px, use CSS variable for dark mode

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Improve Typography Hierarchy in DashboardSuperAdmin

**Files:**
- Modify: `Components/Pages/DashboardSuperAdmin.razor` (same pattern as Task 4)

**Step 1: Update all stat card main values (h4 → h3 bold)**

Find each main value display (Aziende ~135, Clienti ~219, Viaggi ~300, Revenue ~359, ViaggiFatti ~389, ViaggiDaFare ~428) and apply:

```razor
<MudText Typo="Typo.h3" Style="font-weight: 700; line-height: 1.2;">
    @(_stats*?.MainValue ?? 0)
</MudText>
```

**Step 2: Update all labels (add medium weight)**

Apply to each label:

```razor
<MudText Typo="Typo.body2" Style="font-weight: 500;">
    [Label Text]
</MudText>
```

**Step 3: Update captions (improve readability)**

Apply to captions:

```razor
<MudText Typo="Typo.body2" Style="font-size: 12px; color: var(--mud-palette-text-secondary);">
    (% @_selectedYear su @(_selectedYear - 1))
</MudText>
```

**Step 4: Test SuperAdmin typography**

Login as SuperAdmin, verify typography improvements match DashboardAdmin.

**Step 5: Commit**

```bash
git add Components/Pages/DashboardSuperAdmin.razor
git commit -m "feat(dashboard): improve typography hierarchy in DashboardSuperAdmin

- Main values: h4 → h3 with font-weight 700
- Labels: add font-weight 500
- Captions: increase to 12px, use CSS variable

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Optimize Recent Activity Spacing in DashboardAdmin

**Files:**
- Modify: `Components/Pages/DashboardAdmin.razor:589-604`

**Step 1: Remove Dense attribute**

Find line 590:

```razor
<!-- BEFORE -->
<MudList T="string" Dense="true">

<!-- AFTER -->
<MudList T="string" Dense="false">
```

**Step 2: Reduce max-height**

Find line 589:

```razor
<!-- BEFORE -->
<div style="max-height: 400px; overflow-y: auto; padding-right: 4px;">

<!-- AFTER -->
<div style="max-height: 300px; overflow-y: auto; padding-right: 4px;">
```

**Step 3: Add explicit padding to list items (optional enhancement)**

Find line 593, add style:

```razor
<MudListItem Icon="@GetActivityIcon(item.EventType)"
             IconColor="@GetActivityColor(item.EventType)"
             Style="padding: 12px 16px;">
```

**Step 4: Test spacing**

Run app, verify:
- Recent Activity list is not dense (more spacing)
- Max height 300px shows ~8-10 items
- Scroll works correctly
- Readability improved

**Step 5: Commit**

```bash
git add Components/Pages/DashboardAdmin.razor
git commit -m "feat(dashboard): optimize Recent Activity spacing in DashboardAdmin

- Remove Dense attribute for better readability
- Reduce max-height from 400px to 300px
- Add explicit padding to list items

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Optimize Recent Activity Spacing in DashboardSuperAdmin

**Files:**
- Modify: `Components/Pages/DashboardSuperAdmin.razor:581-594`

**Step 1: Remove Dense attribute**

Find line 582:

```razor
<!-- BEFORE -->
<MudList T="string" Dense="true">

<!-- AFTER -->
<MudList T="string" Dense="false">
```

**Step 2: Reduce max-height**

Find line 581:

```razor
<!-- BEFORE -->
<div style="max-height: 400px; overflow-y: auto;">

<!-- AFTER -->
<div style="max-height: 300px; overflow-y: auto; padding-right: 4px;">
```

**Step 3: Add padding to list items**

Find line 585:

```razor
<MudListItem T="string"
             Icon="@GetActivityIcon(item.EventType)"
             IconColor="@GetActivityColor(item.EventType)"
             Style="padding: 12px 16px;">
```

**Step 4: Test SuperAdmin spacing**

Login as SuperAdmin, verify spacing improvements.

**Step 5: Commit**

```bash
git add Components/Pages/DashboardSuperAdmin.razor
git commit -m "feat(dashboard): optimize Recent Activity spacing in DashboardSuperAdmin

- Remove Dense attribute
- Reduce max-height to 300px
- Add explicit padding

Part of Fase 3 - Visual Refinement

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Create Feature Branch for Phase 2

**Step 1: Ensure Phase 1 is complete**

Verify all Phase 1 commits are on main:

```bash
git log --oneline -7
```

Expected output shows 7 commits from Tasks 1-7.

**Step 2: Create Phase 2 branch**

```bash
git checkout -b feature/fase3-responsive-navmenu
```

**Step 3: Verify branch**

```bash
git branch --show-current
```

Expected: `feature/fase3-responsive-navmenu`

---

## PHASE 2: Responsive NavMenu

### Task 9: Add JavaScript Helper for Window Width

**Files:**
- Create: `wwwroot/js/responsive-helper.js`

**Step 1: Create the helper file**

Create new file `wwwroot/js/responsive-helper.js`:

```javascript
// Responsive helper functions for .NET MAUI Blazor
window.ResponsiveHelper = {
    getWindowWidth: function() {
        return window.innerWidth;
    },

    isMobile: function() {
        return window.innerWidth < 960; // MudBlazor Breakpoint.Md
    },

    addResizeListener: function(dotnetHelper) {
        window.addEventListener('resize', () => {
            dotnetHelper.invokeMethodAsync('OnWindowResize', window.innerWidth);
        });
    }
};
```

**Step 2: Reference in index.html or _Host.cshtml**

Check which file your project uses:

```bash
find . -name "index.html" -o -name "_Host.cshtml" 2>/dev/null | grep -v node_modules
```

Add script reference before closing `</body>` tag:

```html
<script src="js/responsive-helper.js"></script>
```

**Step 3: Test JavaScript is loaded**

Run app and open browser DevTools Console:

```javascript
console.log(window.ResponsiveHelper.getWindowWidth());
```

Expected: Should output current window width (e.g., 1920)

**Step 4: Commit**

```bash
git add wwwroot/js/responsive-helper.js
# Add index.html or _Host.cshtml depending on your project
git add wwwroot/index.html  # or Components/App.razor or wherever the script reference is
git commit -m "feat(layout): add JavaScript helper for responsive detection

- Create ResponsiveHelper with getWindowWidth and isMobile
- Reference script in app shell

Part of Fase 3 - Responsive NavMenu

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Add NavMenu OnItemClick Callback

**Files:**
- Modify: `Components/Shared/NavMenu.razor:14-230`

**Step 1: Add OnItemClick parameter**

Add at top of NavMenu.razor after `@inject` statements:

```razor
@code {
    [Parameter]
    public EventCallback OnItemClick { get; set; }
}
```

**Step 2: Add callback to each MudNavLink**

Find the first MudNavLink (line ~15) and add the callback:

```razor
<!-- BEFORE -->
<MudNavLink Icon="@Icons.Material.Filled.Dashboard"
            OnClick="@(() => OpenTab(_dashboardRoute, "Dashboard", "dashboard"))">
    <MudText Typo="Typo.body1">Dashboard</MudText>
</MudNavLink>

<!-- AFTER -->
<MudNavLink Icon="@Icons.Material.Filled.Dashboard"
            OnClick="@(async () => { OpenTab(_dashboardRoute, "Dashboard", "dashboard"); await OnItemClick.InvokeAsync(); })">
    <MudText Typo="Typo.body1">Dashboard</MudText>
</MudNavLink>
```

**Step 3: Update OpenTab helper to invoke callback**

Modify the OpenTab method (around line 243):

```csharp
private async Task OpenTab(string route, string title, string icon)
{
    if (!TabManager.CanOpenTab())
    {
        Snackbar.Add($"Impossibile aprire '{title}': limite di {TabManager.MaxTabs} tab raggiunto. Chiudi una tab per continuare.", Severity.Warning, config =>
        {
            config.VisibleStateDuration = 4000;
        });
        return;
    }

    bool opened = TabManager.OpenTab(route, title, icon);
    if (opened)
    {
        Snackbar.Add($"Tab aperto: {title}", Severity.Success, config =>
        {
            config.VisibleStateDuration = 2000;
        });
    }

    // Invoke callback to close drawer on mobile
    await OnItemClick.InvokeAsync();
}
```

**Step 4: Update ALL MudNavLink OnClick to use OpenTab properly**

Change each OnClick from inline lambda to method call that supports async:

```razor
<!-- Pattern to apply everywhere -->
<MudNavLink Icon="@Icons.Material.Filled.Business"
            OnClick="@(() => OpenTab("/anagrafiche/aziende", "Anagrafica Aziende", "business"))">
```

This already calls OpenTab which now invokes the callback.

**Step 5: Test callback is defined**

Build the project to ensure no compilation errors:

```bash
dotnet build
```

Expected: Build succeeds with no errors.

**Step 6: Commit**

```bash
git add Components/Shared/NavMenu.razor
git commit -m "feat(navmenu): add OnItemClick callback for drawer auto-close

- Add EventCallback parameter for parent component
- Invoke callback after successful tab open
- Supports mobile drawer auto-close pattern

Part of Fase 3 - Responsive NavMenu

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Implement Responsive Drawer in MainLayout

**Files:**
- Modify: `Components/Layout/MainLayout.razor`

**Step 1: Add IJSRuntime injection**

Add at the top with other @inject statements:

```razor
@inject IJSRuntime JSRuntime
```

**Step 2: Add responsive state fields**

Add to @code block:

```csharp
@code {
    private bool _drawerOpen = false;
    private bool _isMobile = false;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            try
            {
                _isMobile = await JSRuntime.InvokeAsync<bool>("ResponsiveHelper.isMobile");
                StateHasChanged();
            }
            catch (Exception ex)
            {
                // Fallback: assume desktop if JS fails
                _isMobile = false;
                Console.WriteLine($"Error detecting mobile: {ex.Message}");
            }
        }

        await base.OnAfterRenderAsync(firstRender);
    }

    private void ToggleDrawer()
    {
        _drawerOpen = !_drawerOpen;
    }

    private void CloseDrawerOnMobile()
    {
        if (_isMobile)
        {
            _drawerOpen = false;
            StateHasChanged();
        }
    }
}
```

**Step 3: Update MudDrawer with conditional Variant**

Find the existing MudDrawer (look for `<MudDrawer`):

```razor
<!-- BEFORE (likely something like this) -->
<MudDrawer Open="true" Variant="DrawerVariant.Mini" OpenMiniOnHover="true">
    <NavMenu />
</MudDrawer>

<!-- AFTER -->
<MudDrawer @bind-Open="_drawerOpen"
           Variant="@(_isMobile ? DrawerVariant.Temporary : DrawerVariant.Mini)"
           OpenMiniOnHover="@(!_isMobile)"
           CloseOnEscape="@_isMobile"
           Anchor="Anchor.Left"
           Elevation="1">
    <NavMenu OnItemClick="@CloseDrawerOnMobile" />
</MudDrawer>
```

**Step 4: Add hamburger menu button in AppBar**

Find the MudAppBar and add button at the start:

```razor
<MudAppBar Elevation="1">
    @if (_isMobile)
    {
        <MudIconButton Icon="@Icons.Material.Filled.Menu"
                       Color="Color.Inherit"
                       Edge="Edge.Start"
                       OnClick="@ToggleDrawer"
                       aria-label="Apri menu" />
    }

    <!-- Existing AppBar content -->
    <MudSpacer />
    <!-- ... rest of AppBar ... -->
</MudAppBar>
```

**Step 5: Test responsive behavior**

Run the app:

```bash
dotnet run
```

**Desktop test (≥960px):**
- Drawer should be Mini variant
- No hamburger button
- Hover expands drawer

**Mobile test (<960px, use browser DevTools responsive mode):**
- Drawer should be Temporary variant (closed by default)
- Hamburger button visible
- Click hamburger opens drawer
- Click menu item closes drawer
- Click outside drawer closes it

**Step 6: Commit**

```bash
git add Components/Layout/MainLayout.razor
git commit -m "feat(layout): implement responsive NavMenu drawer

- Add IJSRuntime for mobile detection
- Conditional DrawerVariant: Temporary on mobile, Mini on desktop
- Hamburger menu button for mobile drawer toggle
- Auto-close drawer after menu item click on mobile

Part of Fase 3 - Responsive NavMenu

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 12: Test Complete Phase 2 Integration

**Step 1: Test desktop mode (≥960px)**

Open app in browser, ensure window is full-width:

- [ ] Drawer is DrawerVariant.Mini (icon-only sidebar)
- [ ] Hover over drawer expands to show full labels
- [ ] No hamburger menu button visible
- [ ] Clicking menu items opens tabs normally

**Step 2: Test tablet mode (768px-959px)**

Open DevTools, set responsive mode to tablet (iPad):

- [ ] Drawer becomes Temporary (hidden by default)
- [ ] Hamburger button appears in AppBar
- [ ] Clicking hamburger opens drawer overlay
- [ ] Clicking menu item closes drawer
- [ ] Clicking outside drawer closes it

**Step 3: Test mobile mode (<768px)**

Set responsive mode to mobile (iPhone):

- [ ] Same behavior as tablet
- [ ] Drawer takes full screen width on mobile
- [ ] Touch interactions work correctly

**Step 4: Test resize behavior**

Manually resize browser window from desktop → mobile → desktop:

- [ ] Variant switches correctly
- [ ] Hamburger appears/disappears
- [ ] No visual glitches during transition

**Step 5: Document test results**

If all tests pass, proceed to merge. If issues found, fix and re-test.

---

### Task 13: Merge Phase 2 to Main

**Step 1: Verify branch is clean**

```bash
git status
```

Expected: "nothing to commit, working tree clean"

**Step 2: Switch to main**

```bash
git checkout main
```

**Step 3: Merge feature branch**

```bash
git merge feature/fase3-responsive-navmenu --no-ff -m "feat(fase3): merge Responsive NavMenu implementation

Phase 2 of Fase 3 Dashboard Improvements:
- JavaScript helper for responsive detection
- NavMenu OnItemClick callback for auto-close
- Conditional DrawerVariant in MainLayout
- Hamburger menu for mobile/tablet

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Step 4: Delete feature branch**

```bash
git branch -d feature/fase3-responsive-navmenu
```

**Step 5: Verify final state**

```bash
git log --oneline -10
```

Expected: See all Phase 1 and Phase 2 commits merged to main.

**Step 6: Final full app test**

Run app and verify both phases working together:
- [ ] Mini-graphs are 140x60px
- [ ] Typography hierarchy is clear
- [ ] Recent Activity spacing improved
- [ ] Responsive NavMenu works on all screen sizes

---

## Post-Implementation Checklist

- [ ] All 13 tasks completed
- [ ] All commits follow conventional commit format
- [ ] Desktop (≥960px) testing passed
- [ ] Tablet (768-959px) testing passed
- [ ] Mobile (<768px) testing passed
- [ ] Light mode verified
- [ ] Dark mode verified
- [ ] No console errors
- [ ] Design document updated with final implementation notes (if needed)

---

## Rollback Procedures

### If Phase 1 has issues:

```bash
# Find the commit before Phase 1
git log --oneline --grep="feat(dashboard)" -7

# Revert specific commits
git revert <commit-hash>..HEAD
```

### If Phase 2 has issues:

```bash
# Checkout main before Phase 2 merge
git log --oneline --grep="merge Responsive NavMenu" -1
git revert <merge-commit-hash>
```

---

## Success Criteria

**Phase 1 Complete When:**
- All mini-graphs are 140x60px in both dashboards
- Typography uses h3 bold for main values, medium for labels
- Recent Activity lists are not dense, max-height 300px
- Light and dark modes work correctly

**Phase 2 Complete When:**
- Desktop shows DrawerVariant.Mini with hover expand
- Mobile/tablet shows DrawerVariant.Temporary with hamburger
- Drawer auto-closes on mobile after menu item click
- Responsive breakpoint transitions are smooth

**Fase 3 Complete When:**
- All success criteria from design document met
- All tests pass
- Code reviewed and merged to main
- No regressions in existing functionality

---

**Plan created:** 2026-02-17
**Estimated time:** Phase 1 ~45 minutes, Phase 2 ~30 minutes, Total ~75 minutes
