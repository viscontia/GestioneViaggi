using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Data;
using System.Text.Json;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Implementazione base per operazioni CRUD su database PostgreSQL
/// </summary>
/// <typeparam name="T">Tipo di entità che eredita da BaseEntity</typeparam>
public abstract class BaseCrudService<T> : ICrudService<T> where T : BaseEntity, new()
{
    protected readonly IDatabaseService _databaseService;
    protected readonly ILogger _logger;
    protected abstract string TableName { get; }
    protected abstract string IdColumnName { get; }

    protected BaseCrudService(IDatabaseService databaseService, ILogger logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public virtual async Task<List<T>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} ORDER BY {IdColumnName}";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<T>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti gli elementi da {TableName}", TableName);
            throw;
        }
    }

    public virtual async Task<T?> GetByIdAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} WHERE {IdColumnName} = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dell'elemento {Id} da {TableName}", id, TableName);
            throw;
        }
    }

    public abstract Task<T> CreateAsync(T entity);
    public abstract Task<T> UpdateAsync(T entity);

    public virtual async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"DELETE FROM {TableName} WHERE {IdColumnName} = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);

            var rowsAffected = await command.ExecuteNonQueryAsync();
            return rowsAffected > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione dell'elemento {Id} da {TableName}", id, TableName);
            throw;
        }
    }

    /// <summary>
    /// Mappa un DataReader su un'entità T
    /// </summary>
    protected abstract T MapFromReader(NpgsqlDataReader reader);

    /// <summary>
    /// Helper per leggere un valore nullable dal reader
    /// </summary>
    protected string? ReadNullableString(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    /// <summary>
    /// Helper per leggere un int dal reader
    /// </summary>
    protected int ReadInt(NpgsqlDataReader reader, string columnName)
    {
        return reader.GetInt32(reader.GetOrdinal(columnName));
    }
}
