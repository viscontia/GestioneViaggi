using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoViaggioService : BaseCrudService<TipoViaggio>
{
    protected override string TableName => "ana_tipo_viaggi";
    protected override string IdColumnName => "tipo_viaggi_id";

    public TipoViaggioService(IDatabaseService databaseService, ILogger<TipoViaggioService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoViaggio> CreateAsync(TipoViaggio entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_viaggi (
                    tipo_viaggi_tipo,
                    tipo_viaggi_descrizione
                )
                VALUES (@tipo, @descrizione)
                RETURNING tipo_viaggi_id, tipo_viaggi_tipo, tipo_viaggi_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("tipo", entity.Tipo);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo viaggio");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo viaggio");
            throw;
        }
    }

    public override async Task<TipoViaggio> UpdateAsync(TipoViaggio entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_viaggi
                SET tipo_viaggi_tipo = @tipo,
                    tipo_viaggi_descrizione = @descrizione
                WHERE tipo_viaggi_id = @id
                RETURNING tipo_viaggi_id, tipo_viaggi_tipo, tipo_viaggi_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("tipo", entity.Tipo);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo viaggio con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo viaggio");
            throw;
        }
    }

    protected override TipoViaggio MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoViaggio
        {
            Id = ReadInt(reader, "tipo_viaggi_id"),
            Tipo = reader.GetString(reader.GetOrdinal("tipo_viaggi_tipo")),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_viaggi_descrizione"))
        };
    }
}
