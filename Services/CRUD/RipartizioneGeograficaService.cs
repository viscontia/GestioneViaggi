using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class RipartizioneGeograficaService : BaseCrudService<RipartizioneGeografica>
{
    protected override string TableName => "ana_geo_ita_ripgeo";
    protected override string IdColumnName => "ripgeo_id";

    public RipartizioneGeograficaService(IDatabaseService databaseService, ILogger<RipartizioneGeograficaService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<RipartizioneGeografica> CreateAsync(RipartizioneGeografica entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_geo_ita_ripgeo (ripgeo_descrizione)
                VALUES (@descrizione)
                RETURNING ripgeo_id, ripgeo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la ripartizione geografica");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della ripartizione geografica");
            throw;
        }
    }

    public override async Task<RipartizioneGeografica> UpdateAsync(RipartizioneGeografica entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_geo_ita_ripgeo
                SET ripgeo_descrizione = @descrizione
                WHERE ripgeo_id = @id
                RETURNING ripgeo_id, ripgeo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Ripartizione geografica con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della ripartizione geografica");
            throw;
        }
    }

    protected override RipartizioneGeografica MapFromReader(NpgsqlDataReader reader)
    {
        return new RipartizioneGeografica
        {
            Id = ReadInt(reader, "ripgeo_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("ripgeo_descrizione"))
        };
    }
}
