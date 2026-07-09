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

### FornitoreSelect
Componente autocomplete per la selezione di fornitori (`Components/Shared/FornitoreSelect.razor`).
*   **Funzionalità**:
    *   Carica i fornitori da `ana_fornitori` filtrati per azienda.
    *   Ricerca testuale in tempo reale su Ragione Sociale e Nome Breve.
    *   Supporta parametro `AziendaId` esplicito che ha precedenza sul `TenantContext`.
    *   Ricarica automaticamente i fornitori quando cambia `AziendaId`.
    *   Visualizza Ragione Sociale e Nome Breve (se presente) nel dropdown.
*   **Parametri Chiave**:
    *   `AziendaId` (int?, opzionale): ID azienda per filtrare i fornitori. Se non specificato, usa `TenantContext`.
    *   `SelectedFornitoreId` (int): ID fornitore selezionato (binding).
    *   `Required`, `Clearable`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <FornitoreSelect @bind-SelectedFornitoreId="@Entity.FornitoreId"
                     AziendaId="@_currentAziendaId"
                     Required="true" />
    ```
*   **Nota SuperAdmin**: Per il ruolo SuperAdmin è necessario passare esplicitamente `AziendaId` dopo la selezione dell'azienda, altrimenti il combobox rimane vuoto.

### ControparteSelect
Componente autocomplete per la selezione di una Controparte (Fornitore/Cliente) (`Components/Shared/ControparteSelect.razor`).
*   **Funzionalità**:
    *   Carica controparti da `ana_controparti` filtrate per azienda.
    *   Supporta filtro dinamico basato sul ciclo contabile:
        - `CausaleCiclo="PASSIVO"` → mostra solo fornitori (is_fornitore = TRUE)
        - `CausaleCiclo="ATTIVO"` → mostra solo clienti (is_cliente = TRUE)
        - `CausaleCiclo=null` → mostra tutti
    *   Include opzione virtuale "TUTTE LE CONTROPARTI" (ID=0) per selezione globale nelle stampe.
    *   Visualizza Ragione Sociale, Nome Breve (se presente) e Tipo Controparte nel dropdown.
    *   Ricerca testuale su Ragione Sociale e Nome Breve.
    *   Ricarica automatica quando cambia `AziendaId` o `CausaleCiclo`.
*   **Parametri Chiave**:
    *   `SelectedControparteId` (int): ID controparte selezionata (binding).
    *   `AziendaId` (int?, opzionale): ID azienda per filtrare. Se non specificato, usa `TenantContext`.
    *   `CausaleCiclo` (string?, opzionale): "ATTIVO" o "PASSIVO" per filtrare clienti/fornitori.
    *   `Required`, `Clearable`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <ControparteSelect @bind-SelectedControparteId="_filtroControparteIdInt"
                       AziendaId="@_aziendaIdEffettivo"
                       CausaleCiclo="@_filtroCausaleCiclo"
                       Label="Filtra per Controparte"
                       Clearable="true" />
    ```

### ViaggioSelect
Componente autocomplete per la selezione di un Viaggio (`Components/Shared/ViaggioSelect.razor`).
*   **Funzionalità**:
    *   Carica viaggi da `ana_viaggi` filtrati per azienda.
    *   Visualizza Descrizione Breve, Nazione e Numero Giorni nel dropdown.
    *   Ricerca testuale su Descrizione Breve, Descrizione Estesa e Nome Nazione.
    *   Supporta parametro `CustomItems` per fornire lista personalizzata di viaggi.
    *   Ricarica automaticamente quando cambia `AziendaId`.
*   **Parametri Chiave**:
    *   `SelectedViaggioId` (int?): ID viaggio selezionato (binding).
    *   `AziendaId` (int?, opzionale): ID azienda per filtrare i viaggi.
    *   `CustomItems` (IEnumerable<AnaViaggi>?, opzionale): Lista personalizzata di viaggi.
    *   `Required`, `Clearable`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <ViaggioSelect @bind-SelectedViaggioId="_filtroViaggioId"
                   AziendaId="@_aziendaIdEffettivo"
                   Clearable="true" />
    ```

### ViaggioMultiSelect
Componente per la selezione multipla di viaggi (`Components/Shared/ViaggioMultiSelect.razor`).
*   **Funzionalità**:
    *   Carica viaggi da `ana_viaggi` filtrati per azienda.
    *   Permette la selezione multipla tramite `MudSelect`.
    *   Supporta funzionalità "Seleziona Tutti".
    *   Visualizza Descrizione Breve nel dropdown.
    *   Ricarica automaticamente quando cambia `AziendaId`.
*   **Parametri Chiave**:
    *   `SelectedViaggioIds` (IEnumerable<int>): IDs viaggi selezionati (binding).
    *   `AziendaId` (int?, opzionale): ID azienda per filtrare i viaggi.
    *   `Label`: Etichetta del campo.
    *   `Required`, `Clearable`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <ViaggioMultiSelect @bind-SelectedViaggioIds="_selectedIds"
                        AziendaId="@_aziendaId"
                        Label="Seleziona Viaggi" />
    ```

### ValutaSelect
Componente per la selezione di valute (`Components/Shared/ValutaSelect.razor`).
*   **Implementazione**: Utilizza `MudAutocomplete<AnaValute>` invece di `MudSelect` per risolvere il problema di sovrapposizione tra asterisco required e freccia dropdown.
*   **Funzionalità**:
    *   Carica automaticamente le valute attive da `ana_valute` all'inizializzazione.
    *   Visualizza codice ISO (es. "EUR") e descrizione completa nel formato: `EUR - Euro`.
    *   Supporta ricerca testuale case-insensitive sia sul codice ISO che sulla descrizione.
    *   Mostra icona di ricerca blu (AdornmentIcon) a destra del campo.
    *   Supporta validazione con asterisco rosso nella label quando `Required="true"`.
    *   L'asterisco e l'icona di ricerca sono entrambi visibili senza sovrapposizioni.
    *   Gestisce automaticamente il binding bidirezionale tra `SelectedValutaId` (int) e l'oggetto `AnaValute` interno.
*   **Parametri Chiave**:
    *   `SelectedValutaId` (int): ID valuta selezionata (binding). Usa 0 per nessuna selezione.
    *   `SelectedValutaIdChanged` (EventCallback<int>): Evento scatenato al cambio selezione.
    *   `Label` (string): Etichetta del campo (default: "Valuta").
    *   `Required` (bool): Campo obbligatorio (mostra asterisco rosso nella label).
    *   `RequiredError` (string): Messaggio di errore personalizzato (default: "Campo obbligatorio").
    *   `Clearable` (bool): Permette di cancellare la selezione con pulsante X (default: false).
    *   `Class` (string): Classi CSS aggiuntive.
*   **Comportamento**:
    *   Se non viene digitato testo, mostra tutte le valute disponibili (sono poche).
    *   Durante la digitazione, filtra in tempo reale per codice ISO o descrizione.
    *   Gestisce automaticamente gli stati di caricamento con `_isLoading`.
