using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per la mappa statica del tour (web_tour_mappa), relazione 1:1 col viaggio.
/// Wrappa fn_web_tour_mappa_*. Multi-tenant (azienda_id); audit via trg_web_audit.
/// </summary>
public class WebTourMappaService : BaseCrudService<WebTourMappa>
{
    protected override string TableName => "web_tour_mappa";
    protected override string IdColumnName => "web_tour_mappa_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTourMappaService(IDatabaseService databaseService, ILogger<WebTourMappaService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Tutte le mappe di un'azienda.</summary>
    public async Task<List<WebTourMappa>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_mappa_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTourMappa>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero mappe per azienda {AziendaId}", aziendaId);
            return new List<WebTourMappa>();
        }
    }

    /// <summary>Recupera una mappa per id, scopata per azienda.</summary>
    public async Task<WebTourMappa?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_mappa_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero mappa {Id} azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Recupera la mappa associata a un viaggio (relazione 1:1), scopata per azienda.</summary>
    public async Task<WebTourMappa?> GetByViaggioAsync(int viaggioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_mappa_get_by_viaggio(@ViaggioId::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero mappa per viaggio {ViaggioId} azienda {AziendaId}", viaggioId, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourMappa> CreateAsync(WebTourMappa entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_mappa_insert(
                @AziendaId::integer, @ViaggioIdFk::integer, @GpxOriginale::text, @GpxFilename::varchar,
                @BboxMinLat::numeric, @BboxMinLon::numeric, @BboxMaxLat::numeric, @BboxMaxLon::numeric,
                @Provider::varchar, @Stile::varchar, @ParametriRender::jsonb,
                @ImmagineUrl::text, @ImmagineStoragePath::varchar, @DataGenerazione::timestamptz)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            entity.WebTourMappaId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Mappa creata ID {Id} (viaggio {ViaggioId})", entity.WebTourMappaId, entity.ViaggioIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business creazione mappa: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione mappa (viaggio {ViaggioId})", entity.ViaggioIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourMappa> UpdateAsync(WebTourMappa entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_mappa_update(
                @Id::bigint, @AziendaId::integer, @ViaggioIdFk::integer, @GpxOriginale::text, @GpxFilename::varchar,
                @BboxMinLat::numeric, @BboxMinLon::numeric, @BboxMaxLat::numeric, @BboxMaxLon::numeric,
                @Provider::varchar, @Stile::varchar, @ParametriRender::jsonb,
                @ImmagineUrl::text, @ImmagineStoragePath::varchar, @DataGenerazione::timestamptz)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTourMappaId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Mappa {entity.WebTourMappaId} non trovata per l'azienda {entity.AziendaId}.");

            _logger.LogInformation("Mappa {Id} aggiornata", entity.WebTourMappaId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business aggiornamento mappa {Id}: {Error}", entity.WebTourMappaId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento mappa {Id}", entity.WebTourMappaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una mappa, scopata per azienda.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_mappa_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Mappa {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business eliminazione mappa {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione mappa {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    private static void BindWritableParams(NpgsqlCommand cmd, WebTourMappa e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("ViaggioIdFk", e.ViaggioIdFk);
        cmd.Parameters.AddWithValue("GpxOriginale", (object?)e.GpxOriginale ?? DBNull.Value);
        cmd.Parameters.AddWithValue("GpxFilename", (object?)e.GpxFilename ?? DBNull.Value);
        cmd.Parameters.AddWithValue("BboxMinLat", (object?)e.BboxMinLat ?? DBNull.Value);
        cmd.Parameters.AddWithValue("BboxMinLon", (object?)e.BboxMinLon ?? DBNull.Value);
        cmd.Parameters.AddWithValue("BboxMaxLat", (object?)e.BboxMaxLat ?? DBNull.Value);
        cmd.Parameters.AddWithValue("BboxMaxLon", (object?)e.BboxMaxLon ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Provider", (object?)e.Provider ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Stile", (object?)e.Stile ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ParametriRender", (object?)e.ParametriRender ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ImmagineUrl", (object?)e.ImmagineUrl ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ImmagineStoragePath", (object?)e.ImmagineStoragePath ?? DBNull.Value);
        cmd.Parameters.AddWithValue("DataGenerazione", (object?)e.DataGenerazione ?? DBNull.Value);
    }

    protected override WebTourMappa MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTourMappa
        {
            WebTourMappaId = reader.GetInt64(reader.GetOrdinal("web_tour_mappa_id")),
            ViaggioIdFk = ReadInt(reader, "viaggio_id_fk"),
            AziendaId = ReadInt(reader, "azienda_id"),
            GpxOriginale = ReadNullableString(reader, "gpx_originale"),
            GpxFilename = ReadNullableString(reader, "gpx_filename"),
            BboxMinLat = ReadNullableDecimal(reader, "bbox_min_lat"),
            BboxMinLon = ReadNullableDecimal(reader, "bbox_min_lon"),
            BboxMaxLat = ReadNullableDecimal(reader, "bbox_max_lat"),
            BboxMaxLon = ReadNullableDecimal(reader, "bbox_max_lon"),
            Provider = ReadNullableString(reader, "provider"),
            Stile = ReadNullableString(reader, "stile"),
            ParametriRender = ReadNullableString(reader, "parametri_render"),
            ImmagineUrl = ReadNullableString(reader, "immagine_url"),
            ImmagineStoragePath = ReadNullableString(reader, "immagine_storage_path"),
            DataGenerazione = ReadNullableDateTime(reader, "data_generazione"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
