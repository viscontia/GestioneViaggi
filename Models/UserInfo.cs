namespace GestioneViaggi.Models;

public class UserInfo
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

    public string FullName => $"{Nome} {Cognome}".Trim();
    public bool IsSuperAdmin => RoleCode?.ToLower() == "superadmin";
}
