using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per la lista di soppressione newsletter (web_newsletter_soppressioni).
/// Delega ogni operazione alle funzioni fn_web_newsletter_soppressioni_* (Blocco 2).
/// Le email presenti qui sono escluse da ogni invio (vedi fn_web_destinatari_newsletter).
/// Multi-tenant: ogni operazione è scopata per azienda_id.
/// </summary>
public class WebNewsletterSoppressioniService : BaseCrudService<WebNewsletterSoppressione>
{
    protected override string TableName => "web_newsletter_soppressioni";
    protected override string IdColumnName => "web_newsletter_soppressioni_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebNewsletterSoppressioniService(IDatabaseService databaseService, ILogger<WebNewsletterSoppressioniService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco delle soppressioni di un'azienda.</summary>
    public async Task<List<WebNewsletterSoppressione>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_soppressioni_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebNewsletterSoppressione>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero soppressioni newsletter per azienda {AziendaId}", aziendaId);
            return new List<WebNewsletterSoppressione>();
        }
    }

    /// <summary>Recupera una soppressione per id, scopata per azienda. NULL se non trovata/altra azienda.</summary>
    public async Task<WebNewsletterSoppressione?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_soppressioni_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero soppressione {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterSoppressione> CreateAsync(WebNewsletterSoppressione entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_soppressioni_insert(
                @AziendaId::integer,
                @Email::citext,
                @Motivo::varchar,
                @Data::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebNewsletterSoppressioneId = Convert.ToInt64(result);

            _logger.LogInformation("Soppressione newsletter creata con ID {Id} ({Email})", entity.WebNewsletterSoppressioneId, entity.Email);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione soppressione: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della soppressione {Email}", entity.Email);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterSoppressione> UpdateAsync(WebNewsletterSoppressione entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_soppressioni_update(
                @Id::bigint,
                @AziendaId::integer,
                @Email::citext,
                @Motivo::varchar,
                @Data::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebNewsletterSoppressioneId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Soppressione {entity.WebNewsletterSoppressioneId} non trovata per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Soppressione {Id} aggiornata", entity.WebNewsletterSoppressioneId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento soppressione {Id}: {Error}", entity.WebNewsletterSoppressioneId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della soppressione {Id}", entity.WebNewsletterSoppressioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una soppressione, scopata per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_newsletter_soppressioni_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Soppressione {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione soppressione {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della soppressione {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebNewsletterSoppressione e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("Email", e.Email);
        cmd.Parameters.AddWithValue("Motivo", e.Motivo);
        cmd.Parameters.AddWithValue("Data", (object?)e.Data ?? DBNull.Value);
    }

    protected override WebNewsletterSoppressione MapFromReader(NpgsqlDataReader reader)
    {
        return new WebNewsletterSoppressione
        {
            WebNewsletterSoppressioneId = reader.GetInt64(reader.GetOrdinal("web_newsletter_soppressioni_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            Email = reader.GetString(reader.GetOrdinal("email")),
            Motivo = reader.GetString(reader.GetOrdinal("motivo")),
            Data = ReadNullableDateTime(reader, "data"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