*   **Contesto Stampe e Profilo Utente**:
    *   Integrato nei contesti documentali (es. **StampaBilancioViaggioDialog**, **StampaBilancioAnnualeViaggiDialog**).
    *   In tali maschere, il componente sfrutta la sessione (`SessionManager`) per pre-istanziare la `ValutaDefaultId` dell'utente collegato, fungendo da filtro di Valuta Report personalizzabile e automatizzato.
*   **Utilizzo Base**:
    ```razor
    <ValutaSelect SelectedValutaId="@(User.ValutaDefaultId ?? 0)"
                  SelectedValutaIdChanged="@HandleValutaChanged"
                  Label="Valuta di Default"
                  Required="true"
                  Clearable="false" />
    ```
*   **Utilizzo in Filtri Stampe (Pre-selezione profilo utente)**:
    ```razor
    <ValutaSelect SelectedValutaId="_selectedValutaId"
                  SelectedValutaIdChanged="@(val => _selectedValutaId = val)"
                  Label="Valuta Report"
                  Clearable="true" />
    ```

### RuoloSelect
Componente per la selezione del ruolo utente (`Components/Shared/RuoloSelect.razor`).
*   **Funzionalità**:
    *   Carica i ruoli disponibili da `IRoleService`.
    *   Visualizza il nome del ruolo (es. "Administrator", "User").
    *   Supporta validazione con asterisco rosso quando `Required="true"`.
    *   Utilizza `MudAutocomplete` per permettere ricerca e mostrare icona di ricerca + asterisco required.
    *   Non è clearable (un utente deve sempre avere un ruolo).
*   **Parametri Chiave**:
    *   `SelectedRoleCode` (string): Codice ruolo selezionato (binding).
    *   `Label` (string): Etichetta del campo (default: "Ruolo").
    *   `Required` (bool): Campo obbligatorio (mostra asterisco rosso).
    *   `RequiredError` (string): Messaggio di errore personalizzato.
*   **Utilizzo**:
    ```razor
    <RuoloSelect SelectedRoleCode="@User.RoleCode"
                 SelectedRoleCodeChanged="@HandleRoleChanged"
                 Label="Ruolo"
                 Class="mb-3"
                 Required="true"
                 RequiredError="Ruolo obbligatorio" />
    ```
 
### CausaleSelect
Componente autocomplete per la selezione della causale contabile (`Components/Shared/CausaleSelect.razor`).
*   **Funzionalità**:
    *   Carica i tipi causali da `ana_tipi_causali` filtrati per azienda.
    *   Visualizza la descrizione della causale (es. "Fattura passiva", "Nota di Credito").
    *   Supporta ricerca testuale per codice o descrizione.
    *   Validazione integrata con asterisco rosso.
*   **Utilizzo**:
    ```razor
    <CausaleSelect @bind-SelectedCausaleId="@Entity.TransazioneCausaleTipoId"
                   Required="true" />
    ```

### AliquotaIvaSelect
Componente autocomplete per la selezione dell'aliquota IVA (`Components/Shared/AliquotaIvaSelect.razor`).
*   **Implementazione**: Utilizza `BaseEntitySelect<AnaAliquotaIva>` per coerenza con gli altri componenti select.
*   **Funzionalità**:
    *   Carica automaticamente le aliquote IVA attive da `ana_aliquote_iva` filtrate per azienda.
    *   Visualizza codice, percentuale e descrizione nel formato: `22% - IVA Ordinaria 22%`.
    *   Supporta ricerca testuale case-insensitive su codice, descrizione e percentuale.
    *   Supporta validazione con asterisco rosso nella label quando `Required="true"`.
    *   Parametro `AziendaId` esplicito che ha precedenza sul `TenantContext`.
    *   Ricarica automaticamente le aliquote quando cambia `AziendaId`.
*   **Parametri Chiave**:
    *   `SelectedAliquotaId` (int?): ID aliquota IVA selezionata (binding). Usa null per nessuna selezione.
    *   `SelectedAliquotaIdChanged` (EventCallback<int?>): Evento scatenato al cambio selezione.
    *   `Label` (string): Etichetta del campo (default: "Aliquota IVA").
    *   `Required` (bool): Campo obbligatorio (mostra asterisco rosso nella label).
    *   `RequiredError` (string): Messaggio di errore personalizzato (default: "Aliquota obbligatoria").
    *   `Clearable` (bool): Permette di cancellare la selezione con pulsante X (default: true).
    *   `AziendaId` (int?): ID azienda per filtrare le aliquote. Se non specificato, usa `TenantContext`.
*   **Utilizzo**:
    ```razor
    <AliquotaIvaSelect SelectedAliquotaId="Transazione.TransazioneAliquotaIvaFk"
                       SelectedAliquotaIdChanged="@OnAliquotaIvaChanged"
                       AziendaId="@AziendaId"
                       Required="@_causaleRichiedeIva"
                       Label="@(_causaleRichiedeIva ? "Aliquota IVA *" : "Aliquota IVA")"
                       Clearable="!_causaleRichiedeIva" />
    ```

### CicloSelect
Componente select per la selezione del ciclo contabile (Cash Flow) (`Components/Shared/CicloSelect.razor`).
*   **Funzionalità**:
    *   Utilizza `MudSelect` con valori statici predefiniti.
    *   Opzioni disponibili:
        - `ATTIVO` → Entrate (Crediti da Clienti)
        - `PASSIVO` → Uscite (Debiti verso Fornitori)
    *   Campo clearable di default per permettere selezione "Tutti".
*   **Parametri Chiave**:
    *   `Value` (string?): Valore selezionato (binding).
    *   `Label` (string): Etichetta del campo (default: "Tipo Cash Flow").
    *   `Clearable` (bool): Permette cancellazione selezione (default: true).
    *   `Required`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <CicloSelect @bind-Value="_filtroCausaleCiclo" />
    ```

### UrgenzaSelect
Componente select per la selezione dell'urgenza delle scadenze (`Components/Shared/UrgenzaSelect.razor`).
*   **Funzionalità**:
    *   Utilizza `MudSelect` con valori statici predefiniti.
    *   Opzioni disponibili:
        - `SCADUTO` → Scaduto (in ritardo)
        - `URGENTE` → Urgente (entro 7 giorni)
        - `IN_SCADENZA` → In scadenza (entro 30 giorni)
        - `NORMALE` → Normale (oltre 30 giorni)
    *   Campo clearable di default per permettere selezione "Tutti".
*   **Parametri Chiave**:
    *   `Value` (string?): Valore selezionato (binding).
    *   `Label` (string): Etichetta del campo (default: "Urgenza").
    *   `Clearable` (bool): Permette cancellazione selezione (default: true).
    *   `Required`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <UrgenzaSelect @bind-Value="_filtroUrgenza" />
    ```

