using GestioneViaggi.Models;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Models.Web;
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
    private int _annoScelto = DateTime.Today.Year;
    private int _meseScelto = DateTime.Today.Month;

    private readonly CultureInfo _culture = new("it-IT");
    private readonly string[] _dayNames = { "Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom" };

    protected override async Task OnInitializedAsync()
    {
        await PosizionaSullePartenzeAsync();
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    protected override async Task OnParametersSetAsync()
    {
        // Ricarica se cambia l'azienda
        if (AziendaId != _lastLoadedAziendaId && AziendaId > 0)
        {
            // Cambiando azienda cambiano le partenze, quindi cambia anche il mese giusto su cui
            // stare: restare sul mese di prima mostrerebbe un calendario vuoto di un'altra azienda.
            await PosizionaSullePartenzeAsync();
            BuildCalendarGrid();
            await LoadTravelsAsync();
        }
    }

    /// <summary>
    /// Porta il calendario sul mese della prossima partenza invece che su quello corrente.
    /// </summary>
    /// <remarks>
    /// Aprirsi sul mese corrente sembra naturale ma mente: a novembre, con la prossima partenza a
    /// marzo, si vede un calendario vuoto e si conclude che non c'è niente in programma.
    /// </remarks>
    private async Task PosizionaSullePartenzeAsync()
    {
        if (AziendaId <= 0) return;

        _currentDate = await ViaggiService.GetCalendarMeseInizialeAsync(AziendaId);
        _annoScelto = _currentDate.Year;
        _meseScelto = _currentDate.Month;
    }

    /// <summary>Anni proposti nelle tendine: un margine attorno all'anno corrente e a quello scelto.</summary>
    private IEnumerable<int> AnniDisponibili
    {
        get
        {
            var minimo = Math.Min(DateTime.Today.Year, _annoScelto) - 2;
            var massimo = Math.Max(DateTime.Today.Year, _annoScelto) + 2;
            for (var anno = minimo; anno <= massimo; anno++) yield return anno;
        }
    }

    private async Task OnAnnoChanged(int anno)
    {
        _annoScelto = anno;
        await VaiAlMeseSceltoAsync();
    }

    private async Task OnMeseChanged(int mese)
    {
        _meseScelto = mese;
        await VaiAlMeseSceltoAsync();
    }

    private async Task VaiAlMeseSceltoAsync()
    {
        _currentDate = new DateTime(_annoScelto, _meseScelto, 1);
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    /// <summary>Tiene le tendine allineate quando ci si sposta con le frecce o con «Oggi».</summary>
    private void AllineaTendine()
    {
        _annoScelto = _currentDate.Year;
        _meseScelto = _currentDate.Month;
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
        AllineaTendine();
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    private async Task NextMonth()
    {
        _currentDate = _currentDate.AddMonths(1);
        AllineaTendine();
        BuildCalendarGrid();
        await LoadTravelsAsync();
    }

    private async Task GoToToday()
    {
        _currentDate = DateTime.Today;
        AllineaTendine();
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

    /// <summary>
    /// I tre colori del calendario, uno per livello di stato.
    /// </summary>
    /// <remarks>
    /// ⛔️ Sono qui e non duplicati fra targhette e legenda: quando i colori sono stati riportati al
    /// vocabolario di <c>StatoPartenzaChip</c> (blu = conclusa, ambra = anomalia, neutro = in
    /// programma) la legenda è rimasta a quelli di prima — verde/arancio/rosso — e per settimane ha
    /// spiegato colori che il calendario non usava più. Due copie divergono sempre: con una sola
    /// fonte, cambiare un colore lo cambia in entrambi i posti.
    /// </remarks>
    private static (string Sfondo, string Testo, string Bordo) ColoriPerLivello(LivelloStatoPartenza livello)
        => livello switch
        {
            LivelloStatoPartenza.Conclusa => ("#e3f2fd", "#1565c0", "#2196f3"),
            LivelloStatoPartenza.Anomalia => ("#fff3e0", "#ef6c00", "#ff9800"),
            _                             => ("#eeeeee", "#424242", "#9e9e9e")
        };

    /// <summary>
    /// Le tre voci della legenda, con la stessa etichetta che compare nel dettaglio di una partenza.
    /// </summary>
    /// <remarks>
    /// Le etichette non sono riscritte a mano: si chiedono a <see cref="StatoPartenzaRules"/>
    /// costruendo un caso rappresentativo per ciascun livello, così la legenda dice esattamente le
    /// parole che l'utente ritrova passando il mouse su una targhetta.
    /// </remarks>
    private static IEnumerable<(string Etichetta, string Colore)> VociLegenda()
    {
        var oggi = DateTime.Today;
        var ieri = oggi.AddDays(-1);
        var domani = oggi.AddDays(1);

        // (effettuato, dataFine) scelti per produrre un livello ciascuno:
        //   in programma = non effettuata e non ancora conclusa
        //   effettuata   = effettuata e conclusa
        //   anomalia     = conclusa ma non registrata
        foreach (var (effettuato, fine) in new[] { (false, domani), (true, ieri), (false, ieri) })
        {
            var stato = StatoPartenzaRules.Valuta(effettuato, fine, oggi);
            yield return (stato.Etichetta, ColoriPerLivello(stato.Livello).Bordo);
        }
    }

    /// <summary>Stile della targhetta di una partenza nel calendario.</summary>
    private static string GetTravelChipStyle(CalendarTravelDTO travel)
    {
        const string baseStyle = "font-size: 0.7rem; padding: 2px 6px; border-radius: 4px; cursor: pointer; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;";

        var livello = StatoPartenzaRules.Valuta(travel.Effettuato, travel.DataFine, DateTime.Today).Livello;
        var (sfondo, testo, bordo) = ColoriPerLivello(livello);

        return $"{baseStyle} background-color: {sfondo}; color: {testo}; border-left: 3px solid {bordo};";
    }

    private static string TruncateText(string text, int maxLength)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        return text.Length <= maxLength ? text : text[..maxLength] + "...";
    }
}
