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
*   **Utilizzo**:
    ```razor
    <ValutaSelect SelectedValutaId="@(User.ValutaDefaultId ?? 0)"
                  SelectedValutaIdChanged="@HandleValutaChanged"
                  Label="Valuta di Default"
                  Required="true"
                  RequiredError="Valuta di default obbligatoria"
                  Clearable="false"
                  Class="mb-3" />
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
| **ViaggioMultiSelect** | `ViaggioMultiSelect.razor` | `ana_viaggi` | Descrizione Breve | Selezione multipla viaggi. Supporta "Seleziona Tutti" e filtro azienda. |
| **OrdinamentoStampaSelect** | `OrdinamentoStampaSelect.razor` | - | - | Selezione ordinamento per le stampe contabili: Fornitore, Data Documento, Importo ASC/DESC, Tipo Movimento. |

---

## Componenti Dialog

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
