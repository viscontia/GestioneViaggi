# Architettura UI e Componenti Shared

## Libreria Componenti (Shared)
È stata avviata la creazione di una libreria di componenti personalizzati per garantire riutilizzabilità e coerenza grafica.

### EnterpriseDataGrid
Componente che estende `MudDataGrid` (`Components/Shared/EnterpriseDataGrid.cs`).
*   **Funzionalità**:
    *   **Default**: Selezione singola, ReadOnly, Dense, Striped, Hover.
    *   **Toolbar**: Include automaticamente un titolo e una casella di ricerca (Search Box).
    *   **Filtro**: Supporta una `SearchFunction` personalizzata per il filtro trasversale.
*   **Utilizzo**:
    ```razor
    <EnterpriseDataGrid T="Modello" Title="Titolo" SearchFunction="@SearchFunc" @bind-SelectedItem="_selectedItem">
        <Columns>
            ...
            <EnterpriseActionsColumn T="Modello" OnEdit="..." OnDelete="..." />
        </Columns>
    </EnterpriseDataGrid>
    ```

### EnterpriseActionsColumn
Colonna standard per le azioni (Modifica/Elimina) (`Components/Shared/EnterpriseActionsColumn.razor`).
*   **Funzionalità**: Mostra icone standard con Tooltip.
*   **Parametri**: `OnEdit` e `OnDelete` (EventCallback).

### EnterpriseGridToolbar
Componente interno usato da EnterpriseDataGrid per renderizzare Titolo e SearchBox.

### EnterprisePager
Componente per la paginazione (`Components/Shared/EnterprisePager.razor`).
*   **Funzionalità**: Wrapper di `MudDataGridPager` con testi pre-localizzati in Italiano ("Righe per pagina", record count).
*   **Utilizzo**: Da inserire nel `PagerContent` della griglia.

### CountrySelect
Componente dropdown riutilizzabile per la selezione di paesi (`Components/Shared/CountrySelect.razor`).
*   **Funzionalità**:
    *   Carica automaticamente tutti i paesi da `eba_countries` ordinati per nome (ASC).
    *   Supporta binding bidirezionale con `@bind-SelectedCountryId`.
    *   Item vuoto "-- Seleziona --" per gestione valori null.
    *   Configurabile: Label, Required, RequiredError, Disabled, AutoFocus, Class, HelperText, Placeholder.
    *   Mostra asterisco rosso se Required=true (classe `required-field`).
*   **Parametri**:
    *   `SelectedCountryId` (int?) - ID paese selezionato (binding)
    *   `Label` (string) - Etichetta campo (default: "Paese")
    *   `Required` (bool) - Campo obbligatorio (default: false)
    *   `RequiredError` (string) - Messaggio errore (default: "Il paese è obbligatorio")
    *   `Disabled` (bool) - Campo disabilitato (default: false)
    *   `AutoFocus` (bool) - Focus automatico al render (default: false)
    *   `Class` (string) - Classi CSS aggiuntive (default: "mb-3")
    *   `HelperText` (string) - Testo helper (default: "Seleziona il paese dall'elenco")
    *   `Placeholder` (string) - Placeholder (default: "Seleziona un paese...")
*   **Utilizzo**:
    ```razor
    <CountrySelect SelectedCountryId="@(Entity.CountryIdFk == 0 ? null : Entity.CountryIdFk)"
                   SelectedCountryIdChanged="@((int? value) => Entity.CountryIdFk = value ?? 0)"
                   Required="true"
                   AutoFocus="true"
                   RequiredError="Il paese è obbligatorio" />
    ```
*   **Dipendenze**: Richiede `CountryService` registrato in `MauiProgram.cs`.
*   **Best Practice**: Convertire valore 0 → null nel binding per evitare visualizzazione "0" iniziale.

### RegioneSelect
Componente dropdown riutilizzabile per la selezione di regioni (`Components/Shared/RegioneSelect.razor`).
*   **Funzionalità**:
    *   Carica automaticamente tutte le regioni da `ana_geo_regioni_ita` ordinate per descrizione (ASC).
    *   Supporta binding bidirezionale con `@bind-SelectedRegioneId`.
    *   Configurabile: Label, Required, RequiredError, Disabled, AutoFocus, Class, HelperText.
    *   Mostra asterisco rosso se Required=true (classe `required-field`).
*   **Parametri**:
    *   `SelectedRegioneId` (int?) - ID regione selezionata (binding)
    *   `Label` (string) - Etichetta campo (default: "Regione")
    *   `Required` (bool) - Campo obbligatorio (default: false)
    *   `RequiredError` (string) - Messaggio errore (default: "La regione è obbligatoria")
    *   `Disabled` (bool) - Campo disabilitato (default: false)
    *   `AutoFocus` (bool) - Focus automatico al render (default: false)
    *   `Class` (string) - Classi CSS aggiuntive (default: "mb-3")
    *   `HelperText` (string) - Testo helper (default: "Seleziona la regione corretta dall'elenco")
*   **Utilizzo**:
    ```razor
    <RegioneSelect @bind-SelectedRegioneId="@Entity.RegioneIdFk"
                   Required="true"
                   RequiredError="La regione è obbligatoria"
                   HelperText="Seleziona la regione amministrativa di riferimento." />
    ```
*   **Dipendenze**: Richiede `RegioneService` registrato in `MauiProgram.cs`.

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