### RaggruppamentoStampaSelect
Componente select per la selezione del criterio di raggruppamento nelle stampe scadenzario (`Components/Shared/RaggruppamentoStampaSelect.razor`).
*   **Funzionalità**:
    *   Utilizza `MudSelect` con valori statici predefiniti.
    *   Opzioni disponibili:
        - `URGENZA` → Urgenza (Scaduto/Urgente/Normale) - Default
        - `MESE` → Mese di Scadenza
        - `CONTROPARTE` → Controparte
    *   Non è clearable (deve sempre avere un valore selezionato).
*   **Parametri Chiave**:
    *   `Value` (string): Valore selezionato (binding). Default: "URGENZA".
    *   `Label` (string): Etichetta del campo (default: "Raggruppa per").
    *   `Clearable` (bool): Non permette cancellazione (default: false).
    *   `Required`, `Disabled`: Opzioni standard.
*   **Utilizzo**:
    ```razor
    <RaggruppamentoStampaSelect @bind-Value="_raggruppamento" />
    ```

### Elenco Completo Componenti Select

Di seguito l'elenco di tutti i componenti di selezione (Combobox/Autocomplete) disponibili in `Components/Shared`:

| Componente | File | Tabella / Campo | Ordinamento | Scopo |
|---|---|---|---|---|
| **AliquotaIvaSelect** | `AliquotaIvaSelect.razor` | `ana_aliquote_iva` | Ordinamento + Descrizione | Selezione aliquota IVA per transazioni contabili. Supporta parametro `AziendaId` esplicito. Visualizza codice, percentuale e descrizione. |
| **AziendaSelect** | `AziendaSelect.razor` | `ana_aziende` | Ragione Sociale | Selezione azienda per contesto multi-tenant. Include opzione "Tutte". |
| **CausaleSelect** | `CausaleSelect.razor` | `ana_tipi_causali` | Descrizione | Selezione causale contabile con logica di segno algebrico. |
| **CapoluogoSelect** | `CapoluogoSelect.razor` | `ana_geo_comuni` (flag capoluogo) | Descrizione | Selezione città capoluogo di provincia. |
| **CicloSelect** | `CicloSelect.razor` | Valori statici | - | Selezione ciclo contabile (ATTIVO/PASSIVO) per Cash Flow. Utilizzato nei filtri stampe. |
| **ComuneSelect** | `ComuneSelect.razor` | `ana_geo_comuni` | Nome | Ricerca completa comuni italiani ed esteri. |
| **ControparteSelect** | `ControparteSelect.razor` | `ana_controparti` | Ragione Sociale | Selezione controparte (Fornitore/Cliente) con filtro dinamico per ciclo. Supporta parametro `AziendaId` e `CausaleCiclo`. Include opzione "TUTTE LE CONTROPARTI". |
| **CountrySelect** | `CountrySelect.razor` | `eba_countries` | Name (Nome Paese) | Selezione nazione (standard ISO). |
| **CountryIntermediate** | `CountryIntermediateSelect` | `eba_countries_intermediate_regions` | Name | Selezione macro-regione intermedia (ONU). |
| **CountryOrganization** | `CountryOrganizationSelect` | `eba_countries_organizations` | Name | Selezione organizzazione internazionale. |
| **CountryRegion** | `CountryRegionSelect` | `eba_countries_regions` | Name | Selezione regione mondiale (es. Europe, Asia). |
| **CountrySubRegion** | `CountrySubRegionSelect` | `eba_countries_sub_regions` | Name | Selezione sotto-regione (es. Southern Europe). |
| **FormaGiuridica** | `FormaGiuridicaSelect.razor` | `ana_forme_giuridiche` | Descrizione | Selezione forma giuridica azienda (SPA, SRL...). |
| **FornitoreSelect** | `FornitoreSelect.razor` | `ana_fornitori` | Ragione Sociale | Selezione fornitore con ricerca testuale su Ragione Sociale e Nome Breve. Supporta parametro `AziendaId` esplicito. |
| **MarcaVeicolo** | `MarcaVeicoloSelect.razor` | `ana_marche_veicoli` | Descrizione | Selezione marca veicolo (es. Fiat, BMW). |
| **ProvinciaSelect** | `ProvinciaSelect.razor` | `ana_geo_province_ita` | Descrizione | Selezione provincia (sigla visualizzata). supporta filtro estero. |
| **RegioneSelect** | `RegioneSelect.razor` | `ana_geo_regioni_ita` | Descrizione | Selezione regione amministrativa italiana. |
| **RepartoSelect** | `RepartoSelect.razor` | `ana_reparti` | NomeReparto | Assegnazione reparto interno (es. Amministrazione). |
| **RaggruppamentoStampaSelect** | `RaggruppamentoStampaSelect.razor` | Valori statici | - | Selezione criterio di raggruppamento per stampe scadenzario (URGENZA/MESE/CONTROPARTE). Non clearable. |
| **RipGeoSelect** | `RipGeoSelect.razor` | `ana_geo_ripartizioni_geo` | Descrizione | Selezione ripartizione geografica (Nord, Centro, Sud). |
| **RuoloSelect** | `RuoloSelect.razor` | `IRoleService` | RoleName | Selezione ruolo utente (Administrator, User, ecc.). Convertito a MudAutocomplete per supportare asterisco + icona ricerca. |
| **SedeSelect** | `SedeSelect.razor` | `ana_sedi` | Tipologia + Indirizzo | Selezione sede operativa/legale di un'azienda. |
| **TipoMezzo** | `TipoMezzoSelect.razor` | `ana_tipi_mezzo` | Descrizione | Classificazione mezzi (Auto, Moto, Furgone). |
| **TipoSede** | `TipoSedeSelect.razor` | `ana_tipi_sede` | Descrizione | Classificazione sedi (Legale, Operativa, Magazzino). |
| **UrgenzaSelect** | `UrgenzaSelect.razor` | Valori statici | - | Selezione urgenza scadenze (SCADUTO/URGENTE/IN_SCADENZA/NORMALE). Utilizzato nei filtri stampe. |
| **ValutaSelect** | `ValutaSelect.razor` | `ana_valute` | Codice ISO + Descrizione | Selezione valuta per transazioni e preferenze utente. Convertito a MudAutocomplete per supportare asterisco + icona ricerca. |
| **ViaggioSelect** | `ViaggioSelect.razor` | `ana_viaggi` | Descrizione Breve | Selezione viaggio con ricerca su descrizione e nazione. Supporta parametro `AziendaId` e `CustomItems`. |
| **DataViaggioBilancioSelect** | `DataViaggioBilancioSelect.razor` | `ana_date_viaggi` | Data Inizio DESC | **Specializzato per Stampe**: Selezione data viaggio con indicatore ($) presenza movimenti. Avvisa se la data non ha movimenti. |
| **ViaggioMultiSelect** | `ViaggioMultiSelect.razor` | `ana_viaggi` | Descrizione Breve | Selezione multipla viaggi. Supporta "Seleziona Tutti" e filtro azienda. |
| **OrdinamentoStampaSelect** | `OrdinamentoStampaSelect.razor` | - | - | Selezione ordinamento per le stampe contabili: Fornitore, Data Documento, Importo ASC/DESC, Tipo Movimento. |

