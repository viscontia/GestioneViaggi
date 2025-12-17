using Microsoft.Extensions.Logging;
using Npgsql;
using System.Text.Json;

namespace GestioneViaggi.Services.Database;

public class PostgreSqlService : IDatabaseService
{
    private readonly IDatabaseConnectionManager _connectionManager;
    private readonly ILogger<PostgreSqlService> _logger;

    public PostgreSqlService(IDatabaseConnectionManager connectionManager, ILogger<PostgreSqlService> logger)
    {
        _connectionManager = connectionManager;
        _logger = logger;
    }

    public async Task<NpgsqlConnection> GetConnectionAsync()
    {
        return await _connectionManager.GetConnectionAsync();
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
