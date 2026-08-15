using GestioneViaggi.Models;
using Microsoft.AspNetCore.Components;
using MudBlazor;

namespace GestioneViaggi.Components.Shared;

public partial class TravelDataSelectorDialog
{
    [CascadingParameter] private IMudDialogInstance MudDialog { get; set; } = default!;

    [Parameter] public int AziendaId { get; set; }
    [Parameter] public bool IsSuperAdmin { get; set; }
    [Parameter] public PrintType PrintType { get; set; } = PrintType.TravelDataSheet;

    /// <summary>
    /// Titolo del dialogo. Se valorizzato prevale su quello ricavato da <see cref="PrintType"/>.
    /// Serve a riusare il selettore fuori dal contesto stampa (es. scelta dell'edizione per un
    /// riquadro tour della newsletter) senza doverlo duplicare.
    /// </summary>
    [Parameter] public string? TitoloPersonalizzato { get; set; }

    /// <summary>Etichetta del pulsante di conferma. Se valorizzata prevale su quella da PrintType.</summary>
    [Parameter] public string? EtichettaConferma { get; set; }

    // State Variables
    private int _selectedAziendaId;
    private int? _selectedTripId;
    private int? _selectedDateId;
    private List<AnaDataViaggio>? _dates;
    private List<TravelTreeData>? _treeData;
    private TravelTreeNode? _selectedTreeNode;
    private int? _yearToExpandByDefault;
    private int _activeTabIndex = 0;

    // TreeView expansion state tracking
    private Dictionary<int, bool> _yearExpansionState = new();
    private Dictionary<string, bool> _viaggioExpansionState = new();

    // Loading States
    private bool _isLoadingDates;
    private bool _isLoadingTree;

    // Computed Properties
    private bool _canShowSelectors => !IsSuperAdmin || _selectedAziendaId > 0;
    private AnaDataViaggio? _selectedDate => _dates?.FirstOrDefault(d => d.Id == _selectedDateId);

    protected override async Task OnInitializedAsync()
    {
        _selectedAziendaId = AziendaId;

        // Se non è SuperAdmin, carica subito i dati
        if (!IsSuperAdmin && _selectedAziendaId > 0)
        {
            await LoadTreeDataAsync();
        }
    }

    protected override async Task OnParametersSetAsync()
    {
        // Watch for AziendaId changes (from SuperAdmin selection)
        if (_selectedAziendaId != AziendaId && AziendaId > 0)
        {
            await OnAziendaChangedAsync();
        }
    }

    private async Task OnAziendaSelected(int aziendaId)
    {
        _selectedAziendaId = aziendaId;
        await OnAziendaChangedAsync();
    }

    private async Task OnAziendaChangedAsync()
    {
        // Reset tutto quando cambia azienda
        _selectedTripId = null;
        _selectedDateId = null;
        _dates = null;
        _treeData = null;
        _selectedTreeNode = null;
        _yearToExpandByDefault = null;
        _yearExpansionState.Clear();
        _viaggioExpansionState.Clear();

        if (_selectedAziendaId > 0)
        {
            // Carica TreeData solo per la tab "Per Anno"
            // Per la tab "Ricerca Rapida", ViaggiSelect si auto-carica
            if (_activeTabIndex == 1) // Tab TreeView
            {
                await LoadTreeDataAsync();
            }
        }
    }

    private async Task OnTripSelectedFromCombobox(int? tripId)
    {
        _selectedTripId = tripId;
        _selectedDateId = null;

        await LoadDatesAsync();
    }

    private async Task LoadDatesAsync()
    {
        _dates = null;

        if (_selectedTripId.HasValue)
        {
            _isLoadingDates = true;
            StateHasChanged();
            try
            {
                _dates = await ViaggiService.GetDatesByTripIdAsync(_selectedTripId.Value);
            }
            catch (Exception ex)
            {
                Snackbar.Add($"Errore caricamento date: {ex.Message}", Severity.Error);
            }
            finally
            {
                _isLoadingDates = false;
            }
        }
    }

