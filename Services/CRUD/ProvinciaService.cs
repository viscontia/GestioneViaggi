using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class ProvinciaService : BaseCrudService<Provincia>
{
    protected override string TableName => "ana_geo_province";
    protected override string IdColumnName => "provincia_id";

    public ProvinciaService(IDatabaseService databaseService, ILogger<ProvinciaService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Override di GetAllAsync per includere JOIN con regioni e ORDER BY descrizione
    /// </summary>
    public override async Task<List<Provincia>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    p.provincia_id,
                    p.provincia_descrizione,
                    p.provincia_sigla,
                    p.provincia_superficie,
                    p.provincia_residenti,
                    p.provincia_num_comuni,
                    p.regione_id_fk,
                    r.regione_descrizione
                FROM ana_geo_province p
                INNER JOIN ana_geo_regioni_ita r ON p.regione_id_fk = r.regione_id
                ORDER BY p.provincia_descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var province = new List<Provincia>();
            while (await reader.ReadAsync())
            {
                province.Add(MapFromReaderWithRegione(reader));
            }

            return province;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle province");
            throw;
        }
    }

    public override async Task<Provincia> CreateAsync(Provincia entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_geo_province (
                    provincia_descrizione,
                    provincia_sigla,
                    provincia_superficie,
                    provincia_residenti,
                    provincia_num_comuni,
                    regione_id_fk
                )
                VALUES (@descrizione, @sigla, @superficie, @residenti, @comuni, @regioneFk)
                RETURNING provincia_id, provincia_descrizione, provincia_sigla, provincia_superficie,
                          provincia_residenti, provincia_num_comuni, regione_id_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("sigla", entity.Sigla);
            command.Parameters.AddWithValue("superficie", (object?)entity.Superficie ?? DBNull.Value);
            command.Parameters.AddWithValue("residenti", (object?)entity.Residenti ?? DBNull.Value);
            command.Parameters.AddWithValue("comuni", (object?)entity.NumeroComuni ?? DBNull.Value);
            command.Parameters.AddWithValue("regioneFk", entity.RegioneIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la provincia");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della provincia");
            throw;
        }
    }

    public override async Task<Provincia> UpdateAsync(Provincia entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_geo_province
                SET provincia_descrizione = @descrizione,
                    provincia_sigla = @sigla,
                    provincia_superficie = @superficie,
                    provincia_residenti = @residenti,
                    provincia_num_comuni = @comuni,
                    regione_id_fk = @regioneFk
                WHERE provincia_id = @id
                RETURNING provincia_id, provincia_descrizione, provincia_sigla, provincia_superficie,
                          provincia_residenti, provincia_num_comuni, regione_id_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("sigla", entity.Sigla);
            command.Parameters.AddWithValue("superficie", (object?)entity.Superficie ?? DBNull.Value);
            command.Parameters.AddWithValue("residenti", (object?)entity.Residenti ?? DBNull.Value);
            command.Parameters.AddWithValue("comuni", (object?)entity.NumeroComuni ?? DBNull.Value);
            command.Parameters.AddWithValue("regioneFk", entity.RegioneIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Provincia con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della provincia");
            throw;
        }
    }

    protected override Provincia MapFromReader(NpgsqlDataReader reader)
    {
        return new Provincia
        {
            Id = ReadInt(reader, "provincia_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("provincia_descrizione")),
            Sigla = reader.GetString(reader.GetOrdinal("provincia_sigla")),
            Superficie = ReadNullableDecimal(reader, "provincia_superficie"),
            Residenti = ReadNullableInt(reader, "provincia_residenti"),
            NumeroComuni = ReadNullableInt(reader, "provincia_num_comuni"),
            RegioneIdFk = ReadInt(reader, "regione_id_fk")
        };
    }

    /// <summary>
    /// Mapper specifico per query con JOIN che include regione_descrizione
    /// </summary>
    private Provincia MapFromReaderWithRegione(NpgsqlDataReader reader)
    {
        var provincia = MapFromReader(reader);
        provincia.RegioneDescrizione = ReadNullableString(reader, "regione_descrizione");
        return provincia;
    }
}
