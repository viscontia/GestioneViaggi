using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per il log consegna destinatari di un invio newsletter
/// (web_newsletter_invii_destinatari). Delega alle funzioni
/// fn_web_newsletter_invii_destinatari_* (Blocco 2).
/// Multi-tenant: ogni operazione è scopata per azienda_id.
/// </summary>
public class WebNewsletterInviiDestinatariService : BaseCrudService<WebNewsletterInvioDestinatario>
{
    protected override string TableName => "web_newsletter_invii_destinatari";
    protected override string IdColumnName => "web_newsletter_invii_destinatari_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebNewsletterInviiDestinatariService(IDatabaseService databaseService, ILogger<WebNewsletterInviiDestinatariService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco dei destinatari di un invio, scopato per azienda.</summary>
    public async Task<List<WebNewsletterInvioDestinatario>> ListByInvioAsync(long invioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_invii_destinatari_list(@InvioId::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("InvioId", invioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebNewsletterInvioDestinatario>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero destinatari invio {InvioId} per azienda {AziendaId}", invioId, aziendaId);
            return new List<WebNewsletterInvioDestinatario>();
        }
    }

    /// <summary>Recupera un destinatario per id, scopato per azienda. NULL se non trovato/altra azienda.</summary>
    public async Task<WebNewsletterInvioDestinatario?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_invii_destinatari_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero destinatario invio {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterInvioDestinatario> CreateAsync(WebNewsletterInvioDestinatario entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_invii_destinatari_insert(
                @AziendaId::integer,
                @InvioIdFk::bigint,
                @Email::citext,
                @Lingua::varchar,
                @StatoConsegna::varchar,
                @Data::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebNewsletterInvioDestinatarioId = Convert.ToInt64(result);

            _logger.LogInformation("Destinatario invio creato con ID {Id} (invio {InvioId})", entity.WebNewsletterInvioDestinatarioId, entity.InvioIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione destinatario invio: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del destinatario invio (invio {InvioId})", entity.InvioIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterInvioDestinatario> UpdateAsync(WebNewsletterInvioDestinatario entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_invii_destinatari_update(
                @Id::bigint,
                @AziendaId::integer,
                @InvioIdFk::bigint,
                @Email::citext,
                @Lingua::varchar,
                @StatoConsegna::varchar,
                @Data::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebNewsletterInvioDestinatarioId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Destinatario invio {entity.WebNewsletterInvioDestinatarioId} non trovato per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Destinatario invio {Id} aggiornato", entity.WebNewsletterInvioDestinatarioId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento destinatario invio {Id}: {Error}", entity.WebNewsletterInvioDestinatarioId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del destinatario invio {Id}", entity.WebNewsletterInvioDestinatarioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un destinatario, scopato per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_newsletter_invii_destinatari_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Destinatario invio {Id} eliminato ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione destinatario invio {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del destinatario invio {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebNewsletterInvioDestinatario e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("InvioIdFk", e.InvioIdFk);
        cmd.Parameters.AddWithValue("Email", e.Email);
        cmd.Parameters.AddWithValue("Lingua", (object?)e.Lingua ?? DBNull.Value);
        cmd.Parameters.AddWithValue("StatoConsegna", (object?)e.StatoConsegna ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Data", (object?)e.Data ?? DBNull.Value);
    }

    protected override WebNewsletterInvioDestinatario MapFromReader(NpgsqlDataReader reader)
    {
        var lingua = ReadNullableString(reader, "lingua");
        return new WebNewsletterInvioDestinatario
        {
            WebNewsletterInvioDestinatarioId = reader.GetInt64(reader.GetOrdinal("web_newsletter_invii_destinatari_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            InvioIdFk = reader.GetInt64(reader.GetOrdinal("invio_id_fk")),
            Email = reader.GetString(reader.GetOrdinal("email")),
            Lingua = lingua?.Trim(),
            StatoConsegna = ReadNullableString(reader, "stato_consegna"),
            Data = ReadNullableDateTime(reader, "data"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
