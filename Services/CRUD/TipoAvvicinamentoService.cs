using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoAvvicinamentoService : BaseCrudService<TipoAvvicinamento>
{
    protected override string TableName => "ana_tipo_avvicinamento";
    protected override string IdColumnName => "tipo_avvicinamento_id";

    public TipoAvvicinamentoService(IDatabaseService databaseService, ILogger<TipoAvvicinamentoService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoAvvicinamento> CreateAsync(TipoAvvicinamento entity)
    {
        // Wrapper per gestire il retry in caso di sequenza mancante
        return await CreateAsyncInternal(entity, true);
    }

    private async Task<TipoAvvicinamento> CreateAsyncInternal(TipoAvvicinamento entity, bool allowRetry)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_avvicinamento (tipo_avvicinamento_descrizione)
                VALUES (@descrizione)
                RETURNING tipo_avvicinamento_id, tipo_avvicinamento_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo di avvicinamento");
        }
        catch (PostgresException ex) when (allowRetry && ex.SqlState == "42P01" && ex.Message.Contains("ana_tipo_avvicinamento_seq"))
        {
            _logger.LogWarning(ex, "Sequence mancante per ana_tipo_avvicinamento. Tentativo di auto-fix.");
            await FixSequenceAsync();
            return await CreateAsyncInternal(entity, false); // Retry
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo di avvicinamento");
            throw;
        }
    }

    public override async Task<TipoAvvicinamento> UpdateAsync(TipoAvvicinamento entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_avvicinamento
                SET tipo_avvicinamento_descrizione = @descrizione
                WHERE tipo_avvicinamento_id = @id
                RETURNING tipo_avvicinamento_id, tipo_avvicinamento_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo di avvicinamento con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo di avvicinamento");
            throw;
        }
    }

    protected override TipoAvvicinamento MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoAvvicinamento
        {
            Id = ReadInt(reader, "tipo_avvicinamento_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_avvicinamento_descrizione"))
        };
    }

    protected override async Task FixSequenceAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                DO $$
                BEGIN
                    -- 1. Crea la sequence se non esiste
                    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'ana_tipo_avvicinamento_seq') THEN
                        CREATE SEQUENCE ana_tipo_avvicinamento_seq;
                    END IF;

                    -- 2. Imposta il default della colonna ID
                    ALTER TABLE ana_tipo_avvicinamento 
                    ALTER COLUMN tipo_avvicinamento_id SET DEFAULT nextval('ana_tipo_avvicinamento_seq');

                    -- 3. Sincronizza con il MAX ID attuale
                    PERFORM setval('ana_tipo_avvicinamento_seq', COALESCE((SELECT MAX(tipo_avvicinamento_id) FROM ana_tipo_avvicinamento), 0) + 1, false);
                END $$;";

            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il fix della sequence per ana_tipo_avvicinamento");
            throw;
        }
    }
}
