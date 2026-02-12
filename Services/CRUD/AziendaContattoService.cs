using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaContattoService : BaseCrudService<AziendaContatto>
{
    protected override string TableName => "ana_aziende_contatti";
    protected override string IdColumnName => "contatto_id";

    public AziendaContattoService(
        IDatabaseService databaseService,
        ILogger<AziendaContattoService> logger,
        ITenantContext tenantContext)
        : base(databaseService, logger, tenantContext)
    {
    }

    public override async Task<AziendaContatto> CreateAsync(AziendaContatto entity)
    {
        // Validazione tenant: verifica accesso all'azienda
        await ValidateTenantAccessAsync(entity.AziendaIdFk);

        try
        {
            // Normalizza stringhe nullable (converte "" in NULL)
            NormalizeEntityBeforeSave(entity);

            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende_contatti (
                    azienda_fk, sede_fk, nome, cognome, ruolo,
                    telefono_diretto, cellulare, email, note
                )
                VALUES (@aziendaFk, @sedeFk, @nome, @cognome, @ruolo,
                        @telefonoDiretto, @cellulare, @email, @note)
                RETURNING contatto_id, azienda_fk, sede_fk, nome, cognome, ruolo,
                          telefono_diretto, cellulare, email, note, data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("sedeFk", entity.SedeIdFk);
            command.Parameters.AddWithValue("nome", entity.Nome);
            command.Parameters.AddWithValue("cognome", entity.Cognome);
            command.Parameters.AddWithValue("ruolo", entity.Ruolo);
            command.Parameters.AddWithValue("telefonoDiretto", (object?)entity.TelefonoDiretto ?? DBNull.Value);
            command.Parameters.AddWithValue("cellulare", (object?)entity.Cellulare ?? DBNull.Value);
            command.Parameters.AddWithValue("email", (object?)entity.Email ?? DBNull.Value);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il contatto");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del contatto");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AziendaContatto> UpdateAsync(AziendaContatto entity)
    {
        // Validazione tenant: verifica accesso all'azienda
        await ValidateTenantAccessAsync(entity.AziendaIdFk);

        try
        {
            // Normalizza stringhe nullable (converte "" in NULL)
            NormalizeEntityBeforeSave(entity);

            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_contatti
                SET sede_fk = @sedeFk,
                    nome = @nome,
                    cognome = @cognome,
                    ruolo = @ruolo,
                    telefono_diretto = @telefonoDiretto,
                    cellulare = @cellulare,
                    email = @email,
                    note = @note
                WHERE contatto_id = @id
                RETURNING contatto_id, azienda_fk, sede_fk, nome, cognome, ruolo,
                          telefono_diretto, cellulare, email, note, data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("sedeFk", entity.SedeIdFk);
            command.Parameters.AddWithValue("nome", entity.Nome);
            command.Parameters.AddWithValue("cognome", entity.Cognome);
            command.Parameters.AddWithValue("ruolo", entity.Ruolo);
            command.Parameters.AddWithValue("telefonoDiretto", (object?)entity.TelefonoDiretto ?? DBNull.Value);
            command.Parameters.AddWithValue("cellulare", (object?)entity.Cellulare ?? DBNull.Value);
            command.Parameters.AddWithValue("email", (object?)entity.Email ?? DBNull.Value);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Contatto con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del contatto");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AziendaContatto MapFromReader(NpgsqlDataReader reader)
    {
        return new AziendaContatto
        {
            Id = ReadInt(reader, "contatto_id"),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            SedeIdFk = ReadInt(reader, "sede_fk"),
            Nome = reader.GetString(reader.GetOrdinal("nome")),
            Cognome = reader.GetString(reader.GetOrdinal("cognome")),
            Ruolo = reader.GetString(reader.GetOrdinal("ruolo")),
            TelefonoDiretto = ReadNullableString(reader, "telefono_diretto"),
            Cellulare = ReadNullableString(reader, "cellulare"),
            Email = ReadNullableString(reader, "email"),
            Note = ReadNullableString(reader, "note"),
            DataUltimaModifica = ReadNullableDateTime(reader, "data_ultima_modifica")
        };
    }

    /// <summary>
    /// Ottiene tutti i contatti di una specifica azienda con JOIN per lookup
    /// </summary>
    public async Task<List<AziendaContatto>> GetByAziendaIdAsync(int aziendaId)
    {
        // Validazione tenant: verifica accesso all'azienda
        await ValidateTenantAccessAsync(aziendaId);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    c.contatto_id, c.azienda_fk, c.sede_fk, c.nome, c.cognome, c.ruolo,
                    c.telefono_diretto, c.cellulare, c.email, c.note, c.data_ultima_modifica,
                    s.indirizzo as sede_indirizzo,
                    co.comune_descrizione as sede_citta
                FROM ana_aziende_contatti c
                INNER JOIN ana_aziende_sedi s ON c.sede_fk = s.sede_id
                INNER JOIN ana_geo_comuni co ON s.comune_fk = co.comune_id
                WHERE c.azienda_fk = @aziendaId
                ORDER BY c.cognome ASC, c.nome ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var contatti = new List<AziendaContatto>();
            while (await reader.ReadAsync())
            {
                var contatto = MapFromReader(reader);
                contatto.SedeIndirizzo = ReadNullableString(reader, "sede_indirizzo");
                contatto.SedeCitta = ReadNullableString(reader, "sede_citta");
                contatti.Add(contatto);
            }

            return contatti;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei contatti per azienda {AziendaId}", aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }
}
