# Configurazione GitHub e Progetto

## Repository
Il progetto è ospitato su GitHub al seguente indirizzo:
**[https://github.com/viscontia/GestioneViaggi](https://github.com/viscontia/GestioneViaggi)**

## Stato del Progetto - Versione Iniziale

### Configurazione "Enterprise"
L'applicazione è stata configurata con un layout di livello Enterprise utilizzando **MudBlazor**:
*   **Layout**: Utilizzo di `MudLayout` con `MudAppBar` e `MudDrawer`.
*   **Menu Laterale (Mud Mini)**: Implementato il "Mini Drawer" che si riduce a icone e si espande al passaggio del mouse (`Variant="DrawerVariant.Mini"`, `OpenMiniOnHover="true"`).
*   **Tema**: Configurato `MudThemeProvider` con palette personalizzata (toni del blu) e supporto Dark Mode.

### Ottimizzazioni Desktop
*   **Window Size**: Per le piattaforme Desktop (MacCatalyst/Windows), è stata impostata una dimensione finestra predefinita di **1200x800** in `App.xaml.cs` per evitare il ridimensionamento standard "mobile/tablet".

### Setup GitHub
Il repository è stato inizializzato e pushato utilizzando la CLI di GitHub (`gh`).
*   File `.gitignore` standard per .NET incluso.
*   Branch principale: `Main-Repository`.

## Architettura UI e Componenti

### Libreria Componenti (Shared)
È stata avviata la creazione di una libreria di componenti personalizzati per garantire riutilizzabilità e coerenza grafica.
*   **EnterpriseDataGrid**: Componente che estende `MudDataGrid` (`Components/Shared/EnterpriseDataGrid.cs`).
    *   Applica automaticamente le classi CSS enterprise.
    *   Configura i default (Dense, Striped, Hover).
    *   Risolve i problemi di ereditarietà dei tipi generici tramite `[CascadingTypeParameter]`.

### Stili CSS Avanzati
Gli stili non sono inline ma organizzati in file CSS specifici.
*   **Grid CSS** (`wwwroot/css/components/grid.css`): Definisce la tipografia (Maiuscolo, peso font) e i colori esatti per Header e Righe, con supporto completo per **Light Mode** e **Dark Mode** tramite classi scope (`.theme-dark`, `.theme-light`).
*   **Theme Switching**: `MainLayout` inietta dinamicamente la classe del tema nel contenitore principale per attivare le variabili CSS corrette.
