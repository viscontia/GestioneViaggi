using GestioneViaggi.Models;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.CRUD;
using Microsoft.AspNetCore.Components;
using System.Globalization;

namespace GestioneViaggi.Components.Shared;

public partial class TravelCalendar : ComponentBase
{
    [Inject] private AnaViaggiService ViaggiService { get; set; } = null!;

    /// <summary>
    /// ID dell'azienda per cui caricare i viaggi (obbligatorio)
    /// </summary>
    [Parameter, EditorRequired]
    public int AziendaId { get; set; }

    /// <summary>
    /// Callback quando viene cliccato un viaggio
    /// </summary>
    [Parameter]
    public EventCallback<CalendarTravelDTO> OnTravelClick { get; set; }

    private const int MaxVisibleTravels = 3;

    private DateTime _currentDate = DateTime.Today;
    private List<CalendarTravelDTO> _travels = new();
    private List<DateTime[]> _weeks = new();
    private bool _isLoading = true;
    private int _lastLoadedAziendaId;

    private readonly CultureInfo _culture = new("it-IT");
    private readonly string[] _dayNames = { "Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom" };

    protected override async Task OnInitializedAsync()
    {
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    protected override async Task OnParametersSetAsync()
    {
        // Ricarica se cambia l'azienda
        if (AziendaId != _lastLoadedAziendaId && AziendaId > 0)
        {
            await LoadTravelsAsync();
        }
    }

    private async Task LoadTravelsAsync()
    {
        if (AziendaId <= 0) return;

        _isLoading = true;
        StateHasChanged();

        try
        {
            _travels = await ViaggiService.GetCalendarDataAsync(
                _currentDate.Year,
                _currentDate.Month,
                AziendaId);
            _lastLoadedAziendaId = AziendaId;
        }
        catch
        {
            _travels = new();
        }
        finally
        {
            _isLoading = false;
            StateHasChanged();
        }
    }

    private void BuildCalendarGrid()
    {
        _weeks = new List<DateTime[]>();

        // Primo giorno del mese
        var firstDayOfMonth = new DateTime(_currentDate.Year, _currentDate.Month, 1);

        // Trova il lunedi della prima settimana
        var startDate = firstDayOfMonth;
        while (startDate.DayOfWeek != DayOfWeek.Monday)
        {
            startDate = startDate.AddDays(-1);
        }

        // Genera 6 settimane per coprire tutti i mesi possibili
        var currentDay = startDate;
        for (int week = 0; week < 6; week++)
        {
            var weekDays = new DateTime[7];
            for (int day = 0; day < 7; day++)
            {
                weekDays[day] = currentDay;
                currentDay = currentDay.AddDays(1);
            }
            _weeks.Add(weekDays);

            // Se abbiamo superato il mese corrente e siamo nel mese successivo, possiamo fermarci
            if (weekDays[0].Month > _currentDate.Month && weekDays[0].Year >= _currentDate.Year)
            {
                break;
            }
        }
    }

    private List<CalendarTravelDTO> GetTravelsForDay(DateTime day)
    {
        return _travels
            .Where(t => day.Date >= t.DataInizio.Date && day.Date <= t.DataFine.Date)
            .OrderBy(t => t.DataInizio)
            .ThenBy(t => t.DescrizioneViaggio)
            .ToList();
    }

    private async Task PreviousMonth()
    {
        _currentDate = _currentDate.AddMonths(-1);
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    private async Task NextMonth()
    {
        _currentDate = _currentDate.AddMonths(1);
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    private async Task GoToToday()
    {
        _currentDate = DateTime.Today;
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    private async Task HandleTravelClick(CalendarTravelDTO travel)
    {
        if (OnTravelClick.HasDelegate)
        {
            await OnTravelClick.InvokeAsync(travel);
        }
    }

    private static string GetTravelChipStyle(TravelStatus status)
    {
        var baseStyle = "font-size: 0.7rem; padding: 2px 6px; border-radius: 4px; cursor: pointer; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;";

        return status switch
        {
            TravelStatus.Completed => $"{baseStyle} background-color: #c8e6c9; color: #2e7d32; border-left: 3px solid #4caf50;",
            TravelStatus.Future => $"{baseStyle} background-color: #fff3e0; color: #ef6c00; border-left: 3px solid #ff9800;",
            TravelStatus.NotCompleted => $"{baseStyle} background-color: #ffcdd2; color: #c62828; border-left: 3px solid #f44336;",
            _ => baseStyle
        };
    }

    private static string TruncateText(string text, int maxLength)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        return text.Length <= maxLength ? text : text[..maxLength] + "...";
    }
}
