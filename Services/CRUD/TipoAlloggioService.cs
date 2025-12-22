using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoAlloggioService : BaseCrudService<TipoAlloggio>
{
    protected override string TableName => "ana_tipo_alloggio";
    protected override string IdColumnName => "tipo_alloggio_id";

    public TipoAlloggioService(IDatabaseService databaseService, ILogger<TipoAlloggioService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoAlloggio> CreateAsync(TipoAlloggio entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_alloggio (tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento)
                VALUES (@descrizione, @numero_occupanti, @supplemento)
                RETURNING tipo_alloggio_id, tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("numero_occupanti", entity.NumeroOccupanti);
            command.Parameters.AddWithValue("supplemento", entity.SupplementoDb);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo di alloggio");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo di alloggio");
            throw;
        }
    }

    public override async Task<TipoAlloggio> UpdateAsync(TipoAlloggio entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_alloggio
                SET tipo_alloggio_descrizione = @descrizione,
                    tipo_alloggio_numero_occupanti = @numero_occupanti,
                    tipo_alloggio_supplemento = @supplemento
                WHERE tipo_alloggio_id = @id
                RETURNING tipo_alloggio_id, tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("numero_occupanti", entity.NumeroOccupanti);
            command.Parameters.AddWithValue("supplemento", entity.SupplementoDb);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo di alloggio con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo di alloggio");
            throw;
        }
    }

    protected override TipoAlloggio MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoAlloggio
        {
            Id = ReadInt(reader, "tipo_alloggio_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_alloggio_descrizione")),
            NumeroOccupanti = reader.GetInt32(reader.GetOrdinal("tipo_alloggio_numero_occupanti")),
            SupplementoDb = reader.GetString(reader.GetOrdinal("tipo_alloggio_supplemento"))
        };
    }
}
