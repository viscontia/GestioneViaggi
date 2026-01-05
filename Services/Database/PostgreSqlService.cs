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

        try
        {
            // Set the current app user for audit triggers
            string? emailToSet = null;
            var session = await _sessionManager.GetSessionAsync();

            if (session?.IsValid == true && !string.IsNullOrEmpty(session.User.Email))
            {
                emailToSet = session.User.Email;
            }
            else
            {
                // Fallback: try to get the last login email if session is missing/expired
                // This covers cases where the user might be re-authenticating or in a weird state
                emailToSet = await _sessionManager.GetLastLoginEmailAsync();

                if (string.IsNullOrEmpty(emailToSet))
                {
                    _logger.LogWarning("No valid session or last login email found. Audit user will default to DB user.");
                }
            }

            if (!string.IsNullOrEmpty(emailToSet))
            {
                using var cmd = new NpgsqlCommand("SELECT set_config('my.app_user', @email, false)", connection);
                cmd.Parameters.AddWithValue("email", emailToSet);
                await cmd.ExecuteNonQueryAsync();

                _logger.LogDebug("Audit user set to: {Email}", emailToSet);
            }
        }
        catch (Exception ex)
        {
            // Logging but not failing - audit is important but shouldn't break the app if fails? 
            // Better to log only debug to avoid noise, or warning.
            _logger.LogWarning(ex, "Failed to set audit user session variable");
        }

        return connection;
    }

    public async Task<T?> ExecuteFunctionAsync<T>(string functionName, params (string Name, object? Value)[] parameters)
    {
        try
        {
            await using var connection = await GetConnectionAsync();

            var paramNames = string.Join(", ", parameters.Select((_, i) => $"@p{i}"));
            var sql = $"SELECT {functionName}({paramNames})";

            await using var command = new NpgsqlCommand(sql, connection);

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
