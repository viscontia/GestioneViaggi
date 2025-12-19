using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class CountryIntermediateService : BaseCrudService<CountryIntermediate>
{
    protected override string TableName => "eba_country_intermediates";
    protected override string IdColumnName => "id";

    public CountryIntermediateService(IDatabaseService databaseService, ILogger<CountryIntermediateService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Ottiene tutte le regioni intermedie ordinate per nome ASC
    /// </summary>
    public async Task<List<CountryIntermediate>> GetAllOrderedByNameAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT id, name
                FROM eba_country_intermediates
                ORDER BY name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var intermediates = new List<CountryIntermediate>();
            while (await reader.ReadAsync())
            {
                intermediates.Add(MapFromReader(reader));
            }

            return intermediates;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle regioni intermedie");
            throw;
        }
    }

    protected override CountryIntermediate MapFromReader(NpgsqlDataReader reader)
    {
        return new CountryIntermediate
        {
            Id = ReadInt(reader, "id"),
            Name = reader.GetString(reader.GetOrdinal("name"))
        };
    }

    public override async Task<CountryIntermediate> CreateAsync(CountryIntermediate entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO eba_country_intermediates (name)
                VALUES (@name)
                RETURNING id, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la regione intermedia");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della regione intermedia");
            throw;
        }
    }

    public override async Task<CountryIntermediate> UpdateAsync(CountryIntermediate entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE eba_country_intermediates
                SET name = @name
                WHERE id = @id
                RETURNING id, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Regione intermedia con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della regione intermedia");
            throw;
        }
    }
}
