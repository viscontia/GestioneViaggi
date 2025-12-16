# Architettura UI e Componenti Shared

## Libreria Componenti (Shared)
È stata avviata la creazione di una libreria di componenti personalizzati per garantire riutilizzabilità e coerenza grafica.

### EnterpriseDataGrid
Componente che estende `MudDataGrid` (`Components/Shared/EnterpriseDataGrid.cs`).
*   **Funzionalità**:
    *   Applica automaticamente le classi CSS enterprise (`.enterprise-grid`).
    *   Configura i default (Dense, Striped, Hover, Elevation=0).
    *   Risolve i problemi di ereditarietà dei tipi generici tramite `[CascadingTypeParameter]`.
*   **Utilizzo**: `<EnterpriseDataGrid T="Modello" ...>`

### EnterprisePager
Componente per la paginazione (`Components/Shared/EnterprisePager.razor`).
*   **Funzionalità**: Wrapper di `MudDataGridPager` con testi pre-localizzati in Italiano ("Righe per pagina", record count).
*   **Utilizzo**: Da inserire nel `PagerContent` della griglia.

## Stili CSS Avanzati
Gli stili sono organizzati in file CSS specifici in `wwwroot/css/components/`.

### Grid CSS (`grid.css`)
Definisce lo stile per le tabelle enterprise:
*   **Header**: Font weight 600, 0.78rem, Uppercase, Letter-spacing 0.06em.
*   **Colori**: Definiti specificamente per **Light Mode** e **Dark Mode**.
    *   *Dark*: Header `#B8BCC6` su `#2E3038`.
    *   *Light*: Header `#5F6470` su `#F4F5F7`.

### Theme Switching
Il `MainLayout` inietta dinamicamente la classe `.theme-dark` o `.theme-light` nel contenitore `MudMainContent` per attivare le variabili CSS corrette.

## Configurazione Globale

### Layout "Enterprise"
*   **MudLayout**: Struttura base con AppBar e Drawer.
*   **Mini Drawer**: Menu laterale che si riduce a icone (`DrawerVariant.Mini`).
*   **Tema**: Palette personalizzata (toni del blu) configurata in `MudThemeProvider`.

### Desktop Optimization
*   **Window Size**: Su MacCatalyst/Windows, dimensione finestra predefinita impostata a **1200x800** in `App.xaml.cs`.
