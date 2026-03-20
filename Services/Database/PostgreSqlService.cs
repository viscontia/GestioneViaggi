using Microsoft.Extensions.Logging;
using Npgsql;
using System.Text.Json;
using GestioneViaggi.Services.Session;

namespace GestioneViaggi.Services.Database;

public class PostgreSqlService : IDatabaseService
{
    private readonly IDatabaseConnectionManager _connectionManager;
    private readonly Services.Session.ISessionManager _sessionManager;
    private readonly ILogger<PostgreSqlService> _logger;

    public PostgreSqlService(
        IDatabaseConnectionManager connectionManager,
        Services.Session.ISessionManager sessionManager,
        ILogger<PostgreSqlService> logger)
    {
        _connectionManager = connectionManager;
        _sessionManager = sessionManager;
        _logger = logger;
    }

    public async Task<NpgsqlConnection> GetConnectionAsync()
    {
        var connection = await _connectionManager.GetConnectionAsync();
        var email = await GetAuditEmailAsync();

        if (!string.IsNullOrEmpty(email))
        {
            await SetAuditUserAsync(connection, email);
        }

        return connection;
    }

    private async Task<string?> GetAuditEmailAsync()
    {
        try
        {
            var session = await _sessionManager.GetSessionAsync();

            if (session?.IsValid == true && !string.IsNullOrEmpty(session.User.Email))
            {
                return session.User.Email;
            }

            return await _sessionManager.GetLastLoginEmailAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to retrieve audit email from session");
            return null;
        }
    }

    private async Task SetAuditUserAsync(NpgsqlConnection connection, string email)
    {
        try
        {
            using var cmd = new NpgsqlCommand("SELECT set_config('my.app_user', @email, true)", connection);
            cmd.Parameters.AddWithValue("email", email);
            await cmd.ExecuteNonQueryAsync();
            _logger.LogDebug("Audit user set to: {Email}", email);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to set audit user session variable.");
            throw; // Caller should handle or retry
        }
    }

    public async Task<T?> ExecuteFunctionAsync<T>(string functionName, params (string Name, object? Value)[] parameters)
    {
        try
        {
            // Get a clean connection from the manager to handle batching ourselves
            await using var connection = await _connectionManager.GetConnectionAsync();
            var email = await GetAuditEmailAsync();

            var paramNames = string.Join(", ", parameters.Select((_, i) => $"@p{i}"));
            string sql;

            if (!string.IsNullOrEmpty(email))
            {
                // OPTIMIZATION: Batch set_config and the function call in a single round-trip.
                // This is crucial for high-latency connections (e.g. from South Africa).
                sql = $"SELECT {functionName}({paramNames}) FROM (SELECT set_config('my.app_user', @app_user, true)) s";
            }
            else
            {
                sql = $"SELECT {functionName}({paramNames})";
            }

            await using var command = new NpgsqlCommand(sql, connection);

            if (!string.IsNullOrEmpty(email))
            {
                command.Parameters.AddWithValue("app_user", email);
            }

            for (int i = 0; i < parameters.Length; i++)
            {
                command.Parameters.AddWithValue($"p{i}", parameters[i].Value ?? DBNull.Value);
            }

            var result = await command.ExecuteScalarAsync();

            if (result == null || result == DBNull.Value)
                return default;

            if (typeof(T) == typeof(string))
                return (T)(object)result.ToString()!;

            var jsonString = result.ToString();
            if (string.IsNullOrEmpty(jsonString))
                return default;

            return JsonSerializer.Deserialize<T>(jsonString, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing function {FunctionName}", functionName);
            throw;
        }
    }
}
