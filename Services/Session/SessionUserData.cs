namespace GestioneViaggi.Services.Session;

public class SessionUserData
{
    public Guid UserId { get; set; }
    public string TenantId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string Cognome { get; set; } = string.Empty;
    public string? RoleCode { get; set; }
    public string? RoleName { get; set; }
    public int? AziendaId { get; set; }
    public DateTime? LastLoginAt { get; set; }
}
