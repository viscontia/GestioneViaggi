namespace GestioneViaggi.Models;

public class PasswordResetResponse
{
    public bool Success { get; set; }
    public bool UserFound { get; set; }
    public string? ResetCode { get; set; }
    public Guid? UserId { get; set; }
    public string? Email { get; set; }
    public string? Nome { get; set; }
    public int? AziendaId { get; set; }
    public string? RoleCode { get; set; }
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
}
