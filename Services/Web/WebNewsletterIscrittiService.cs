using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per gli iscritti newsletter (web_newsletter_iscritti).
/// Delega ogni operazione alle funzioni fn_web_newsletter_iscritti_* (Blocco 2).
/// TokenDisiscrizione e DataIscrizione sono generati dal DB (mai passati da C#).
/// Multi-tenant: ogni operazione è scopata per azienda_id, tranne GetByTokenAsync
/// (il token è il segreto del link di disiscrizione).
/// </summary>
public class WebNewsletterIscrittiService : BaseCrudService<WebNewsletterIscritto>
{
    protected override string TableName => "web_newsletter_iscritti";
    protected override string IdColumnName => "web_newsletter_iscritti_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebNewsletterIscrittiService(IDatabaseService databaseService, ILogger<WebNewsletterIscrittiService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco degli iscritti newsletter di un'azienda.</summary>
    public async Task<List<WebNewsletterIscritto>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_iscritti_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebNewsletterIscritto>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero iscritti newsletter per azienda {AziendaId}", aziendaId);
            return new List<WebNewsletterIscritto>();
        }
    }

    /// <summary>Recupera un iscritto per id, scopato per azienda. NULL se non trovato/altra azienda.</summary>
    public async Task<WebNewsletterIscritto?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_iscritti_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero iscritto newsletter {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Recupera un iscritto dal token di disiscrizione (flusso unsubscribe, senza azienda).</summary>
    public async Task<WebNewsletterIscritto?> GetByTokenAsync(string token)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_iscritti_by_token(@Token::varchar)", conn);
            cmd.Parameters.AddWithValue("Token", token);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero iscritto newsletter da token");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterIscritto> CreateAsync(WebNewsletterIscritto entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_iscritti_insert(
                @AziendaId::integer,
                @Email::citext,
                @Nome::varchar,
                @Cognome::varchar,
                @Lingua::varchar,
                @Consenso::boolean,
                @ConsensoData::timestamptz,
                @ConsensoFonte::varchar,
                @Stato::varchar,
                @ClienteFk::integer
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebNewsletterIscrittoId = Convert.ToInt64(result);

            _logger.LogInformation("Iscritto newsletter creato con ID {Id} ({Email})", entity.WebNewsletterIscrittoId, entity.Email);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione iscritto newsletter: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'iscritto newsletter {Email}", entity.Email);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterIscritto> UpdateAsync(WebNewsletterIscritto entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_iscritti_update(
                @Id::bigint,
                @AziendaId::integer,
                @Email::citext,
                @Nome::varchar,
                @Cognome::varchar,
                @Lingua::varchar,
                @Consenso::boolean,
                @ConsensoData::timestamptz,
                @ConsensoFonte::varchar,
                @Stato::varchar,
                @ClienteFk::integer
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebNewsletterIscrittoId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Iscritto newsletter {entity.WebNewsletterIscrittoId} non trovato per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Iscritto newsletter {Id} aggiornato", entity.WebNewsletterIscrittoId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento iscritto newsletter {Id}: {Error}", entity.WebNewsletterIscrittoId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'iscritto newsletter {Id}", entity.WebNewsletterIscrittoId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un iscritto newsletter, scopato per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_newsletter_iscritti_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Iscritto newsletter {Id} eliminato ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione iscritto newsletter {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione dell'iscritto newsletter {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// Token e data_iscrizione NON si passano: li genera il DB.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebNewsletterIscritto e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("Email", e.Email);
        cmd.Parameters.AddWithValue("Nome", (object?)e.Nome ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Cognome", (object?)e.Cognome ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Lingua", string.IsNullOrWhiteSpace(e.Lingua) ? "IT" : e.Lingua);
        cmd.Parameters.AddWithValue("Consenso", e.Consenso);
        cmd.Parameters.AddWithValue("ConsensoData", (object?)e.ConsensoData ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ConsensoFonte", (object?)e.ConsensoFonte ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Stato", string.IsNullOrWhiteSpace(e.Stato) ? "attivo" : e.Stato);
        cmd.Parameters.AddWithValue("ClienteFk", (object?)e.ClienteFk ?? DBNull.Value);
    }

    protected override WebNewsletterIscritto MapFromReader(NpgsqlDataReader reader)
    {
        return new WebNewsletterIscritto
        {
            WebNewsletterIscrittoId = reader.GetInt64(reader.GetOrdinal("web_newsletter_iscritti_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            Email = reader.GetString(reader.GetOrdinal("email")),
            Nome = ReadNullableString(reader, "nome"),
            Cognome = ReadNullableString(reader, "cognome"),
            Lingua = reader.GetString(reader.GetOrdinal("lingua")).Trim(),
            DataIscrizione = ReadNullableDateTime(reader, "data_iscrizione"),
            Consenso = reader.GetBoolean(reader.GetOrdinal("consenso")),
            ConsensoData = ReadNullableDateTime(reader, "consenso_data"),
            ConsensoFonte = ReadNullableString(reader, "consenso_fonte"),
            Stato = reader.GetString(reader.GetOrdinal("stato")),
            TokenDisiscrizione = ReadNullableString(reader, "token_disiscrizione"),
            ClienteFk = ReadNullableInt(reader, "cliente_fk"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