---

## Componenti Dialog

### SendEmailDialog
Dialog riutilizzabile per l'invio email con Rich Text Editor (`Components/Shared/SendEmailDialog.razor`).
*   **Dual-Mode**: Supporta due modalita operative selezionate automaticamente in base ai parametri:
    *   **Trip Mode** (`DataViaggioId` valorizzato): Carica i destinatari dai partecipanti del viaggio tramite `MovClientiViaggiService`. Mostra conteggio partecipanti con/senza email. Oggetto pre-compilato.
    *   **Direct Mode** (`RecipientEmails` fornito, `DataViaggioId` null): Usa le email passate direttamente, nessuna chiamata DB. Mostra il label del destinatario.
*   **Funzionalita**:
    *   Rich Text Editor (Quill.js via `BlazoredTextEditor`) con toolbar completa (grassetto, corsivo, sottolineato, colori, liste, link).
    *   Validazione: Oggetto obbligatorio, corpo messaggio minimo 3 caratteri, almeno un destinatario.
    *   Template HTML aziendale tramite `CompanyEmailTemplate` (logo, branding, footer).
    *   Invio tramite `EmailSenderFactory` (SMTP aziendale o Resend fallback).
    *   CC automatico all'utente corrente.
*   **Parametri Chiave**:
    *   `AziendaId` (int, richiesto): ID azienda per branding e sender.
    *   `DefaultSubject` (string): Oggetto pre-compilato.
    *   `DataViaggioId` (int?, opzionale): Se valorizzato, attiva Trip Mode.
    *   `TripName` (string?, opzionale): Nome viaggio (per template e oggetto).
    *   `DateRange` (string?, opzionale): Range date viaggio (per template).
    *   `RecipientEmails` (List\<string\>?, opzionale): Email destinatari diretti (Direct Mode).
    *   `RecipientDisplayLabel` (string?, opzionale): Label visualizzato nell'alert (es. "ROSSI Mario (mario@email.com)").
*   **Utilizzo Trip Mode** (da `ViaggioDatesManager`):
    ```razor
    var parameters = new DialogParameters
    {
        ["DataViaggioId"] = date.Id,
        ["AziendaId"] = AziendaId,
        ["TripName"] = tripName,
        ["DateRange"] = dateRange,
        ["DefaultSubject"] = $"{tripName} - {dateRange}"
    };
    await DialogService.ShowAsync<SendEmailDialog>("", parameters, options);
    ```
*   **Utilizzo Direct Mode** (da `Clienti.razor`):
    ```razor
    var parameters = new DialogParameters
    {
        ["AziendaId"] = aziendaId,
        ["DefaultSubject"] = string.Empty,
        ["RecipientEmails"] = new List<string> { client.Email.Trim() },
        ["RecipientDisplayLabel"] = $"{client.Cognome} {client.Nome} ({client.Email})"
    };
    await DialogService.ShowAsync<SendEmailDialog>("", parameters, options);
    ```

### StampaMovimentiDialog
Dialog per la selezione filtri e stampa dei movimenti contabili (`Components/Shared/StampaMovimentiDialog.razor`).
*   **Funzionalità**:
    *   Filtri completi: Azienda, Fornitore, Tipo Movimento, Stato (multiselezione), Viaggio, Data Viaggio, Valuta.
    *   Range Date: Transazione Da/A, Documento Da/A.
    *   Range Importo: Da/A.
    *   Numero Documento (ricerca parziale).
    *   Checkbox: Solo con documento, Solo scadute, Solo con/senza viaggio, Solo con fattura.
    *   Ordinamento tramite `OrdinamentoStampaSelect`.
*   **Controlli Formali**:
    *   Data Da <= Data A (transazione e documento).
    *   Importo Da <= Importo A.
    *   Viaggio obbligatorio se Data Viaggio selezionata.
    *   Checkbox "con viaggio" / "senza viaggio" mutuamente esclusive.
*   **Database**: Utilizza la function `fn_get_transazioni_per_stampa` per il filtraggio lato server.
*   **Utilizzo**: Accessibile da NavMenu → Stampe Contabili → Elenco Movimenti Contabili.

### StampaScadenzarioDialog
Dialog per la selezione filtri e stampa dello scadenzario (`Components/Shared/StampaScadenzarioDialog.razor`).
*   **Funzionalità**:
    *   Filtri disponibili:
        - Azienda (solo per SuperAdmin) tramite `AziendaSelect`
        - Tipo Cash Flow tramite `CicloSelect` (ATTIVO/PASSIVO)
        - Controparte tramite `ControparteSelect` (con filtro dinamico per ciclo)
        - Urgenza tramite `UrgenzaSelect` (SCADUTO/URGENTE/IN_SCADENZA/NORMALE)
        - Range Date Scadenza (Da/A)
        - Viaggio tramite `ViaggioSelect`
        - Checkbox: Solo con viaggio, Solo senza viaggio (mutuamente esclusive)
    *   Raggruppamento tramite `RaggruppamentoStampaSelect` (URGENZA/MESE/CONTROPARTE)
*   **Controlli Formali**:
    *   Data Scadenza Da <= Data Scadenza A
    *   Checkbox "con viaggio" / "senza viaggio" mutuamente esclusive
*   **Database**: Utilizza la function `fn_get_scadenzario_stampa` per il filtraggio lato server.
*   **Utilizzo**: Accessibile da NavMenu → Stampe Contabili → Scadenzario.

### SelezioneBancaDialog
Dialog per la selezione del conto bancario da stampare sulla fattura attiva (`Components/Shared/SelezioneBancaDialog.razor`).
*   **Funzionalità**:
    *   Carica i conti bancari dell'azienda tramite `AziendaBancaService.GetByAziendaIdAsync()`.
    *   Visualizza `MudDataGrid` con colonne: Stella (predefinito), Nome Banca, Filiale, IBAN.
    *   Pre-seleziona automaticamente la banca con `IsPredefinito = true`.
    *   La riga della banca predefinita è evidenziata con sfondo giallo chiaro (`#FFF8E1`) e icona stella.
    *   Gestisce stati di caricamento (`MudProgressLinear`) e assenza dati (`MudAlert`).
*   **Parametri Chiave**:
    *   `AziendaId` (int): ID azienda per caricare i conti bancari.
*   **Valore Restituito**: `AziendaBanca` selezionata (tramite `DialogResult.Ok()`), oppure `Canceled` se l'utente annulla.
*   **Utilizzo**:
    ```razor
    var parameters = new DialogParameters { ["AziendaId"] = _aziendaIdEffettivo };
    var options = new DialogOptions { CloseOnEscapeKey = true, MaxWidth = MaxWidth.Medium, FullWidth = true };
    var dialog = await DialogService.ShowAsync<SelezioneBancaDialog>("Seleziona Conto Bancario", parameters, options);
    var result = await dialog.Result;
    if (result != null && !result.Canceled && result.Data is AziendaBanca selectedBanca)
    {
        // Usa selectedBanca
    }
    ```
