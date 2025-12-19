using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class CountrySubRegionService : BaseCrudService<CountrySubRegion>
{
    protected override string TableName => "eba_country_sub_regions";
    protected override string IdColumnName => "id";

    public CountrySubRegionService(IDatabaseService databaseService, ILogger<CountrySubRegionService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Ottiene tutte le sotto-regioni ordinate per nome ASC
    /// </summary>
    public async Task<List<CountrySubRegion>> GetAllOrderedByNameAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT id, name
                FROM eba_country_sub_regions
                ORDER BY name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var subRegions = new List<CountrySubRegion>();
            while (await reader.ReadAsync())
            {
                subRegions.Add(MapFromReader(reader));
            }

            return subRegions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle sotto-regioni");
            throw;
        }
    }

    protected override CountrySubRegion MapFromReader(NpgsqlDataReader reader)
    {
        return new CountrySubRegion
        {
            Id = ReadInt(reader, "id"),
            Name = reader.GetString(reader.GetOrdinal("name"))
        };
    }

    public override async Task<CountrySubRegion> CreateAsync(CountrySubRegion entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO eba_country_sub_regions (name)
                VALUES (@name)
                RETURNING id, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la sotto-regione");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della sotto-regione");
            throw;
        }
    }

    public override async Task<CountrySubRegion> UpdateAsync(CountrySubRegion entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE eba_country_sub_regions
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

            throw new Exception($"Sotto-regione con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della sotto-regione");
            throw;
        }
    }
}
