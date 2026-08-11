# Architettura UI e Componenti Shared

## Libreria Componenti (Shared)
È stata avviata la creazione di una libreria di componenti personalizzati per garantire riutilizzabilità e coerenza grafica.

### StatoPartenzaChip
Stato di una partenza (`Components/Shared/StatoPartenzaChip.razor`), come chip o sola icona, con tooltip esplicativo.
*   **Non è un semplice "sì/no"**: incrocia il flag *Viaggio Effettuato* (`ana_date_viaggi.data_viaggio_effettuato_sino`) con la **data di fine**, perché le due informazioni possono contraddirsi ed è la contraddizione che l'operatore deve vedere. Quattro casi: conclusa e registrata · **conclusa ma non registrata** (anomalia) · in programma (normale) · **spuntata ma non ancora conclusa** (anomalia).
*   **Parametri**: `Effettuato` (required), `DataFine`, `Size`, `SoloIcona` (colonne strette: resta l'icona, il significato non si perde perché il tooltip è lo stesso).
*   **Regole e testi** stanno in `Models/Web/StatoPartenza.cs` (`StatoPartenzaRules`): il componente fa solo la resa grafica, così la stessa lettura vale ovunque. Lì c'è anche `MotivoNonPubblicabile`, che decide se un'edizione è pubblicabile sul sito.
*   **Usato da**: `ViaggioDatesManager` (colonna EFFETT.) e `WebEdizioniManager` (selettore edizione). Dettagli nella sezione contenuti web.

### StatoContenutoWebIcon
Stato della **scheda web** di una partenza (`Components/Shared/StatoContenutoWebIcon.razor`), come icona colorata con tooltip.
*   **Quattro stati**: *senza scheda* (grigio, `PublicOff`) · *bozza* (giallo, `Public`) · *pubblicata* (verde, `Public`) · *archiviata* (grigio, `Inventory2`). Archiviata e bozza hanno colore simile perché **per il sito sono la stessa cosa**: la differenza è solo editoriale, e il tooltip lo dice.
*   **Quando non c'è scheda l'icona diventa un pulsante** e apre `WebCreaContenutoDialog`. È la scorciatoia che rende visibile il clone: prima esisteva solo dentro il selettore edizione dei contenuti web e lo si scopriva per caso, capitando su un'edizione vuota.
*   **Parametri**: `StatoPubblicazione` (null = nessuna scheda), `Clonabile` (cambia il solo tooltip del caso "senza scheda"), `OnClick` (se valorizzato l'icona è cliccabile), `Disabled`, `Size`.
*   **Regole e testi** stanno in `Models/Web/StatoContenutoWeb.cs` (`ContenutoWebRules`), come per `StatoPartenzaChip`: il componente fa solo la resa grafica. Uno stato non previsto non viene nascosto, viene segnalato.
*   **Usato da**: `ViaggioDatesManager` (colonna AZIONI) e — indirettamente, tramite le stesse regole — dal selettore edizione dei contenuti web.

### WebCreaContenutoDialog
Creazione della scheda web di una partenza (`Components/Shared/WebCreaContenutoDialog.razor`): **da zero** oppure **clonando** da un'altra partenza dello stesso viaggio.
*   **Unico proprietario dell'operazione**. Richiamato da due punti di ingresso — la griglia delle date e la scheda Contenuti Web — perché la logica del clone non è banale e duplicarla vorrebbe dire mantenerne due copie divergenti.
*   **Contiene il controllo sulle durate diverse**: confronta le giornate di itinerario dell'origine con la durata della partenza di destinazione e, se non coincidono, chiede se rinunciare o clonare solo le prime N giornate (vedi `SqlScripts/505`).
*   **Default ragionato**: se esiste almeno una sorgente, parte già su "Clona" — su uno stesso viaggio è quasi sempre ciò che si vuole, cambiano solo le date — e preseleziona l'unica sorgente quando è una sola. Resta una scelta esplicita, non un automatismo.
*   **Parametri**: `ViaggioId`, `AziendaId`, `Destinazione` (l'`EdizioneViaggio` su cui creare), `Sorgenti` (edizioni con scheda), `DescrizioneBreve` (per costruire lo slug della scheda nuova). Chiude con `DialogResult.Ok(long)` = id della scheda creata.
*   **Avvisa** che foto e mappe della copia restano **gli stessi file** dell'originale: eliminandoli dalla partenza di origine spariscono anche dalla copia.

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

### ⚠️ Titolo che dipende da dati caricati in async
`<TitleContent>` viene reso **una volta** dal contenitore del dialogo e non si rilegge quando il componente carica i dati: un titolo valorizzato dopo un `await` non arriva mai a schermo (in `ViaggioPartecipantiManagerDialog` restava "Caricamento..." con l'elenco già visibile). Per questi casi si usa **`IMudDialogInstance.SetTitleAsync(...)`**, l'API prevista da MudBlazor proprio per i titoli che dipendono da un valore interno al dialogo. ⚠️ La sua documentazione avverte: *"Has no effect when TitleContent is set"* — quindi il blocco `<TitleContent>` va **rimosso**, non affiancato. Titoli assegnati da un parametro **prima** del primo `await`, o proprietà calcolate su dati già disponibili al primo render, non hanno il problema: `MovTransazioniEditDialog` e `ViaggioAlloggiAdvancedDialog` restano com'erano.

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

### FieldHelp
Icona "?" di aiuto contestuale riutilizzabile accanto a un campo form — Blocco 5 Task 1 (`Components/Shared/FieldHelp.razor`).
*   **Funzionalità**: `MudMenu` con `MudIconButton` (`HelpOutline`, `Size.Small`, `Color.Info`) come activator; il click apre un `MudPaper` con `Title` (subtitle2) + `Text` (body2) o, in alternativa, `ChildContent` per contenuti formattati (es. esempi). Apertura/chiusura gestite da `MudMenu` (click fuori chiude automaticamente).
*   **Parametri**: `Title` (string, required), `Text` (string?), `ChildContent` (RenderFragment?), `MaxWidthPx` (int, default `320`) — si allarga solo per gli aiuti articolati, che a 320px diventerebbero una colonna troppo alta (es. lo **stato di pubblicazione**, che usa `440`).
*   **Contesto**: usato in `WebTourContenutiTab` accanto ai campi SEO/tecnici (slug, meta title/description, ordine, prima pubblicazione) e allo **stato di pubblicazione** per spiegare in linguaggio semplice il significato di ciascun campo a utenti non tecnici. L'aiuto sullo stato è il più esteso perché deve chiarire tre cose che senza spiegazione sembrano difetti: il controllo scatta al **salvataggio** e non alla scelta della voce; **archiviato** per il sito è identico a **bozza**; e il tour esce dal sito **da solo** quando la partenza inizia, senza che lo stato cambi.

### WebTourContenutiTab
Scheda "Contenuti Web" del viaggio — estensione web, Blocco 5 (`Components/Shared/WebTourContenutiTab.razor`).
*   **Funzionalità**:
    *   Carica/crea i contenuti editoriali web del tour (1:1 con `ana_viaggi`) via `WebTourContenutiService` (funzioni `fn_web_tour_contenuti_*`).
    *   Campi editoriali: sottotitolo, difficoltà (select `turistica/media/medio_alta/alta`), durata testo, luoghi visitati.
    *   5 editor RichText (`Blazored.TextEditor`/Quill): descrizione + pernottamento/pasti/equipaggiamento/altre info. L'HTML esistente è caricato con `LoadHTMLContent` (retry perché Quill si inizializza async); l'HTML "vuoto" di Quill (`<p><br></p>`) è normalizzato a NULL.
    *   SEO: slug (obbligatorio, con generazione dal titolo via adornment e slugify accent-safe), meta title, meta description (counter 320). Ogni campo tecnico ha un'icona `FieldHelp` con spiegazione in linguaggio semplice (Blocco 5 Fase 1).
    *   **Pulsanti "Suggerisci" (Blocco 5 Fase 2, Task 5)**: adornment End (icona `AutoFixHigh`, stesso pattern del "genera" slug) su meta title e meta description. `SuggerisciMetaTitle()` pre-compila da `DescrizioneBreve` troncato a 60 caratteri; `SuggerisciMetaDescription()` pre-compila da `StripHtml(DescrizioneHtml)` (fallback `Sottotitolo`) troncato a 155 caratteri. Helper statici `StripHtml` (rimuove tag HTML via regex, decodifica entità con `WebUtility.HtmlDecode`, comprime spazi multipli) e `Troncatura` (taglia sull'ultimo confine di parola prima del limite). Il valore resta editabile dopo il suggerimento; questi campi alimentano il fallback DB-side di `fn_web_tour_pubblicati` (script `486`, vedi `Funzioni_DB.md`).
    *   Pubblicazione: stato (`bozza/pubblicato/archiviato`), ordine, prima pubblicazione (resa come label statica non editabile — `MudField` con icona lucchetto — valorizzata dal sistema al primo passaggio a `pubblicato`).
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
*   **Slider "Dimensione miniature"** (`MudSlider<int>`, 96–240px step 8, di fianco al titolo del picker): ridimensiona le thumbnail (`ThumbStyle`, altezza ≈ larghezza×0,75) e il box scrollabile (`MaxPickerHeight = _thumbSize + 60`). Preferenza "nascosta" per-utente (nessuna UI CRUD), chiave `galleria.thumb_size` **condivisa** con `WebTourGalleriaTab` — persistita via `UserPreferenzeService` (`sys_utente_preferenze` / `fn_sys_utente_pref_get`/`_set`, `SqlScripts/489_SysUtentePreferenze.sql`). Default 120px se non impostata.
*   Ritorna il passo modificato (`DialogResult.Ok`) al `WebTourItinerarioTab`, che persiste via create/update (pattern CRUD: il dialog non salva).
*   **Parametri**: `Passo` (required), `ViaggioId`/`AziendaId` (per caricare la galleria) — i valori sono applicati solo al Salva.

### WebTourGalleriaTab
Scheda "Galleria" del contenuto/edizione — estensione web, Blocco 7 (`Components/Shared/WebTourGalleriaTab.razor`; gli stili delle card sono un `<style>` GLOBALE inline nel component, prefissato `.galleria-tab`, perché sono resi da `RenderFragment<T>` locali e lo scoped CSS `::deep` di `.razor.css` non li raggiunge — `.razor.css` è volutamente vuoto).
*   **Upload multiplo** (`MudFileUpload`, accept image/*) con **overlay bloccante** (`MudOverlay`) e contatore "Caricamento foto N di M…" durante il loop. Per file → dedup per **nome file** (case-insensitive/trim contro `NomeFile` delle immagini già in memoria, incluse quelle appena caricate nello stesso batch: skip + Snackbar warning) → `WebImageProcessor.ToOptimizedWebpAsync` (WebP ≤2000px, q80, cattura larghezza/altezza) → `IWebMediaStorage.UploadAsync` (Supabase Storage) → `WebTourImmaginiService.CreateAsync` (url = `BuildPublicUrl`, `storage_path` = verità, `NomeFile` = `IBrowserFile.Name`).
*   **Due viste** (toggle `MudButtonGroup`, default Dettaglio): **Dettaglio** = copertina grande in cima (`CardTemplateCopertina`) + "Altre foto" in **colonna verticale, una per riga, card orizzontale grande** (immagine ~240px a sinistra, Titolo/Testo alternativo + azioni a destra — `CardTemplateDettaglio`), editing inline con auto-save (`@bind-Value:after` → `SaveCampi`/`ImmaginiService.UpdateAsync`); **Griglia** = panoramica compatta di sola lettura (`CardTemplateGriglia`, thumb ridimensionabile), niente campi editabili (alert informativo). `@foreach` con `@key="img.WebTourImmagineId"` (e sulla copertina) per evitare che Blazor riusi il DOM/i binding della card sbagliata quando la copertina cambia o una foto viene caricata/rimossa.
*   **Slider "Dimensione miniature"** (`MudSlider<int>`, 96–240px step 8, accanto al toggle vista, visibile solo in Griglia): applica la dimensione via CSS custom property `--thumb` impostata inline sul contenitore grid (`.img-card-mini`/`.thumb` in `<style>` la leggono con `var(--thumb, 120px)`, ereditata dai discendenti). Preferenza "nascosta" per-utente, chiave `galleria.thumb_size` **condivisa** con `WebTourPassoEditDialog` — persistita via `UserPreferenzeService` (`sys_utente_preferenze`, `SqlScripts/489_SysUtentePreferenze.sql`). Default 120px se non impostata.
*   **Copertina**: `SetPrincipaleAsync` + ricalcolo locale di `Tipo` su tutte le immagini + overlay `_busy` (cloud, stesso overlay usato da `DeleteImmagine`). Elimina: record + `IWebMediaStorage.DeleteAsync` (orfano storage tollerato), overlay `_busy` durante l'attesa.
*   **Foto in uso non eliminabili** (integrità con l'itinerario): `web_tour_itinerario_passaggi.immagine_storage_path` referenzia una foto della galleria **senza FK** (legame debole per valore di `storage_path`). `WebTourImmagine.InUso` (transiente, non persistita) è calcolata in `ReloadAsync` via `WebTourImmaginiService.GetStoragePathInUsoAsync` (→ `fn_web_immagini_in_uso`) e disabilita il pulsante Elimina (con tooltip) nei 3 template. Difesa anche lato DB: `fn_web_tour_immagini_delete` fa `RAISE EXCEPTION` (P0001) se lo storage_path è in uso, tradotto dal service in `InvalidOperationException` col messaggio friendly.
*   **"Elimina tutte le foto"** (vicino alla toolbar upload, visibile se ci sono foto): conferma (`DeleteConfirmationDialog`, bottone "Elimina tutte"/`Color.Error`, messaggio che avvisa su copertina/anteprima/pubblicazione e foto in uso mantenute) → elimina tutte le non-`InUso` (overlay `_busy`) → Snackbar riepilogo + reload.
*   **"Applica a tutte le foto"** (sezione in alto, solo vista Dettaglio): due campi master Titolo/Testo alternativo (con `HelperText` esplicativo) + pulsante che, dopo conferma (`DeleteConfirmationDialog`, bottone "Applica"/`Color.Primary` per non confondersi con un'eliminazione), sovrascrive e salva solo i campi master non vuoti su tutte le foto.
*   **Promemoria attributi mancanti**: a fine batch di upload, se ≥1 foto appena caricata ha Titolo e Testo alternativo entrambi vuoti, Snackbar info non bloccante col conteggio.
*   **Live-save**; MUST UI: `setupTabNavigation`, niente uppercase su alt/titolo (web), `BackdropClick=false` dal chiamante.
*   **Parametri**: `ContenutoId` (long)/`AziendaId` (required). Montato come 2° `MudTabPanel` ("Galleria") in `WebEdizioniManager`; il pulsante "Anteprima" del manager è disabilitato finché la Galleria non è `WebTabStato.Completo` (serve una copertina).
*   **Sicurezza**: la `ServiceKey` (service-role) è usata contro il bucket di TEST; hardening produzione (chiave scoped / upload server-side) = **debito documentato** per il go-live.

> **WebTourImmagineEditDialog — eliminato (2026-07-27).** Modificava alt/titolo di un'immagine di galleria (Blocco 7). Era stato lasciato come orfano per un eventuale riuso, ma la modifica inline in `WebTourGalleriaTab` (auto-save on blur) è la soluzione adottata e non c'è motivo di tornare a un dialog. Recuperabile dalla storia git.

### WebTipiViaggioDescrizioniPage + WebTipoViaggioDescrizioneDialog (Blocco 8)
Gestione delle **descrizioni web dei tipi di viaggio** (lookup GLOBALE `web_tipi_viaggio_descrizioni`, ex categoria sport).
*   **Pagina** `Components/Pages/WebTipiViaggioDescrizioniPage.razor` (`/tabelle/descrizioni-web`, menu "Descrizioni Web (sito)"): CRUD via `EnterpriseDataGrid` su `WebTipiViaggioDescrizioniService` (globale, `ListAsync`/Create/Update/Delete). Colonne descrizione/slug/ordine.
*   **Dialog** `Components/Shared/WebTipoViaggioDescrizioneDialog.razor`: campi `descrizione_web`/`slug`/`ordine` — **niente uppercase** (è web); setupTabNavigation + focus primo campo.
*   **Mapping**: `TipoViaggioDialog` (esistente) ha un `MudSelect` "Descrizione web (sito)" che valorizza `TipoViaggio.DescrizioneWebFk` (persistito da `TipoViaggioService.UpdateAsync`); `TipoViaggioPage` mostra la descrizione mappata in colonna. Più tipi possono condividere la stessa descrizione (N:1). Esposta al sito da `fn_web_tour_pubblicati`.

### WebTourMappaTab + pipeline GPX→mappa (Blocco 9)
Scheda "Mappa" del viaggio: genera una **mappa statica** dal GPX, tutto lato gestionale (la traccia non raggiunge mai il browser).
*   **Componente** `Components/Shared/WebTourMappaTab.razor` (`MudTabPanel` in `WebEdizioniManager`, solo edit): **elenco** delle mappe dell'edizione (card con immagine, descrizione, chip dell'abbinamento, GPX, data, Rigenera/Elimina) + form di caricamento. Attribuzione © OpenStreetMap contributors.
*   **Mappe multiple (2026-07-25)**: un'edizione ha **N mappe**, ognuna dell'**intero viaggio** o di **una giornata** dell'itinerario. Il form chiede l'abbinamento invece di dedurlo: giornate già occupate escluse dal select, opzione "Intero viaggio" disabilitata se già presente, descrizione **proposta dal titolo della giornata** e modificabile (non forzata in maiuscolo: è testo per il web, tradotto in `web_traduzioni`). I casi ambigui li rifiuta il **DB** (`SqlScripts/493`, vedi `Funzioni_DB.md`), non la form; su errore si resta nel form senza perdere il file scelto. Design: `Estensione Progetto WEB/Documenti/2026-07-25-Mappe_Multiple_GPX_design.md`.
*   **Pipeline** `Services/Web/WebTourMappaGeneratorService.cs`: `GpxParser` (parse `<trkpt>`) → `DouglasPeucker` → `GeoapifyStaticMapClient.ComputeBbox` + `FetchAsync` (Geoapify Static Maps, HTTP REST, formato validato: `area=rect`/`geometry=polyline` in lon,lat, colori %23) → JPEG → `WebImageProcessor` WebP → `IWebMediaStorage` → upsert per *(contenuto, giornata)* su `web_tour_mappa`. Descrizione obbligatoria per la mappa d'insieme e **controllo doppione** (nome case-insensitive + dimensione UTF-8) girano **prima** di Geoapify, così un caricamento che il DB rifiuterebbe non consuma una chiamata API.
*   **Modifica** (`WebTourMappaEditDialog`): cambia **descrizione** e **abbinamento** senza ricaricare il GPX. Solo descrizione → semplice UPDATE, nessuna chiamata a Geoapify; abbinamento → la riga si aggiorna *prima*, così la rigenerazione ritrova la stessa mappa invece di crearne una nuova, e il vecchio oggetto su Storage viene cancellato. `gpx_filename` e `descrizione` restano due cose distinte: il primo è tracciabilità tecnica (mostrato, non modificabile), la seconda è il nome mnemonico che vede il cliente ed è quella che va in `web_traduzioni` — un file `provaG1.gpx` può avere descrizione "Mappa Giorno 1".
*   **Attesa**: la generazione chiama Geoapify e dura secondi; un `MudOverlay` copre la scheda e blocca i clic (con `StateHasChanged` esplicito, altrimenti comparirebbe a operazione conclusa).
*   **Storage**: un percorso per mappa — `{azienda}/{contenuto}/mappa-viaggio.webp` oppure `mappa-giornata-{itinerarioId}.webp` (bucket `tour-media`). Si usa l'**id** della giornata e non il `giorno_numero`, che cambia riordinando l'itinerario e lascerebbe file orfani nel bucket a ogni riordino. L'eliminazione della mappa cancella anche l'oggetto (orfano tollerato, come in galleria).
*   **Config**: sezione `Geoapify` in appsettings (`GeoapifyOptions`: ApiKey, Style, colori, `MaxPolylinePoints`). **`MaxPolylinePoints` = 70**: non è più solo un cap per la lunghezza dell'URL ma il **criterio di generalizzazione** del tracciato (non replicabile da chi conosce il territorio). Un budget di punti è preferibile a una tolleranza in metri perché è relativo all'estensione: stessa ruvidezza su mappa d'insieme e di giornata, mentre 600 m fissi collassano una tappa di 4 km a 6 punti. Le options sono costruite **a mano** in `MauiProgram`: una chiave nuova in appsettings senza la riga corrispondente lì viene ignorata in silenzio. Chiave API **non cifrata** (free, rigenerabile dal cliente).
*   **Parametri tab**: `ContenutoId`/`AziendaId` (required), `DataInizio`/`NumeroGiorni` (etichette giornata con data reale). Se la chiave non è configurata (`Generator.IsConfigured=false`) la generazione è disabilitata con avviso.

### "Traduci mancanti": mai ritradurre ciò che è già a posto (2026-07-29)
`TranslateAsync` ripassava **tutte** le coppie campo×lingua a ogni esecuzione. Non era solo spreco di crediti: `fn_web_traduzioni_upsert` rimette `revisionato = FALSE`, quindi una seconda esecuzione **cancellava tutta la revisione già fatta** e costringeva a riapprovare l'intero tour (successo davvero: 104 traduzioni riapprovate da zero).
*   Ora si traducono solo le coppie **mancanti o obsolete**; le altre si contano e si riportano ("N già a posto, non ritradotte").
*   Il pulsante si chiama **"Traduci mancanti"** ed è disabilitato quando non c'è nulla da fare; accanto al contatore delle revisioni compare "N da tradurre".
*   Un testo italiano modificato rende obsolete le sue traduzioni (`MarkObsoleteAsync`), che quindi rientrano automaticamente fra quelle da rifare: il ciclo si chiude senza bisogno di ritradurre tutto.

### Anteprima: partenze e lingua (2026-07-29)
*   **Prossime partenze**: in testa all'anteprima, le date future del viaggio (`fn_web_tour_prossime_partenze`, solo `data_inizio >= oggi`), con l'edizione in lavorazione evidenziata; se non ce ne sono, avviso "Nessuna data in calendario". Le date non fanno parte del contenuto, ma accorgersi che il viaggio non ha partenze prenotabili mentre se ne cura la scheda è utile.
*   **Lingua dell'anteprima**: combo con IT + le lingue **complete e approvate**. Una lingua compare solo se OGNI campo traducibile è tradotto, revisionato e non obsoleto: un'anteprima a metà in lingua straniera confonderebbe. Se nessuna lo è, la combo è disabilitata con tooltip che invita a completare le traduzioni. Il totale atteso viene da `n_traducibili` (`fn_web_tour_stato_sezioni`), **non** dalle traduzioni presenti: un campo mai tradotto sparirebbe dal denominatore e falserebbe il conteggio.
*   I **titoli delle giornate** sono tradotti dallo script `503`, quindi l'anteprima in lingua è completa.

### Revisione traduzioni: mai HTML a vista (2026-07-29)
`WebTraduzioneReviewDialog` modificava i campi `*_html` in una textarea con i **tag in chiaro**. Da evitare: l'utente non deve sapere cosa sia uno `<strong>`, e un tag toccato per sbaglio rompe la pagina pubblica — con la colpa che ricade su chi ha consegnato il software.
*   **Ora**: per i campi `*_html` la traduzione si modifica con lo **stesso editor visuale** (`BlazoredTextEditor`/Quill) con cui si scrive l'italiano; il sorgente IT è mostrato **reso**. I campi di testo puro (sottotitolo, meta, durata) restano su `MudTextField`.
*   **Quali campi sono HTML**: NON basta il suffisso `_html` — `viaggio_incluso`/`viaggio_escluso` contengono markup pur non chiamandosi così, e con la sola regola sul nome finivano davanti all'utente come tag grezzi. Si usa un **elenco esplicito** (`descrizione_html`, `info_*_html`, `altre_info_html`, `testo_html`, `viaggio_incluso`, `viaggio_escluso`) **più** un riconoscimento dal contenuto: se il testo contiene tag viene comunque reso, così un campo aggiunto in futuro e dimenticato nell'elenco non torna a mostrare markup. Verifica sui dati (2026-07-31): 8 campi con HTML, 7 di testo puro (`sottotitolo`, `durata_testo`, `luoghi_visitati`, `meta_title`, `meta_description`, `titolo_giornata`, `descrizione` mappa).
*   **Effetto collaterale utile**: Quill normalizza il markup al caricamento, quindi aprire e salvare una traduzione con HTML corrotto la **ripara**.
*   **Salvataggio**: `GetHTML()` + controllo di non-vuoto (un editor svuotato produce `<p><br></p>`, che salvato pubblicherebbe un paragrafo vuoto).
*   **Integrità del markup a monte**: il modello a volte riscrive i tag mentre traduce (nei dati di test è stato trovato `<strong>Arbataxong>`, con `</strong>` mancante). `ClaudeTranslationClient.FirmaTag` confronta la sequenza dei tag di sorgente e traduzione: se non combacia si **ritenta una volta**, e se il secondo tentativo sbaglia ancora la traduzione si tiene ma viene **conteggiata a parte** e segnalata all'utente ("N con formattazione alterata"). Il prompt è stato irrigidito sul rispetto dei tag.

### Consumo Claude e soglia di spesa (2026-07-28)
Il credito della chiave Anthropic è precaricato e l'API non ne espone il residuo: il gestionale conta i token che ogni risposta riporta già (`usage`), quindi il tracciamento è **a costo zero**.
*   **Dove si vede**: riquadro di riepilogo in cima a `WebTraduzioniTab` (spesa stimata + soglia, diventa arancione oltre il 90%); pannello completo in `AziendaTabs/AziendaTabTraduzioni` con token, spesa, impostazione della **soglia** e pulsante *"Ho ricaricato: riparti da oggi"* (sposta `conteggio_da`, non cancella lo storico).
*   **Servizi**: `WebAiConsumoService` (registro e riepiloghi) e `WebAiAlertService` (email al 90%, una sola volta per periodo — la decisione è del DB, vedi `fn_web_ai_soglia_da_avvisare`). L'avviso si verifica **a fine blocco** di traduzione, non a ogni chiamata.
*   **Prezzi**: `ClaudeOptions.PrezzoInputPerMilione`/`PrezzoOutputPerMilione`/`Valuta` (sezione `Claude` in appsettings). I default ($1 input / $5 output per MTok) corrispondono al listino **Claude Haiku 4.5**, il modello in uso, verificato il 2026-07-28. ⚠️ Restano **configurazione, non un dato letto dall'API**: da riallineare se si cambia modello o se il listino cambia. Come per Geoapify, le options si costruiscono a mano in `MauiProgram`: una chiave in appsettings senza la riga corrispondente lì viene ignorata in silenzio.
*   **Onestà del dato**: la UI dichiara sempre che è una stima dei consumi di *questo* gestionale, non il saldo Anthropic.

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

### AziendaSmtpDialog + AziendaTabSmtp
Dialog di configurazione SMTP/IMAP dell'azienda (`Components/Shared/AziendaSmtpDialog.razor`), montato da `Components/Shared/AziendaTabs/AziendaTabSmtp.razor` (sotto-tab della form Aziende, elenco configurazioni + apri/elimina).
*   **Toggle mostra/nascondi password** (icona occhio, outbound e inbound indipendenti): `ToggleShowPassword`/`ToggleShowInboundPassword` cambiano l'`InputType` del campo Password/Password Inbound tra `Password` e `Text`. Al **primo** "mostra" (se il campo contiene ancora il placeholder `***`) recuperano il valore reale decifrato dal DB via `AziendaSmtpService.GetRealPasswordForEditAsync(smtpId, aziendaId)` / `GetRealInboundPasswordForEditAsync(smtpId, aziendaId)` (validano il tenant, poi chiamano `fn_ana_aziende_smtp_secrets_get` che decifra outbound+inbound via pgcrypto).
*   **Fix lettura password reale**: `AziendaSmtpService.GetRealPasswordAsync` (usato anche dal test connessione) ora passa dalla stessa function `fn_ana_aziende_smtp_secrets_get` invece di leggere `password_enc->>'value'` su colonna `bytea` (pattern rotto, non decifrava nulla).
*   **Avviso VPN**: testo in dialog che avvisa che il test connessione può fallire con VPN attiva (molti server di posta bloccano gli IP VPN/datacenter); i messaggi d'errore del test sono generati da `SmtpErrorTranslator` (vedi `Documents/Gestione_check.md` §SmtpErrorTranslator), inclusa la diagnostica che distingue "host irraggiungibile" da "porta bloccata da firewall/VPN".

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

### Newsletter (Estensione Web — Blocco 11)

Motore newsletter **per-azienda** e relativa UI. Multilingua: la lingua di ogni destinatario deriva da `iscritti.lingua` o `ana_clienti.cliente_lingua` (funzione DB `fn_web_destinatari_newsletter`). Il corpo, scritto in italiano, viene tradotto per-lingua via Claude (chiave per-azienda, riuso Blocco 10); senza chiave i destinatari non-IT ricevono la versione italiana.

*   **NewsletterSenderService** (`Services/Web/NewsletterSenderService.cs`): risolve i destinatari (clienti+iscritti−soppressioni), traduce oggetto+corpo per-lingua, genera l'email con il template brandizzato **`CompanyEmailTemplate`** (logo azienda + footer con sito/telefono, come le altre mail) aggiungendo in coda il footer di disiscrizione, invia via SMTP/ESP dell'azienda (`EmailSenderFactory`), logga la consegna per-destinatario e registra la campagna.
    *   `CountRecipientsAsync(aziendaId)` / `GetRecipientsAsync(aziendaId)` — conteggio/elenco destinatari risolti.
    *   `SendCampaignAsync(aziendaId, oggetto, corpoHtml)` → `NewsletterSendResult(Totale, Inviate, Errori, TradottoIncompleto)`.
    *   `SendTestAsync(aziendaId, oggetto, corpoHtml, testEmail)` — invio di prova (solo IT, non registra la campagna).
*   **NewsletterUnsubscribe** (`Services/Shared/NewsletterUnsubscribe.cs`): helper statico per il link di disiscrizione firmato HMAC-SHA256 (segreto = `ana_aziende.token_iscrizione`). `BuildUrl(baseUrl, email, secret)` → `{baseUrl}/unsubscribe?email=...&sig=...` (il sito in Fase 3 verifica la firma).
*   **NewsletterPage** (`/newsletter`, `Components/Pages/NewsletterPage.razor`): pagina a 4 tab — **Campagna** (compose Quill + conteggio + invio di prova + invia a tutti con conferma), **Storico** (elenco invii + log per-destinatario), **Iscritti** (read-only, dal sito), **Soppressioni** (aggiungi/rimuovi). `aziendaId` via `ITenantContext.GetCurrentAziendaIdAsync()`.
*   **NewsletterLogDialog** (`Components/Shared/NewsletterLogDialog.razor`): dialog di log consegna per-destinatario di una campagna (email/lingua/esito/data).

### Funzioni Web per-azienda (Estensione Web — Blocco 12)

Toggle **per-azienda** delle funzionalità web (`web_aziende_funzioni`, chiave logica azienda+funzione).

*   **WebAziendeFunzioniService** (`Services/Web/WebAziendeFunzioniService.cs`): CRUD DB-first sulle funzioni (`fn_web_aziende_funzioni_*`). Costanti funzione note (`newsletter`/`recensioni`/`blog`/`pagamenti_online`). `SetAttivaAsync(azienda, funzione, attiva)` = upsert; `IsAttivaAsync(azienda, funzione, defaultWhenMissing)` e `IsNewsletterEnabledAsync(azienda)` (default **true** = opt-out) per il **gating**.
*   **AziendaTabFunzioniWeb** (`Components/Shared/AziendaTabs/AziendaTabFunzioniWeb.razor`): sotto-tab della form Aziende con gli switch dei 4 flag + card **"Regole di pagamento" disabilitata** (placeholder Fase 4). Solo `newsletter` ha effetto nel gestionale oggi (gating menu/pagina); gli altri sono predisposti per il sito pubblico (Fase 3).
*   **Gating newsletter**: `NavMenu` nasconde il gruppo "Estensione Web" quando la newsletter è disattivata per l'azienda corrente (best-effort); `NewsletterPage` (`/newsletter`) è la **guardia autoritativa** (mostra "non attiva" se disabilitata). ESP (`ana_aziende_esp`) **rimandato** pre-release (vedi Checklist Go-Live §2.2).

### Contenuti web per edizione (Estensione Web — Blocco 13)

I contenuti web sono **per-edizione**: `web_tour_contenuti` è figlio di **(viaggio + data_viaggio)**, non più 1:1 col viaggio. Un contenuto per data; `n` per viaggio. Prezzi/date/categoria/**difficoltà** sono **riferimento vivo** dall'anagrafica (`ana_date_viaggi`, `ana_viaggi.viaggio_difficolta`), non editabili nel contenuto. Immagini/itinerario/mappa pendono da `web_tour_contenuti_id_fk`.

*   **WebEdizioniManager** (`Components/Shared/WebEdizioniManager.razor`): unico tab "Contenuti Web" nel dialog viaggio. **Selettore edizione** (`fn_web_edizioni_per_viaggio`): ogni data del viaggio con dal–al + chip "con/senza contenuto" e "effettuato/da effettuare" (`data_viaggio_effettuato_sino`). Data senza contenuto → **Crea** (nuovo bozza) o **Clona da** un'altra edizione; data con contenuto → 5 sotto-tab (Contenuti/Itinerario/Galleria/Mappa/Traduzioni) su `ContenutoId` + **Anteprima**.
*   **WebTourAnteprimaDialog** (`Components/Shared/WebTourAnteprimaDialog.razor`): anteprima IT read-only del contenuto (sottotitolo, descrizione, itinerario+passi, galleria, mappa), speculare al sito.
*   **Chip di stato del selettore edizione.** Due informazioni distinte, entrambe con tooltip: *"Con contenuto (stato)"* riguarda la **scheda web**; l'altro riguarda la **partenza**.
*   **`StatoContenutoWebIcon`** (`Components/Shared/StatoContenutoWebIcon.razor`): icona con lo stato della scheda web di una partenza (senza scheda / bozza / pubblicata / archiviata) e relativo tooltip; quando la scheda manca è cliccabile e apre `WebCreaContenutoDialog`. Regole e testi in `ContenutoWebRules`.
*   **`WebCreaContenutoDialog`** (`Components/Shared/WebCreaContenutoDialog.razor`): dialogo "crea da zero o clona", unico proprietario dell'operazione (compreso il controllo sulle durate diverse fra partenze). Usato dalla griglia delle date e dalla scheda Contenuti Web.
*   **`StatoPartenzaChip`** (`Components/Shared/StatoPartenzaChip.razor`): chip riusabile con lo stato della partenza e il relativo tooltip. Parametri `Effettuato` (required), `DataFine`, `SoloIcona` (per le colonne strette delle griglie: resta l'icona, il significato non si perde perché il tooltip è lo stesso). Usato dal selettore edizione dei contenuti web e dalla colonna EFFETT. di `ViaggioDatesManager`. La sola resa grafica: regole e testi stanno in `StatoPartenzaRules`, così la stessa lettura vale ovunque si ragioni su una partenza (contenuti web, elenco date, calendario).
*   **Pubblicabilità** (`StatoPartenzaRules.MotivoNonPubblicabile`): un'edizione si pubblica solo se **deve ancora partire** (data di inizio ≥ giorno successivo a oggi) e **non è già effettuata** — pubblicare una partenza già avviata non serve, nessuno può più prenotarla. Il gating in `WebTourContenutiTab.Salva` è una catena esclusiva: *partenza non pubblicabile* → *sotto-tab incompleti* → *verifiche non bloccanti*. Come il resto del gating, l'enforcement è **UI**; la difesa DB-first resta il passo previsto e non ancora fatto.
*   **Stato della partenza** (`StatoPartenzaRules`, unica sede di regole e testi): non basta il flag `ana_date_viaggi.data_viaggio_effettuato_sino` (la spunta "Viaggio Effettuato" della scheda Date, la stessa delle statistiche viaggi fatti/da fare) — va **incrociato con la data di fine**, perché le due informazioni possono contraddirsi ed è la contraddizione che l'operatore deve vedere:

    | Flag | Calendario | Livello | Etichetta |
    |---|---|---|---|
    | SI | conclusa | Conclusa (info) | Partenza effettuata — curarne la scheda web di solito non serve più |
    | NO | conclusa | **Anomalia** | Conclusa ma non registrata — o manca l'aggiornamento del flag, o il viaggio non è stato fatto |
    | NO | in programma | Normale | Partenza da effettuare |
    | SI | in programma | **Anomalia** | Effettuata ma non ancora conclusa — spunta messa in anticipo o per errore |

    "Conclusa" = ultimo giorno **passato** (il giorno stesso della fine il viaggio è ancora in corso). Senza data di fine si riporta il solo flag. Sui dati di test l'incrocio ha fatto emergere 9 partenze concluse ma non registrate.
*   **Data reale delle giornate.** L'itinerario non memorizza date: `Helpers/GiornataHelper` le **deriva** da `data_viaggio_data_inizio + (giorno_numero − 1)`. La corrispondenza è esatta perché il trigger `trg_validate_date_viaggio_duration` rifiuta ogni edizione la cui durata non coincida con `ana_viaggi.viaggio_numero_giorni`. `WebTourItinerarioTab` mostra la data **per esteso** ("Sabato 2 Maggio 2026") come informazione **non editabile** accanto al titolo, che resta libero e descrittivo; deriva da `GiornoNumero`, che i tre percorsi di riordino riscrivono, quindi segue lo spostamento da sola. Le giornate oltre la durata prevista mostrano "oltre la durata prevista". Derivare invece di memorizzare evita date rimaste indietro dopo uno spostamento della partenza e date sbagliate dopo un clone su un'altra edizione (`fn_web_tour_contenuti_clona`).
*   **Semaforo dei sotto-tab.** L'icona di ogni sotto-tab è colorata da `WebTabStato` (🟢 Completo · 🔴 Parziale · 🟡 Vuoto) e alimenta anche il pulsante **Anteprima** (serve la copertina) e il **gating di pubblicazione**. `MudTabs` non tiene vivi i pannelli, quindi i sotto-tab non visitati non esistono e non possono notificare il proprio stato: il manager lo **precarica** all'apertura e a ogni cambio edizione con `WebTourContenutiService.GetStatoSezioniAsync` → `fn_web_tour_stato_sezioni` (una query, `SqlScripts/492`). Mentre si edita restano i sotto-tab a notificare via `StatoChanged`. Le soglie stanno **in un solo posto**, `WebTabStatoRules` (`Models/Web/WebTabStato.cs`), usate sia dal prefetch sia dai tab: non duplicarle nei componenti.
*   I 5 tab (`WebTourContenutiTab`/`WebTourItinerarioTab`/`WebTourGalleriaTab`/`WebTourMappaTab`/`WebTraduzioniTab`) ricevono ora `ContenutoId` (long) e i service espongono `*ByContenutoAsync`. `WebTourContenutiService`: `GetByDataViaggioAsync`, `ListEdizioniAsync`, `ClonaAsync` (→ `fn_web_tour_contenuti_clona`). Difficoltà editabile ora **solo** in `AnaViaggiDialog` (anagrafica viaggio).

## InputTextDialog

Dialogo condiviso per chiedere **una riga di testo** (un nome, un oggetto, un titolo). Nato con la
newsletter a blocchi (2026-08-09): prima esistevano solo dialoghi di **conferma**, e ogni schermata
che avesse bisogno di un nome se lo sarebbe inventato per conto proprio.

Parametri: `Title`, `Label`, `Testo` (spiegazione opzionale sopra il campo), `Value` (valore
iniziale), `ButtonText`, `MaxLength` (default 255).

Comportamento: focus automatico sul campo all'apertura (regola UI del progetto), **Invio conferma**
— con un campo solo, obbligare al clic sarebbe una scortesia — e pulsante di conferma disabilitato
finché il campo è vuoto. Restituisce la stringa **già trimmata** via `DialogResult.Ok`, oppure
`Canceled`.

## NewsletterBloccoDialog / NewsletterAnteprimaDialog / NewsletterDestinatariDialog

Tre dialoghi della pagina Newsletter.

*   **`NewsletterBloccoDialog`** — modifica di un singolo blocco. I campi mostrati **dipendono dal
    tipo**: far comparire "collegamento" su un separatore confonderebbe e basta. Su intestazione e
    footer non mostra campi ma spiega che si compilano dai dati dell'azienda.
    Sul blocco **tour** offre *Scegli il tour*, che apre `TravelDataSelectorDialog` e compila da solo
    titolo, periodo, copertina (convertita in JPEG) e collegamento. Avvisa se la scheda web è ancora
    in **bozza** (il link porterebbe a una pagina inesistente) o se manca il sito aziendale.
    **Non sovrascrive** un testo già scritto dall'utente.
*   **`NewsletterAnteprimaDialog`** — l'HTML reale dentro un **iframe**. L'iframe non è un vezzo:
    isola gli stili della newsletter da quelli di MudBlazor. Inserito nella pagina, l'HTML della
    mail erediterebbe il CSS dell'applicazione e mostrerebbe qualcosa di **diverso** da ciò che
    arriva al destinatario — cioè l'errore che un'anteprima deve evitare.
*   **`NewsletterDestinatariDialog`** — elenco in sola lettura di chi riceverà (Cognome, Nome, Mail,
    Telefono, Lingua). Il telefono è vuoto per gli iscritti dal sito, che lasciano la sola email.

## TravelDataSelectorDialog — riuso fuori dalle stampe

Selettore **viaggio + data di partenza**, nato per le stampe: restituisce l'`id` della data scelta.
Dal 2026-08-09 è riusabile anche fuori da quel contesto grazie a due parametri opzionali:

*   `TitoloPersonalizzato` — titolo del dialogo; se assente si usa quello derivato da `PrintType`.
*   `EtichettaConferma` — testo del pulsante; se assente si usa quello derivato da `PrintType`.

I chiamanti esistenti (NavMenu, dashboard) non sono stati toccati: senza i due parametri il
comportamento è identico a prima. Primo riuso: la scelta dell'edizione per il riquadro tour della
newsletter — dove duplicare la logica di selezione sarebbe stato l'errore da manuale.

## ImmaginePicker

Scelta di un'immagine da una galleria, come strip di miniature. **Estratto** nel 2026-08-09 da
`WebTourPassoEditDialog`, dove la logica era già scritta e collaudata (Blocco 7): serviva anche ai
blocchi della newsletter, e duplicarla sarebbe stato l'errore che questo documento esiste per evitare.

Il componente **non sa da dove arrivano le immagini**: gliele passa il chiamante come
`List<ImmaginePicker.Voce>` (`Url`, `StoragePath`, `Alt`, `Contesto`). Così serve sia la galleria di
un singolo tour (`ListByContenutoAsync`) sia tutte le foto dell'azienda
(`fn_web_immagini_azienda`, script `515`) senza saperne nulla.

Parametri: `Immagini`, `Titolo`, `TestoGalleriaVuota`, `ConsentiNessuna` (default true),
`SelectedStoragePath`/`SelectedUrl` con i rispettivi `Changed`, e `OnScelta` che notifica la voce
completa — utile quando serve anche l'alt o il contesto.

Mantiene lo **slider dimensione miniature** con la preferenza per-utente `galleria.thumb_size`,
**condivisa** con `WebTourGalleriaTab`: chi allarga le miniature in un posto se le ritrova allargate
ovunque. Il `Contesto` finisce in tooltip: senza, una parete di miniature è indistinguibile.

**Usato da:** `WebTourPassoEditDialog` (foto del passo d'itinerario) e `NewsletterBloccoDialog`
(blocchi testata / immagine / tour). Nella newsletter la scelta passa poi da
`NewsletterMediaService.ConvertiDaUrlAsync`, perché la galleria produce WebP e Outlook non lo mostra.

## WebIndirizzoDialog

Modifica di una voce della rubrica indirizzi web (`Tabelle → Tabelle web → Indirizzi web`, script
`517`). Nome, indirizzo, note, attivo.

Valida **prima** di salvare (nome ≥ 2 caratteri, URL con protocollo) pur avendo gli stessi vincoli
sulla tabella: dire subito cosa manca è meglio che far tornare l'errore dal database a salvataggio
avvenuto. I messaggi dei vincoli sono comunque nel dizionario centrale, per i casi che sfuggono.

## FileUploader

Caricamento di file, **unico per tutta l'applicazione**. Creato il 2026-08-11 dopo aver constatato
che i sette punti che caricavano file avevano parametri tutti diversi e che **quattro su sette non
impostavano `MaxFileSize`**: ereditavano il default di 10 MB di MudBlazor, che scarta i file più
grandi **senza dirlo**. Un difetto silenzioso ripetuto in mezza applicazione.

Incapsula le tre cose che si dimenticano sempre:

*   **`MaxByte`** (default **20 MB**, non i 10 di MudBlazor) — e il file troppo grande viene
    **segnalato**, non scartato in silenzio.
*   **`MaxFile`** (default 30) per le selezioni multiple.
*   **`ClearAsync()`** dopo l'elaborazione: senza, riselezionare gli *stessi* file non fa scattare
    l'evento perché l'input conserva il valore precedente, e il pulsante sembra rotto dal secondo
    tentativo in poi. È il difetto che ha fatto nascere questo componente.

Parametri: `Attivatore` (il pulsante, come `RenderFragment`), `Multiplo`, `Accept`, `MaxFile`,
`MaxByte`, `EstensioniAmmesse` + `MessaggioEstensione`, `Disabilitato`, `MostraAttesa`,
`RiepilogoAutomatico`.

`OnFile` viene chiamata **una volta per file** con lo stream già aperto (`FileDaCaricare`), e lo
chiude il componente: il chiamante scrive solo cosa fare del contenuto. `OnCompletato` riceve il
riepilogo (`EsitoCaricamento`).

**`EstensioniAmmesse` è controllata lato applicazione**, non solo con `Accept`: quell'attributo è un
suggerimento del browser e si aggira trascinando un file.

**Usato da:** `WebImmaginiLibreriaPage` (multiplo) e `WebIndirizzoDialog` (icona social, solo PNG).
**Da migrare:** `WebTourGalleriaTab`, `WebTourMappaTab`, `AziendaLogoDialog`, `ClienteDialog`,
`OracleImport` — funzionano, ma quattro di questi non hanno un limite di dimensione.

## PosizioneSelect

`Components/Shared/PosizioneSelect.razor` — scelta di una posizione orizzontale
(sinistra / centro / destra).

Le voci **non sono scritte nel componente**: arrivano da `NewsletterLayout.Posizioni`
(`Models/Web/NewsletterDefinizioni.cs`), che è il catalogo unico di questo concetto. Ogni
posizione vi porta con sé le tre forme in cui serve:

| Campo | A cosa serve | Chi lo usa |
|---|---|---|
| `Codice` | valore salvato a database (`sinistra` \| `centro` \| `destra`) | il vincolo CHECK su `web_newsletter_blocchi.layout` e `layout_pulsante` |
| `Etichetta` | testo mostrato all'utente | `PosizioneSelect` |
| `Css` | allineamento HTML (`left` \| `center` \| `right`) | `NewsletterHtmlRenderer`, l'anteprima del piè di pagina |
| `Casella` | colonna nella fila di pulsanti (0, 1, 2) | `RenderPulsantiInFila` |

Prima la stessa corrispondenza era **riscritta quattro volte** in forme scollegate: due `switch`
nel renderer, un array `{ "left", "center", "right" }` e un ternario nell'anteprima — più i tre
elenchi di voci nelle form. Un codice nuovo, o un refuso in uno solo di quei punti, dava un
valore che nessuna mappatura riconosceva: il contenuto finiva a sinistra senza alcun errore.

```razor
<PosizioneSelect @bind-Value="Blocco.Layout" Label="Allineamento"
                 HelperText="Come viene allineato il contenuto." />

@* Clearable dove "nessuna scelta" ha un senso suo: sul pulsante significa
   "segui la posizione dell'immagine". *@
<PosizioneSelect @bind-Value="Blocco.LayoutPulsante" Label="Posizione del pulsante"
                 Clearable="true" HelperText="Vuoto = segue la posizione dell'immagine." />
```

Per l'allineamento CSS usare sempre `NewsletterLayout.Css(codice, cssDiRiserva)`. Il valore di
riserva è un parametro perché **non è lo stesso ovunque**: un blocco nasce a sinistra, il piè di
pagina nasce centrato. Appiattirlo su un unico default cambierebbe di nascosto le newsletter già
composte.

**Quando NON usarlo.** Dove il vocabolario è diverso, e nel dialogo dei blocchi lo è in due punti:
l'icona del riquadro informativo ammette solo sinistra e destra (a piena larghezza non è una
disposizione possibile), e l'immagine di tour e riquadri aggiunge `pieno` con etichette che
descrivono anche dove finisce il testo. Sono scelte diverse, non tre posizioni: vanno lasciate
com'è. Il catalogo copre la posizione orizzontale, non ogni menù che le somiglia.
