namespace GestioneViaggi.Models;

/// <summary>
/// DTO per lo storico viaggi completo di un cliente.
/// Mappa i risultati della function get_client_travel_history.
/// </summary>
public class ClienteTravelHistory
{
    public int DataViaggioId { get; set; }
    public string Titolo { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;

    public DateTime DataInizio { get; set; }
    public DateTime DataFine { get; set; }

    public int Km { get; set; }
    public int Giorni { get; set; }
    public int Notti { get; set; }

    public int StatusCode { get; set; } // 0=Futuro, 1=Fatto, 2=NoPart
    public string StatusDesc { get; set; } = string.Empty;

    public string Ruolo { get; set; } = string.Empty;

    // Popolato separatamente
    public string CompagniViaggio { get; set; } = string.Empty;
}

/// <summary>
/// DTO per i passeggeri di un viaggio.
/// Mappa i risultati della function get_travel_passengers.
/// </summary>
public class TravelPassenger
{
    public string Nominativo { get; set; } = string.Empty;
    public string Ruolo { get; set; } = string.Empty;
}
