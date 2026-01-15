using System;

namespace GestioneViaggi.Models.DTOs;

public class AuditLoginDTO
{
    public Guid LoginId { get; set; }
    public Guid UserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string? Ip { get; set; }
    public string? UserAgent { get; set; }

    // Joined fields from AppUsers
    public string? Email { get; set; }
    public string? Nome { get; set; }
    public string? Cognome { get; set; }

    // Helper
    public string FullName => $"{Nome} {Cognome}".Trim();
}
