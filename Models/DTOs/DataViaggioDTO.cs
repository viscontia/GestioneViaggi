namespace GestioneViaggi.Models.DTOs;

public class DataViaggioDTO
{
    public int DataViaggioId { get; set; }
    public int ViaggioIdFk { get; set; }
    public DateTime DataInizio { get; set; }
    public DateTime DataFine { get; set; }
    public string? Effettuato { get; set; }

    public string DisplayText => $"{DataInizio:dd/MM/yyyy} - {DataFine:dd/MM/yyyy}";
}
