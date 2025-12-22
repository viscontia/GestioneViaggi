using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoPernottamentoService : BaseCrudService<TipoPernottamento>
{
    protected override string TableName => "ana_tipo_pernottamento";
    protected override string IdColumnName => "ana_tipo_pernottamento_id";

    public TipoPernottamentoService(IDatabaseService databaseService, ILogger<TipoPernottamentoService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoPernottamento> CreateAsync(TipoPernottamento entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_pernottamento (ana_tipo_pernottamento_descrizione, ana_tipo_pernottamento_con_albergo)
                VALUES (@descrizione, @con_albergo)
                RETURNING ana_tipo_pernottamento_id, ana_tipo_pernottamento_descrizione, ana_tipo_pernottamento_con_albergo";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("con_albergo", entity.ConAlbergoDb);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo di pernottamento");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo di pernottamento");
            throw;
        }
    }

    public override async Task<TipoPernottamento> UpdateAsync(TipoPernottamento entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_pernottamento
                SET ana_tipo_pernottamento_descrizione = @descrizione,
                    ana_tipo_pernottamento_con_albergo = @con_albergo
                WHERE ana_tipo_pernottamento_id = @id
                RETURNING ana_tipo_pernottamento_id, ana_tipo_pernottamento_descrizione, ana_tipo_pernottamento_con_albergo";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("con_albergo", entity.ConAlbergoDb);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo di pernottamento con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo di pernottamento");
            throw;
        }
    }

    protected override TipoPernottamento MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoPernottamento
        {
            Id = ReadInt(reader, "ana_tipo_pernottamento_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("ana_tipo_pernottamento_descrizione")),
            ConAlbergoDb = reader.GetString(reader.GetOrdinal("ana_tipo_pernottamento_con_albergo"))
        };
    }
}