*   **Contesto**: Utilizzato da `StampaFattureAttivePage` e `MovTransazioniPage` quando l'azienda ha più di un conto bancario. Se l'azienda ha un solo conto, viene usato automaticamente senza mostrare il dialog.

---

### WebTourContenutiTab
Scheda "Contenuti Web" del viaggio — estensione web, Blocco 5 (`Components/Shared/WebTourContenutiTab.razor`).
*   **Funzionalità**:
    *   Carica/crea i contenuti editoriali web del tour (1:1 con `ana_viaggi`) via `WebTourContenutiService` (funzioni `fn_web_tour_contenuti_*`).
    *   Campi editoriali: sottotitolo, difficoltà (select `turistica/media/medio_alta/alta`), durata testo, luoghi visitati.
    *   5 editor RichText (`Blazored.TextEditor`/Quill): descrizione + pernottamento/pasti/equipaggiamento/altre info. L'HTML esistente è caricato con `LoadHTMLContent` (retry perché Quill si inizializza async); l'HTML "vuoto" di Quill (`<p><br></p>`) è normalizzato a NULL.
    *   SEO: slug (obbligatorio, con generazione dal titolo via adornment e slugify accent-safe), meta title, meta description (counter 320).
    *   Pubblicazione: stato (`bozza/pubblicato/archiviato`), ordine, prima pubblicazione (readonly, valorizzata al primo passaggio a `pubblicato`).
    *   Salvataggio autonomo nel tab ("Salva Contenuti Web"): create se nuovo, update altrimenti; violazione slug univoco → messaggio tradotto da `DbErrorTranslator` via snackbar.
*   **⚠️ ECCEZIONE UI (documentata)**: i campi editoriali/RichText NON usano il maiuscolo forzato — sono destinati alle pagine del sito pubblico (overview.md §3.3).
*   **UI rules rispettate**: `AutoFocus` sul primo campo (sottotitolo), `dialogFormHelper.setupTabNavigation` in `OnAfterRenderAsync`, `BackdropClick=false` (impostato dal chiamante di `AnaViaggiDialog`).
*   **Parametri Chiave**:
    *   `ViaggioId` (int, required): viaggio a cui appartengono i contenuti.
    *   `AziendaId` (int, required): scoping multi-tenant.
    *   `DescrizioneBreve` (string?): titolo del viaggio, usato per suggerire lo slug.
*   **Contesto**: montato come terzo `MudTabPanel` ("Contenuti Web") in `AnaViaggiDialog`, **solo in edit mode** (la FK 1:1 richiede un viaggio già salvato).

### WebTourItinerarioTab
Scheda "Itinerario" del viaggio — estensione web, Blocco 6 (`Components/Shared/WebTourItinerarioTab.razor` + `.razor.css`).
*   **Struttura a due livelli**: Giornate (`web_tour_itinerario`) → Passi (`web_tour_itinerario_passaggi`), gestiti via `WebTourItinerarioService` / `WebTourItinerarioPassaggiService`.
*   **Pattern "Sidebar + Main Board"**: due `MudDropContainer` **paralleli** (non annidati). Sinistra (`xs=3`) = sommario giornate riordinabili in DnD (1 sola zona `sidebar`, `AllowReorder`). Destra (`xs=9`) = una `MudDropZone` **per giornata** (Identifier = id giornata), generate da `@foreach ... OrderBy(Ordine)`: i passi si trascinano dentro e **tra** le giornate. I due container sono isolati → nessun conflitto di puntatore su WebView; il riordino giornate è implicito (aggiorna `Ordine`, la board ridisegna le zone).
*   **Live-save**: ogni add/modifica/elimina/riordino persiste subito. Il **riordino è atomico** via `fn_web_tour_itinerario_reorder` / `fn_web_tour_itinerario_passaggi_reorder` (`ReorderAsync`, un array di id ordinati → `UNNEST WITH ORDINALITY`). Su errore si ricarica dal DB.
*   **Passo**: card leggera (snippet del testo + didascalia). La modifica del contenuto (Quill + didascalia) avviene in `WebTourPassoEditDialog` on-demand (niente Quill inline nella card → board a 60fps, no guerra eventi puntatore). **Immagine rinviata al Blocco 7**: qui solo `immagine_didascalia`.
*   **DropZone vuota**: `min-height` nel `.razor.css` scoped (`::deep .drop-zone-passo`) — una giornata senza passi collasserebbe a 0px e non sarebbe un bersaglio di drop.
*   **⚠️ ECCEZIONE UI (documentata)**: titoli/testi editoriali NON in maiuscolo forzato (destinati al sito).
*   **UI rules rispettate**: `dialogFormHelper.setupTabNavigation` in `OnAfterRenderAsync` (fa anche il focus primo campo), `BackdropClick=false` (dal chiamante).
*   **Parametri Chiave**: `ViaggioId` (int, required), `AziendaId` (int, required).
*   **Contesto**: montato come quarto `MudTabPanel` ("Itinerario") in `AnaViaggiDialog`, **solo in edit mode**.

### WebTourPassoEditDialog
Dialog di modifica di un passo dell'itinerario — Blocco 6 (`Components/Shared/WebTourPassoEditDialog.razor`).
*   Editor RichText Quill (`Blazored.TextEditor`) per `testo_html` (caricato con `LoadHTMLContent` + retry; vuoto Quill `<p><br></p>` normalizzato a NULL) + campo `immagine_didascalia`.
*   **Picker immagine (Blocco 7)**: strip di thumbnail della galleria del viaggio (`ListByViaggioAsync`); la selezione valorizza `immagine_storage_path` + `immagine_url`. Opzione "Nessuna".
*   Ritorna il passo modificato (`DialogResult.Ok`) al `WebTourItinerarioTab`, che persiste via create/update (pattern CRUD: il dialog non salva).
*   **Parametri**: `Passo` (required), `ViaggioId`/`AziendaId` (per caricare la galleria) — i valori sono applicati solo al Salva.

