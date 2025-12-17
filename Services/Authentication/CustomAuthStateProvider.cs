using GestioneViaggi.Services.Session;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.Extensions.Logging;
using System.Security.Claims;

namespace GestioneViaggi.Services.Authentication;

public class CustomAuthStateProvider : AuthenticationStateProvider
{
    private readonly IAuthenticationService _authService;
    private readonly ISessionManager _sessionManager;
    private readonly ILogger<CustomAuthStateProvider> _logger;

    public CustomAuthStateProvider(
        IAuthenticationService authService,
        ISessionManager sessionManager,
        ILogger<CustomAuthStateProvider> logger)
    {
        _authService = authService;
        _sessionManager = sessionManager;
        _logger = logger;
    }

    public override async Task<AuthenticationState> GetAuthenticationStateAsync()
    {
        try
        {
            var user = await _authService.GetCurrentUserAsync();

            if (user == null)
            {
                _logger.LogDebug("No authenticated user found");
                return new AuthenticationState(new ClaimsPrincipal(new ClaimsIdentity()));
            }

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Name, user.FullName),
                new Claim("TenantId", user.TenantId)
            };

            if (!string.IsNullOrEmpty(user.RoleCode))
            {
                claims.Add(new Claim(ClaimTypes.Role, user.RoleCode));
            }

            if (user.AziendaId.HasValue)
            {
                claims.Add(new Claim("AziendaId", user.AziendaId.Value.ToString()));
            }

            var identity = new ClaimsIdentity(claims, "Custom");
            var principal = new ClaimsPrincipal(identity);

            _logger.LogDebug("Authentication state resolved for user: {Email}", user.Email);
            return new AuthenticationState(principal);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting authentication state");
            return new AuthenticationState(new ClaimsPrincipal(new ClaimsIdentity()));
        }
    }

    public void NotifyAuthenticationStateChanged()
    {
        NotifyAuthenticationStateChanged(GetAuthenticationStateAsync());
    }

    public async Task<bool> ValidateSessionAsync()
    {
        var session = await _sessionManager.GetSessionAsync();
        
        if (session?.IsExpired ?? true)
        {
            _logger.LogWarning("Session is invalid or expired");
            await _sessionManager.ClearSessionAsync();
            NotifyAuthenticationStateChanged();
            return false;
        }

        _logger.LogDebug("Session is valid");
        return true;
    }
}
