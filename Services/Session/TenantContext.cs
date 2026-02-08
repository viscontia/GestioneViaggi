using GestioneViaggi.Models;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Session;

/// <summary>
/// Implementazione concreta del contesto multi-tenant.
/// Gestisce la logica di scoping dei dati per company_id.
/// </summary>
public class TenantContext : ITenantContext
{
    private readonly ISessionManager _sessionManager;
    private readonly ILogger<TenantContext> _logger;

    public TenantContext(ISessionManager sessionManager, ILogger<TenantContext> logger)
    {
        _sessionManager = sessionManager;
        _logger = logger;
    }

    public async Task<int?> GetCurrentAziendaIdAsync()
    {
        var session = await _sessionManager.GetSessionAsync();
        
        if (session?.User == null)
        {
            _logger.LogWarning("GetCurrentAziendaIdAsync: Nessuna sessione attiva");
            return null;
        }

        // SuperAdmin non ha tenant scope
        if (session.User.IsSuperAdmin)
        {
            _logger.LogDebug("User {Email} is SuperAdmin - no tenant scope", session.User.Email);
            return null;
        }

        if (!session.User.AziendaId.HasValue)
        {
            _logger.LogError("User {Email} non ha AziendaId configurato (non SuperAdmin)", session.User.Email);
            throw new InvalidOperationException("Utente non associato ad alcuna azienda. Contattare l'amministratore.");
        }

        _logger.LogDebug("User {Email} tenant scope: AziendaId={AziendaId}", 
            session.User.Email, session.User.AziendaId.Value);

        return session.User.AziendaId.Value;
    }

    public async Task<bool> IsSuperAdminAsync()
    {
        var session = await _sessionManager.GetSessionAsync();
        var result = session?.User?.IsSuperAdmin ?? false;

        _logger.LogDebug("IsSuperAdminAsync for user {Email}: {Result}", 
            session?.User?.Email ?? "UNKNOWN", result);

        return result;
    }

    public async Task<bool> CanAccessAziendaAsync(int aziendaId)
    {
        var isSuperAdmin = await IsSuperAdminAsync();
        
        if (isSuperAdmin)
        {
            _logger.LogDebug("SuperAdmin can access AziendaId={AziendaId}", aziendaId);
            return true;
        }

        var currentAziendaId = await GetCurrentAziendaIdAsync();
        
        if (!currentAziendaId.HasValue)
        {
            _logger.LogWarning("User has no AziendaId - access denied to AziendaId={AziendaId}", aziendaId);
            return false;
        }

        var canAccess = currentAziendaId.Value == aziendaId;

        _logger.LogDebug("User AziendaId={UserAziendaId} can access AziendaId={TargetAziendaId}: {Result}",
            currentAziendaId.Value, aziendaId, canAccess);

        return canAccess;
    }

    public async Task<string> GetTenantFilterSqlAsync(string columnName = "azienda_id_fk", bool includeWhereKeyword = true)
    {
        var isSuperAdmin = await IsSuperAdminAsync();
        
        if (isSuperAdmin)
        {
            _logger.LogDebug("SuperAdmin - no tenant filter applied");
            return string.Empty;
        }

        var aziendaId = await GetCurrentAziendaIdAsync();
        
        if (!aziendaId.HasValue)
        {
            _logger.LogError("Cannot generate tenant filter - user has no AziendaId");
            throw new InvalidOperationException("Impossibile determinare il contesto aziendale dell'utente");
        }

        var filter = $"{columnName} = {aziendaId.Value}";
        
        if (includeWhereKeyword)
        {
            filter = $"WHERE {filter}";
        }

        _logger.LogDebug("Generated tenant filter: {Filter}", filter);
        
        return filter;
    }

    public async Task<UserInfo?> GetCurrentUserAsync()
    {
        var session = await _sessionManager.GetSessionAsync();
        return session?.User;
    }

    public async Task ValidateAccessAsync(int aziendaId)
    {
        var canAccess = await CanAccessAziendaAsync(aziendaId);
        
        if (!canAccess)
        {
            var session = await GetCurrentUserAsync();
            var userEmail = session?.Email ?? "UNKNOWN";
            
            _logger.LogWarning("SECURITY: User {Email} attempted to access AziendaId={AziendaId} without permission", 
                userEmail, aziendaId);

            throw new UnauthorizedAccessException(
                $"Non si dispone dei permessi per accedere ai dati dell'azienda con ID {aziendaId}");
        }
    }
}
