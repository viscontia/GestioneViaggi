using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaBancaService : BaseCrudService<AziendaBanca>
{
    protected override string TableName => "ana_aziende_banche";
    protected override string IdColumnName => "banca_id";

    public AziendaBancaService(IDatabaseService databaseService, ILogger<AziendaBancaService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<AziendaBanca> CreateAsync(AziendaBanca entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende_banche (
                    azienda_fk, nome_banca, filiale, iban, swift_bic, is_predefinito, note
                )
                VALUES (@aziendaFk, @nomeBanca, @filiale, @iban, @swiftBic, @isPredefinito, @note)
                RETURNING banca_id, azienda_fk, nome_banca, filiale, iban, swift_bic, is_predefinito, note";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("nomeBanca", entity.NomeBanca);
            command.Parameters.AddWithValue("filiale", (object?)entity.Filiale ?? DBNull.Value);
            command.Parameters.AddWithValue("iban", entity.Iban);
            command.Parameters.AddWithValue("swiftBic", (object?)entity.SwiftBic ?? DBNull.Value);
            command.Parameters.AddWithValue("isPredefinito", entity.IsPredefinito);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il conto bancario");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del conto bancario");
            throw;
        }
    }

    public override async Task<AziendaBanca> UpdateAsync(AziendaBanca entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_banche
                SET nome_banca = @nomeBanca,
                    filiale = @filiale,
                    iban = @iban,
                    swift_bic = @swiftBic,
                    is_predefinito = @isPredefinito,
                    note = @note
                WHERE banca_id = @id
                RETURNING banca_id, azienda_fk, nome_banca, filiale, iban, swift_bic, is_predefinito, note";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("nomeBanca", entity.NomeBanca);
            command.Parameters.AddWithValue("filiale", (object?)entity.Filiale ?? DBNull.Value);
            command.Parameters.AddWithValue("iban", entity.Iban);
            command.Parameters.AddWithValue("swiftBic", (object?)entity.SwiftBic ?? DBNull.Value);
            command.Parameters.AddWithValue("isPredefinito", entity.IsPredefinito);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Conto bancario con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del conto bancario");
            throw;
        }
    }

    protected override AziendaBanca MapFromReader(NpgsqlDataReader reader)
    {
        return new AziendaBanca
        {
            Id = ReadInt(reader, "banca_id"),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            NomeBanca = reader.GetString(reader.GetOrdinal("nome_banca")),
            Filiale = ReadNullableString(reader, "filiale"),
            Iban = reader.GetString(reader.GetOrdinal("iban")),
            SwiftBic = ReadNullableString(reader, "swift_bic"),
            IsPredefinito = reader.GetBoolean(reader.GetOrdinal("is_predefinito")),
            Note = ReadNullableString(reader, "note")
        };
    }

    /// <summary>
    /// Ottiene tutti i conti bancari di una specifica azienda
    /// </summary>
    public async Task<List<AziendaBanca>> GetByAziendaIdAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    banca_id, azienda_fk, nome_banca, filiale, iban, swift_bic, is_predefinito, note
                FROM ana_aziende_banche
                WHERE azienda_fk = @aziendaId
                ORDER BY is_predefinito DESC, nome_banca ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var banche = new List<AziendaBanca>();
            while (await reader.ReadAsync())
            {
                banche.Add(MapFromReader(reader));
            }

            return banche;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei conti bancari per azienda {AziendaId}", aziendaId);
            throw;
        }
    }
}
