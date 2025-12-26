using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class RegioneService : BaseCrudService<Regione>
{
    protected override string TableName => "ana_geo_regioni_ita";
    protected override string IdColumnName => "regione_id";

    public RegioneService(IDatabaseService databaseService, ILogger<RegioneService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<Regione> CreateAsync(Regione entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_geo_regioni_ita (
                    regione_descrizione,
                    regione_nr_residenti,
                    regione_perc_residenti,
                    regione_densita_kmq,
                    regione_nr_province,
                    regione_nr_comuni,
                    country_id_fk
                )
                VALUES (@descrizione, @residenti, @percResidenti, @densita, @province, @comuni, @countryFk)
                RETURNING regione_id, regione_descrizione, regione_nr_residenti, regione_perc_residenti,
                          regione_densita_kmq, regione_nr_province, regione_nr_comuni, country_id_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("residenti", (object?)entity.NumeroResidenti ?? DBNull.Value);
            command.Parameters.AddWithValue("percResidenti", (object?)entity.PercentualeResidenti ?? DBNull.Value);
            command.Parameters.AddWithValue("densita", (object?)entity.DensitaKmq ?? DBNull.Value);
            command.Parameters.AddWithValue("province", (object?)entity.NumeroProvince ?? DBNull.Value);
            command.Parameters.AddWithValue("comuni", (object?)entity.NumeroComuni ?? DBNull.Value);
            command.Parameters.AddWithValue("countryFk", entity.CountryIdFk);

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

    public override async Task<Regione> UpdateAsync(Regione entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_geo_regioni_ita
                SET regione_descrizione = @descrizione,
                    regione_nr_residenti = @residenti,
                    regione_perc_residenti = @percResidenti,
                    regione_densita_kmq = @densita,
                    regione_nr_province = @province,
                    regione_nr_comuni = @comuni,
                    country_id_fk = @countryFk
                WHERE regione_id = @id
                RETURNING regione_id, regione_descrizione, regione_nr_residenti, regione_perc_residenti,
                          regione_densita_kmq, regione_nr_province, regione_nr_comuni, country_id_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("residenti", (object?)entity.NumeroResidenti ?? DBNull.Value);
            command.Parameters.AddWithValue("percResidenti", (object?)entity.PercentualeResidenti ?? DBNull.Value);
            command.Parameters.AddWithValue("densita", (object?)entity.DensitaKmq ?? DBNull.Value);
            command.Parameters.AddWithValue("province", (object?)entity.NumeroProvince ?? DBNull.Value);
            command.Parameters.AddWithValue("comuni", (object?)entity.NumeroComuni ?? DBNull.Value);
            command.Parameters.AddWithValue("countryFk", entity.CountryIdFk);

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

    protected override Regione MapFromReader(NpgsqlDataReader reader)
    {
        return new Regione
        {
            Id = ReadInt(reader, "regione_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("regione_descrizione")),
            NumeroResidenti = ReadNullableInt(reader, "regione_nr_residenti"),
            PercentualeResidenti = ReadNullableDecimal(reader, "regione_perc_residenti"),
            DensitaKmq = ReadNullableDecimal(reader, "regione_densita_kmq"),
            NumeroProvince = ReadNullableInt(reader, "regione_nr_province") ?? 0,
            NumeroComuni = ReadNullableInt(reader, "regione_nr_comuni") ?? 0,
            CountryIdFk = ReadInt(reader, "country_id_fk")
        };
    }

    /// <summary>
    /// Override di GetAllAsync per includere JOIN con countries e ORDER BY descrizione
    /// </summary>
    public override async Task<List<Regione>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    r.regione_id,
                    r.regione_descrizione,
                    r.regione_nr_residenti,
                    r.regione_perc_residenti,
                    r.regione_densita_kmq,
                    r.regione_nr_province,
                    r.regione_nr_comuni,
                    r.country_id_fk,
                    c.name as country_name
                FROM ana_geo_regioni_ita r
                INNER JOIN eba_countries c ON r.country_id_fk = c.country_id
                ORDER BY r.regione_descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var regioni = new List<Regione>();
            while (await reader.ReadAsync())
            {
                regioni.Add(MapFromReaderWithCountry(reader));
            }

            return regioni;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle regioni");
            throw;
        }
    }

    /// <summary>
    /// Ottiene tutte le regioni ordinate per descrizione (ASC) - per uso in dropdown
    /// </summary>
    public async Task<List<Regione>> GetAllOrderedByDescrizioneAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT regione_id, regione_descrizione, regione_nr_residenti, regione_perc_residenti,
                       regione_densita_kmq, regione_nr_province, regione_nr_comuni, country_id_fk
                FROM ana_geo_regioni_ita
                ORDER BY regione_descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var regioni = new List<Regione>();
            while (await reader.ReadAsync())
            {
                regioni.Add(MapFromReader(reader));
            }

            return regioni;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle regioni ordinate");
            throw;
        }
    }

    /// <summary>
    /// Mapper specifico per query con JOIN che include country_name
    /// </summary>
    private Regione MapFromReaderWithCountry(NpgsqlDataReader reader)
    {
        var regione = MapFromReader(reader);
        regione.CountryName = ReadNullableString(reader, "country_name");
        return regione;
    }
}
