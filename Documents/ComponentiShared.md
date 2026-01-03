# Architettura UI e Componenti Shared

## Libreria Componenti (Shared)
È stata avviata la creazione di una libreria di componenti personalizzati per garantire riutilizzabilità e coerenza grafica.

### EnterpriseDataGrid
Componente che estende `MudDataGrid` (`Components/Shared/EnterpriseDataGrid.cs`).
*   **Funzionalità**:
    *   **Default**: Selezione singola, ReadOnly, Dense, Striped, Hover.
    *   **Toolbar**: Include automaticamente un titolo, una casella di ricerca (Search Box) con tasto "Clear" e un'area per azioni personalizzate (es. bottone "Nuovo").
    *   **Filtro**: Supporta una `SearchFunction` personalizzata per il filtro trasversale.
*   **Utilizzo**:
    ```razor
    <EnterpriseDataGrid T="Modello" 
                        Title="Titolo" 
                        SearchFunction="@SearchFunc" 
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
            <EnterpriseActionsColumn T="Modello" OnEdit="..." OnDelete="..." />
        </Columns>
    </EnterpriseDataGrid>
    ```

### EnterpriseActionsColumn
Colonna standard per le azioni (Modifica/Elimina) (`Components/Shared/EnterpriseActionsColumn.razor`).
*   **Funzionalità**: Mostra icone standard con Tooltip.
*   **Parametri**: `OnEdit` e `OnDelete` (EventCallback).

### EnterpriseGridToolbar
Componente interno usato da EnterpriseDataGrid per renderizzare Titolo, SearchBox e Azioni.
*   **Layout**: [Titolo] [Spacer] [SearchBox] [Azioni]
*   **SearchBox**: Include icona lente d'ingrandimento a sinistra e tasto "X" (Clear) a destra.


### EnterprisePager
Componente per la paginazione (`Components/Shared/EnterprisePager.razor`).
*   **Funzionalità**: Wrapper di `MudDataGridPager` con testi pre-localizzati in Italiano ("Righe per pagina", record count).
*   **Utilizzo**: Da inserire nel `PagerContent` della griglia.

---

## Componenti Select (Autocomplete)
Gran parte dei componenti di selezione (Dropdown) sono stati migrati per utilizzare internamente `MudAutocomplete` tramite un componente base comune.

### BaseEntitySelect
Componente base generico (`Components/Shared/BaseEntitySelect.razor`) che incapsula la logica di `MudAutocomplete`.
*   **Funzionalità**:
    *   **Ricerca**: Permette di filtrare gli elementi digitando nel campo.
    *   **Clear**: Include un pulsante "X" per pulire la selezione.
    *   **Validazione**: Supporta `Required` e `RequiredError` con stile visuale standard (asterisco rosso).
    *   **Auto-Focus**: Supporta il focus automatico al caricamento.
*   **Parametri Chiave**:
    *   `TItem`: Il tipo dell'entità (es. `Country`, `Regione`).
    *   `SearchFunc`: Funzione di ricerca `Func<string, CancellationToken, Task<IEnumerable<TItem>>>`.
    *   `ToStringFunc`: Funzione per visualizzare il testo dell'item.

### CountrySelect
Componente per la selezione di paesi (`Components/Shared/CountrySelect.razor`).
*   **Funzionalità**:
    *   Carica automaticamente i paesi da `eba_countries`.
    *   Permette la ricerca per nome.
*   **Utilizzo**:
    ```razor
    <CountrySelect SelectedCountryId="@(Entity.CountryIdFk == 0 ? null : Entity.CountryIdFk)"
                   SelectedCountryIdChanged="@((int? value) => Entity.CountryIdFk = value ?? 0)"
                   Required="true"
                   AutoFocus="true"
                   RequiredError="Il paese è obbligatorio" />
    ```

### RegioneSelect
Componente per la selezione di regioni (`Components/Shared/RegioneSelect.razor`).
*   **Funzionalità**:
    *   Carica le regioni da `ana_geo_regioni_ita`.
    *   Permette la ricerca per descrizione.
*   **Utilizzo**:
    ```razor
    <RegioneSelect @bind-SelectedRegioneId="@Entity.RegioneIdFk"
                   Required="true"
                   HelperText="Seleziona la regione amministrativa." />
    ```

### ProvinciaSelect
Componente per la selezione di province (`Components/Shared/ProvinciaSelect.razor`).
*   **Funzionalità**:
    *   Carica le province da `ana_geo_province_ita`.
    *   Supporta il filtro `FilterEsteroOnly` per distinguere province IT/Estere.
*   **Utilizzo**:
    ```razor
    <ProvinciaSelect @bind-SelectedProvinciaId="@Entity.ProvinciaIdFk"
                     Required="true"
                     FilterEsteroOnly="@Entity.ComuneEstero" />
    ```

### AziendaSelect (New)
Componente specifico per la selezione dell'azienda (`Components/Shared/AziendaSelect.razor`).
*   **Differenza**: Utilizza `MudSelect` standard invece di Autocomplete (lista limitata).
*   **Funzionalità**:
    *   Caricamento asincrono aziende.
    *   Supporto opzione "Tutte le Aziende" (Value=0) utile per SuperAdmin.
*   **Parametri**: `ShowAllOption`, `Required`.

### Elenco Completo Componenti Select

Di seguito l'elenco di tutti i componenti di selezione (Combobox/Autocomplete) disponibili in `Components/Shared`:

