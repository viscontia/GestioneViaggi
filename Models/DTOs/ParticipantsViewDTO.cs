namespace GestioneViaggi.Models.DTOs;

public class ParticipantsViewDTO
{
    public int ViaggioId { get; set; }
    public int DataId { get; set; }
    public int ClienteId { get; set; }
    public string Nominativo { get; set; } = string.Empty;
    public int TipoPartecipanteId { get; set; }
    public string Ruolo { get; set; } = string.Empty;
    public string? Note { get; set; }
    public string? CaneSino { get; set; }
    public string? Intolleranze { get; set; }

    // Vehicle Details (Computed by DB Function)
    public string? MezzoDettagli { get; set; }

    public int? ClientePilotaId { get; set; }
    public int GroupingKey { get; set; }
    public bool IsPilot { get; set; }
    public string? Email { get; set; }
}
