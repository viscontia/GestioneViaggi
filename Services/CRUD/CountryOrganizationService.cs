using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class CountryOrganizationService : BaseCrudService<CountryOrganization>
{
    protected override string TableName => "eba_country_organizations";
    protected override string IdColumnName => "id";

    public CountryOrganizationService(IDatabaseService databaseService, ILogger<CountryOrganizationService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Ottiene tutte le organizzazioni ordinate per nome ASC
    /// </summary>
    public async Task<List<CountryOrganization>> GetAllOrderedByNameAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT id, code, name
                FROM eba_country_organizations
                ORDER BY name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var organizations = new List<CountryOrganization>();
            while (await reader.ReadAsync())
            {
                organizations.Add(MapFromReader(reader));
            }

            return organizations;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle organizzazioni");
            throw;
        }
    }

    protected override CountryOrganization MapFromReader(NpgsqlDataReader reader)
    {
        return new CountryOrganization
        {
            Id = ReadInt(reader, "id"),
            Code = reader.GetString(reader.GetOrdinal("code")),
            Name = reader.GetString(reader.GetOrdinal("name"))
        };
    }

    public override async Task<CountryOrganization> CreateAsync(CountryOrganization entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO eba_country_organizations (code, name)
                VALUES (@code, @name)
                RETURNING id, code, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("code", entity.Code);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare l'organizzazione");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'organizzazione");
            throw;
        }
    }

    public override async Task<CountryOrganization> UpdateAsync(CountryOrganization entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE eba_country_organizations
                SET code = @code,
                    name = @name
                WHERE id = @id
                RETURNING id, code, name";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("code", entity.Code);
            command.Parameters.AddWithValue("name", entity.Name);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Organizzazione con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'organizzazione");
            throw;
        }
    }
}
