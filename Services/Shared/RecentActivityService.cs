using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Npgsql;

namespace GestioneViaggi.Services.Shared;

public interface IRecentActivityService
{
    Task<List<ActivityLogItem>> GetRecentActivitiesAsync(int? aziendaId, string? usernameFilter = null, int limit = 10);
    Task<int> CleanupActivitiesAsync(int daysToKeep);
}

public class RecentActivityService : IRecentActivityService
{
    private readonly IDatabaseService _databaseService;

    public RecentActivityService(IDatabaseService databaseService)
    {
        _databaseService = databaseService;
    }

    public async Task<List<ActivityLogItem>> GetRecentActivitiesAsync(int? aziendaId, string? usernameFilter = null, int limit = 10)
    {
        var result = new List<ActivityLogItem>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT event_id, event_type, description, entity_table, entity_id, azienda_id, created_at, created_by
                FROM ana_business_events
                WHERE (@aziendaId IS NULL OR azienda_id = @aziendaId OR azienda_id IS NULL)
                  AND (@usernameFilter IS NULL OR LOWER(created_by) = LOWER(@usernameFilter))
                ORDER BY created_at DESC
                LIMIT @limit";

            await using var command = new NpgsqlCommand(sql, connection);
            
            command.Parameters.Add(new NpgsqlParameter("aziendaId", NpgsqlTypes.NpgsqlDbType.Integer) 
            { 
                Value = (object?)aziendaId ?? DBNull.Value,
                IsNullable = true
            });
            
            command.Parameters.Add(new NpgsqlParameter("usernameFilter", NpgsqlTypes.NpgsqlDbType.Varchar) 
            { 
                Value = (object?)usernameFilter ?? DBNull.Value,
                IsNullable = true 
            });
            
            command.Parameters.AddWithValue("limit", limit);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new ActivityLogItem
                {
                    EventId = reader.GetInt32(reader.GetOrdinal("event_id")),
                    EventType = reader.GetString(reader.GetOrdinal("event_type")),
                    Description = reader.GetString(reader.GetOrdinal("description")),
                    EntityTable = reader.GetString(reader.GetOrdinal("entity_table")),
                    EntityId = reader.GetInt32(reader.GetOrdinal("entity_id")),
                    AziendaId = reader.IsDBNull(reader.GetOrdinal("azienda_id")) ? null : reader.GetInt32(reader.GetOrdinal("azienda_id")),
                    CreatedAt = reader.GetDateTime(reader.GetOrdinal("created_at")),
                    CreatedBy = reader.IsDBNull(reader.GetOrdinal("created_by")) ? "System" : reader.GetString(reader.GetOrdinal("created_by"))
                });
            }
        }
        catch (Exception)
        {
            // Log error
        }
        return result;
    }

    public async Task<int> CleanupActivitiesAsync(int daysToKeep)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT cleanup_business_events(@days)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("days", daysToKeep);

            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result);
        }
        catch (Exception)
        {
            return -1;
        }
    }
}
