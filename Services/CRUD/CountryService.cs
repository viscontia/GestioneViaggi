using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class CountryService : BaseCrudService<Country>
{
    protected override string TableName => "eba_countries";
    protected override string IdColumnName => "country_id";

    public CountryService(IDatabaseService databaseService, ILogger<CountryService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Ottiene tutti i paesi ordinati per nome ASC
    /// </summary>
    public async Task<List<Country>> GetAllOrderedByNameAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    country_id,
                    name,
                    nationality,
                    country_code,
                    iso_alpha2,
                    capital,
                    population,
                    area_km2,
                    region_id,
                    sub_region_id,
                    intermediate_region_id,
                    organization_region_id
                FROM eba_countries
                ORDER BY name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var countries = new List<Country>();
            while (await reader.ReadAsync())
            {
                countries.Add(MapFromReader(reader));
            }

            return countries;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei paesi");
            throw;
        }
    }

    public override async Task<Country> CreateAsync(Country entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO eba_countries (
                    name,
                    nationality,
                    country_code,
                    iso_alpha2,
                    capital,
                    population,
                    area_km2,
                    region_id,
                    sub_region_id,
                    intermediate_region_id,
                    organization_region_id
                )
                VALUES (@name, @nationality, @countryCode, @isoAlpha2, @capital, @population, @areaKm2,
                        @regionId, @subRegionId, @intermediateRegionId, @organizationRegionId)
                RETURNING country_id, name, nationality, country_code, iso_alpha2, capital, population,
                          area_km2, region_id, sub_region_id, intermediate_region_id, organization_region_id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("name", entity.Name);
            command.Parameters.AddWithValue("nationality", entity.Nationality);
            command.Parameters.AddWithValue("countryCode", entity.CountryCode);
            command.Parameters.AddWithValue("isoAlpha2", entity.IsoAlpha2);
            command.Parameters.AddWithValue("capital", (object?)entity.Capital ?? DBNull.Value);
            command.Parameters.AddWithValue("population", (object?)entity.Population ?? DBNull.Value);
            command.Parameters.AddWithValue("areaKm2", (object?)entity.AreaKm2 ?? DBNull.Value);
            command.Parameters.AddWithValue("regionId", (object?)entity.RegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("subRegionId", (object?)entity.SubRegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("intermediateRegionId", (object?)entity.IntermediateRegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("organizationRegionId", (object?)entity.OrganizationRegionId ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il paese");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del paese");
            throw;
        }
    }

    public override async Task<Country> UpdateAsync(Country entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE eba_countries
                SET name = @name,
                    nationality = @nationality,
                    country_code = @countryCode,
                    iso_alpha2 = @isoAlpha2,
                    capital = @capital,
                    population = @population,
                    area_km2 = @areaKm2,
                    region_id = @regionId,
                    sub_region_id = @subRegionId,
                    intermediate_region_id = @intermediateRegionId,
                    organization_region_id = @organizationRegionId
                WHERE country_id = @id
                RETURNING country_id, name, nationality, country_code, iso_alpha2, capital, population,
                          area_km2, region_id, sub_region_id, intermediate_region_id, organization_region_id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("name", entity.Name);
            command.Parameters.AddWithValue("nationality", entity.Nationality);
            command.Parameters.AddWithValue("countryCode", entity.CountryCode);
            command.Parameters.AddWithValue("isoAlpha2", entity.IsoAlpha2);
            command.Parameters.AddWithValue("capital", (object?)entity.Capital ?? DBNull.Value);
            command.Parameters.AddWithValue("population", (object?)entity.Population ?? DBNull.Value);
            command.Parameters.AddWithValue("areaKm2", (object?)entity.AreaKm2 ?? DBNull.Value);
            command.Parameters.AddWithValue("regionId", (object?)entity.RegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("subRegionId", (object?)entity.SubRegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("intermediateRegionId", (object?)entity.IntermediateRegionId ?? DBNull.Value);
            command.Parameters.AddWithValue("organizationRegionId", (object?)entity.OrganizationRegionId ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Paese con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del paese");
            throw;
        }
    }

    protected override Country MapFromReader(NpgsqlDataReader reader)
    {
        return new Country
        {
            Id = ReadInt(reader, "country_id"),
            Name = reader.GetString(reader.GetOrdinal("name")),
            Nationality = reader.GetString(reader.GetOrdinal("nationality")),
            CountryCode = reader.GetString(reader.GetOrdinal("country_code")),
            IsoAlpha2 = reader.GetString(reader.GetOrdinal("iso_alpha2")),
            Capital = ReadNullableString(reader, "capital"),
            Population = ReadNullableLong(reader, "population"),
            AreaKm2 = ReadNullableDecimal(reader, "area_km2"),
            RegionId = ReadNullableInt(reader, "region_id"),
            SubRegionId = ReadNullableInt(reader, "sub_region_id"),
            IntermediateRegionId = ReadNullableInt(reader, "intermediate_region_id"),
            OrganizationRegionId = ReadNullableInt(reader, "organization_region_id")
        };
    }

    /// <summary>
    /// Helper per leggere long nullable
    /// </summary>
    private long? ReadNullableLong(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetInt64(ordinal);
    }
}
