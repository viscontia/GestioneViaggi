using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public interface IRoleService
{
    Task<List<RoleInfo>> GetRolesAsync();
    Task CreateRoleAsync(RoleInfo role);
    Task UpdateRoleAsync(RoleInfo role);
    Task DeleteRoleAsync(string roleCode);
}

public class RoleInfo
{
    public int RoleId { get; set; }
    public string RoleCode { get; set; } = string.Empty;
    public string RoleName { get; set; } = string.Empty;
    public bool IsSystem { get; set; }
}

public class RoleService : IRoleService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<RoleService> _logger;

    public RoleService(IDatabaseService databaseService, ILogger<RoleService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<List<RoleInfo>> GetRolesAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_app_list_roles()";

            var result = new List<RoleInfo>();
            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                result.Add(new RoleInfo
                {
                    RoleId = reader.GetInt32(reader.GetOrdinal("role_id")),
                    RoleCode = reader.GetString(reader.GetOrdinal("role_code")),
                    RoleName = reader.GetString(reader.GetOrdinal("role_name")),
                    IsSystem = reader.GetBoolean(reader.GetOrdinal("is_system"))
                });
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting roles");
            throw;
        }
    }

    private async Task ExecuteCommandAsync(string sql, params (string Name, object? Value)[] parameters)
    {
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);

        foreach (var p in parameters)
        {
            command.Parameters.AddWithValue(p.Name, p.Value ?? DBNull.Value);
        }

        await command.ExecuteNonQueryAsync();
    }

    public async Task CreateRoleAsync(RoleInfo role)
    {
        try
        {
            _logger.LogInformation("Creating role: {RoleCode} - {RoleName}", role.RoleCode, role.RoleName);
            await ExecuteCommandAsync("CALL sp_app_create_role(@p_role_code, @p_role_name, @p_is_system)",
                ("p_role_code", role.RoleCode),
                ("p_role_name", role.RoleName),
                ("p_is_system", role.IsSystem)
            );
            _logger.LogInformation("Role created successfully");
        }
        catch (PostgresException ex) when (ex.Message.Contains("ROLE_CODE_ALREADY_EXISTS") || ex.SqlState == "23505")
        {
            _logger.LogWarning(ex, "Role creation failed: Duplicate code");
            throw new InvalidOperationException($"Un ruolo con il codice '{role.RoleCode}' esiste già.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating role: {Message}", ex.Message);
            throw;
        }
    }

    public async Task UpdateRoleAsync(RoleInfo role)
    {
        try
        {
            _logger.LogInformation("Updating role: {RoleCode} -> {RoleName}", role.RoleCode, role.RoleName);

            // Inline execution to check rows affected (though CALL might not return it reliably for SPs, we'll try)
            // For Procedures in PG, ExecuteNonQuery might return -1. 
            // Better approach: Since we rely on SP raising exception if not found, we trust it? 
            // BUT user says it doesn't update. 
            // Let's verify if the input is correct.

            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("CALL sp_app_update_role(@p_role_code, @p_role_name, @p_is_system)", connection);
            command.Parameters.AddWithValue("p_role_code", role.RoleCode);
            command.Parameters.AddWithValue("p_role_name", role.RoleName);
            command.Parameters.AddWithValue("p_is_system", role.IsSystem);

            await command.ExecuteNonQueryAsync();

            _logger.LogInformation("Role updated successfully");
        }
        catch (PostgresException ex)
        {
            _logger.LogError(ex, "PG Error updating role: {Code} - {Message}", ex.SqlState, ex.Message);

            if (ex.Message.Contains("CANNOT_MODIFY_SYSTEM_ROLE") || ex.Message.Contains("SYSTEM_ROLE"))
                throw new InvalidOperationException("Non è possibile modificare un ruolo di sistema.");

            if (ex.Message.Contains("ROLE_NOT_FOUND"))
                throw new InvalidOperationException("Ruolo non trovato. Potrebbe essere stato eliminato.");

            throw new InvalidOperationException($"Errore DB durante l'aggiornamento: {ex.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating role");
            throw;
        }
    }

    public async Task DeleteRoleAsync(string roleCode)
    {
        try
        {
            _logger.LogInformation("Deleting role: {RoleCode}", roleCode);
            await ExecuteCommandAsync("CALL sp_app_delete_role(@p_role_code)",
               ("p_role_code", roleCode)
           );
            _logger.LogInformation("Role deleted successfully");
        }
        catch (PostgresException ex)
        {
            _logger.LogError(ex, "PG Error deleting role: {Code} - {Message}", ex.SqlState, ex.Message);

            // Broaden the check
            if (ex.Message.Contains("CANNOT_DELETE_SYSTEM_ROLE"))
                throw new InvalidOperationException("Non è possibile eliminare un ruolo di sistema.");

            if (ex.Message.Contains("ROLE_IN_USE") || ex.SqlState == "23503")
                throw new InvalidOperationException("Impossibile eliminare: il ruolo è assegnato a uno o più utenti.");

            if (ex.Message.Contains("ROLE_NOT_FOUND"))
                throw new InvalidOperationException("Ruolo non trovato.");

            // Generic fallback to prevent crash and show something
            throw new InvalidOperationException($"Errore Database: {ex.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting role");
            throw new InvalidOperationException($"Errore imprevisto durante l'eliminazione: {ex.Message}");
        }
    }
}
