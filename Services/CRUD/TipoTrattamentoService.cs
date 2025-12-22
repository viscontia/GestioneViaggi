using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoTrattamentoService : BaseCrudService<TipoTrattamento>
{
    protected override string TableName => "ana_tipo_trattamento";
    protected override string IdColumnName => "tipo_trattamento_id";

    public TipoTrattamentoService(IDatabaseService databaseService, ILogger<TipoTrattamentoService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoTrattamento> CreateAsync(TipoTrattamento entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_trattamento (tipo_trattamento_descrizione)
                VALUES (@descrizione)
                RETURNING tipo_trattamento_id, tipo_trattamento_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo di trattamento");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo di trattamento");
            throw;
        }
    }

    public override async Task<TipoTrattamento> UpdateAsync(TipoTrattamento entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_trattamento
                SET tipo_trattamento_descrizione = @descrizione
                WHERE tipo_trattamento_id = @id
                RETURNING tipo_trattamento_id, tipo_trattamento_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo di trattamento con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo di trattamento");
            throw;
        }
    }

    protected override TipoTrattamento MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoTrattamento
        {
            Id = ReadInt(reader, "tipo_trattamento_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_trattamento_descrizione"))
        };
    }
}
