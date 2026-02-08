using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace GestioneViaggi.Services.Authentication;

public class AuthenticationService : IAuthenticationService
{
    private readonly IDatabaseService _database;
    private readonly ISessionManager _sessionManager;
    private readonly ILogger<AuthenticationService> _logger;
    private UserInfo? _currentUser;

    public AuthenticationService(
        IDatabaseService database,
        ISessionManager sessionManager,
        ILogger<AuthenticationService> logger)
    {
        _database = database;
        _sessionManager = sessionManager;
        _logger = logger;
    }

    public async Task<bool> IsDbConnectableAsync()
    {
        try
        {
            var result = await _database.ExecuteFunctionAsync<JsonElement>("fn_app_health_check");
            return result.ValueKind != JsonValueKind.Undefined && result.ValueKind != JsonValueKind.Null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed");
            return false;
        }
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        try
        {
            _logger.LogInformation("Attempting login for user: {Email}", request.Email);

            var dbResponse = await _database.ExecuteFunctionAsync<JsonElement>(
                "fn_app_login_text",
                ("p_email", request.Email),
                ("p_password", request.Password)
            );

            _logger.LogDebug("Database response: {Response}", dbResponse.ToString());

            if (dbResponse.ValueKind == JsonValueKind.Undefined || dbResponse.ValueKind == JsonValueKind.Null)
            {
                _logger.LogError("Database returned null or undefined response");
                return new LoginResponse
                {
                    Success = false,
                    Error = "Data Base non raggiungibile: rivolgersi all'assistenza tecnica."
                };
            }

            if (!dbResponse.TryGetProperty("success", out var successProp))
            {
                _logger.LogError("Database response missing 'success' property");
                return new LoginResponse
                {
                    Success = false,
                    Error = "Risposta inaspettata dal database: rivolgersi all'assistenza tecnica."
                };
            }

            var success = successProp.GetBoolean();
            _logger.LogInformation("Login success flag: {Success}", success);

            if (!success)
            {
                var errorCode = dbResponse.TryGetProperty("error", out var errorProp)
                    ? errorProp.GetString()
                    : "UNKNOWN_ERROR";

                _logger.LogWarning("Login failed for {Email} with error code: {ErrorCode}", request.Email, errorCode);

                var errorMessage = errorCode switch
                {
                    "USER_NOT_FOUND" => "Utente non abilitato all'uso dell'applicazione: rivolgersi all'Amministratore",
                    "INVALID_PASSWORD" => "Utente non abilitato all'uso dell'applicazione: rivolgersi all'Amministratore",
                    "USER_SUSPENDED_OR_INACTIVE" => "Utente non abilitato all'uso dell'applicazione: rivolgersi all'Amministratore",
                    _ => $"Utente non abilitato all'uso dell'applicazione: rivolgersi all'Amministratore [{errorCode}]"
                };

                return new LoginResponse
                {
                    Success = false,
                    Error = errorMessage
                };
            }

            if (!dbResponse.TryGetProperty("user", out var userElement))
            {
                _logger.LogError("Database response missing 'user' property for successful login");
                return new LoginResponse
                {
                    Success = false,
                    Error = "Risposta inaspettata dal database: rivolgersi all'assistenza tecnica."
                };
            }

            _logger.LogDebug("Parsing user data from database response");

            try
            {
                var user = new UserInfo
                {
                    UserId = Guid.Parse(userElement.GetProperty("user_id").GetString()!),
                    Email = userElement.GetProperty("email").GetString() ?? string.Empty,
                    Nome = userElement.GetProperty("nome").GetString() ?? string.Empty,
                    Cognome = userElement.GetProperty("cognome").GetString() ?? string.Empty,
                    RoleCode = userElement.TryGetProperty("role_code", out var roleProp)
                        ? roleProp.GetString()
                        : null,
                    RoleName = userElement.TryGetProperty("role_name", out var roleNameProp)
                        ? roleNameProp.GetString()
                        : null,
                    AziendaId = userElement.TryGetProperty("azienda_id", out var aziendaProp) && aziendaProp.ValueKind != JsonValueKind.Null
                        ? aziendaProp.GetInt32()
                        : null,
                    ValutaDefaultId = userElement.TryGetProperty("valuta_default_id", out var valutaProp) && valutaProp.ValueKind != JsonValueKind.Null
                        ? valutaProp.GetInt32()
                        : null,
                    LastLoginAt = ParseDateTime(userElement, "last_login_at")
                };

                _logger.LogInformation("User data parsed: UserId={UserId}, Email={Email}, Role={Role}",
                    user.UserId, user.Email, user.RoleCode);

                _currentUser = user;

                var sessionToken = GenerateSessionToken(user.UserId);
                _logger.LogDebug("Generated session token for user: {Email}", user.Email);

                await _sessionManager.SaveSessionAsync(user, sessionToken);
                _logger.LogInformation("Session saved successfully for user: {Email}", user.Email);

                _logger.LogInformation("Login successful and session saved for user: {Email}, Role: {Role}",
                    user.Email, user.RoleCode);

                return new LoginResponse
                {
                    Success = true,
                    User = user
                };
            }
            catch (ArgumentNullException ex)
            {
                var userElementJson = userElement.ToString();
                _logger.LogError(ex, "ArgumentNull during user parsing: {Message}", ex.Message);
                return new LoginResponse
                {
                    Success = false,
                    Error = $"Errore durante l'elaborazione dei dati utente (Null): {ex.ParamName}"
                };
            }
            catch (JsonException ex)
            {
                var userElementJson = userElement.ToString();
                _logger.LogError(ex, "JSON parsing error during user data extraction");
                return new LoginResponse
                {
                    Success = false,
                    Error = $"Errore durante l'elaborazione dei dati utente (JSON): {ex.Message}"
                };
            }
            catch (Exception ex)
            {
                var userElementJson = userElement.ToString();
                _logger.LogError(ex, "Error parsing user data from database response: {UserElement}",
                    userElementJson);

                return new LoginResponse
                {
                    Success = false,
                    Error = $"Errore durante l'elaborazione dei dati utente [{ex.GetType().Name}]: {ex.Message}\n\nDati ricevuti: {userElementJson}"
                };
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during login for {Email}", request.Email);
            return new LoginResponse
            {
                Success = false,
                Error = $"Errore durante il login: {ex.GetType().Name} - {ex.Message}"
            };
        }
    }

    public async Task LogoutAsync()
    {
        try
        {
            var currentUser = _currentUser;

            // Email is preserved by SessionManager - LastLoginEmail is not cleared
            _currentUser = null;
            await _sessionManager.ClearSessionAsync();
            // Don't clear persisted data - it contains LastLoginEmail
            // await _sessionManager.ClearPersistedDataAsync();

            _logger.LogInformation("User logged out: {Email}", currentUser?.Email ?? "Unknown");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout");
            throw;
        }
    }

    public async Task<UserInfo?> GetCurrentUserAsync()
    {
        if (_currentUser != null)
            return _currentUser;

        var session = await _sessionManager.GetSessionAsync();
        if (session?.IsValid ?? false)
        {
            _currentUser = session.User;
            return _currentUser;
        }

        return null;
    }

    public bool IsAuthenticated()
    {
        return _currentUser != null || _sessionManager.IsSessionValid();
    }

    private string GenerateSessionToken(Guid userId)
    {
        var timestamp = DateTime.UtcNow.Ticks;
        var randomBytes = new byte[16];

        using (var rng = System.Security.Cryptography.RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }

        var tokenData = $"{userId}:{timestamp}:{Convert.ToBase64String(randomBytes)}";
        return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(tokenData));
    }

    private DateTime? ParseDateTime(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var dateProp))
            return null;

        if (dateProp.ValueKind == JsonValueKind.Null)
            return null;

        try
        {
            var dateString = dateProp.GetString();
            if (string.IsNullOrEmpty(dateString))
                return null;

            if (DateTime.TryParse(dateString, System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.RoundtripKind, out var parsedDate))
            {
                return parsedDate;
            }

            _logger.LogWarning("Unable to parse date '{DateString}' from property '{PropertyName}'",
                dateString, propertyName);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error parsing date from property '{PropertyName}'", propertyName);
            return null;
        }
    }
}
