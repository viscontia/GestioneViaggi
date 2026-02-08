namespace GestioneViaggi.Models;

public class UserInfo
{
    public Guid UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string Cognome { get; set; } = string.Empty;
    public string? RoleCode { get; set; }
    public string? RoleName { get; set; }
    public int? AziendaId { get; set; }
    public string? RagioneSocialeAzienda { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DataNascita { get; set; }
    public DateTime? LastLoginAt { get; set; }
    public int? ValutaDefaultId { get; set; }
    public string ValutaCodiceIso { get; set; } = "EUR";

    public string FullName => $"{Nome} {Cognome}".Trim();
    public bool IsSuperAdmin => RoleCode?.ToLower() == "superadmin";

    /// <summary>
    /// Username per audit trail database (usa email come identificatore univoco)
    /// </summary>
    public string Username => Email;
}
