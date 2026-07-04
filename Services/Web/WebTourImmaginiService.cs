using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per le immagini del tour (web_tour_immagini).
/// Wrappa fn_web_tour_immagini_*. Multi-tenant (azienda_id); audit via trg_web_audit.
/// Il binario risiede su IWebMediaStorage: qui si persistono url + storage_path.
/// </summary>
public class WebTourImmaginiService : BaseCrudService<WebTourImmagine>
{
    protected override string TableName => "web_tour_immagini";
    protected override string IdColumnName => "web_tour_immagini_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTourImmaginiService(IDatabaseService databaseService, ILogger<WebTourImmaginiService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Immagini di un viaggio (ordinate lato DB).</summary>
    public async Task<List<WebTourImmagine>> ListByViaggioAsync(int viaggioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_immagini_list(@ViaggioId::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTourImmagine>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero immagini per viaggio {ViaggioId} azienda {AziendaId}", viaggioId, aziendaId);
            return new List<WebTourImmagine>();
        }
    }

    /// <summary>Recupera un'immagine per id, scopata per azienda.</summary>
    public async Task<WebTourImmagine?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_immagini_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero immagine {Id} azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourImmagine> CreateAsync(WebTourImmagine entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            // Ordine argomenti insert: azienda, viaggio, url, storage_path, tipo, alt, titolo, larghezza, altezza, mime, ordine
            const string sql = @"SELECT fn_web_tour_immagini_insert(
                @AziendaId::integer, @ViaggioIdFk::integer, @Url::text, @StoragePath::varchar,
                @Tipo::varchar, @AltText::varchar, @Titolo::varchar,
                @Larghezza::integer, @Altezza::integer, @Mime::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            entity.WebTourImmagineId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Immagine creata ID {Id} (viaggio {ViaggioId})", entity.WebTourImmagineId, entity.ViaggioIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business creazione immagine: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione immagine (viaggio {ViaggioId})", entity.ViaggioIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourImmagine> UpdateAsync(WebTourImmagine entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            // Ordine argomenti update: id, azienda, viaggio, tipo, url, storage_path, alt, titolo, larghezza, altezza, mime, ordine
            const string sql = @"SELECT fn_web_tour_immagini_update(
                @Id::bigint, @AziendaId::integer, @ViaggioIdFk::integer, @Tipo::varchar,
                @Url::text, @StoragePath::varchar, @AltText::varchar, @Titolo::varchar,
                @Larghezza::integer, @Altezza::integer, @Mime::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTourImmagineId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Immagine {entity.WebTourImmagineId} non trovata per l'azienda {entity.AziendaId}.");

            _logger.LogInformation("Immagine {Id} aggiornata", entity.WebTourImmagineId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business aggiornamento immagine {Id}: {Error}", entity.WebTourImmagineId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento immagine {Id}", entity.WebTourImmagineId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un'immagine (record DB), scopata per azienda.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_immagini_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Immagine {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business eliminazione immagine {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione immagine {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    private static void BindWritableParams(NpgsqlCommand cmd, WebTourImmagine e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("ViaggioIdFk", e.ViaggioIdFk);
        cmd.Parameters.AddWithValue("Tipo", string.IsNullOrWhiteSpace(e.Tipo) ? "galleria" : e.Tipo);
        cmd.Parameters.AddWithValue("Url", e.Url);
        cmd.Parameters.AddWithValue("StoragePath", e.StoragePath);
        cmd.Parameters.AddWithValue("AltText", (object?)e.AltText ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Titolo", (object?)e.Titolo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Larghezza", (object?)e.Larghezza ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Altezza", (object?)e.Altezza ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Mime", (object?)e.Mime ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
    }

    protected override WebTourImmagine MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTourImmagine
        {
            WebTourImmagineId = reader.GetInt64(reader.GetOrdinal("web_tour_immagini_id")),
            ViaggioIdFk = ReadInt(reader, "viaggio_id_fk"),
            AziendaId = ReadInt(reader, "azienda_id"),
            Tipo = reader.GetString(reader.GetOrdinal("tipo")),
            Url = reader.GetString(reader.GetOrdinal("url")),
            StoragePath = reader.GetString(reader.GetOrdinal("storage_path")),
            AltText = ReadNullableString(reader, "alt_text"),
            Titolo = ReadNullableString(reader, "titolo"),
            Larghezza = ReadNullableInt(reader, "larghezza"),
            Altezza = ReadNullableInt(reader, "altezza"),
            Mime = ReadNullableString(reader, "mime"),
            Ordine = ReadInt(reader, "ordine"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