### WebTourGalleriaTab
Scheda "Galleria" del viaggio — estensione web, Blocco 7 (`Components/Shared/WebTourGalleriaTab.razor` + `.razor.css`).
*   **Upload multiplo** (`MudFileUpload`, accept image/*): per file → `WebImageProcessor.ToOptimizedWebpAsync` (WebP ≤2000px, q80, cattura larghezza/altezza) → `IWebMediaStorage.UploadAsync` (Supabase Storage) → `WebTourImmaginiService.CreateAsync` (url = `BuildPublicUrl`, `storage_path` = verità).
*   **Griglia con DnD reorder** (`MudDropContainer` 1 zona, `AllowReorder`) → `ReorderAsync` atomico. Per immagine: **copertina** (`SetPrincipaleAsync`, badge sulla `principale`), modifica alt/titolo (`WebTourImmagineEditDialog`), elimina (record + `IWebMediaStorage.DeleteAsync`; orfano storage tollerato).
*   **Live-save**; MUST UI: `setupTabNavigation`, niente uppercase su alt/titolo (web), `BackdropClick=false` dal chiamante.
*   **Parametri**: `ViaggioId`/`AziendaId` (required). Montato come **5° `MudTabPanel`** ("Galleria") in `AnaViaggiDialog`, solo edit mode.
*   **Sicurezza**: la `ServiceKey` (service-role) è usata contro il bucket di TEST; hardening produzione (chiave scoped / upload server-side) = **debito documentato** per il go-live.

### WebTourImmagineEditDialog
Dialog di modifica alt/titolo di un'immagine di galleria — Blocco 7 (`Components/Shared/WebTourImmagineEditDialog.razor`).
*   Campi `titolo` + `alt_text` (no uppercase, web). Ritorna l'immagine modificata; il `WebTourGalleriaTab` persiste via `UpdateAsync`. In dialog per non mettere campi editabili in una card trascinabile (conflitto col DnD).

### WebTipiViaggioDescrizioniPage + WebTipoViaggioDescrizioneDialog (Blocco 8)
Gestione delle **descrizioni web dei tipi di viaggio** (lookup GLOBALE `web_tipi_viaggio_descrizioni`, ex categoria sport).
*   **Pagina** `Components/Pages/WebTipiViaggioDescrizioniPage.razor` (`/tabelle/descrizioni-web`, menu "Descrizioni Web (sito)"): CRUD via `EnterpriseDataGrid` su `WebTipiViaggioDescrizioniService` (globale, `ListAsync`/Create/Update/Delete). Colonne descrizione/slug/ordine.
*   **Dialog** `Components/Shared/WebTipoViaggioDescrizioneDialog.razor`: campi `descrizione_web`/`slug`/`ordine` — **niente uppercase** (è web); setupTabNavigation + focus primo campo.
*   **Mapping**: `TipoViaggioDialog` (esistente) ha un `MudSelect` "Descrizione web (sito)" che valorizza `TipoViaggio.DescrizioneWebFk` (persistito da `TipoViaggioService.UpdateAsync`); `TipoViaggioPage` mostra la descrizione mappata in colonna. Più tipi possono condividere la stessa descrizione (N:1). Esposta al sito da `fn_web_tour_pubblicati`.

### WebTourMappaTab + pipeline GPX→mappa (Blocco 9)
Scheda "Mappa" del viaggio: genera una **mappa statica** dal GPX, tutto lato gestionale (la traccia non raggiunge mai il browser).
*   **Componente** `Components/Shared/WebTourMappaTab.razor` (6° `MudTabPanel` in `AnaViaggiDialog`, solo edit): upload `.gpx` (`MudFileUpload`) → "Genera mappa" → anteprima immagine + rigenera/elimina. Attribuzione © OpenStreetMap contributors.
*   **Pipeline** `Services/Web/WebTourMappaGeneratorService.cs`: `GpxParser` (parse `<trkpt>`) → `DouglasPeucker` (decimazione a mano, iterativa, cap punti per limite URL) → `GeoapifyStaticMapClient.ComputeBbox` + `FetchAsync` (Geoapify Static Maps, HTTP REST, formato validato: `area=rect`/`geometry=polyline` in lon,lat, colori %23) → JPEG → `WebImageProcessor` WebP → `IWebMediaStorage` (`{azienda}/{viaggio}/mappa.webp`, bucket `tour-media`) → upsert 1:1 su `web_tour_mappa` (gpx_originale, bbox, provider/stile, parametri_render jsonb, immagine_*).
*   **Config**: sezione `Geoapify` in appsettings (`GeoapifyOptions`: ApiKey, Style, colori, MaxPolylinePoints). Chiave **non cifrata** (free, rigenerabile dal cliente). Registrazione: `AddHttpClient<GeoapifyStaticMapClient>` + generator Scoped.
*   **Parametri tab**: `ViaggioId`/`AziendaId` (required). Se la chiave non è configurata (`Generator.IsConfigured=false`) la generazione è disabilitata con avviso.

### WebTraduzioniTab + pipeline traduzioni Claude (Blocco 10)
Scheda "Traduzioni" del viaggio: traduce i campi editoriali in EN/DE/FR/ES via Claude API.
*   **Componente** `Components/Shared/WebTraduzioniTab.razor` (7° `MudTabPanel` in `AnaViaggiDialog`, solo edit): campo per la **chiave Claude per-azienda**, pulsante **"Traduci tutto"**, tabella stato per lingua (mancante / da revisionare / obsoleto / ok) e **revisione** via `WebTraduzioneReviewDialog` (edit testo + toggle `revisionato`).
*   **Orchestratore** `Services/Web/WebTraduzioneOrchestratorService.cs`: get/set chiave (`ana_aziende.claude_api_key` via `fn_ana_aziende_*_claude_key`); raccoglie i campi IT del viaggio (`web_tour_contenuti` + passi `web_tour_itinerario_passaggi`); per (campo × lingua) chiama `ClaudeTranslationClient` → upsert `web_traduzioni` (`fn_web_traduzioni_upsert`). Lingue: `WebTraduzioneOrchestratorService.Lingue` = EN/DE/FR/ES.
*   **Client** `Services/Shared/Ai/ClaudeTranslationClient.cs` (HTTP REST, Anthropic Messages, no SDK; Haiku 4.5 via `ClaudeOptions`): prompt che preserva l'HTML e non traduce i nomi propri. Chiave passata per-chiamata (per-azienda).
*   **Obsolescenza**: al salvataggio IT (Contenuti/Itinerario) i campi cambiati → `fn_web_traduzioni_marca_obsolete` (`WebTraduzioniService.MarkObsoleteAsync`). `fn_web_tour_pubblicati` serve solo le traduzioni non-obsolete.
*   **Sicurezza**: chiave Claude in chiaro su `ana_aziende` → nel debito "cifrare pre-rilascio" con SMTP/ESP.
*   **Parametri tab**: `ViaggioId`/`AziendaId` (required).
*   **Chiave azienda nel form Aziende**: sotto-tab `Components/Shared/AziendaTabs/AziendaTabTraduzioni.razor` (get/set `claude_api_key` via l'orchestratore, nessun plumbing sull'entity Azienda). Montato in `AziendaDialog`.
*   **Descrizione tipo (globale)**: `WebTipoDescrizioneTraduzioniDialog.razor` aperto da un'azione "Traduzioni" per riga in `WebTipiViaggioDescrizioniPage` — traduce `descrizione_web` nelle 4 lingue (azienda corrente via `ITenantContext`). Obsolescenza via `fn_web_traduzioni_marca_obsolete_global` (entità globale). Riusa `WebTraduzioneReviewDialog`.

---

## Componenti Export

### ExcelExportButton
Componente bottone riutilizzabile per l'export Excel (`Components/Shared/ExcelExportButton.razor`).
*   **Funzionalità**:
    *   Bottone con icona download e stile `Variant.Outlined` colore `Color.Success`.
    *   Mostra spinner di caricamento durante l'esportazione (stato `_isExporting`).
    *   Impedisce doppio click durante l'esportazione.
    *   Tooltip configurabile.
*   **Parametri Chiave**:
    *   `OnExport` (EventCallback): Callback asincrono per eseguire l'esportazione.
    *   `Disabled` (bool): Disabilita il bottone (es. quando non ci sono dati).
    *   `Label` (string): Testo del bottone (default: "Esporta Excel").
    *   `Tooltip` (string): Testo tooltip (default: "Esporta i dati in formato Excel (.xlsx)").
*   **Utilizzo**:
    ```razor
    <ExcelExportButton OnExport="@ExportToExcel" Disabled="@(!_items.Any())" />
    ```
*   **Pattern Completo di Export** (esempio pagina Clienti):
    ```csharp
    @inject IClienteExportService ClienteExportService
    @inject IExcelExportService ExcelExportService
    @inject IFileOpenerService FileOpenerService

    private async Task ExportToExcel()
    {
        var data = await ClienteExportService.GetClientiExportAsync(aziendaId);
        var columns = ClienteExportService.GetColumnDefinitions();
        var fileName = $"Anagrafica_Clienti_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx";
        var outputPath = await ExcelExportService.ExportToExcelAsync(data, columns, fileName, "Clienti");
        await FileOpenerService.OpenFileAsync(outputPath, "Export Completato");
    }
    ```

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

### `get_count_travel_future`
Conta i viaggi futuri (in programma) per un cliente.
**Parametri**: `p_cliente_id` (INT), `p_azienda_id` (INT)
**Return**: `INTEGER`

### `get_client_travel_history`
Restituisce lo storico completo dei viaggi di un cliente, ordinato per data decrescente.
**Parametri**: `p_cliente_id` (INT), `p_azienda_id` (INT)
**Return**: `TABLE`
- `data_viaggio_id`: ID univoco viaggio.
- `titolo`: Titolo del viaggio.
- `tipo`: Tipo del viaggio (es. 4x4, Crociera).
- `status_code`: 0=Futuro (Giallo), 1=Fatto (Verde), 2=Non Partecipato (Rosso).
- `status_desc`: Descrizione testuale stato.
- `ruolo`: Ruolo del cliente nel viaggio.
- `km`, `giorni`, `notti`: Statistiche viaggio.

### `get_travel_passengers`
Restituisce la lista dei compagni di viaggio per un dato viaggio, escluso il cliente richiedente.
**Parametri**: `p_data_viaggio_id` (INT), `p_exclude_client_id` (INT)
**Return**: `TABLE`
- `nominativo`: Nome e Cognome del passeggero.
- `ruolo`: Ruolo del passeggero.
*   **File Script**: `SqlScripts/26_Create_GetCountTravelFuture.sql`
*   **Parametri Input**:
    *   `p_cliente_id` (integer): ID del cliente.
    *   `p_azienda_id` (integer): ID dell'azienda.
*   **Valore Restituito**: `integer` (Numero di viaggi futuri).
*   **Logica**:
    *   Filtra per `cliente_id` e `azienda_id`.
    *   Richiede `data_viaggio_effettuato_sino = 'N'`.
    *   Richiede `data_viaggio_data_inizio > CURRENT_DATE` (viaggi che iniziano dopo oggi).

### `get_all_travel_detail`
Restituisce **TUTTI** i dettagli di un singolo viaggio (Data Viaggio) incrociando `ana_date_viaggi`, `ana_viaggi` e tutti i lookup (nazione, trattamento, pernottamento).
**Parametri**: `p_data_viaggio_id` (INT)
**Return**: `TABLE` con campi piatti (es. `titolo`, `descrizione_estesa`, `trattamento`, `costo_pilota`, ecc.).
*   **File Script**: `SqlScripts/30_Create_GetAllTravelDetail.sql`

### `get_all_participants_travel`
Restituisce la lista completa dei partecipanti ad un viaggio (Data Viaggio), ordinata alfabeticamente per Cognome e Nome.
**Parametri**: `p_data_viaggio_id` (INT)
**Return**: `TABLE`
- `nominativo`: Cognome e Nome del partecipante. I piloti sono identificati dal flag `tipo_partecipante_pilota` e hanno suffisso `(P)`.
*   **File Script**: `SqlScripts/29_Create_GetAllParticipantsTravel.sql`

### `get_cliente_detail`
Restituisce **TUTTE** le informazioni anagrafiche e documentali di un cliente, incluse le decodifiche (join) per comuni e province di nascita e residenza.
**Parametri**: `p_cliente_id` (INT) - (L'Azienda non è necessaria in quanto l'ID cliente è univoco).
**Return**: `TABLE` con tutti i campi di `ana_clienti` + `azienda_ragione_sociale`, `comune_nascita_nome`, `comune_nascita_provincia`, `comune_residenza_nome`, `comune_residenza_provincia`.
*   **File Script**: `SqlScripts/31_Create_GetClienteDetail.sql`

### `get_exist_travel_customer_by_Year`
Restituisce la lista degli anni (in formato intero, ordinati decrescenti) in cui un cliente ha effettuato viaggi registrati a sistema. Utilizzata per popolare il filtro "Anno" nelle statistiche.
**Parametri**: `p_cliente_id` (INT)
**Return**: `TABLE`
- `anno`: Anno del viaggio (INTEGER).
*   **File Script**: `SqlScripts/32_Create_GetExistTravelCustomerByYear.sql`

---

## Servizi Shared (Backend Logic)

### IWebMediaStorage / SupabaseMediaStorage (Blocco 7)
Storage media web su Supabase Storage via HTTP REST, no SDK (`Services/Shared/Storage/`).
*   **`IWebMediaStorage`**: `UploadAsync(storagePath, stream, contentType)` → ritorna `storage_path`; `BuildPublicUrl(storagePath)`; `DeleteAsync(storagePath)`.
*   **`SupabaseMediaStorage`**: `PUT/DELETE {apiRoot}/{bucket}/{path}` con `Authorization: Bearer {ServiceKey}` (`apiRoot` = BaseUrl senza `/public`); `x-upsert:true`. `storage_path` = verità, URL ricomposto dal `BaseUrl` d'ambiente. Registrato con `AddHttpClient<IWebMediaStorage, SupabaseMediaStorage>()`.
*   **`WebMediaStorageOptions`**: `BaseUrl`/`Bucket`/`ServiceKey` (sezione `WebMediaStorage` in appsettings).
*   ⚠️ **Sicurezza**: `ServiceKey` service-role usata contro il bucket di TEST; in produzione non deve restare nel binario MAUI → chiave scoped o upload server-side (debito go-live).

### WebImageProcessor (Blocco 7)
Ottimizzazione immagini web (`Services/Shared/Storage/WebImageProcessor.cs`, ImageSharp).
*   Statico: `ToOptimizedWebpAsync(stream)` → downscale lato lungo a ≤2000px (mai upscale) + WebP q80; ritorna `ProcessedImage(Bytes, Width, Height, Mime)`. Alias `using` per risolvere i clash `Image/Size/ResizeMode` coi global using MAUI.

### CompanyEmailTemplate
Template HTML generico per email aziendali (`Services/Email/CompanyEmailTemplate.cs`).
*   **Classe statica** con metodo `GetHtmlBody(...)`.
*   **Design**: Layout responsive 600px con branding aziendale (logo, nome azienda in serif blu, separatore, data/ora invio, contenuto utente, footer con contatti).
*   **Sezioni opzionali**: Nome viaggio e range date sono renderizzati solo se forniti (parametri nullable `tripName`, `dateRange`). Questo permette l'uso sia per email legate ai viaggi che per comunicazioni generiche.
*   **Parametri**: `logoBase64`, `logoMimeType`, `companyName`, `tripName?`, `dateRange?`, `userHtmlContent`, `sendDateTime`, `companyWebsite?`, `companyPhone?`.
*   **Nota**: Sostituisce il precedente `ParticipantsEmailTemplate` (rinominato per riflettere l'uso generico).

### ExchangeRateService
Servizio per l'aggiornamento automatico dei tassi di cambio.
*   **Interfaccia**: `IExchangeRateService`
*   **Implementazione**: `Services/Shared/ExchangeRateService.cs`
*   **Fonte Dati**: API Pubblica Frankfurter (`https://api.frankfurter.app`) basata su dati BCE.
*   **Funzionalità**:
    *   `CheckInternetConnectionAsync()`: Verifica la connettività internet (ping su endpoint API).
    *   `UpdateAllRatesAsync()`: Aggiorna i tassi di cambio per tutte le valute attive nel sistema rispetto all'EUR (Data odierna).
    *   `UpdateRateAsync(string isoCode)`: Aggiorna il tasso di cambio per una specifica valuta (es. "USD").
*   **Dipendenze**: `HttpClient`, `AnaValuteService`, `AnaTassiCambioService`.


### FileOpenerService
Servizio generico per aprire qualsiasi tipo di file dopo la generazione (`Services/Shared/FileOpenerService.cs`).
*   **Interfaccia**: `IFileOpenerService`
*   **Metodo**: `Task<bool> OpenFileAsync(string filePath, string title = "File Generato")`
*   **Funzionalità**:
    *   Mostra un `DialogService.ShowMessageBox` per chiedere conferma apertura.
    *   Gestisce l'apertura cross-platform:
        *   **MacCatalyst**: Usa `System.Diagnostics.Process.Start("open", ...)`.
        *   **Altro**: Usa `Launcher.Default.OpenAsync`.
    *   **Gestione errore**: Se l'app non riesce ad aprire il file, mostra un messaggio italiano informando che il file è comunque disponibile nella cartella Downloads.
*   **Relazione con PdfOpenerService**: `PdfOpenerService` ora delega internamente a `FileOpenerService`, mantenendo retrocompatibilità con tutti i chiamanti esistenti.
*   **Utilizzo**:
    ```csharp
    await FileOpenerService.OpenFileAsync(outputPath, "Export Completato");
    ```

### ExcelExportService
Servizio generico per la generazione di file Excel .xlsx (`Services/Export/ExcelExportService.cs`).
*   **Interfaccia**: `IExcelExportService`
*   **Libreria**: ClosedXML (MIT license)
*   **Metodo**: `Task<string> ExportToExcelAsync<T>(IEnumerable<T> data, List<ExcelColumnDefinition<T>> columns, string fileName, string sheetName = "Dati")`
*   **Funzionalità**:
    *   Accetta qualsiasi tipo T con configurazione colonne flessibile.
    *   Genera file .xlsx nella cartella Downloads (`UserProfile/Downloads`).
    *   Header riga con sfondo blu e testo bianco bold.
    *   Auto-fit colonne, auto-filter sulla riga header.
    *   Supporto formattazione date (`dd/MM/yyyy`) e numeri.
    *   Restituisce il path completo del file generato.
*   **ExcelColumnDefinition<T>**:
    *   `Header` (string): Titolo colonna.
    *   `ValueSelector` (Func<T, object?>): Funzione per estrarre il valore dalla riga.
    *   `NumberFormat` (string?): Formato numerico/data opzionale.
*   **Utilizzo**:
    ```csharp
    var columns = new List<ExcelColumnDefinition<MyDTO>>
    {
        new() { Header = "Nome", ValueSelector = x => x.Nome },
        new() { Header = "Data", ValueSelector = x => x.Data, NumberFormat = "dd/MM/yyyy" }
    };
    var path = await ExcelExportService.ExportToExcelAsync(data, columns, "Export.xlsx");
    ```

---

## Gestione Stampe

### ReportHeaderHelper

`ReportHeaderHelper` è una classe statica che centralizza la logica per la generazione di header e footer nei report PDF (QuestPDF). Assicura coerenza grafica e riduce la duplicazione del codice.

#### Metodi Principali

*   **ComposeCompanyHeader**: Genera l'intestazione standard con:
    *   Logo aziendale (se presente) o Ragione Sociale (testo).
    *   Dettagli azienda (indirizzo, P.IVA, telefono, email).
    *   Titolo del report (es. "BILANCIO DI VIAGGIO").
    *   Data di stampa e utente (opzionali).
    
    ```csharp
    ReportHeaderHelper.ComposeCompanyHeader(
        container, 
        companyData,     // DTO con dati azienda e logo
        "TITOLO REPORT", 
        DateTime.Now,    // Data stampa
        currentUser      // Utente
    );
    ```

*   **ComposeFooter**: Genera il piè di pagina standard con:
    *   Copyright e nome applicazione.
    *   Numerazione pagine (Pagina X di Y).

    ```csharp
    page.Footer().Element(ReportHeaderHelper.ComposeFooter);
    ```

#### Stili Condivisi

*   **BrandColors**: Definisce i colori principali da usare nei report (Primary, Secondary, Background).
*   **GridHeaderStyle**: Stile standard per le intestazioni delle tabelle.

### PdfOpenerService

`PdfOpenerService` centralizza la logica per richiedere all'utente di aprire un file PDF generato (in `Downloads`) e, in caso affermativo, lanciare il viewer di sistema.

*   **Interfaccia**: `IPdfOpenerService`
*   **Metodo**: `Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata")`
*   **Funzionalità**:
    *   Mostra un `DialogService.ShowMessageBox` per chiedere conferma.
    *   Gestisce l'apertura cross-platform:
        *   **MacCatalyst**: Usa `System.Diagnostics.Process.Start("open", ...)` per bypassare limitazioni di `Launcher`.
        *   **Altro**: Usa `Launcher.Default.OpenAsync`.
*   **Utilizzo**:
    ```csharp
    await PdfOpenerService.OpenPdfAsync(outputPath);
    ```
