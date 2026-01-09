namespace GestioneViaggi.Models.DTOs;

public class ViaggioPartecipantiGruppoDTO
{
    public int GruppoId { get; set; }
    public string PilotaNominativo { get; set; } = string.Empty;
    public string PasseggeriNominativi { get; set; } = string.Empty;
}
