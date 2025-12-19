using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class CountryRegionService : BaseCrudService<CountryRegion>
{
    protected override string TableName => "eba_country_regions";
    protected override string IdColumnName => "id";

    public CountryRegionService(IDatabaseService databaseService, ILogger<CountryRegionService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Ottiene tutte le regioni ordinate per nome ASC
    /// </summary>
    public async Task<List<CountryRegion>> GetAllOrderedByNameAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT id, name
                FROM eba_country_regions
                ORDER BY name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var regions = new List<CountryRegion>();
            while (await reader.ReadAsync())
            {
                regions.Add(MapFromReader(reader));
            }

            return regions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle regioni geografiche");
            throw;
        }
    }

    protected override CountryRegion MapFromReader(NpgsqlDataReader reader)
    {
        return new CountryRegion
        {
            Id = ReadInt(reader, "id"),
            Name = reader.GetString(reader.GetOrdinal("name"))
        };
    }

    public override async Task<CountryRegion> CreateAsync(CountryRegion entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO eba_country_regions (name)
                VALUES (@name)
                RETURNING id, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la regione");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della regione");
            throw;
        }
    }

    public override async Task<CountryRegion> UpdateAsync(CountryRegion entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE eba_country_regions
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

            throw new Exception($"Regione con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della regione");
            throw;
        }
    }
}
