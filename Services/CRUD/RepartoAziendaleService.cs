using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Validation.Syntax;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class RepartoAziendaleService : BaseCrudService<RepartoAziendale>
{
    protected override string TableName => "reparti_aziendali";
    protected override string IdColumnName => "reparto_id";

    public RepartoAziendaleService(IDatabaseService databaseService, ILogger<RepartoAziendaleService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<RepartoAziendale> CreateAsync(RepartoAziendale entity)
    {
        try
        {
            // Validazione sintattica del telefono (opzionale)
            if (!string.IsNullOrWhiteSpace(entity.TelefonoReparto))
            {
                var validationResult = PhoneValidator.CheckTelefonoItaly(entity.TelefonoReparto);
                if (!validationResult.IsValid)
                {
                    throw new ArgumentException(validationResult.ErrorMessage);
                }
            }

            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO reparti_aziendali (
                    azienda_fk, nome_reparto, descrizione, telefono_reparto,
                    manager_contatto_fk, is_active
                )
                VALUES (@aziendaFk, @nomeReparto, @descrizione, @telefonoReparto,
                        @managerContattoFk, @isActive)
                RETURNING reparto_id, azienda_fk, nome_reparto, descrizione, telefono_reparto,
                          manager_contatto_fk, is_active";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("nomeReparto", entity.NomeReparto);
            command.Parameters.AddWithValue("descrizione", (object?)entity.Descrizione ?? DBNull.Value);
            command.Parameters.AddWithValue("telefonoReparto", (object?)entity.TelefonoReparto ?? DBNull.Value);
            command.Parameters.AddWithValue("managerContattoFk", (object?)entity.ManagerContattoIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("isActive", entity.IsActive);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il reparto");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del reparto");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<RepartoAziendale> UpdateAsync(RepartoAziendale entity)
    {
        try
        {
            // Validazione sintattica del telefono (opzionale)
            if (!string.IsNullOrWhiteSpace(entity.TelefonoReparto))
            {
                var validationResult = PhoneValidator.CheckTelefonoItaly(entity.TelefonoReparto);
                if (!validationResult.IsValid)
                {
                    throw new ArgumentException(validationResult.ErrorMessage);
                }
            }

            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE reparti_aziendali
                SET nome_reparto = @nomeReparto,
                    descrizione = @descrizione,
                    telefono_reparto = @telefonoReparto,
                    manager_contatto_fk = @managerContattoFk,
                    is_active = @isActive
                WHERE reparto_id = @id
                RETURNING reparto_id, azienda_fk, nome_reparto, descrizione, telefono_reparto,
                          manager_contatto_fk, is_active";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("nomeReparto", entity.NomeReparto);
            command.Parameters.AddWithValue("descrizione", (object?)entity.Descrizione ?? DBNull.Value);
            command.Parameters.AddWithValue("telefonoReparto", (object?)entity.TelefonoReparto ?? DBNull.Value);
            command.Parameters.AddWithValue("managerContattoFk", (object?)entity.ManagerContattoIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("isActive", entity.IsActive);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Reparto con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del reparto");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override RepartoAziendale MapFromReader(NpgsqlDataReader reader)
    {
        return new RepartoAziendale
        {
            Id = ReadInt(reader, "reparto_id"),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            NomeReparto = reader.GetString(reader.GetOrdinal("nome_reparto")),
            Descrizione = ReadNullableString(reader, "descrizione"),
            TelefonoReparto = ReadNullableString(reader, "telefono_reparto"),
            ManagerContattoIdFk = ReadNullableInt(reader, "manager_contatto_fk"),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active"))
        };
    }

    /// <summary>
    /// Ottiene tutti i reparti attivi di una specifica azienda ordinati per nome
    /// </summary>
    public async Task<List<RepartoAziendale>> GetByAziendaIdAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT reparto_id, azienda_fk, nome_reparto, descrizione, telefono_reparto,
                       manager_contatto_fk, is_active
                FROM reparti_aziendali
                WHERE azienda_fk = @aziendaId AND is_active = true
                ORDER BY nome_reparto ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var reparti = new List<RepartoAziendale>();
            while (await reader.ReadAsync())
            {
                reparti.Add(MapFromReader(reader));
            }

            return reparti;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei reparti per azienda {AziendaId}", aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }
}
