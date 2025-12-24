using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Session;

public interface ISessionManager
{
    Task InitializeAsync();
    Task SaveSessionAsync(UserInfo user, string sessionToken);
    Task<SessionData?> GetSessionAsync();
    Task ClearSessionAsync();
    bool IsSessionValid();
    Task<bool> RefreshSessionAsync();
    int? GetCurrentAziendaId();
    Task<string?> GetLastLoginEmailAsync();
    Task ClearPersistedDataAsync();
}

