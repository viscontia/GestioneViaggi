using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per i passaggi di una giornata dell'itinerario
/// (web_tour_itinerario_passaggi). Wrappa fn_web_tour_itinerario_passaggi_*.
/// Multi-tenant (azienda_id); audit via trg_web_audit.
/// </summary>
public class WebTourItinerarioPassaggiService : BaseCrudService<WebTourItinerarioPassaggio>
{
    protected override string TableName => "web_tour_itinerario_passaggi";
    protected override string IdColumnName => "web_tour_itinerario_passaggi_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTourItinerarioPassaggiService(IDatabaseService databaseService, ILogger<WebTourItinerarioPassaggiService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Passaggi di una giornata (ordinati lato DB).</summary>
    public async Task<List<WebTourItinerarioPassaggio>> ListByItinerarioAsync(long itinerarioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_itinerario_passaggi_list(@ItinerarioId::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ItinerarioId", itinerarioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTourItinerarioPassaggio>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero passaggi per itinerario {ItinerarioId} azienda {AziendaId}", itinerarioId, aziendaId);
            return new List<WebTourItinerarioPassaggio>();
        }
    }

    /// <summary>Recupera un passaggio per id, scopato per azienda.</summary>
    public async Task<WebTourItinerarioPassaggio?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_itinerario_passaggi_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero passaggio {Id} azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourItinerarioPassaggio> CreateAsync(WebTourItinerarioPassaggio entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_itinerario_passaggi_insert(
                @AziendaId::integer, @ItinerarioIdFk::bigint, @TestoHtml::text,
                @ImmagineUrl::text, @ImmagineStoragePath::varchar, @ImmagineDidascalia::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            entity.WebTourItinerarioPassaggioId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Passaggio creato ID {Id} (itinerario {ItinerarioId})", entity.WebTourItinerarioPassaggioId, entity.ItinerarioIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business creazione passaggio: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione passaggio (itinerario {ItinerarioId})", entity.ItinerarioIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourItinerarioPassaggio> UpdateAsync(WebTourItinerarioPassaggio entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_itinerario_passaggi_update(
                @Id::bigint, @AziendaId::integer, @ItinerarioIdFk::bigint, @TestoHtml::text,
                @ImmagineUrl::text, @ImmagineStoragePath::varchar, @ImmagineDidascalia::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTourItinerarioPassaggioId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Passaggio {entity.WebTourItinerarioPassaggioId} non trovato per l'azienda {entity.AziendaId}.");

            _logger.LogInformation("Passaggio {Id} aggiornato", entity.WebTourItinerarioPassaggioId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business aggiornamento passaggio {Id}: {Error}", entity.WebTourItinerarioPassaggioId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento passaggio {Id}", entity.WebTourItinerarioPassaggioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un passaggio, scopato per azienda.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_itinerario_passaggi_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Passaggio {Id} eliminato ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business eliminazione passaggio {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione passaggio {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Riordina atomicamente i passi di UNA giornata: ogni id viene (ri)assegnato a
    /// <paramref name="itinerarioId"/> e la sua posizione nell'array diventa il nuovo ordine
    /// (fn_web_tour_itinerario_passaggi_reorder). Gestisce il cross-day: un id proveniente da
    /// un'altra giornata viene reparentato. Su uno spostamento cross-day chiamare per la zona di
    /// ARRIVO e per quella di PARTENZA. Ritorna il numero di righe aggiornate.
    /// </summary>
    public async Task<int> ReorderAsync(int aziendaId, long itinerarioId, IReadOnlyList<long> orderedIds)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_tour_itinerario_passaggi_reorder(@AziendaId::integer, @ItinerarioId::bigint, @Ids::bigint[])", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("ItinerarioId", itinerarioId);
            cmd.Parameters.AddWithValue("Ids", orderedIds.ToArray());

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Riordino {Rows} passi (giornata {ItinerarioId})", rows, itinerarioId);
            return rows;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore riordino passi (giornata {ItinerarioId})", itinerarioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    private static void BindWritableParams(NpgsqlCommand cmd, WebTourItinerarioPassaggio e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("ItinerarioIdFk", e.ItinerarioIdFk);
        cmd.Parameters.AddWithValue("TestoHtml", e.TestoHtml);
        cmd.Parameters.AddWithValue("ImmagineUrl", (object?)e.ImmagineUrl ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ImmagineStoragePath", (object?)e.ImmagineStoragePath ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ImmagineDidascalia", (object?)e.ImmagineDidascalia ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
    }

    protected override WebTourItinerarioPassaggio MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTourItinerarioPassaggio
        {
            WebTourItinerarioPassaggioId = reader.GetInt64(reader.GetOrdinal("web_tour_itinerario_passaggi_id")),
            ItinerarioIdFk = reader.GetInt64(reader.GetOrdinal("itinerario_id_fk")),
            AziendaId = ReadInt(reader, "azienda_id"),
            TestoHtml = reader.GetString(reader.GetOrdinal("testo_html")),
            ImmagineUrl = ReadNullableString(reader, "immagine_url"),
            ImmagineStoragePath = ReadNullableString(reader, "immagine_storage_path"),
            ImmagineDidascalia = ReadNullableString(reader, "immagine_didascalia"),
            Ordine = ReadInt(reader, "ordine"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
