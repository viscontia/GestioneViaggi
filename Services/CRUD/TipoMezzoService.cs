using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoMezzoService : BaseCrudService<TipoMezzo>
{
    protected override string TableName => "ana_tipo_mezzi";
    protected override string IdColumnName => "ana_tipo_mezzo_id";

    public TipoMezzoService(IDatabaseService databaseService, ILogger<TipoMezzoService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<List<TipoMezzo>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM ana_tipo_mezzi ORDER BY ana_tipo_mezzo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<TipoMezzo>();
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

    public override async Task<TipoMezzo> CreateAsync(TipoMezzo entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_mezzi (
                    ana_tipo_mezzo_descrizione
                )
                VALUES (@descrizione)
                RETURNING ana_tipo_mezzo_id, ana_tipo_mezzo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo mezzo");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo mezzo");
            throw;
        }
    }

    public override async Task<TipoMezzo> UpdateAsync(TipoMezzo entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_mezzi
                SET ana_tipo_mezzo_descrizione = @descrizione
                WHERE ana_tipo_mezzo_id = @id
                RETURNING ana_tipo_mezzo_id, ana_tipo_mezzo_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo mezzo con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo mezzo");
            throw;
        }
    }

    protected override TipoMezzo MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoMezzo
        {
            Id = ReadInt(reader, "ana_tipo_mezzo_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("ana_tipo_mezzo_descrizione"))
        };
    }
}
