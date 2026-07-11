using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per le giornate dell'itinerario tour (web_tour_itinerario).
/// Wrappa fn_web_tour_itinerario_*. Multi-tenant (azienda_id); audit via trg_web_audit.
/// </summary>
public class WebTourItinerarioService : BaseCrudService<WebTourItinerario>
{
    protected override string TableName => "web_tour_itinerario";
    protected override string IdColumnName => "web_tour_itinerario_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTourItinerarioService(IDatabaseService databaseService, ILogger<WebTourItinerarioService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Giornate dell'itinerario di un contenuto (ordinate lato DB).</summary>
    public async Task<List<WebTourItinerario>> ListByContenutoAsync(long contenutoId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_itinerario_list(@ContenutoId::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ContenutoId", contenutoId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTourItinerario>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero itinerario per contenuto {ContenutoId} azienda {AziendaId}", contenutoId, aziendaId);
            return new List<WebTourItinerario>();
        }
    }

    /// <summary>Recupera una giornata per id, scopata per azienda.</summary>
    public async Task<WebTourItinerario?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_itinerario_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero giornata itinerario {Id} azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourItinerario> CreateAsync(WebTourItinerario entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_itinerario_insert(
                @AziendaId::integer, @WebTourContenutoIdFk::bigint, @GiornoNumero::integer, @TitoloGiornata::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            entity.WebTourItinerarioId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Giornata itinerario creata ID {Id} (contenuto {ContenutoId})", entity.WebTourItinerarioId, entity.WebTourContenutoIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business creazione giornata itinerario: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione giornata itinerario (contenuto {ContenutoId})", entity.WebTourContenutoIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourItinerario> UpdateAsync(WebTourItinerario entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            const string sql = @"SELECT fn_web_tour_itinerario_update(
                @Id::bigint, @AziendaId::integer, @WebTourContenutoIdFk::bigint, @GiornoNumero::integer, @TitoloGiornata::varchar, @Ordine::integer)";
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTourItinerarioId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Giornata itinerario {entity.WebTourItinerarioId} non trovata per l'azienda {entity.AziendaId}.");

            _logger.LogInformation("Giornata itinerario {Id} aggiornata", entity.WebTourItinerarioId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business aggiornamento giornata itinerario {Id}: {Error}", entity.WebTourItinerarioId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento giornata itinerario {Id}", entity.WebTourItinerarioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una giornata (cascata sui passaggi lato DB), scopata per azienda.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_itinerario_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Giornata itinerario {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business eliminazione giornata itinerario {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione giornata itinerario {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Riordina atomicamente le giornate del contenuto: la posizione degli id nell'array
    /// diventa il nuovo giorno_numero/ordine (fn_web_tour_itinerario_reorder, UNNEST WITH ORDINALITY).
    /// Ritorna il numero di righe aggiornate.
    /// </summary>
    public async Task<int> ReorderAsync(int aziendaId, long contenutoId, IReadOnlyList<long> orderedIds)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_tour_itinerario_reorder(@AziendaId::integer, @ContenutoId::bigint, @Ids::bigint[])", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("ContenutoId", contenutoId);
            cmd.Parameters.AddWithValue("Ids", orderedIds.ToArray());

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Riordino {Rows} giornate itinerario (contenuto {ContenutoId})", rows, contenutoId);
            return rows;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore riordino giornate itinerario (contenuto {ContenutoId})", contenutoId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    private static void BindWritableParams(NpgsqlCommand cmd, WebTourItinerario e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("WebTourContenutoIdFk", e.WebTourContenutoIdFk);
        cmd.Parameters.AddWithValue("GiornoNumero", e.GiornoNumero);
        cmd.Parameters.AddWithValue("TitoloGiornata", e.TitoloGiornata);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
    }

    protected override WebTourItinerario MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTourItinerario
        {
            WebTourItinerarioId = reader.GetInt64(reader.GetOrdinal("web_tour_itinerario_id")),
            WebTourContenutoIdFk = reader.GetInt64(reader.GetOrdinal("web_tour_contenuti_id_fk")),
            AziendaId = ReadInt(reader, "azienda_id"),
            GiornoNumero = ReadInt(reader, "giorno_numero"),
            TitoloGiornata = reader.GetString(reader.GetOrdinal("titolo_giornata")),
            Ordine = ReadInt(reader, "ordine"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
