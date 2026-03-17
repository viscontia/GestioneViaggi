namespace GestioneViaggi.Models.DTOs;

/// <summary>
/// DTO per i dati del calendario viaggi
/// </summary>
public class CalendarTravelDTO
{
    public int DataViaggioId { get; set; }
    public int ViaggioId { get; set; }
    public string DescrizioneViaggio { get; set; } = string.Empty;
    public DateTime DataInizio { get; set; }
    public DateTime DataFine { get; set; }
    public int TotClienti { get; set; }
    public TravelStatus Status { get; set; }
    public int AziendaId { get; set; }
    public string AziendaNome { get; set; } = string.Empty;

    /// <summary>
    /// Calcola lo stato del viaggio basandosi su EffettuatoSino e DataInizio
    /// </summary>
    public static TravelStatus ComputeStatus(char effettuatoSino, DateTime dataInizio)
    {
        if (effettuatoSino == 'Y' || effettuatoSino == 'S')
            return TravelStatus.Completed;

        if (dataInizio.Date > DateTime.Today)
            return TravelStatus.Future;

        return TravelStatus.NotCompleted;
    }
}