| Componente | File | Tabella / Campo | Ordinamento | Scopo |
|---|---|---|---|---|
| **AziendaSelect** | `AziendaSelect.razor` | `ana_aziende` | Ragione Sociale | Selezione azienda per contesto multi-tenant. Include opzione "Tutte". |
| **CapoluogoSelect** | `CapoluogoSelect.razor` | `ana_geo_comuni` (flag capoluogo) | Descrizione | Selezione città capoluogo di provincia. |
| **ComuneSelect** | `ComuneSelect.razor` | `ana_geo_comuni` | Nome | Ricerca completa comuni italiani ed esteri. |
| **CountrySelect** | `CountrySelect.razor` | `eba_countries` | Name (Nome Paese) | Selezione nazione (standard ISO). |
| **CountryIntermediate** | `CountryIntermediateSelect` | `eba_countries_intermediate_regions` | Name | Selezione macro-regione intermedia (ONU). |
| **CountryOrganization** | `CountryOrganizationSelect` | `eba_countries_organizations` | Name | Selezione organizzazione internazionale. |
| **CountryRegion** | `CountryRegionSelect` | `eba_countries_regions` | Name | Selezione regione mondiale (es. Europe, Asia). |
| **CountrySubRegion** | `CountrySubRegionSelect` | `eba_countries_sub_regions` | Name | Selezione sotto-regione (es. Southern Europe). |
| **FormaGiuridica** | `FormaGiuridicaSelect.razor` | `ana_forme_giuridiche` | Descrizione | Selezione forma giuridica azienda (SPA, SRL...). |
| **MarcaVeicolo** | `MarcaVeicoloSelect.razor` | `ana_marche_veicoli` | Descrizione | Selezione marca veicolo (es. Fiat, BMW). |
| **ProvinciaSelect** | `ProvinciaSelect.razor` | `ana_geo_province_ita` | Descrizione | Selezione provincia (sigla visualizzata). supporta filtro estero. |
| **RegioneSelect** | `RegioneSelect.razor` | `ana_geo_regioni_ita` | Descrizione | Selezione regione amministrativa italiana. |
| **RepartoSelect** | `RepartoSelect.razor` | `ana_reparti` | NomeReparto | Assegnazione reparto interno (es. Amministrazione). |
| **RipGeoSelect** | `RipGeoSelect.razor` | `ana_geo_ripartizioni_geo` | Descrizione | Selezione ripartizione geografica (Nord, Centro, Sud). |
| **SedeSelect** | `SedeSelect.razor` | `ana_sedi` | Tipologia + Indirizzo | Selezione sede operativa/legale di un'azienda. |
| **TipoMezzo** | `TipoMezzoSelect.razor` | `ana_tipi_mezzo` | Descrizione | Classificazione mezzi (Auto, Moto, Furgone). |
| **TipoSede** | `TipoSedeSelect.razor` | `ana_tipi_sede` | Descrizione | Classificazione sedi (Legale, Operativa, Magazzino). |

---

## Componenti UI Generali

### AppBreadcrumbs
Componente di navigazione (`Components/Shared/AppBreadcrumbs.razor`).
*   Gestisce la visualizzazione del percorso di navigazione corrente.

### StatusBar
Barra di stato inferiore (`Components/Shared/StatusBar.razor`).
*   Visualizza informazioni di sistema o utente corrente.

### StatusBadge
Badge per visualizzazioni stati semplici (`Components/Shared/StatusBadge.razor`).

---

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

## Comportamento Modali (Dialogs)
**Regola Globale**: Tutte le modali di inserimento/modifica devono impedire la chiusura accidentale tramite click esterno.
*   **Implementazione**: Quando si crea l'oggetto `DialogOptions`, impostare sempre **`BackdropClick = false`**.
*   **Esempio**: `new DialogOptions { BackdropClick = false, ... }`

---

## Funzioni Database
Questa sezione elenca le stored function personalizzate create nel database PostgreSQL.

### get_count_travel_made
Calcola il numero di viaggi effettuati da un cliente per una specifica azienda.
*   **File Script**: `SqlScripts/25_Create_GetCountTravelMade.sql`
*   **Parametri Input**:
    *   `p_cliente_id` (integer): ID del cliente.
    *   `p_azienda_id` (integer): ID dell'azienda (tenant).
*   **Valore Restituito**: `integer` (Numero di viaggi trovati).
*   **Logica**:
    *   Esegue una JOIN tra `mov_clienti_viaggi` e `ana_date_viaggi`.
    *   Filtra per `cliente_id` e `azienda_id`.
    *   Filtra per `cliente_id` e `azienda_id`.
    *   Considera validi solo i viaggi con `data_viaggio_effettuato_sino = 'Y'`.

### get_count_travel_future
Conta i viaggi futuri (prenotati ma non ancora effettuati) di un cliente per una specifica azienda.
*   **File Script**: `SqlScripts/26_Create_GetCountTravelFuture.sql`
*   **Parametri Input**:
    *   `p_cliente_id` (integer): ID del cliente.
    *   `p_azienda_id` (integer): ID dell'azienda.
*   **Valore Restituito**: `integer` (Numero di viaggi futuri).
*   **Logica**:
    *   Filtra per `cliente_id` e `azienda_id`.
    *   Richiede `data_viaggio_effettuato_sino = 'N'`.
    *   Richiede `data_viaggio_data_inizio > CURRENT_DATE` (viaggi che iniziano dopo oggi).
