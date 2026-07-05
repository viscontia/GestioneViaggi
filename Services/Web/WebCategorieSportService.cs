using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per le categorie sport del sito (web_categorie_sport).
/// Delega ogni operazione alle funzioni fn_web_categorie_sport_* (Blocco 2).
/// Multi-tenant: ogni operazione è scopata per azienda_id. Audit gestito dal
/// trigger DB trg_web_audit (l'utente arriva via my.app_user impostato da GetConnectionAsync).
/// </summary>
public class WebCategorieSportService : BaseCrudService<WebCategoriaSport>
{
    protected override string TableName => "web_categorie_sport";
    protected override string IdColumnName => "web_categorie_sport_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebCategorieSportService(IDatabaseService databaseService, ILogger<WebCategorieSportService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco delle categorie sport di un'azienda (ordinate per ordine, etichetta).</summary>
    public async Task<List<WebCategoriaSport>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_categorie_sport_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebCategoriaSport>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero categorie sport per azienda {AziendaId}", aziendaId);
            return new List<WebCategoriaSport>();
        }
    }

    /// <summary>Recupera una categoria per id, scopata per azienda. NULL se non trovata/altra azienda.</summary>
    public async Task<WebCategoriaSport?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_categorie_sport_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero categoria sport {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebCategoriaSport> CreateAsync(WebCategoriaSport entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_categorie_sport_insert(
                @AziendaId::integer,
                @Codice::varchar,
                @Etichetta::varchar,
                @Slug::varchar,
                @Ordine::integer
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebCategoriaSportId = Convert.ToInt64(result);

            _logger.LogInformation("Categoria sport creata con ID {Id} ({Codice})", entity.WebCategoriaSportId, entity.Codice);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione categoria sport: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della categoria sport {Codice}", entity.Codice);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebCategoriaSport> UpdateAsync(WebCategoriaSport entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_categorie_sport_update(
                @Id::bigint,
                @AziendaId::integer,
                @Codice::varchar,
                @Etichetta::varchar,
                @Slug::varchar,
                @Ordine::integer
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebCategoriaSportId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Categoria sport {entity.WebCategoriaSportId} non trovata per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Categoria sport {Id} aggiornata", entity.WebCategoriaSportId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento categoria sport {Id}: {Error}", entity.WebCategoriaSportId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della categoria sport {Id}", entity.WebCategoriaSportId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una categoria sport, scopata per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_categorie_sport_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Categoria sport {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione categoria sport {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della categoria sport {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebCategoriaSport e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("Codice", e.Codice);
        cmd.Parameters.AddWithValue("Etichetta", e.Etichetta);
        cmd.Parameters.AddWithValue("Slug", e.Slug);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
    }

    protected override WebCategoriaSport MapFromReader(NpgsqlDataReader reader)
    {
        return new WebCategoriaSport
        {
            WebCategoriaSportId = reader.GetInt64(reader.GetOrdinal("web_categorie_sport_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            Codice = reader.GetString(reader.GetOrdinal("codice")),
            Etichetta = reader.GetString(reader.GetOrdinal("etichetta")),
            Slug = reader.GetString(reader.GetOrdinal("slug")),
            Ordine = ReadInt(reader, "ordine"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
