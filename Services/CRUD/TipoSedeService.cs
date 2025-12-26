using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoSedeService : BaseCrudService<TipoSede>
{
    protected override string TableName => "ana_tipo_sedi";
    protected override string IdColumnName => "tipo_sede_id";

    public TipoSedeService(IDatabaseService databaseService, ILogger<TipoSedeService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoSede> CreateAsync(TipoSede entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_tipo_sedi (
                    codice, descrizione, is_active
                )
                VALUES (@codice, @descrizione, @isActive)
                RETURNING tipo_sede_id, codice, descrizione, is_active, created_at, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("codice", entity.Codice.ToUpper());
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("isActive", entity.IsActive);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo sede");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo sede");
            throw;
        }
    }

    public override async Task<TipoSede> UpdateAsync(TipoSede entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_tipo_sedi
                SET codice = @codice,
                    descrizione = @descrizione,
                    is_active = @isActive
                WHERE tipo_sede_id = @id
                RETURNING tipo_sede_id, codice, descrizione, is_active, created_at, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("codice", entity.Codice.ToUpper());
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("isActive", entity.IsActive);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo sede con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo sede");
            throw;
        }
    }

    protected override TipoSede MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoSede
        {
            Id = ReadInt(reader, "tipo_sede_id"),
            Codice = reader.GetString(reader.GetOrdinal("codice")),
            Descrizione = reader.GetString(reader.GetOrdinal("descrizione")),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            CreatedAt = reader.GetDateTime(reader.GetOrdinal("created_at")),
            UpdatedAt = ReadNullableDateTime(reader, "updated_at")
        };
    }

    /// <summary>
    /// Ottiene tutti i tipi sede attivi ordinati per descrizione
    /// </summary>
    public async Task<List<TipoSede>> GetAllActiveAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT tipo_sede_id, codice, descrizione, is_active, created_at, updated_at
                FROM ana_tipo_sedi
                WHERE is_active = true
                ORDER BY descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var tipiSede = new List<TipoSede>();
            while (await reader.ReadAsync())
            {
                tipiSede.Add(MapFromReader(reader));
            }

            return tipiSede;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei tipi sede attivi");
            throw;
        }
    }
}
