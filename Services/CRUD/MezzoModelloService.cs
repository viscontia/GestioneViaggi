using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class MezzoModelloService : BaseCrudService<MezzoModello>
{
    protected override string TableName => "ana_mezzi_modelli";
    protected override string IdColumnName => "mezzo_modello_id";

    public MezzoModelloService(IDatabaseService databaseService, ILogger<MezzoModelloService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<List<MezzoModello>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            // Join per recuperare le descrizioni delle FK
            var sql = @"
                SELECT 
                    m.mezzo_modello_id, 
                    m.mezzo_modello_descrizione, 
                    m.mezzo_modello_mezzo_fk, 
                    m.mezzo_modello_tipo_fk,
                    am.ana_mezzi_descrizione,
                    atm.ana_tipo_mezzo_descrizione
                FROM ana_mezzi_modelli m
                LEFT JOIN ana_mezzi am ON m.mezzo_modello_mezzo_fk = am.ana_mezzi_id
                LEFT JOIN ana_tipo_mezzi atm ON m.mezzo_modello_tipo_fk = atm.ana_tipo_mezzo_id
                ORDER BY 
                    atm.ana_tipo_mezzo_descrizione,
                    am.ana_mezzi_descrizione,
                    m.mezzo_modello_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<MezzoModello>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti i modelli veicolo");
            throw;
        }
    }

    public override async Task<MezzoModello> CreateAsync(MezzoModello entity)
    {
        return await CreateAsyncInternal(entity, true);
    }

    private async Task<MezzoModello> CreateAsyncInternal(MezzoModello entity, bool allowRetry)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_mezzi_modelli (
                    mezzo_modello_descrizione,
                    mezzo_modello_mezzo_fk,
                    mezzo_modello_tipo_fk
                )
                VALUES (@descrizione, @marcaId, @tipoId)
                RETURNING mezzo_modello_id, mezzo_modello_descrizione, mezzo_modello_mezzo_fk, mezzo_modello_tipo_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("marcaId", entity.MarcaIdFk);
            command.Parameters.AddWithValue("tipoId", entity.TipoMezzoIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                // Nota: qui ritorniamo l'oggetto senza le descrizioni delle FK popolate, 
                // ma per la logica di creazione va bene. Se serve visualizzarlo subito in griglia
                // con le descrizioni, bisognerebbe fare una rilettura o assegnarle manualmente se note.
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il modello veicolo");
        }
        catch (PostgresException ex) when (allowRetry && ex.SqlState == "42P01" && ex.Message.Contains("ana_mezzi_modelli_seq"))
        {
            _logger.LogWarning(ex, "Sequence ana_mezzi_modelli_seq missing. Attempting to auto-fix schema.");
            await FixSequenceAsync();
            return await CreateAsyncInternal(entity, false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del modello veicolo");
            throw;
        }
    }

    private async Task FixSequenceAsync()
    {
        try 
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                DO $$
                BEGIN
                    -- 1. Create the sequence if it doesn't exist
                    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'ana_mezzi_modelli_seq') THEN
                        CREATE SEQUENCE ana_mezzi_modelli_seq;
                    END IF;

                    -- 2. Set the default value for the id column to use the sequence
                    ALTER TABLE ana_mezzi_modelli 
                    ALTER COLUMN mezzo_modello_id SET DEFAULT nextval('ana_mezzi_modelli_seq');

                    -- 3. Sync the sequence with the current max id
                    PERFORM setval('ana_mezzi_modelli_seq', COALESCE((SELECT MAX(mezzo_modello_id) FROM ana_mezzi_modelli), 0) + 1, false);
                END $$;";
                
            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();
            _logger.LogInformation("Schema auto-fix applied: ana_mezzi_modelli_seq created and synced.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to auto-fix schema for ana_mezzi_modelli_seq");
            throw; // Re-throw to let the original error eventually surface if needed
        }
    }

    public override async Task<MezzoModello> UpdateAsync(MezzoModello entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_mezzi_modelli
                SET mezzo_modello_descrizione = @descrizione,
                    mezzo_modello_mezzo_fk = @marcaId,
                    mezzo_modello_tipo_fk = @tipoId
                WHERE mezzo_modello_id = @id
                RETURNING mezzo_modello_id, mezzo_modello_descrizione, mezzo_modello_mezzo_fk, mezzo_modello_tipo_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("marcaId", entity.MarcaIdFk);
            command.Parameters.AddWithValue("tipoId", entity.TipoMezzoIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Modello veicolo con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del modello veicolo");
            throw;
        }
    }

    protected override MezzoModello MapFromReader(NpgsqlDataReader reader)
    {
        var entity = new MezzoModello
        {
            Id = ReadInt(reader, "mezzo_modello_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("mezzo_modello_descrizione")),
            MarcaIdFk = ReadInt(reader, "mezzo_modello_mezzo_fk"),
            TipoMezzoIdFk = ReadInt(reader, "mezzo_modello_tipo_fk")
        };

        // Tentativo di leggere le colonne di join se presenti (per GetAllAsync)
        try
        {
            entity.MarcaDescrizione = reader.GetString(reader.GetOrdinal("ana_mezzi_descrizione"));
            entity.TipoMezzoDescrizione = reader.GetString(reader.GetOrdinal("ana_tipo_mezzo_descrizione"));
        }
        catch
        {
            // Colonne non presenti (es. durante Create/Update RETURNING)
            // Ignoriamo l'errore
        }

        return entity;
    }
}
