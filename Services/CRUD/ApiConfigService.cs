using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service DB-First per gestione ana_api_config.
/// Delega tutta la logica a stored procedures PostgreSQL.
/// Tabella globale (non multi-tenant) - NON eredita da BaseCrudService.
/// </summary>
public class ApiConfigService
{
    private readonly IDatabaseService _databaseService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<ApiConfigService> _logger;

    public ApiConfigService(
        IDatabaseService databaseService,
        ITenantContext tenantContext,
        ILogger<ApiConfigService> logger)
    {
        _databaseService = databaseService;
        _tenantContext = tenantContext;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutte le configurazioni API.
    /// Ordinate per service_code, display_order.
    /// </summary>
    public async Task<IEnumerable<ApiConfig>> GetAllAsync()
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<ApiConfig>(
                "SELECT * FROM fn_ana_api_config_get_all()"
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle configurazioni API");
            return Enumerable.Empty<ApiConfig>();
        }
    }

    /// <summary>
    /// Recupera le configurazioni per un servizio specifico.
    /// </summary>
    public async Task<IEnumerable<ApiConfig>> GetByServiceAsync(string serviceCode)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<ApiConfig>(
                "SELECT * FROM fn_ana_api_config_get_by_service(@ServiceCode)",
                new { ServiceCode = serviceCode }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero configurazioni per servizio {ServiceCode}", serviceCode);
            return Enumerable.Empty<ApiConfig>();
        }
    }

    /// <summary>
    /// Recupera il valore di una singola configurazione per servizio e chiave.
    /// </summary>
    public async Task<string?> GetValueAsync(string serviceCode, string configKey)
    {
        try
        {
            var configs = await GetByServiceAsync(serviceCode);
            return configs.FirstOrDefault(c =>
                c.ConfigKey.Equals(configKey, StringComparison.OrdinalIgnoreCase))?.ConfigValue;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero valore per {ServiceCode}/{ConfigKey}", serviceCode, configKey);
            return null;
        }
    }

    /// <summary>
    /// Recupera il valore di una configurazione API attiva tramite function DB dedicata.
    /// DB-First: tutta la logica di validazione (esistenza, attivazione, valore non vuoto) è nel database.
    /// </summary>
    public async Task<string?> GetConfigValueAsync(string serviceCode, string configKey)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            var value = await conn.ExecuteScalarAsync<string>(
                "SELECT fn_get_api_config_value(@ServiceCode, @ConfigKey)",
                new { ServiceCode = serviceCode, ConfigKey = configKey }
            );
            return value;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Configurazione API non disponibile per {ServiceCode}/{ConfigKey}: {Error}",
                serviceCode, configKey, pex.MessageText);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero configurazione API per {ServiceCode}/{ConfigKey}",
                serviceCode, configKey);
            return null;
        }
    }

    /// <summary>
    /// Crea una nuova configurazione API.
    /// </summary>
    public async Task<ApiConfig> CreateAsync(ApiConfig entity)
    {
        var currentUser = await GetCurrentUsernameAsync();
        entity.CreatedBy = currentUser;

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            entity.ConfigId = await conn.ExecuteScalarAsync<int>(
                @"SELECT sp_ana_api_config_create(
                    @ServiceCode,
                    @ServiceName,
                    @ConfigKey,
                    @ConfigValue,
                    @ConfigType,
                    @ConfigDescription,
                    @IsSecret,
                    @IsActive,
                    @DisplayOrder,
                    @CreatedBy
                )",
                new
                {
                    entity.ServiceCode,
                    entity.ServiceName,
                    entity.ConfigKey,
                    entity.ConfigValue,
                    entity.ConfigType,
                    entity.ConfigDescription,
                    entity.IsSecret,
                    entity.IsActive,
                    entity.DisplayOrder,
                    entity.CreatedBy
                }
            );

            _logger.LogInformation("Configurazione API {ServiceCode}/{ConfigKey} creata con ID {Id}",
                entity.ServiceCode, entity.ConfigKey, entity.ConfigId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante creazione config API: {Error}", errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della configurazione API {ServiceCode}/{ConfigKey}",
                entity.ServiceCode, entity.ConfigKey);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "configurazione API");
        }
    }

    /// <summary>
    /// Aggiorna una configurazione API esistente.
    /// </summary>
    public async Task<ApiConfig> UpdateAsync(ApiConfig entity)
    {
        var currentUser = await GetCurrentUsernameAsync();
        entity.UpdatedBy = currentUser;

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                @"SELECT sp_ana_api_config_update(
                    @ConfigId,
                    @ServiceCode,
                    @ServiceName,
                    @ConfigKey,
                    @ConfigValue,
                    @ConfigType,
                    @ConfigDescription,
                    @IsSecret,
                    @IsActive,
                    @DisplayOrder,
                    @UpdatedBy
                )",
                new
                {
                    entity.ConfigId,
                    entity.ServiceCode,
                    entity.ServiceName,
                    entity.ConfigKey,
                    entity.ConfigValue,
                    entity.ConfigType,
                    entity.ConfigDescription,
                    entity.IsSecret,
                    entity.IsActive,
                    entity.DisplayOrder,
                    entity.UpdatedBy
                }
            );

            _logger.LogInformation("Configurazione API {Id} aggiornata", entity.ConfigId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante aggiornamento config API {Id}: {Error}", entity.ConfigId, errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della configurazione API {Id}", entity.ConfigId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "configurazione API");
        }
    }

    /// <summary>
    /// Elimina una singola configurazione API.
    /// </summary>
    public async Task<bool> DeleteAsync(int configId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                "SELECT sp_ana_api_config_delete(@ConfigId)",
                new { ConfigId = configId }
            );

            _logger.LogInformation("Configurazione API {Id} eliminata", configId);
            return true;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante eliminazione config API {Id}: {Error}", configId, errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della configurazione API {Id}", configId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "configurazione API");
        }
    }

    /// <summary>
    /// Elimina tutte le configurazioni di un servizio.
    /// </summary>
    public async Task<bool> DeleteServiceAsync(string serviceCode)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                "SELECT sp_ana_api_config_delete_service(@ServiceCode)",
                new { ServiceCode = serviceCode }
            );

            _logger.LogInformation("Tutte le configurazioni del servizio {ServiceCode} eliminate", serviceCode);
            return true;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante eliminazione servizio {ServiceCode}: {Error}", serviceCode, errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del servizio {ServiceCode}", serviceCode);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "servizio API");
        }
    }

    private async Task<string> GetCurrentUsernameAsync()
    {
        try
        {
            var user = await _tenantContext.GetCurrentUserAsync();
            return user?.Username ?? "SYSTEM";
        }
        catch
        {
            return "SYSTEM";
        }
    }
}
