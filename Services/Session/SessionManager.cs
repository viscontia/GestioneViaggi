using GestioneViaggi.Models;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Session;

public class SessionManager : ISessionManager
{
    private readonly ILogger<SessionManager> _logger;
    private readonly ISecureStorageProvider _storageProvider;
    private SessionData? _cachedSession;

    public SessionManager(ILogger<SessionManager> logger, ISecureStorageProvider storageProvider)
    {
        _logger = logger;
        _storageProvider = storageProvider;
    }

    public async Task InitializeAsync()
    {
        try
        {
            var session = await GetSessionAsync();
            
            if (session?.IsExpired ?? false)
            {
                _logger.LogWarning("Session expired. Clearing stored session.");
                await ClearSessionAsync();
                _cachedSession = null;
            }
            else
            {
                _cachedSession = session;
                _logger.LogInformation("Session initialized. User: {Email}, Tenant: {TenantId}", 
                    session?.User.Email, session?.TenantId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error initializing session");
            _cachedSession = null;
        }
    }

    public async Task SaveSessionAsync(UserInfo user, string sessionToken)
    {
        await Task.CompletedTask;

        try
        {
            _logger.LogDebug("SaveSessionAsync started");

            if (user == null)
            {
                _logger.LogError("User is null");
                throw new ArgumentNullException(nameof(user));
            }

            _logger.LogDebug("User validation passed: {Email}", user.Email);

            if (string.IsNullOrWhiteSpace(sessionToken))
            {
                _logger.LogError("Session token is empty or whitespace");
                throw new ArgumentException("Session token cannot be empty", nameof(sessionToken));
            }

            _logger.LogDebug("Session token validation passed");

            var now = DateTime.UtcNow;
            _logger.LogDebug("Creating SessionData object");

            var sessionData = new SessionData
            {
                SessionToken = sessionToken,
                User = user,
                TenantId = user.TenantId,
                IssuedAt = now,
                ExpiresAt = now.AddHours(SessionConstants.SessionExpiryHours)
            };

            _logger.LogDebug("SessionData object created successfully, storing in cache");

            _cachedSession = sessionData;

            _logger.LogDebug("Persisting email to storage: {Email}", user.Email);
            await _storageProvider.SetAsync(SessionStorageConstants.LastLoginEmailKey, user.Email);
            
            _logger.LogDebug("Persisting tenant to storage: {TenantId}", user.TenantId);
            await _storageProvider.SetAsync(SessionStorageConstants.LastLoginTenantIdKey, user.TenantId);

            _logger.LogInformation("Session saved in memory for user: {Email}, Tenant: {TenantId}", 
                user.Email, user.TenantId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving session: {Message}", ex.Message);
            throw;
        }
    }

    public async Task<SessionData?> GetSessionAsync()
    {
        await Task.CompletedTask;

        if (_cachedSession != null && _cachedSession.IsValid)
        {
            _logger.LogDebug("Returning session from memory for user: {Email}", _cachedSession.User.Email);
            return _cachedSession;
        }

        _logger.LogDebug("No valid session in memory");
        return null;
    }

    public async Task ClearSessionAsync()
    {
        await Task.CompletedTask;

        try
        {
            _cachedSession = null;
            _logger.LogInformation("Session cleared from memory");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error clearing session");
        }
    }

    public bool IsSessionValid()
    {
        return _cachedSession?.IsValid ?? false;
    }

    public async Task<bool> RefreshSessionAsync()
    {
        await Task.CompletedTask;

        try
        {
            if (_cachedSession?.User == null)
                return false;

            var refreshedExpiry = DateTime.UtcNow.AddHours(SessionConstants.SessionExpiryHours);

            var refreshedSessionData = new SessionData
            {
                SessionToken = _cachedSession.SessionToken,
                User = _cachedSession.User,
                TenantId = _cachedSession.TenantId,
                IssuedAt = DateTime.UtcNow,
                ExpiresAt = refreshedExpiry
            };

            _cachedSession = refreshedSessionData;
            _logger.LogInformation("Session refreshed for user: {Email}", _cachedSession.User.Email);

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing session");
            return false;
        }
    }

    public string? GetCurrentTenantId()
    {
        return _cachedSession?.TenantId;
    }

    public async Task<string?> GetLastLoginEmailAsync()
    {
        try
        {
            var email = await _storageProvider.GetAsync(SessionStorageConstants.LastLoginEmailKey);
            if (!string.IsNullOrEmpty(email))
            {
                _logger.LogDebug("Retrieved last login email from storage: {Email}", email);
            }
            return email;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving last login email");
            return null;
        }
    }

    public async Task ClearPersistedDataAsync()
    {
        try
        {
            _logger.LogDebug("Clearing persisted session data");
            _storageProvider.Remove(SessionStorageConstants.LastLoginEmailKey);
            _storageProvider.Remove(SessionStorageConstants.LastLoginTenantIdKey);
            _logger.LogInformation("Persisted session data cleared successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error clearing persisted session data");
        }
    }
}
