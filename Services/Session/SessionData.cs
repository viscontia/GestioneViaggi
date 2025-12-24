using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Session;

public class SessionData
{
    public string SessionToken { get; set; } = string.Empty;
    public UserInfo User { get; set; } = new();
    public DateTime IssuedAt { get; set; }
    public DateTime ExpiresAt { get; set; }

    public bool IsExpired => DateTime.UtcNow >= ExpiresAt;
    public bool IsValid => !IsExpired && !string.IsNullOrEmpty(SessionToken) && User != null;
}
