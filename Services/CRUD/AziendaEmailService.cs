using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaEmailService : BaseCrudService<AziendaEmail>
{
    protected override string TableName => "ana_aziende_email";
    protected override string IdColumnName => "email_id";

    public AziendaEmailService(IDatabaseService databaseService, ILogger<AziendaEmailService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<AziendaEmail> CreateAsync(AziendaEmail entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende_email (
                    azienda_fk, email, is_principale, note, reparto_fk
                )
                VALUES (@aziendaFk, @email, @isPrincipale, @note, @repartoFk)
                RETURNING email_id, azienda_fk, email, is_principale, note, reparto_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("email", entity.Email);
            command.Parameters.AddWithValue("isPrincipale", entity.IsPrincipale);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);
            command.Parameters.AddWithValue("repartoFk", entity.RepartoIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare l'email aziendale");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'email");
            throw;
        }
    }

    public override async Task<AziendaEmail> UpdateAsync(AziendaEmail entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_email
                SET email = @email,
                    is_principale = @isPrincipale,
                    note = @note,
                    reparto_fk = @repartoFk
                WHERE email_id = @id
                RETURNING email_id, azienda_fk, email, is_principale, note, reparto_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("email", entity.Email);
            command.Parameters.AddWithValue("isPrincipale", entity.IsPrincipale);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);
            command.Parameters.AddWithValue("repartoFk", entity.RepartoIdFk);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Email aziendale con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'email");
            throw;
        }
    }

    protected override AziendaEmail MapFromReader(NpgsqlDataReader reader)
    {
        return new AziendaEmail
        {
            Id = ReadInt(reader, "email_id"),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            Email = reader.GetString(reader.GetOrdinal("email")),
            IsPrincipale = reader.GetBoolean(reader.GetOrdinal("is_principale")),
            Note = ReadNullableString(reader, "note"),
            RepartoIdFk = ReadInt(reader, "reparto_fk")
        };
    }

    /// <summary>
    /// Ottiene tutte le email di una specifica azienda con JOIN per lookup
    /// </summary>
    public async Task<List<AziendaEmail>> GetByAziendaIdAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    e.email_id, e.azienda_fk, e.email, e.is_principale, e.note, e.reparto_fk,
                    r.nome_reparto as reparto_nome
                FROM ana_aziende_email e
                INNER JOIN reparti_aziendali r ON e.reparto_fk = r.reparto_id
                WHERE e.azienda_fk = @aziendaId
                ORDER BY e.is_principale DESC, r.nome_reparto ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var emails = new List<AziendaEmail>();
            while (await reader.ReadAsync())
            {
                var email = MapFromReader(reader);
                email.RepartoNome = ReadNullableString(reader, "reparto_nome");
                emails.Add(email);
            }

            return emails;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle email per azienda {AziendaId}", aziendaId);
            throw;
        }
    }
}
