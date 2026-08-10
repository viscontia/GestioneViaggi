using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Rubrica degli indirizzi web dell'azienda (script 517). Le guardie (URL con protocollo,
/// descrizione unica) stanno sui vincoli della tabella: qui si lasciano passare tradotte dal
/// dizionario centrale, non si riscrivono.
/// </summary>
public sealed class WebIndirizziService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<WebIndirizziService> _logger;

    public WebIndirizziService(IDatabaseService db, ILogger<WebIndirizziService> logger)
    {
        _db = db; _logger = logger;
    }

    public async Task<List<WebIndirizzo>> ListAsync(int aziendaId, bool soloAttivi = false)
    {
        var list = new List<WebIndirizzo>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_web_indirizzi_list(@Az::integer, @Attivi::boolean)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Attivi", soloAttivi);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    public async Task<long> CreateAsync(WebIndirizzo e)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_indirizzi_insert(@Az::integer, @Descr::varchar, @Url::varchar, @Note::text, NULL::integer, @Attivo::boolean)", conn);
            Bind(cmd, e);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione indirizzo web per azienda {Az}", e.AziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "web_indirizzi");
        }
    }

    public async Task<bool> UpdateAsync(WebIndirizzo e)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_indirizzi_update(@Id::bigint, @Az::integer, @Descr::varchar, @Url::varchar, @Note::text, @Ordine::integer, @Attivo::boolean)", conn);
            cmd.Parameters.AddWithValue("Id", e.WebIndirizzoId);
            cmd.Parameters.AddWithValue("Ordine", e.Ordine);
            Bind(cmd, e);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento indirizzo web {Id}", e.WebIndirizzoId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "web_indirizzi");
        }
    }

    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_indirizzi_delete(@Id::bigint, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Id", id);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
    }

    private static void Bind(NpgsqlCommand cmd, WebIndirizzo e)
    {
        cmd.Parameters.AddWithValue("Az", e.AziendaId);
        cmd.Parameters.AddWithValue("Descr", (object?)e.Descrizione ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Url", (object?)e.Url ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Note", (object?)e.Note ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Attivo", e.Attivo);
    }

    private static WebIndirizzo Map(NpgsqlDataReader r) => new()
    {
        WebIndirizzoId = r.GetInt64(r.GetOrdinal("web_indirizzi_id")),
        Descrizione    = r.GetString(r.GetOrdinal("descrizione")),
        Url            = r.GetString(r.GetOrdinal("url")),
        Note           = r.IsDBNull(r.GetOrdinal("note")) ? null : r.GetString(r.GetOrdinal("note")),
        Ordine         = r.GetInt32(r.GetOrdinal("ordine")),
        Attivo         = r.GetBoolean(r.GetOrdinal("attivo")),
        AziendaId      = r.GetInt32(r.GetOrdinal("azienda_id")),
    };
}