    private async Task LoadTreeDataAsync()
    {
        _isLoadingTree = true;
        StateHasChanged();

        try
        {
            _treeData = await ViaggiService.GetTravelTreeDataAsync(
                _selectedAziendaId > 0 ? _selectedAziendaId : null
            );

            // Determina l'anno da espandere automaticamente
            if (_treeData != null && _treeData.Any())
            {
                var currentYear = DateTime.Today.Year;
                _yearToExpandByDefault = _treeData.Any(x => x.Anno == currentYear)
                    ? currentYear
                    : _treeData.Select(x => x.Anno).Max(); // Altrimenti l'anno più recente

                // Inizializza lo stato di espansione degli anni
                _yearExpansionState.Clear();
                foreach (var anno in _treeData.Select(x => x.Anno).Distinct())
                {
                    _yearExpansionState[anno] = anno == _yearToExpandByDefault;
                }
            }
        }
        catch (Exception ex)
        {
            Snackbar.Add($"Errore caricamento TreeView: {ex.Message}", Severity.Error);
            _treeData = new List<TravelTreeData>();
        }
        finally
        {
            _isLoadingTree = false;
        }
    }

    private async Task OnTabChanged(int newTabIndex)
    {
        _activeTabIndex = newTabIndex;

        // Quando si passa alla tab TreeView, carica i dati se necessario
        if (newTabIndex == 1 && _treeData == null && _selectedAziendaId > 0)
        {
            await LoadTreeDataAsync();
        }

        // Sincronizza la selezione tra tab quando si cambia
        if (newTabIndex == 1 && _selectedTripId.HasValue && _selectedDateId.HasValue)
        {
            // Passaggio a TreeView: cerca e seleziona il nodo corrispondente
            SyncComboboxToTreeView();
        }
    }

    private void SyncComboboxToTreeView()
    {
        if (_treeData == null || !_selectedTripId.HasValue || !_selectedDateId.HasValue)
            return;

        var matchingData = _treeData.FirstOrDefault(x =>
            x.ViaggioId == _selectedTripId.Value &&
            x.DataViaggioId == _selectedDateId.Value);

        if (matchingData != null)
        {
            _selectedTreeNode = new TravelTreeNode
            {
                Type = TravelTreeNodeType.DataViaggio,
                Year = matchingData.Anno,
                ViaggioId = matchingData.ViaggioId,
                DataViaggioId = matchingData.DataViaggioId,
                DisplayText = GetDateDisplayText(matchingData)
            };
        }
    }

    private async Task OnTreeNodeSelected(TravelTreeNode? node)
    {
        _selectedTreeNode = node;
        
        if (node == null) return;

        if (node.Type == TravelTreeNodeType.Year && node.Year.HasValue)
        {
            ToggleYearExpansion(node.Year.Value);
        }
        else if (node.Type == TravelTreeNodeType.Viaggio && node.ViaggioId.HasValue && node.Year.HasValue)
        {
            var key = GetViaggioKey(node.Year.Value, node.ViaggioId.Value);
            ToggleViaggioExpansion(key);
        }
        else if (node.Type == TravelTreeNodeType.DataViaggio)
        {
            await SelezionaPartenzaAsync(node);
        }
    }

