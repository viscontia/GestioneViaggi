using System.Text.Json;
using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Config recensioni (§A.4): identificativi delle schede Google/TripAdvisor per il sito.</summary>
public sealed record RecensioniConfig(string? GooglePlaceId, string? TripAdvisorUrl);

/// <summary>
/// Service DB-First per i toggle funzioni web per-azienda (web_aziende_funzioni).
/// Delega alle funzioni fn_web_aziende_funzioni_* (Blocco 2). Chiave logica (azienda, funzione).
/// Multi-tenant: ogni operazione è scopata per azienda_id. Il campo JSONB `parametri` non è gestito qui.
/// </summary>
public class WebAziendeFunzioniService : BaseCrudService<WebAziendaFunzione>
{
    protected override string TableName => "web_aziende_funzioni";
    protected override string IdColumnName => "web_aziende_funzioni_id";
    protected override string? TenantColumnName => "azienda_id";

    /// <summary>Codici funzione noti gestiti dalla UI toggle (ordine di visualizzazione).</summary>
    public const string FunzioneNewsletter = "newsletter";
    public const string FunzioneRecensioni = "recensioni";
    public const string FunzioneBlog = "blog";
    public const string FunzionePagamentiOnline = "pagamenti_online";

    public WebAziendeFunzioniService(IDatabaseService databaseService, ILogger<WebAziendeFunzioniService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco delle funzioni configurate per un'azienda (solo le righe esistenti).</summary>
    public async Task<List<WebAziendaFunzione>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_aziende_funzioni_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebAziendaFunzione>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                results.Add(MapFromReader(reader));
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero funzioni web per azienda {AziendaId}", aziendaId);
            return new List<WebAziendaFunzione>();
        }
    }

    /// <summary>Recupera la riga per chiave logica (azienda, funzione). NULL se non configurata.</summary>
    public async Task<WebAziendaFunzione?> GetByFunzioneAsync(int aziendaId, string funzione)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_aziende_funzioni_get_by_funzione(@AziendaId::integer, @Funzione::varchar)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("Funzione", funzione);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero funzione '{Funzione}' per azienda {AziendaId}", funzione, aziendaId);
            return null;
        }
    }

    /// <summary>
    /// True se la funzione è attiva per l'azienda. Se non esiste una riga esplicita, ritorna
    /// <paramref name="defaultWhenMissing"/> (per 'newsletter' usiamo default=true → opt-out).
    /// </summary>
    public async Task<bool> IsAttivaAsync(int aziendaId, string funzione, bool defaultWhenMissing = false)
    {
        var row = await GetByFunzioneAsync(aziendaId, funzione);
        return row?.Attiva ?? defaultWhenMissing;
    }

    /// <summary>Newsletter attiva per l'azienda? Default true quando non configurata (feature già esistente → opt-out).</summary>
    public Task<bool> IsNewsletterEnabledAsync(int aziendaId) => IsAttivaAsync(aziendaId, FunzioneNewsletter, defaultWhenMissing: true);

    /// <summary>Imposta (upsert) lo stato attivo/disattivo di una funzione per l'azienda.</summary>
    public async Task SetAttivaAsync(int aziendaId, string funzione, bool attiva)
    {
        var existing = await GetByFunzioneAsync(aziendaId, funzione);
        if (existing is null)
            await CreateAsync(new WebAziendaFunzione { AziendaId = aziendaId, Funzione = funzione, Attiva = attiva });
        else
        {
            existing.Attiva = attiva;
            await UpdateAsync(existing);
        }
    }

    public override async Task<WebAziendaFunzione> CreateAsync(WebAziendaFunzione entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_aziende_funzioni_insert(@AziendaId::integer, @Funzione::varchar, @Attiva::boolean, @Parametri::jsonb)", conn);
            cmd.Parameters.AddWithValue("AziendaId", entity.AziendaId);
            cmd.Parameters.AddWithValue("Funzione", entity.Funzione);
            cmd.Parameters.AddWithValue("Attiva", entity.Attiva);
            cmd.Parameters.AddWithValue("Parametri", (object?)entity.Parametri ?? DBNull.Value);

            entity.WebAziendeFunzioniId = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Funzione web '{Funzione}' creata (id {Id}) per azienda {AziendaId} → {Attiva}", entity.Funzione, entity.WebAziendeFunzioniId, entity.AziendaId, entity.Attiva);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business creazione funzione web '{Funzione}': {Error}", entity.Funzione, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della funzione web '{Funzione}'", entity.Funzione);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebAziendaFunzione> UpdateAsync(WebAziendaFunzione entity)
    {
        NormalizeEntityBeforeSave(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_aziende_funzioni_update(@Id::bigint, @AziendaId::integer, @Funzione::varchar, @Attiva::boolean, @Parametri::jsonb)", conn);
            cmd.Parameters.AddWithValue("Id", entity.WebAziendeFunzioniId);
            cmd.Parameters.AddWithValue("AziendaId", entity.AziendaId);
            cmd.Parameters.AddWithValue("Funzione", entity.Funzione);
            cmd.Parameters.AddWithValue("Attiva", entity.Attiva);
            cmd.Parameters.AddWithValue("Parametri", (object?)entity.Parametri ?? DBNull.Value);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
                throw new InvalidOperationException($"Funzione web {entity.WebAziendeFunzioniId} non trovata per l'azienda {entity.AziendaId}.");

            _logger.LogInformation("Funzione web '{Funzione}' (id {Id}) aggiornata → {Attiva}", entity.Funzione, entity.WebAziendeFunzioniId, entity.Attiva);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business aggiornamento funzione web {Id}: {Error}", entity.WebAziendeFunzioniId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della funzione web {Id}", entity.WebAziendeFunzioniId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override WebAziendaFunzione MapFromReader(NpgsqlDataReader reader) => new()
    {
        WebAziendeFunzioniId = reader.GetInt64(reader.GetOrdinal("web_aziende_funzioni_id")),
        Funzione = reader.GetString(reader.GetOrdinal("funzione")),
        Attiva = reader.GetBoolean(reader.GetOrdinal("attiva")),
        Parametri = NJson(reader, "parametri"),
        AziendaId = reader.GetInt32(reader.GetOrdinal("azienda_id")),
        CreatedBy = NStr(reader, "created_by"),
        Created = NDt(reader, "created"),
        UpdatedBy = NStr(reader, "updated_by"),
        Updated = NDt(reader, "updated"),
    };

    private static string? NStr(NpgsqlDataReader r, string col)
    {
        var o = r.GetOrdinal(col);
        return r.IsDBNull(o) ? null : r.GetString(o);
    }

    private static DateTime? NDt(NpgsqlDataReader r, string col)
    {
        var o = r.GetOrdinal(col);
        return r.IsDBNull(o) ? null : r.GetDateTime(o);
    }

    private static string? NJson(NpgsqlDataReader r, string col)
    {
        var o = r.GetOrdinal(col);
        return r.IsDBNull(o) ? null : r.GetFieldValue<string>(o);
    }

    // ---- Recensioni (§A.4): config Google/TripAdvisor nel JSONB `parametri` ---------

    /// <summary>Legge la config recensioni (Place ID Google + URL TripAdvisor) dal JSONB della riga 'recensioni'.</summary>
    public async Task<RecensioniConfig> GetRecensioniConfigAsync(int aziendaId)
    {
        var row = await GetByFunzioneAsync(aziendaId, FunzioneRecensioni);
        return ParseRecensioni(row?.Parametri);
    }

    /// <summary>Salva (upsert) la config recensioni preservando lo stato attiva. Se la riga non esiste la crea attiva.</summary>
    public async Task SaveRecensioniConfigAsync(int aziendaId, RecensioniConfig config)
    {
        var placeId = string.IsNullOrWhiteSpace(config.GooglePlaceId) ? null : config.GooglePlaceId!.Trim();
        var tripUrl = string.IsNullOrWhiteSpace(config.TripAdvisorUrl) ? null : config.TripAdvisorUrl!.Trim();

        string? json = null;
        if (placeId is not null || tripUrl is not null)
        {
            var dict = new Dictionary<string, string>();
            if (placeId is not null) dict["google_place_id"] = placeId;
            if (tripUrl is not null) dict["tripadvisor_url"] = tripUrl;
            json = JsonSerializer.Serialize(dict);
        }

        var existing = await GetByFunzioneAsync(aziendaId, FunzioneRecensioni);
        if (existing is null)
            await CreateAsync(new WebAziendaFunzione { AziendaId = aziendaId, Funzione = FunzioneRecensioni, Attiva = true, Parametri = json });
        else
        {
            existing.Parametri = json;
            await UpdateAsync(existing);
        }
    }

    private static RecensioniConfig ParseRecensioni(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new RecensioniConfig(null, null);
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            string? Get(string key) => root.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
            return new RecensioniConfig(Get("google_place_id"), Get("tripadvisor_url"));
        }
        catch
        {
            return new RecensioniConfig(null, null);
        }
    }
}
