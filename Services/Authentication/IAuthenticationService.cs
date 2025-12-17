using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Authentication;

public interface IAuthenticationService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task LogoutAsync();
    Task<UserInfo?> GetCurrentUserAsync();
    bool IsAuthenticated();
    Task<bool> IsDbConnectableAsync();
}