    /// <summary>
    /// Sceglie una partenza dall'albero, allineando anche la scheda "Ricerca Rapida".
    /// </summary>
    /// <remarks>
    /// Chiamata da DUE strade: la selezione del TreeView e il clic diretto sulla foglia. Una sola
    /// delle due basterebbe, ma quale sia dipende da come il TreeView interpreta il clic — ed e'
    /// esattamente cio' che non funzionava: la partenza si evidenziava e non risultava scelta.
    /// Essendo idempotente, arrivarci due volte non fa danno.
    /// </remarks>
    private async Task SelezionaPartenzaAsync(TravelTreeNode node)
    {
        if (!node.DataViaggioId.HasValue) return;

        _selectedTreeNode = node;

        var viaggioId = node.ViaggioId;
        var dataViaggioId = node.DataViaggioId.Value;

        // Le date del viaggio servono anche alla scheda "Ricerca Rapida" e al riepilogo:
        // senza, la partenza risulta scelta ma non se ne vede il dettaglio.
        if (_selectedTripId != viaggioId || _dates == null)
        {
            _selectedTripId = viaggioId;
            await LoadDatesAsync();
        }

        _selectedDateId = dataViaggioId;

        StateHasChanged();
    }

    private void OnDateSelectedFromCombobox(int? dateId)
    {
        _selectedDateId = dateId;

        // Sincronizza con TreeView
        if (_selectedDateId.HasValue && _treeData != null)
        {
            var matchingData = _treeData.FirstOrDefault(x => x.DataViaggioId == _selectedDateId.Value);
            if (matchingData != null)
            {
                _selectedTreeNode = new TravelTreeNode
                {
                    Type = TravelTreeNodeType.DataViaggio,
                    Year = matchingData.Anno,
                    ViaggioId = matchingData.ViaggioId,
                    DataViaggioId = matchingData.DataViaggioId,
                    DisplayText = GetDateDisplayText(matchingData)
                };
            }
        }
    }

    private string GetDateDisplayText(TravelTreeData data)
    {
        var result = data.DataInizio?.ToString("dd/MM/yyyy") ?? "N/D";
        if (data.DataFine.HasValue)
        {
            result += $" - {data.DataFine.Value:dd/MM/yyyy}";
        }
        return result;
    }

    private void Cancel() => MudDialog.Cancel();

    private void Submit()
    {
        if (_selectedDateId.HasValue)
        {
            MudDialog.Close(DialogResult.Ok(_selectedDateId.Value));
        }
    }

    private bool IsValid() => _selectedTripId.HasValue && _selectedDateId.HasValue;

    private string GetDialogTitle()
    {
        return string.IsNullOrWhiteSpace(TitoloPersonalizzato)
            ? PrintType.GetDisplayName()
            : TitoloPersonalizzato!;
    }

    private string GetActionButtonText()
    {
        if (!string.IsNullOrWhiteSpace(EtichettaConferma)) return EtichettaConferma!;

        return PrintType switch
        {
            PrintType.TravelDataSheet => "Stampa Scheda",
            PrintType.TravelDataSheetDetailed => "Stampa Dettaglio",
            PrintType.PassengerList => "Stampa Lista",
            PrintType.RoomingList => "Stampa Rooming List",
            PrintType.InvoiceReport => "Genera Report",
            PrintType.CustomReport => "Genera",
            _ => "Stampa"
        };
    }

    private bool IsYearExpanded(int year)
    {
        return _yearExpansionState.TryGetValue(year, out var expanded) && expanded;
    }

    private void ToggleYearExpansion(int year)
    {
        if (_yearExpansionState.ContainsKey(year))
        {
            _yearExpansionState[year] = !_yearExpansionState[year];
        }
        else
        {
            _yearExpansionState[year] = true;
        }
        StateHasChanged();
    }

    private bool IsViaggioExpanded(string viaggioKey)
    {
        return _viaggioExpansionState.TryGetValue(viaggioKey, out var expanded) && expanded;
    }

    private void ToggleViaggioExpansion(string viaggioKey)
    {
        if (_viaggioExpansionState.ContainsKey(viaggioKey))
        {
            _viaggioExpansionState[viaggioKey] = !_viaggioExpansionState[viaggioKey];
        }
        else
        {
            _viaggioExpansionState[viaggioKey] = true;
        }
        StateHasChanged();
    }

    private string GetViaggioKey(int year, int viaggioId)
    {
        return $"{year}_{viaggioId}";
    }
}
