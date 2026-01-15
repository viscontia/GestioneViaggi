using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace GestioneViaggi.Services;

public class AuditLoginService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<AuditLoginService> _logger;

    public AuditLoginService(IDatabaseService databaseService, ILogger<AuditLoginService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<List<AuditLoginDTO>> GetAllAsync()
    {
        var result = new List<AuditLoginDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT a.login_id, a.user_id, a.created_at, a.event_type, a.ip::text, a.user_agent,
                       u.email, u.nome, u.cognome
                FROM audit_login a
                LEFT JOIN app_users u ON a.user_id = u.user_id
                ORDER BY a.created_at DESC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                result.Add(new AuditLoginDTO
                {
                    LoginId = reader.GetGuid(reader.GetOrdinal("login_id")),
                    UserId = reader.GetGuid(reader.GetOrdinal("user_id")),
                    CreatedAt = reader.GetDateTime(reader.GetOrdinal("created_at")),
                    EventType = reader.GetString(reader.GetOrdinal("event_type")),
                    Ip = reader.IsDBNull(reader.GetOrdinal("ip")) ? null : reader.GetString(reader.GetOrdinal("ip")), // Inet maps to string usually or IPAddress
                    UserAgent = reader.IsDBNull(reader.GetOrdinal("user_agent")) ? null : reader.GetString(reader.GetOrdinal("user_agent")),
                    Email = reader.IsDBNull(reader.GetOrdinal("email")) ? null : reader.GetString(reader.GetOrdinal("email")),
                    Nome = reader.IsDBNull(reader.GetOrdinal("nome")) ? null : reader.GetString(reader.GetOrdinal("nome")),
                    Cognome = reader.IsDBNull(reader.GetOrdinal("cognome")) ? null : reader.GetString(reader.GetOrdinal("cognome"))
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero audit login");
            throw; // Or return empty
        }
        return result;
    }

    public async Task<int> CleanupAsync(int daysToKeep)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT cleanup_audit_login(@days)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("days", daysToKeep);

            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante pulizia audit login");
            throw;
        }
    }
}
