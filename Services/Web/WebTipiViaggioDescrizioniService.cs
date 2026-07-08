using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per le descrizioni web dei tipi di viaggio (web_tipi_viaggio_descrizioni,
/// ex web_categorie_sport). Tabella GLOBALE (nessun azienda_id). Delega a fn_web_tipi_viaggio_descrizioni_*.
/// Audit gestito dal trigger DB (l'utente arriva via my.app_user impostato da GetConnectionAsync).
/// </summary>
public class WebTipiViaggioDescrizioniService : BaseCrudService<WebTipoViaggioDescrizione>
{
    protected override string TableName => "web_tipi_viaggio_descrizioni";
    protected override string IdColumnName => "web_tipi_viaggio_descrizioni_id";

    public WebTipiViaggioDescrizioniService(IDatabaseService databaseService, ILogger<WebTipiViaggioDescrizioniService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco globale delle descrizioni web (ordinate per ordine, descrizione).</summary>
    public async Task<List<WebTipoViaggioDescrizione>> ListAsync()
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tipi_viaggio_descrizioni_list()", conn);

            var results = new List<WebTipoViaggioDescrizione>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                results.Add(MapFromReader(reader));
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero descrizioni web tipi viaggio");
            return new List<WebTipoViaggioDescrizione>();
        }
    }

    public async Task<WebTipoViaggioDescrizione?> GetByIdAsync(long id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tipi_viaggio_descrizioni_get(@Id::bigint)", conn);
            cmd.Parameters.AddWithValue("Id", id);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero descrizione web {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTipoViaggioDescrizione> CreateAsync(WebTipoViaggioDescrizione entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = "SELECT fn_web_tipi_viaggio_descrizioni_insert(@DescrizioneWeb::varchar, @Slug::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            entity.WebTipoViaggioDescrizioneId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Descrizione web creata con ID {Id} ({Descr})", entity.WebTipoViaggioDescrizioneId, entity.DescrizioneWeb);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della descrizione web {Descr}", entity.DescrizioneWeb);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTipoViaggioDescrizione> UpdateAsync(WebTipoViaggioDescrizione entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = "SELECT fn_web_tipi_viaggio_descrizioni_update(@Id::bigint, @DescrizioneWeb::varchar, @Slug::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTipoViaggioDescrizioneId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Descrizione web {entity.WebTipoViaggioDescrizioneId} non trovata.");

            _logger.LogInformation("Descrizione web {Id} aggiornata", entity.WebTipoViaggioDescrizioneId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della descrizione web {Id}", entity.WebTipoViaggioDescrizioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una descrizione web. La FK ana_tipo_viaggi.descrizione_web_fk è ON DELETE SET NULL.</summary>
    public async Task<bool> DeleteAsync(long id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tipi_viaggio_descrizioni_delete(@Id::bigint)", conn);
            cmd.Parameters.AddWithValue("Id", id);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Descrizione web {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della descrizione web {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    private static void BindWritableParams(NpgsqlCommand cmd, WebTipoViaggioDescrizione e)
    {
        cmd.Parameters.AddWithValue("DescrizioneWeb", e.DescrizioneWeb);
        cmd.Parameters.AddWithValue("Slug", e.Slug);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
    }

    protected override WebTipoViaggioDescrizione MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTipoViaggioDescrizione
        {
            WebTipoViaggioDescrizioneId = reader.GetInt64(reader.GetOrdinal("web_tipi_viaggio_descrizioni_id")),
            DescrizioneWeb = reader.GetString(reader.GetOrdinal("descrizione_web")),
            Slug = reader.GetString(reader.GetOrdinal("slug")),
            Ordine = ReadInt(reader, "ordine"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
