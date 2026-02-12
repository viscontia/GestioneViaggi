using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Servizio CRUD specifico per la gestione dei Capoluoghi (tabella ana_geo_capoluogo)
/// </summary>
public class CapoluogoService : BaseCrudService<Capoluogo>
{
    protected override string TableName => "ana_geo_capoluogo";
    protected override string IdColumnName => "capoluogo_id";

    public CapoluogoService(IDatabaseService databaseService, ILogger<CapoluogoService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<Capoluogo> CreateAsync(Capoluogo entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_geo_capoluogo (capoluogo_descrizione)
                VALUES (@descrizione)
                RETURNING capoluogo_id, capoluogo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il capoluogo");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del capoluogo {Descrizione}", entity.Descrizione);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<Capoluogo> UpdateAsync(Capoluogo entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_geo_capoluogo
                SET capoluogo_descrizione = @descrizione
                WHERE capoluogo_id = @id
                RETURNING capoluogo_id, capoluogo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Capoluogo con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del capoluogo {Id}", entity.Id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override Capoluogo MapFromReader(NpgsqlDataReader reader)
    {
        return new Capoluogo
        {
            Id = ReadInt(reader, "capoluogo_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("capoluogo_descrizione"))
        };
    }
}
