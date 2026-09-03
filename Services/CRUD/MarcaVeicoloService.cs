using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class MarcaVeicoloService : BaseCrudService<MarcaVeicolo>
{
    protected override string TableName => "ana_mezzi";
    protected override string IdColumnName => "ana_mezzi_id";

    public MarcaVeicoloService(IDatabaseService databaseService, ILogger<MarcaVeicoloService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<List<MarcaVeicolo>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM ana_mezzi ORDER BY ana_mezzi_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<MarcaVeicolo>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti gli elementi da {TableName}", TableName);
            throw;
        }
    }

    /// <summary>
    /// Le marche che hanno almeno un mezzo del tipo richiesto; con <c>null</c>, tutte.
    ///
    /// La derivazione sta nel database (SqlScripts/577): il tipo e' sul modello, non sulla
    /// marca, e la stessa domanda la fara' il sito di iscrizione.
    /// </summary>
    public async Task<List<MarcaVeicolo>> GetByTipoMezzoAsync(int? tipoMezzoId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT * FROM fn_ana_mezzi_marche_per_tipo(@tipo)", connection);
            command.Parameters.AddWithValue("tipo", (object?)tipoMezzoId ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<MarcaVeicolo>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero delle marche per tipo mezzo {TipoMezzoId}", tipoMezzoId);
            throw;
        }
    }

    public override async Task<MarcaVeicolo> CreateAsync(MarcaVeicolo entity)
    {
        return await CreateAsyncInternal(entity, true);
    }

    private async Task<MarcaVeicolo> CreateAsyncInternal(MarcaVeicolo entity, bool allowRetry)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_mezzi (
                    ana_mezzi_descrizione
                )
                VALUES (@descrizione)
                RETURNING ana_mezzi_id, ana_mezzi_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la marca veicolo");
        }
        catch (PostgresException ex) when (allowRetry && ex.SqlState == "42P01" && ex.Message.Contains("ana_mezzi_seq"))
        {
            _logger.LogWarning(ex, "Sequence ana_mezzi_seq missing. Attempting to auto-fix schema.");
            await FixSequenceAsync();
            return await CreateAsyncInternal(entity, false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della marca veicolo");
            throw;
        }
    }

    protected override async Task FixSequenceAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                DO $$
                BEGIN
                    -- 1. Create the sequence if it doesn't exist
                    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'ana_mezzi_seq') THEN
                        CREATE SEQUENCE ana_mezzi_seq;
                    END IF;

                    -- 2. Set the default value for the id column to use the sequence
                    ALTER TABLE ana_mezzi 
                    ALTER COLUMN ana_mezzi_id SET DEFAULT nextval('ana_mezzi_seq');

                    -- 3. Sync the sequence with the current max id
                    PERFORM setval('ana_mezzi_seq', COALESCE((SELECT MAX(ana_mezzi_id) FROM ana_mezzi), 0) + 1, false);
                END $$;";

            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();
            _logger.LogInformation("Schema auto-fix applied: ana_mezzi_seq created and synced.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to auto-fix schema for ana_mezzi_seq");
            throw; // Re-throw to let the original error eventually surface if needed
        }
    }

    public override async Task<MarcaVeicolo> UpdateAsync(MarcaVeicolo entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_mezzi
                SET ana_mezzi_descrizione = @descrizione
                WHERE ana_mezzi_id = @id
                RETURNING ana_mezzi_id, ana_mezzi_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Marca veicolo con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della marca veicolo");
            throw;
        }
    }

    protected override MarcaVeicolo MapFromReader(NpgsqlDataReader reader)
    {
        return new MarcaVeicolo
        {
            Id = ReadInt(reader, "ana_mezzi_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("ana_mezzi_descrizione"))
        };
    }
}
